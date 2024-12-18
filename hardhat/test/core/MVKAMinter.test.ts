import { expect } from 'chai';
import { Contract } from 'ethers';
import { ethers} from 'hardhat';
interface VkaOrder {
    name: string;
    age: number; // 在 TypeScript 中，uint256 通常映射为 number
}
describe('MVKAMinter',function(){
    let contract:any
    let lockTime:any
    let admin:any
    let pauser:any
    let mvkaAddress=''
    let vkaAddress=''
    let vkaContract:any
    let mvkaContract:any

    before(async function () {
        const signers = await ethers.getSigners();
        admin = signers[0];// adminUser
        pauser=signers[1]//pauser
        // minter=signers[2]//拥有代币铸造的权限,后续将这个权限改为其他合约的地址
        vkaContract=await (await ethers.getContractFactory('VKAToken')).connect(admin).deploy()
        await vkaContract.waitForDeployment()
        vkaAddress=await vkaContract.getAddress()
        console.log(`admin: ${await admin.getAddress()}\n pauser: ${await pauser.getAddress()}\n vkaAddress: ${vkaAddress}`)

    })
    beforeEach(async function () {
        lockTime=20
        contract=await (await ethers.getContractFactory('MVKAMinter')).connect(admin).deploy(lockTime,admin,pauser,vkaAddress);
        await contract.waitForDeployment()
        console.log(`MvkaMinter is deployed in ${await contract.getAddress()}`)
        mvkaAddress=await contract.mvka()
        console.log('mvkaAddress',mvkaAddress)

    })
    
    it('MVAMinter',async ()=>{
        await expect(await contract.lockTime()).equal(lockTime)
        await expect(await contract.isWihdrawBlocked()).equals(true)
    })

    it('StakeVKA',async ()=>{
        let vkaHoldNumber=await vkaContract.balanceOf(admin)
        let stakeNumber=1000
        expect(vkaHoldNumber).gt(stakeNumber)
        let userorders= await contract.getUserOrders()
        expect(userorders).lengthOf(0)
//approve vka
        await vkaContract.approve(await contract.getAddress(),stakeNumber)
        let allowance=await vkaContract.allowance(await admin.getAddress(),await contract.getAddress())
        await expect(allowance).equal(stakeNumber)
//GenerateOrder   
        await contract.connect(admin).mintMVKAByStakeVKA(stakeNumber,stakeNumber*1.5)
        allowance=await vkaContract.allowance(await admin.getAddress(),await contract.getAddress())
        expect(allowance).equal(0)
//checkOrder 
        userorders= await contract.getUserOrders()
        expect(userorders).lengthOf(1)
        // console.log(userorders)
// withdrawMVKA
        let userOrdersSearchedByFrontend=await contract.getUserOrders()
        // console.log(userOrdersSearchedByFrontend)
        await expect(contract.withdrawMvka(userOrdersSearchedByFrontend[0][0])).reverted
// openWithdraw
        await contract.connect(admin).openWithdraw()
        await contract.withdrawMvka(userOrdersSearchedByFrontend[0][0])
// check MVKABalance 

    })

})