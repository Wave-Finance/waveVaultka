// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.18;

interface ICICUserDefinedTypes {
    // Info of each user.
    // reward = user.`amount` * pool.`accRewardPerShare` - `rewardDebt`
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalSupply;
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardTime; // Last second that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewards per share, times ACC_REWARD_PRECISION. See below.
    }
    // Info about token emissions for a given time period.
    struct EmissionPoint {
        uint128 startTimeOffset;
        uint128 rewardsPerSecond;
    }
    // Info about ending time of reward emissions
    struct EndingTime {
        uint256 estimatedTime;
        uint256 lastUpdatedTime;
        uint256 updateCadence;
    }

    enum EligibilityModes {
        // check on all rToken transfers
        FULL,
        // only check on Claim
        LIMITED,
        // 0 eligibility functions run
        DISABLED
    }

    /********************** Events ***********************/
    // Emitted when rewardPerSecond is updated
    event RewardsPerSecondUpdated(uint256 indexed rewardsPerSecond);

    event BalanceUpdated(address indexed token, address indexed user, uint256 balance);

    event EmissionScheduleAppended(uint256[] startTimeOffsets, uint256[] rewardsPerSeconds);

    event Disqualified(address indexed user);

    event EligibilityModeUpdated(EligibilityModes indexed _newVal);

    event BatchAllocPointsUpdated(address[] _tokens, uint256[] _allocPoints);

    event AuthorizedContractUpdated(address _contract, bool _authorized);

    event EndingTimeUpdateCadence(uint256 indexed _lapse);

    event RewardDeposit(uint256 indexed _amount);

    event UpdateRequested(address indexed _user, uint256 feePaid);

    event KeeperConfigSet(address indexed keeper, uint256 executionGasLimit);

    event EmissionStarted(uint256 _startTime);

    event PoolAdded(address indexed _token, uint256 indexed _allocPoint);

    event WhitelistUpdated(address indexed _user, bool _status);

    event WhitelistToggled(bool _status);

    /********************** Errors ***********************/
    error AddressZero();

    error UnknownPool();

    error PoolExists();

    error AlreadyStarted();

    error NotAllowed();

    error ArrayLengthMismatch();

    error InvalidStart();

    error InvalidRToken();

    error InsufficientPermission();

    error AuthorizationAlreadySet();

    error NotVeContract();

    error NotWhitelisted();

    error NotEligible();

    error CadenceTooLong();

    error EligibleRequired();

    error NotValidPool();

    error OutOfRewards();

    error DuplicateSchedule();

    error ValueZero();

    error NotKeeper();

    error InsufficientFee();

    error TransferFailed();

    error UpdateInProgress();

    error ExemptedUser();

    error EthTransferFailed();

    error InvalidToken();
}

interface IChefIncentivesController {
    /**
     * @dev Called by the corresponding asset on any update that affects the rewards distribution
     * @param user The address of the user
     **/
    function handleActionBefore(address user) external;

    /**
     * @dev Called by the corresponding asset on any update that affects the rewards distribution
     * @param user The address of the user
     * @param userBalance The balance of the user of the asset in the lending pool
     **/
    function handleActionAfter(address user, uint256 userBalance) external;

    /**
     * @dev Called by the locking contracts after locking or unlocking happens
     * @param user The address of the user
     **/
    function beforeLockUpdate(address user) external;

    /**
     * @notice Hook for lock update.
     * @dev Called by the locking contracts after locking or unlocking happens
     */
    function afterLockUpdate(address _user) external;

    function addPool(address _token, uint256 _allocPoint) external;

    function claim(address _user, address[] calldata _tokens) external;

    function allPendingRewards(address _user) external view returns (uint256 pending);

    function claimAll(address _user) external;

    function manualStopEmissionsFor(address _user, address[] memory _tokens) external;

    function manualStopAllEmissionsFor(address _user) external;

    function setAddressWLstatus(address user, bool status) external;

    function refreshUserBalance(address _user) external;
}
