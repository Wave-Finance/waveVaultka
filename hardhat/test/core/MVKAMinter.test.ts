import { expect } from 'chai';
import { Contract } from 'ethers';
import { ethers} from 'hardhat';
describe('MVKAMinter',function(){
    let contract:any
    let lockTime:any
    let admin:any
    let pauser:any
    let minter:any
    let mvkaAddress=''
    let vkaAddress=''
    before(async function () {
        const signers = await ethers.getSigners();
        admin = signers[0];// adminUser
        pauser=signers[1]//pauser
        minter=signers[2]//拥有代币铸造的权限,后续将这个权限改为其他合约的地址
        console.log(`admin: ${await admin.getAddress()}\n pauser: ${await pauser.getAddress()}\n minter:${await minter.getAddress()}`)

    })
    beforeEach(async function () {
        contract=await (await ethers.getContractFactory('MVKAMinter')).connect(admin).deploy(lockTime,admin,pauser,mvkaAddress,vkaAddress);
        contract.waitForDeployment()
    })
    
    it('MVKA test',async ()=>{
        // expect(contract).to.be.instanceOf(Contract);
        await expect(await contract.name()).to.equal('MVKA');
        await expect(await contract.symbol()).to.equal('MVKA');   
    })

})