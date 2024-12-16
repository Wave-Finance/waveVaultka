// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProxyStakingContract is Ownable {
    IERC20 public vkaToken;
    IERC721 public nftContract;
    address public vaultkaContract;
    address public mvkaAggregator;
    address public nftOwner;
    uint256 public amount;
    uint256 public unlockTime;
    bool public isRedeemed;
    bool public isTransferredToMvka;
    uint256 public nftTokenId;

    event RightsExecuted(address indexed owner);
    event Redeemed(address indexed owner);
    event NFTBurned(address indexed owner, uint256 mvkaAmount);
    event TransferredToMvkaAggregator(address mvkaAggregator, uint256 amount);
    event NFTOwnerUpdated(address indexed newOwner);

    constructor(
        address _vkaToken,
        address _vaultkaContract,
        address _nftContract,
        address _initialNftOwner,
        uint256 _amount,
        uint256 _duration,
        address _mvkaAggregator,
        uint256 _nftTokenId
    ) Ownable(_initialNftOwner){
        vkaToken = IERC20(_vkaToken);
        vaultkaContract = _vaultkaContract;
        nftContract = IERC721(_nftContract);
        nftOwner = _initialNftOwner;
        amount = _amount;
        unlockTime = block.timestamp + _duration;
        isRedeemed = false;
        isTransferredToMvka = false;
        mvkaAggregator = _mvkaAggregator;
        nftTokenId = _nftTokenId;

        // 将 VKA 代币转移到合约
        vkaToken.transferFrom(_initialNftOwner, address(this), _amount);
    }

    // 更新 NFT 所有者
    function updateNftOwner() public {
        address currentOwner = nftContract.ownerOf(nftTokenId);
        if (currentOwner != nftOwner) {
            nftOwner = currentOwner;
            emit NFTOwnerUpdated(currentOwner);
        }
    }

    // 行使 Vaultka 权益的功能，仅限当前 NFT 所有者调用
    function executeVaultkaRights() external {
        updateNftOwner();
        require(msg.sender == nftOwner, "Not nft owner");

        (bool success, ) = vaultkaContract.call(abi.encodeWithSignature("someFunction()"));
        require(success, "Vaultka execution failed");

        emit RightsExecuted(msg.sender);
    }

    // 赎回质押的 VKA 代币和收益
    function redeem() external {
        updateNftOwner();
        require(msg.sender == nftOwner, "Not nft owner");
        require(block.timestamp >= unlockTime, "The staking is not unlocked");
        require(!isRedeemed, "Staking redeemed");

        isRedeemed = true;
        vkaToken.transfer(nftOwner, amount); // 将质押金额返还给用户

        emit Redeemed(nftOwner);
    }

    // 销毁 NFT 并获取 Mvka 代币
    function burnNFTForMvka() external {
        updateNftOwner();
        require(msg.sender == nftOwner, "Not nft owner");
        require(!isRedeemed, "Staking redeemed");

        uint256 mvkaAmount = calculateMvkaAmount(amount);
        vkaToken.transfer(mvkaAggregator, amount);
        isTransferredToMvka = true;

        emit NFTBurned(msg.sender, mvkaAmount);
        emit TransferredToMvkaAggregator(mvkaAggregator, amount);

        // Mvka 代币的铸造或转账逻辑
    }

    // 解锁后自动赎回并将收益转移到 Mvka 聚合器
    function autoRedeemToMvka() external {
        require(block.timestamp >= unlockTime, "The staking is not unlocked");
        require(!isRedeemed, "Staking redeemed");
        require(isTransferredToMvka, "Positions have not yet been transferred to the Mvka aggregator");

        isRedeemed = true;
        vkaToken.transfer(mvkaAggregator, amount);

        emit TransferredToMvkaAggregator(mvkaAggregator, amount);
    }

    // 计算 Mvka 代币的辅助函数
    function calculateMvkaAmount(uint256 _amount) internal pure returns (uint256) {
        return _amount / 2;
    }
}