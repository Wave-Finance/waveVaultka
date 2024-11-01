import { expect } from 'chai';
import { Contract } from 'ethers';
import { ethers} from 'hardhat';
describe('MVKAToken',function(){
    let contract:any
    let defaultAdmin:any
    let pauser:any
    let minter:any

    before(async function () {
        const signers = await ethers.getSigners();
        defaultAdmin = signers[0];//暂无无任何权限,只是作为部署者
        pauser=signers[1]//拥有交易暂停的权限
        minter=signers[2]//拥有代币铸造的权限,后续将这个权限改为其他合约的地址
        console.log(`admin: ${await defaultAdmin.getAddress()}\n pauser: ${await pauser.getAddress()}\n minter:${await minter.getAddress()}`)

    })
    beforeEach(async function () {
        contract=await (await ethers.getContractFactory('MVKAToken')).connect(defaultAdmin).deploy(defaultAdmin,pauser,minter);
        contract.waitForDeployment()
    })
    
    it('MVKA test',async ()=>{
        // expect(contract).to.be.instanceOf(Contract);
        await expect(await contract.name()).to.equal('MVKA');
        await expect(await contract.symbol()).to.equal('MVKA');   
    })
    it("should minter mint mvka",async ()=>{
        await contract.connect(minter).mint(await minter.getAddress(),100)
        await expect (await contract.balanceOf(minter.getAddress())).equal(100)
    })
    it("should`t user mint mvka",async ()=>{
       await expect(contract.connect(defaultAdmin).mint(await defaultAdmin.getAddress(),100)).reverted
    })
    it('should total supply work',async function () {
        await expect(await contract.totalSupply()).equal(0)
        await contract.connect(minter).mint(await minter.getAddress(),100)
        await expect(await contract.totalSupply()).equal(100)
    })
    it('should burn work',async function () {
        await expect(await contract.totalSupply()).equal(0)
        await contract.connect(minter).mint(await minter.getAddress(),100)
        await contract.connect(minter).burn(30)
        await expect (await contract.balanceOf(minter.getAddress())).equal(70)
        await expect(await contract.totalSupply()).equal(70)
    })
    it('should pauser pause token',async ()=>{
       await contract.connect(pauser).pause()
       await expect(contract.connect(minter).mint(await minter.getAddress(),100)).reverted
       await contract.connect(pauser).unpause()
       await contract.connect(minter).mint(await minter.getAddress(),100)
       await expect (await contract.balanceOf(minter.getAddress())).equal(100)




    })
})