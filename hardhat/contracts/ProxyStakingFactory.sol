// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "./ProxyStakingContract.sol";
// import "./VaultkaStakeNFT.sol";

// contract ProxyStakingFactory is Ownable {
//     address[] public proxyContracts; // 存储所有创建的代理合约地址
//     VaultkaStakeNFT public nftContract;
//     address public mvkaAggregator; // mvka聚合器地址

//     constructor(address _nftContract, address _mvkaAggregator) {
//         nftContract = VaultkaStakeNFT(_nftContract);
//         mvkaAggregator = _mvkaAggregator;
//     }

//     event ProxyStakingCreated(address indexed proxyContract, address indexed owner, uint256 tokenId);

//     // 创建新的代理合约并铸造一个NFT
//     function createProxyStakingContract(address vkaToken, address vaultkaContract, uint256 amount, uint256 duration) external {
//         // 铸造NFT
//         uint256 tokenId = nftContract.safeMint(msg.sender);

//         // 创建代理合约
//         ProxyStakingContract proxyContract = new ProxyStakingContract(
//             vkaToken,
//             vaultkaContract,
//             address(nftContract),
//             msg.sender,
//             amount,
//             duration,
//             mvkaAggregator,
//             tokenId
//         );

//         proxyContracts.push(address(proxyContract));

//         emit ProxyStakingCreated(address(proxyContract), msg.sender, tokenId);
//     }

//     // 获取所有创建的代理合约地址
//     function getAllProxyContracts() external view returns (address[] memory) {
//         return proxyContracts;
//     }
// }
