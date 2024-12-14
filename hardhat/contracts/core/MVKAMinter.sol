pragma solidity ^0.8.20;
import './interface/IMVKAMinte.sol';
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MVKAMinter is IMVKAMinter,AccessControl{
     struct MVKAOrder{
      uint256 id;
      uint256 orderType;
      uint256 startTime;
      uint lockTime;
    }
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bool isWihdrawBlocked;
    uint256 lockTime;
    mapping(address=>MVKAOrder) public userOrder;

    constructor(uint lockTime,address adminUser,address pauser){
            _grantRole(ADMIN_ROLE, adminUser);
            isWihdrawBlocked=false;
            lockTime=lockTime;
      }

/*
 * ViewFunction
 */

     /**
     * 
     * @param vkaNumberStaked vkaNumber that user Want to Stake
     * @notice search for mvka_vka Rate by uniswap and show minumMvka that user could get
     */
      function mintNumberByStake(uint vkaNumberStaked)external  view override  returns(uint256 mVKAReceived){
            return 0;
      }
     /**
     * 
     * @param owner NftOwner
     * @param nftId NFTId
     * @notice compute how much vka that holder of nft can get 
     */
      function mintNumberByUnwrap(address owner,uint256 nftId) external view override  returns(uint256 mVKAReceived){
            return 0;
      }
      


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
      function mintMKAByStakeVKA(uint vkaNumberStaked,uint minumMkaReceived) override  external{

      }
     
     /** 
      * @param owner NFTOwner 
      * @param nftId NFTId
      * @notice UnwrapVeNFT for mvka based on NFTMetaData(how much vka is locked and how long will it unlocked) by a mathematical formula,
      * mvka tokens will be locked for a certain period of time and can be withdrawn
      */
      function unwrapVeNFT(address owner,uint256 nftId) override  external{

      }
    
      /**
      * 
      * @param withdrawNumber how much mvkaUserWantWithdraw
      * @notice withdraw mvka from contract 
      */
      function withdrawMvka(uint withdrawNumber)external override{
      
      }

/*
 * Admin Function
 */

    /**
     * 
     * @param orderType orderType
     * @param lockTime new lockTime
     * @notice adminUser could change lockTime by this method 
     */
    function changeLockTime(uint orderType,uint lockTime)external override onlyRole(ADMIN_ROLE){
            lockTime=lockTime;
     }
/*
 * Internal Function 
 */
      function getRandomNumber() internal returns(uint256){

      }

}
