pragma solidity ^0.8.20;
import './interface/IMVKAMinte.sol';
import "@openzeppelin/contracts/access/AccessControl.sol";
import '../tokens/MVKA.sol';
import '../mock/token/VKA.mock.mock.sol';
contract MVKAMinter is IMVKAMinter,AccessControl{
     struct MVKAOrder{
      uint256 id;
      address owner;
      uint256 orderType;
      uint256 mvkaNumber;
      uint256 startTime;
      uint lockTime;
      bool isClaimed;
    }
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bool isWihdrawBlocked;
    uint256 lockTime;
//fixme 未初始化
    mapping(address=>MVKAOrder[]) public userOrder;
    mapping(uint256=>MVKAOrder) public sys_order;
    MVKAToken public mvka;
    VKAToken public vka;
    uint256 orderId;

    event MVKAMinted(address staker,uint256 mintedTime,uint256 mvkaNumber);
    event VeNFTUnwraped(address owner,uint256 nftId,uint lockTime);
    event OrderMinted(address minter,uint256 mintedTime,uint256 lockTime,uint256 stakedVkaNumber,uint256 mvkaNumber);


     constructor(uint lockTime,address adminUser,address pauser,address mvkaAddress,address vkaAddress){
            _grantRole(ADMIN_ROLE, adminUser);
            orderId=0;
            mvka=MVKAToken(mvkaAddress);
            isWihdrawBlocked=false;
            lockTime=lockTime;
            vka=VKAToken(vkaAddress);
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

      /**
       *@notice getOrdersOfUser
       */
      function getUserOrders()external view returns(MVKAOrder[]){
            return userOrder[msg.sender];
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
    * Todo change mvka transfered addreess to aggregatorAddress
    */    
      function mintMKAByStakeVKA(uint vkaNumberStaked,uint minumMkaReceived) override  external{
            require(vkaNumberStaked>0);
            // market Rate add randomRewardRate
            uint256 rate=(getRateFromUniswapV3Pool()+getRandomNumber());
            // compute mvkNumber that user could get
            uint256 mvkaNumber=vkaNumberStaked*rate;
            require(mvkaNumber>minumMkaReceived);
            (bool status)=vka.transfer(address(this), vkaNumberStaked);     
            require(status==true);
            // add new order
            orderId++;
            MVKAOrder memory mvkaorder= MVKAOrder({
                  id:orderId,
                  owner: msg.sender,
                  orderType: 0,
                  mvkaNumber: mvkaNumber,
                  startTime:block.timestamp,
                  lockTime: lockTime,
                  isClaimed: false
            });
            MVKAOrder[] memory orders;
            orders=userOrder[msg.sender];
            MVKAOrder[] memory newOrders = new MVKAOrder[](orders.length + 1);
            for (uint i = 0; i < orders.length; i++) {
                  newOrders[i] = orders[i];
           }
            newOrders[orders.length] = mvkaorder;
      //      updateOrder
            userOrder[msg.sender]=newOrders;
            sys_order[orderId]=mvkaorder;
            emit OrderMinted(msg.sender,block.timestamp,lockTime,vkaNumberStaked,mvkaNumber);
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
      function withdrawMvka(uint orderId)external override{
            MVKAOrder mvkaOrder=sys_order[orderId];
            address orderOwner=mvkaOrder[onwer];
            uint256 mvkaNumber=mvkaOrder[mvkaNumber];
            require(orderOwner==msg.sender&&mvkaOrder[isClaimed]==false);
            mvka.mint(msg.sender,order,mvkaNumber);
      //update OrderStatus 
      // todo wrap a function for update
            mvkaOrder[isClaimed]==true;
            mvkaOrder[]ordersOfUser=userOrder[msg.sender];
            for(uint i=0;i<ordersOfUser.length;i++){
                  if(ordersOfUser[i][id]==orderId){
                        ordersOfUser[i][isClaimed]=true;
                  }
            }
            emit MVKAMinted(msg.sender,block.timestamp,mvkaNumber);     
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
/**
 * @notice getARandomNumberFromChainlink 
 */
      function getRandomNumber() internal returns(uint256){
            return 2;
      }
/**
 * @notice get MVKA/VKA Rate From UniswapV3Pool 
 */
      function getRateFromUniswapV3Pool() internal returns(uint256){
            return 3;
      }
}
