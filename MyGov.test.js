// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyGov", function () {

  async function getData(count){
    const MyGov = await ethers.getContractFactory("MyGov");
    const mygov = await MyGov.deploy(1000);
    const signers = await ethers.getSigners();
    

    return {mygov, signers: signers.slice(0, count), owner: signers[0]};
  }

  user_counts = [100, 200, 300];


  for(let j = 0; j < user_counts.length; j++){
    const curr_count = user_counts[j];

    it("test faucet with " + curr_count + " users", async function () {
      const {mygov, signers, owner} = await getData(curr_count);

      // all users start with 0 MyGov balances
      for(let i = 0; i<signers.length; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        expect(balance.toNumber()).to.equal(0);
      }

      for(let i = 0; i<signers.length; i++){
        // each signer calls faucet once
        await mygov.connect(signers[i]).faucet();
      }

      // all users now have 1 MyGov
      for(let i = 0; i<signers.length; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        expect(balance.toNumber()).to.equal(1);
      }

      for(let i = 0; i<signers.length; i++){
        // each user tries to call faucet again but it is not allowed
        await expect(mygov.connect(signers[i]).faucet()).to.be.revertedWith("you already took a faucet");
      }

      // all users still have 1 MyGov
      for(let i = 0; i<signers.length; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        expect(balance.toNumber()).to.equal(1);
      }

    });
  }

});
