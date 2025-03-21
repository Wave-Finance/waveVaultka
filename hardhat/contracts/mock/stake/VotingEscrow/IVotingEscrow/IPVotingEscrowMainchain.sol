// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.18;

import "./IPVeToken.sol";

import "../libraries/VeBalanceLib.sol";
import "../libraries/VeHistoryLib.sol";

interface IPVotingEscrowMainchain is IPVeToken {
    event NewLockPosition(address indexed user, uint128 amount, uint128 expiry);

    event Withdraw(address indexed user, uint128 amount);

    event BroadcastTotalSupply(VeBalance newTotalSupply, uint256[] chainIds);

    event BroadcastUserPosition(address indexed user, uint256[] chainIds);

    event UpdateRequestedFromVe(address indexed _user, uint256 feePaid);

    event UpdateRequestedFromVeCrossChain(address indexed _user, uint256 feePaid, uint256 chainId);

    event VeChefSet(address veChef);

    event KeeperConfigSet(address indexed keeper, uint256 indexed fee);

    event cicSet(address cic);

    // ============= ACTIONS =============

    // function increaseLockPosition(uint128 additionalAmountToLock, uint128 expiry) external returns (uint128);

    function increaseLockPosition(
        address user,
        uint128 additionalAmountToLock,
        uint128 expiry
    ) external returns (uint128);

    // function withdraw() external returns (uint128);

    function withdraw(address user) external returns (uint128);

    function totalSupplyAt(uint128 timestamp) external view returns (uint128);

    function getUserHistoryLength(address user) external view returns (uint256);

    function getUserHistoryAt(address user, uint256 index) external view returns (Checkpoint memory);
}
