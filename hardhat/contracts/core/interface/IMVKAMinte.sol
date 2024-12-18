pragma solidity ^0.8.20;
/**
 * @title MVKAMinter
 * @author TreeNewKing 
 * @notice Contract that could MintMvka by Stake VkaToken or unwrap VeNFT
 */
interface IMVKAMinter {
    // event MVKAMinted(address staker,uint256 MintedTime,uint256 stakedVkaNumber,uint256 mvkaNumber,uint256 randomRewardNumber,uint256 lockTime);
    // event VeNFTisUnwraped (address owner,uint256 nftId,uint lockTim) ;
    // event OrderMinted();
/*
 * ViewFunction
 */

    /**
     * 
     * @param vkaNumberStaked vkaNumber that user Want to Stake
     * @notice search for mvka_vka Rate by uniswap and show minumMvka that user could get
     */
    function mintNumberByStake(uint vkaNumberStaked)external  view returns(uint256 mVKAReceived);
 
    /**
     * 
     * @param owner NftOwner
     * @param nftId NFTId
     * @notice compute how much vka that holder of nft can get 
     */
    function mintNumberByUnwrap(address owner,uint256 nftId) external view returns(uint256 mVKAReceived);
    
/*
 * UserFunction 
 */

    /**
    * 
    * @param vkaNumberStaked userStakedVKANumber
    * @param minumMkaReceived MVKANumber that minum received.if number less than it,function will throw exception
    * @notice Stake vka Token for mvka based on market exchange rates and a randomRewardRate,In order to prevent 
    *         arbitrage,mvka tokens will be locked for a certain period of time and can be withdrawn
    */    
    function mintMKAByStakeVKA(uint vkaNumberStaked,uint minumMkaReceived) external;

    /** 
    * @param owner NFTOwner 
    * @param nftId NFTId
    * @notice UnwrapVeNFT for mvka based on NFTMetaData(how much vka is locked and how long will it unlocked) by a mathematical formula,
    * mvka tokens will be locked for a certain period of time and can be withdrawn
    */
    function unwrapVeNFT(address owner,uint256 nftId) external;
   
    /**
     * 
     * @param withdrawNumber how much mvkaUserWantWithdraw
     * @notice withdraw mvka from contract 
     */
    function withdrawMvka(uint withdrawNumber)external;
/*
 * Admin Function
 */
    /**
     * 
     * @param orderType orderType
     * @param lockTime new lockTime
     * @notice adminUser could change lockTime by this method 
     */
    function changeLockTime(uint orderType,uint lockTime)external;

}