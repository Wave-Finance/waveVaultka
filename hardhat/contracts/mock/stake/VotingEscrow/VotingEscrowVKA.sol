// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import { IPVotingEscrowMainchain, IPVeToken } from "./IVotingEscrow/IPVotingEscrowMainchain.sol";

import { Checkpoint, CheckpointHelper, Checkpoints, WeekMath } from "./libraries/VeHistoryLib.sol";

import { VeBalanceLib, VeBalance, LockedPosition } from "./libraries/VeBalanceLib.sol";

import { MiniHelpers } from "./libraries/MiniHelpers.sol";

import { Errors } from "./libraries/Errors.sol";

import { VotingEscrowTokenBase } from "./VotingEscrowTokenBase.sol";

//add ownable back
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IChefIncentivesController } from "./IVotingEscrow/IChefIncentivesController.sol";

import { IDualStaking } from "../interfaces/tokenomics/IDualStaking.sol";

contract VotingEscrowVKA is VotingEscrowTokenBase, IPVotingEscrowMainchain, IDualStaking, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using VeBalanceLib for VeBalance;
    using VeBalanceLib for LockedPosition;
    using Checkpoints for Checkpoints.History;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    IERC20 public protocolToken;

    uint256 public executionGasLimit;

    uint128 public lastSlopeChangeAppliedAt;
    // [wTime] => slopeChanges
    mapping(uint128 => uint128) public slopeChanges;

    // Saving totalSupply checkpoint for each week, later can be used for reward accounting
    // [wTime] => totalSupply
    mapping(uint128 => uint128) public totalSupplyAt;

    // Saving VeBalance checkpoint for users of each week, can later use binary search
    // to ask for their vePendle balance at any wTime
    mapping(address => Checkpoints.History) internal userHistory;

    address public vePeriphery;

    uint256[50] private __gap;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyVePeriphery() {
        if (msg.sender != vePeriphery) revert Errors.OnlyVePeriphery();
        _;
    }

    function initialize(IERC20 _protocolToken) public initializer {
        if (address(_protocolToken) == address(0)) revert Errors.ZeroAddress();
        protocolToken = _protocolToken;
        __Ownable_init();
    }

    function setVePeriphery(address _vePeriphery) external onlyOwner {
        if (_vePeriphery == address(0)) revert Errors.ZeroAddress();
        vePeriphery = _vePeriphery;
    }

    function setLastSlopeChangeAppliedAt() external onlyOwner {
        lastSlopeChangeAppliedAt = getCurrentWeekStart();
    }

    /**
     * @notice increases the lock position of a user (amount and/or expiry). Applicable even when
     * user has no position or the current position has expired.
     * @param additionalAmountToLock pendle amount to be pulled in from user to lock.
     * @param newExpiry new lock expiry. Must be a valid week beginning, and resulting lock
     * duration (since `block.timestamp`) must be within the allowed range.
     * @dev Will revert if resulting position has zero lock amount.
     * @dev See `_increasePosition()` for details on inner workings.
     * @dev Sidechain broadcasting is not bundled since it can be done anytime after.
     */
    function increaseLockPosition(
        address user,
        uint128 additionalAmountToLock,
        uint128 newExpiry
    ) public onlyVePeriphery returns (uint128 newVeBalance) {
        if (!WeekMath.isValidWTime(newExpiry)) revert Errors.InvalidWTime(newExpiry);
        if (MiniHelpers.isTimeInThePast(newExpiry)) revert Errors.ExpiryInThePast(newExpiry);

        if (newExpiry < positionData[user].expiry) revert Errors.VENotAllowedReduceExpiry();

        if (newExpiry > block.timestamp + MAX_LOCK_TIME) revert Errors.VEExceededMaxLockTime();
        if (newExpiry < block.timestamp + MIN_LOCK_TIME) revert Errors.VEInsufficientLockTime();

        uint128 newTotalAmountLocked = additionalAmountToLock + positionData[user].amount;
        if (newTotalAmountLocked == 0) revert Errors.VEZeroAmountLocked();

        uint128 additionalDurationToLock = newExpiry - positionData[user].expiry;

        if (additionalAmountToLock > 0) {
            protocolToken.safeTransferFrom(user, address(this), additionalAmountToLock);
        }

        newVeBalance = _increasePosition(user, additionalAmountToLock, additionalDurationToLock);

        emit NewLockPosition(user, balanceOf(user), newExpiry);
    }

    function withdraw(address user) external onlyVePeriphery returns (uint128 amount) {
        if (!_isPositionExpired(user)) revert Errors.VEPositionNotExpired();
        amount = positionData[user].amount;

        if (amount == 0) revert Errors.VEZeroPosition();

        delete positionData[user];

        protocolToken.safeTransfer(user, amount);

        emit Withdraw(user, amount);
    }

    /**
     * @notice update & return the current totalSupply, but does not broadcast info to other chains
     * @dev See `broadcastTotalSupply()` and `broadcastUserPosition()` for broadcasting
     */
    function totalSupplyCurrent() public virtual override(IPVeToken, VotingEscrowTokenBase) returns (uint128) {
        (VeBalance memory supply, ) = _applySlopeChange();
        return supply.getCurrentValue();
    }

    function getUserHistoryLength(address user) external view returns (uint256) {
        return userHistory[user].length();
    }

    function getUserHistoryAt(address user, uint256 index) external view returns (Checkpoint memory) {
        return userHistory[user].get(index);
    }

    /**
     * @notice increase the locking position of the user
     * @dev works by simply removing the old position from all relevant data (as if the user has
     * never locked) and then add in the new position
     */
    function _increasePosition(
        address user,
        uint128 amountToIncrease,
        uint128 durationToIncrease
    ) internal returns (uint128) {
        LockedPosition memory oldPosition = positionData[user];

        (VeBalance memory newSupply, ) = _applySlopeChange();

        if (!MiniHelpers.isCurrentlyExpired(oldPosition.expiry)) {
            // remove old position not yet expired
            VeBalance memory oldBalance = oldPosition.convertToVeBalance();
            newSupply = newSupply.sub(oldBalance);
            slopeChanges[oldPosition.expiry] -= oldBalance.slope;
        }

        LockedPosition memory newPosition = LockedPosition(
            oldPosition.amount + amountToIncrease,
            oldPosition.expiry + durationToIncrease
        );

        VeBalance memory newBalance = newPosition.convertToVeBalance();
        // add new position
        newSupply = newSupply.add(newBalance);
        slopeChanges[newPosition.expiry] += newBalance.slope;

        _totalSupply = newSupply;
        positionData[user] = newPosition;
        userHistory[user].push(newBalance);
        return newBalance.getCurrentValue();
    }

    /**
     * @notice updates the totalSupply, processing all slope changes of past weeks. At the same time,
     * set the finalized totalSupplyAt
     */
    function _applySlopeChange() internal returns (VeBalance memory, uint128) {
        VeBalance memory supply = _totalSupply;
        uint128 wTime = lastSlopeChangeAppliedAt;
        uint128 currentWeekStart = WeekMath.getCurrentWeekStart();

        if (wTime >= currentWeekStart) {
            return (supply, wTime);
        }

        while (wTime < currentWeekStart) {
            wTime += WEEK;
            supply = supply.sub(slopeChanges[wTime], wTime);
            totalSupplyAt[wTime] = supply.getValueAt(wTime);
        }

        _totalSupply = supply;
        lastSlopeChangeAppliedAt = wTime;

        return (supply, wTime);
    }

    function getCurrentWeekStart() public view returns (uint128) {
        return WeekMath.getCurrentWeekStart();
    }

    //interface support for boosting contract logic
    function totalStakedAmount() public view returns (uint256) {

        return uint256(_totalSupply.getCurrentValue());
    }

    function stakedAmounts(address _user) public view returns (uint256) {
        return balanceOf(_user);
    }
}
