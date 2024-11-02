pragma solidity ^0.8.18;

// SPDX-License-Identifier: MIT

interface IDualStaking {
    //view function for total staked amount
    function totalStakedAmount() external view returns (uint256);

    //view function for stakedAmount of a user
    function stakedAmounts(address _user) external view returns (uint256);
}
