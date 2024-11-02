// SPDX-License-Identifier: MIT
// vaultka 收益领取合约
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { RecoverERC20 } from "./libraries/RecoverERC20.mock.sol";
import { IChefIncentivesController, ICICUserDefinedTypes } from "./IVotingEscrow/IChefIncentivesController.mock.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/// @title ChefIncentivesController Contract
/// @author Vaultka
/// based on Radiant and Sushi MasterChef
///	https://github.com/sushiswap/sushiswap/blob/master/contracts/MasterChef.sol
/// https://github.com/radiant-capital/v2/blob/main/contracts/radiant/staking/ChefIncentivesController.sol

contract VeTokenChefUSDC is
    IChefIncentivesController,
    ICICUserDefinedTypes,
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    RecoverERC20
{
    using SafeERC20 for IERC20;
    // multiplier for reward calc
    uint256 private constant ACC_REWARD_PRECISION = 1e30;
    /********************** Emission Info ***********************/
    // Array of tokens for reward
    address[] public registeredTokens;

    // Current reward per second
    uint256 public rewardsPerSecond;

    // last RPS, used during refill after reserve empty
    uint256 public lastRPS;

    // Info of each pool.
    mapping(address => PoolInfo) public poolInfo;

    // valid pool tokens(?)
    mapping(address => bool) private vaildPODToken;

    // Total allocation points. Must be the sum of all allocation points in all pools.

    uint256 public totalAllocPoint;
    // token => user => Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // user => base claimable balance
    mapping(address => uint256) public userBaseClaimable;

    // MFD, bounties, AC
    mapping(address => bool) public eligibilityExempt;

    // The block number when reward mining starts.
    uint256 public startTime;

    // Amount of deposited rewards
    uint256 public depositedRewards;

    // Amount of accumulated rewards
    uint256 public accountedRewards;

    // Timestamp when all pools updated
    uint256 public lastAllPoolUpdate;
    //use the mainchain / sidechain
    address public veContract;
    // Info of reward emission end time
    EndingTime public endingTime;

    // Contracts that are authorized to handle r/vdToken actions without triggering elgiibility checks
    mapping(address => bool) public authorizedContracts;

    // Mapping of addresses that are whitelisted to perform state changing actions
    mapping(address => bool) public whitelist;

    address public rewardToken;

    uint256[50] private __gap;

    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) revert NotWhitelisted();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializer
     * @param _rewardsPerSecond RPS
     */
    function initialize(
        uint256 _rewardsPerSecond,
        address _rewardToken,
        address _veContract,
        uint256 _endingTimeCadence
    ) public initializer {
        if (_rewardToken == address(0)) revert AddressZero();
        if (_veContract == address(0)) revert AddressZero();

        endingTime.updateCadence = _endingTimeCadence;
        rewardToken = _rewardToken;
        veContract = _veContract;
        rewardsPerSecond = _rewardsPerSecond;
        whitelist[msg.sender] = true;
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /**
     * @dev Returns length of reward pools.
     */
    function poolLength() public view returns (uint256) {
        return registeredTokens.length;
    }

    /********************** Pool Setup + Admin ***********************/
    /**
     * @dev Starts RewardToken emission.
     */
    function start() public onlyOwner {
        if (startTime != 0) revert AlreadyStarted();
        startTime = block.timestamp;
    }

    /**
     * @dev Add a new lp to the pool. Can only be called by the owner.
     * @param _token for reward pool
     * @param _allocPoint allocation point of the pool
     */
    function addPool(address _token, uint256 _allocPoint) public onlyWhitelisted {
        if (poolInfo[_token].lastRewardTime != 0) revert PoolExists();
        _updateEmissions();
        totalAllocPoint = totalAllocPoint + _allocPoint;
        registeredTokens.push(_token);
        PoolInfo storage pool = poolInfo[_token];
        pool.allocPoint = _allocPoint;
        pool.lastRewardTime = block.timestamp;
        vaildPODToken[_token] = true;
    }

    /**
     * @dev Update the given pool's allocation point. Can only be called by the owner.
     * @param _tokens for reward pools
     * @param _allocPoints allocation points of the pools
     */
    function batchUpdateAllocPoint(
        address[] calldata _tokens,
        uint256[] calldata _allocPoints
    ) external onlyWhitelisted {
        if (_tokens.length != _allocPoints.length) revert ArrayLengthMismatch();
        _massUpdatePools();
        uint256 _totalAllocPoint = totalAllocPoint;
        uint256 length = _tokens.length;
        for (uint256 i; i < length; ) {
            PoolInfo storage pool = poolInfo[_tokens[i]];
            if (pool.lastRewardTime == 0) revert UnknownPool();
            _totalAllocPoint = _totalAllocPoint - pool.allocPoint + _allocPoints[i];
            pool.allocPoint = _allocPoints[i];
            unchecked {
                i++;
            }
        }
        totalAllocPoint = _totalAllocPoint;
        emit BatchAllocPointsUpdated(_tokens, _allocPoints);
    }

    /**
     * @notice Sets the reward per second to be distributed. Can only be called by the owner.
     * @dev Its decimals count is ACC_REWARD_PRECISION
     * @param _rewardsPerSecond The amount of reward to be distributed per second.
     */
    function setRewardsPerSecond(uint256 _rewardsPerSecond) external onlyWhitelisted {
        _massUpdatePools();
        rewardsPerSecond = _rewardsPerSecond;
        emit RewardsPerSecondUpdated(_rewardsPerSecond);
    }

    /**
     * @notice Recover tokens in this contract. Callable by owner.
     * @param tokenAddress Token address for recover
     * @param tokenAmount Amount to recover
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        _recoverERC20(tokenAddress, tokenAmount);
    }

    /********************** Pool State Changers ***********************/

    /**
     * @dev Update emission params of CIC.
     */
    function _updateEmissions() internal {
        if (block.timestamp > endRewardTime()) {
            _massUpdatePools();
            lastRPS = rewardsPerSecond;
            rewardsPerSecond = 0;
            return;
        }
    }

    /**
     * @dev Update reward variables for all pools.
     */
    function _massUpdatePools() internal {
        uint256 totalAP = totalAllocPoint;
        uint256 length = poolLength();
        for (uint256 i; i < length; ) {
            _updatePool(poolInfo[registeredTokens[i]], totalAP);
            unchecked {
                i++;
            }
        }
        lastAllPoolUpdate = block.timestamp;
    }

    /**
     * @dev Update reward variables of the given pool to be up-to-date.
     * @param pool pool info
     * @param _totalAllocPoint allocation point of the pool
     */
    function _updatePool(PoolInfo storage pool, uint256 _totalAllocPoint) internal {
        uint256 timestamp = block.timestamp;
        uint256 endReward = endRewardTime();
        if (endReward <= timestamp) {
            timestamp = endReward;
        }
        if (timestamp <= pool.lastRewardTime) {
            return;
        }

        (uint256 reward, uint256 newAccRewardPerShare) = _newRewards(pool, _totalAllocPoint);
        accountedRewards = accountedRewards + reward;
        pool.accRewardPerShare = pool.accRewardPerShare + newAccRewardPerShare;
        pool.lastRewardTime = timestamp;
    }

    /********************** Emission Calc + Transfer ***********************/
    /**
     * @notice Claim rewards.
     * @param _user address for claim
     * @param _tokens array of reward-bearing tokens
     */
    function claim(address _user, address[] memory _tokens) public nonReentrant whenNotPaused {
        _updateEmissions();
        uint256 currentTimestamp = block.timestamp;
        uint256 pending = userBaseClaimable[_user];
        userBaseClaimable[_user] = 0;
        uint256 _totalAllocPoint = totalAllocPoint;
        uint256 length = _tokens.length;
        for (uint256 i; i < length; ) {
            if (!vaildPODToken[_tokens[i]]) revert InvalidRToken();
            PoolInfo storage pool = poolInfo[_tokens[i]];
            if (pool.lastRewardTime == 0) revert UnknownPool();
            _updatePool(pool, _totalAllocPoint);
            UserInfo storage user = userInfo[_tokens[i]][_user];
            uint256 rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_REWARD_PRECISION;
            pending = pending + rewardDebt - user.rewardDebt;
            user.rewardDebt = rewardDebt;
            user.lastClaimTime = currentTimestamp;
            //@note Confirm that ve / POD amount cannot be transfer before using
            // _handleTokenAfterClaim(_tokens[i], _user);
            unchecked {
                i++;
            }
        }
        _sendRewardToken(_user, pending);

        emit Claimed(_user, pending);
    }

    /**
     * @notice Claim rewards entitled to all registered tokens.
     * @param _user address of the user
     */
    function claimAll(address _user) external {
        claim(_user, registeredTokens);
    }

    /**
     * @notice Pending rewards of a user for each pool (not total).
     * @param _user address for claim
     * @param _tokens array of reward-bearing tokens
     * @return claimable rewards array
     */
    function pendingRewards(address _user, address[] memory _tokens) public view returns (uint256[] memory) {
        uint256[] memory claimable = new uint256[](_tokens.length);
        uint256 length = _tokens.length;
        for (uint256 i; i < length; ) {
            address token = _tokens[i];
            PoolInfo storage pool = poolInfo[token];
            UserInfo storage user = userInfo[token][_user];
            uint256 accRewardPerShare = pool.accRewardPerShare;
            if (block.timestamp > pool.lastRewardTime) {
                (, uint256 newAccRewardPerShare) = _newRewards(pool, totalAllocPoint);
                accRewardPerShare = accRewardPerShare + newAccRewardPerShare;
            }
            claimable[i] = (user.amount * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
            unchecked {
                i++;
            }
        }
        return claimable;
    }

    /**
     * @notice Sum of all pending RewardToken rewards.
     * @param _user address of the user
     * @return pending reward amount
     */
    function allPendingRewards(address _user) public view returns (uint256 pending) {
        pending = userBaseClaimable[_user];
        uint256[] memory claimable = pendingRewards(_user, registeredTokens);
        uint256 length = claimable.length;
        for (uint256 i; i < length; ) {
            pending += claimable[i];
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Updates whether the provided address is authorized to call setEligibilityExempt(), only callable by owner.
     * @param _address address of the user or contract whose authorization level is being changed
     */
    function setContractAuthorization(address _address, bool _authorize) external onlyOwner {
        if (authorizedContracts[_address] == _authorize) revert AuthorizationAlreadySet();
        authorizedContracts[_address] = _authorize;
        emit AuthorizedContractUpdated(_address, _authorize);
    }

    /********************** Eligibility + Disqualification ***********************/
    /**
     * @notice `after` Hook for deposit and borrow update.
     * @dev important! eligible status can be updated here
     * @param _token address
     * @param _user address
     * @param _balance new amount
    
     */
    function _handleActionAfterForToken(address _token, address _user, uint256 _balance) internal {
        PoolInfo storage pool = poolInfo[_token];
        if (pool.lastRewardTime == 0) revert UnknownPool();
        // Although we would want the pools to be as up to date as possible when users
        // transfer rTokens or dTokens, updating all pools on every r-/d-Token interaction would be too gas intensive.
        // _updateEmissions();
        _updatePool(pool, totalAllocPoint);
        UserInfo storage user = userInfo[_token][_user];
        uint256 amount = user.amount;
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (amount != 0) {
            uint256 pending = (amount * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
            if (pending != 0) {
                //@update user's claimable balance before actions
                userBaseClaimable[_user] = userBaseClaimable[_user] + pending;
            }
        }
        pool.totalSupply = pool.totalSupply - user.amount;
        //@note updating user's balances
        user.amount = _balance;
        user.rewardDebt = (_balance * accRewardPerShare) / ACC_REWARD_PRECISION;
        pool.totalSupply = pool.totalSupply + _balance;

        emit BalanceUpdated(_token, _user, _balance);
    }

    // performes the logic for  _handleActionAfterForToken function, but for after claim so the parts that deal with claimable rewards are removed
    function _handleTokenAfterClaim(address _token, address _user) internal {
        PoolInfo storage pool = poolInfo[_token];
        //@note performed in claim already
        // if (pool.lastRewardTime == 0) revert UnknownPool();
        // _updatePool(pool, totalAllocPoint);
        UserInfo storage user = userInfo[_token][_user];
        // uint256 amount = user.amount;
        uint256 accRewardPerShare = pool.accRewardPerShare;
        //@note not necessary as emission has been claimed already
        // if (amount != 0) {
        //     uint256 pending = (amount * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
        //     if (pending != 0) {
        //         //@update user's claimable balance before actions
        //         userBaseClaimable[_user] = userBaseClaimable[_user] + pending;
        //     }
        // }
        //@note deduced current balance from total Supply first
        pool.totalSupply = pool.totalSupply - user.amount;
        //@note updating user's balances for rewardDebt and total supply
        uint256 _balance = IERC20(_token).balanceOf(_user);
        user.amount = _balance;
        user.rewardDebt = (_balance * accRewardPerShare) / ACC_REWARD_PRECISION;
        pool.totalSupply = pool.totalSupply + _balance;

        emit BalanceUpdated(_token, _user, _balance);
    }

    /**
     * @notice `after` Hook for deposit and borrow update.
     * @dev important! eligible status can be updated here
     * @param _user address
     * @param _balance balance of token
     */
    function handleActionAfter(address _user, uint256 _balance) external {
        if (!vaildPODToken[msg.sender]) revert NotValidPool();
        _handleActionAfterForToken(msg.sender, _user, _balance);
    }

    /**
     * @notice `before` Hook for deposit and borrow update.
     * @param _user address
     */
    function handleActionBefore(address _user) external {}

    /**
     * @notice Hook for lock update.
     * @dev Called by the locking contracts before locking or unlocking happens
     * @param _user address
     */
    function beforeLockUpdate(address _user) external {}

    /**
     * @notice Hook for lock update.
     * @dev Called by the locking contracts after locking or unlocking happens
     * @param _user address
     */
    function afterLockUpdate(address _user) external {}

    function refreshUserBalance(address _user) external {
        _refreshUserBalance(_user);
    }

    function batchRefreshUserBalance(address[] memory _users) external onlyWhitelisted {
        uint256 length = _users.length;
        for (uint256 i; i < length; ) {
            _refreshUserBalance(_users[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Update balance if there are any unregistered.
     * @param _user address of the user whose balances will be updated
     */
    function _refreshUserBalance(address _user) internal {
        uint256 length = poolLength();
        for (uint256 i; i < length; ) {
            uint256 newBal = IERC20(registeredTokens[i]).balanceOf(_user);
            // uint256 registeredBal = userInfo[registeredTokens[i]][_user].amount;
            // if (newBal != registeredBal) {
            _handleActionAfterForToken(registeredTokens[i], _user, newBal);
            // }
            unchecked {
                i++;
            }
        }
    }

    /********************** Eligibility + Disqualification ***********************/

    /**
     * @dev Returns true if `_user` has some reward eligible tokens.
     * @param _user address of recipient
     */
    function hasEligibleDeposits(address _user) public view returns (bool hasDeposits) {
        uint256 length = poolLength();
        for (uint256 i; i < length; ) {
            if (userInfo[registeredTokens[i]][_user].amount != 0) {
                hasDeposits = true;
                break;
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @dev Stop RewardToken emissions for specific users
     * @param _user address of recipient
     */
    function stopEmissionsFor(address _user) internal {
        // lastEligibleStatus will be fresh from refresh before this call
        uint256 length = poolLength();
        for (uint256 i; i < length; ) {
            address token = registeredTokens[i];
            UserInfo storage user = userInfo[token][_user];

            if (user.amount != 0) {
                _handleActionAfterForToken(token, _user, 0);
            }
            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice function to stop user emissions
     * @param _user address of user to stop emissions for
     */
    function manualStopEmissionsFor(address _user, address[] memory _tokens) public onlyWhitelisted {
        if (_user == address(0)) revert AddressZero();
        uint256 length = _tokens.length;
        for (uint256 i; i < length; ) {
            address token = _tokens[i];
            PoolInfo storage pool = poolInfo[token];
            UserInfo storage user = userInfo[token][_user];

            if (pool.lastRewardTime == 0) revert UnknownPool();

            uint256 amount = user.amount;
            if (amount != 0) {
                uint256 accRewardPerShare = pool.accRewardPerShare;
                uint256 pending = (amount * accRewardPerShare) / ACC_REWARD_PRECISION - user.rewardDebt;
                if (pending != 0) {
                    userBaseClaimable[_user] = userBaseClaimable[_user] + pending;
                }
                uint256 newTotalSupply = pool.totalSupply - amount;
                user.amount = 0;
                user.rewardDebt = 0;
                pool.totalSupply = newTotalSupply;

                emit BalanceUpdated(token, _user, 0);
            }
            unchecked {
                i++;
            }
        }
    }

    function manualStopAllEmissionsFor(address _user) external onlyWhitelisted {
        manualStopEmissionsFor(_user, registeredTokens);
    }

    /**
     * @dev Send RewardToken rewards to user.
     * @param _user address of recipient
     * @param _amount of RewardToken
     */
    function _sendRewardToken(address _user, uint256 _amount) internal {
        if (_amount == 0) {
            return;
        }

        address RewardTokenToken_ = rewardToken;
        uint256 chefReserve = IERC20(RewardTokenToken_).balanceOf(address(this));
        if (_amount > chefReserve) {
            revert OutOfRewards();
        } else {
            IERC20(RewardTokenToken_).safeTransfer(_user, _amount);
        }
    }

    /********************** RewardToken Reserve Management ***********************/

    /**
     * @notice Ending reward distribution time.
     */
    function endRewardTime() public returns (uint256) {
        if (endingTime.lastUpdatedTime + endingTime.updateCadence > block.timestamp) {
            return endingTime.estimatedTime;
        }

        uint256 unclaimedRewards = availableRewards();
        uint256 extra = 0;
        uint256 length = poolLength();
        for (uint256 i; i < length; ) {
            PoolInfo storage pool = poolInfo[registeredTokens[i]];

            if (pool.lastRewardTime > lastAllPoolUpdate) {
                extra +=
                    ((pool.lastRewardTime - lastAllPoolUpdate) * pool.allocPoint * rewardsPerSecond) /
                    totalAllocPoint;
            }
            unchecked {
                i++;
            }
        }
        endingTime.lastUpdatedTime = block.timestamp;

        if (rewardsPerSecond == 0) {
            endingTime.estimatedTime = type(uint256).max;
            return type(uint256).max;
        } else {
            uint256 newEndTime = (unclaimedRewards + extra) / rewardsPerSecond + lastAllPoolUpdate;
            endingTime.estimatedTime = newEndTime;
            return newEndTime;
        }
    }

    /**
     * @notice Updates cadence duration of ending time.
     * @dev Only callable by owner.
     * @param _lapse new cadence
     */

    //@note (i.e. frequency of how often the estimated end time will be checked)
    function setEndingTimeUpdateCadence(uint256 _lapse) external onlyOwner {
        if (_lapse > 1 weeks) revert CadenceTooLong();
        endingTime.updateCadence = _lapse;
        emit EndingTimeUpdateCadence(_lapse);
    }

    /**
     * @notice Add new rewards.
     * @dev Only callable by owner.
     * @param _amount new deposit amount
     */
    function registerRewardDeposit(uint256 _amount) external onlyWhitelisted {
        depositedRewards = depositedRewards + _amount;
        _massUpdatePools();
        if (rewardsPerSecond == 0 && lastRPS > 0) {
            rewardsPerSecond = lastRPS;
        }
        emit RewardDeposit(_amount);
    }

    /**
     * @notice Available reward amount for future distribution.
     * @dev This value is equal to `depositedRewards` - `accountedRewards`.
     * @return amount available
     */
    function availableRewards() internal view returns (uint256 amount) {
        return depositedRewards - accountedRewards;
    }

    /**
     * @notice Pause the claim operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the claim operations.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns new rewards since last reward time.
     * @param pool pool info
     * @param _totalAllocPoint allocation point of the pool
     */
    function _newRewards(
        PoolInfo memory pool,
        uint256 _totalAllocPoint
    ) internal view returns (uint256 newReward, uint256 newAccRewardPerShare) {
        uint256 lpSupply = pool.totalSupply;
        if (lpSupply > 0) {
            uint256 duration = block.timestamp - pool.lastRewardTime;
            uint256 rawReward = duration * rewardsPerSecond;

            uint256 rewards = availableRewards();
            if (rewards < rawReward) {
                rawReward = rewards;
            }
            newReward = (rawReward * pool.allocPoint) / _totalAllocPoint;
            newAccRewardPerShare = (newReward * ACC_REWARD_PRECISION) / lpSupply;
        }
    }

    /**
     * @notice Add new address to whitelist.
     * @param user address
     * @param status for whitelist
     */
    function setAddressWLstatus(address user, bool status) external onlyOwner {
        whitelist[user] = status;
    }

    //function using .call to allow keeper withdraw eth from contact
    function withdrawEth(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{ value: amount }("");
        if (!success) revert EthTransferFailed();
    }
}
