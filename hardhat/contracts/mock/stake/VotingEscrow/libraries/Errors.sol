// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

library Errors {
    // Liquidity Mining
    error VEInvalidNewExpiry(uint256 newExpiry);
    error VEExceededMaxLockTime();
    error VEInsufficientLockTime();
    error VENotAllowedReduceExpiry();
    error VEZeroAmountLocked();
    error VEPositionNotExpired();
    error VEZeroPosition();
    error VEZeroSlope(uint128 bias, uint128 slope);
    error VEReceiveOldSupply(uint256 msgTime);
    error InvalidWTime(uint256 wTime);
    error ExpiryInThePast(uint256 expiry);
    error ChainNotSupported(uint256 chainId);
    error EthTransferFailed();
    error UpdateInProgress();

    error FDInvalidPool(address pool);
    error FDInvalidStartEpoch(uint256 startEpoch);
    error FDPoolAlreadyExists(address pool);
    error FDTotalAmountFundedNotMatch(uint256 totalAmountFunded, uint256 totalAmountFundedInPool);
    error FDEpochLengthMismatch();
    error FDInvalidWTimeFund(uint256 lastFunded, uint256 wTime);
    error FDNotAdmin(address sender);
  
    // Cross-Chain
    error MsgNotFromSendEndpoint(uint16 srcChainId, bytes path);
    error MsgNotFromReceiveEndpoint(address sender);
    error InsufficientFeeToSendMsg(uint256 currentFee, uint256 requiredFee);
    error ApproxDstExecutionGasNotSet();
    error InvalidRetryData();

    // GENERIC MSG
    error ArrayLengthMismatch();
    error ArrayEmpty();
    error ArrayOutOfBounds();
    error ZeroAddress();
    error FailedToSendEther();
    error InvalidMerkleProof();

    error OnlyLayerZeroEndpoint();
    error OnlyYT();
    error OnlyYCFactory();
    error OnlyWhitelisted();
    error LzChainIdNotSet(uint256 dstChainId);
    error OnlyVePeriphery();
}
