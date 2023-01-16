// Right click on the script name and hit "Run" to execute
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MyGov", function () {
  
  async function getData(count){
    const MyGov = await ethers.getContractFactory("MyGov");
    const mygov = await MyGov.deploy(1000);
    const signers = await ethers.getSigners();
    const signers2 = await ethers.getSigners();

    return {mygov, signers: signers.slice(0, count), owner: signers[0]};
  }
  // try with 100, 200, 300 and 350 users
  user_counts = [100,200,300,350];


  for(let j = 0; j < user_counts.length; j++){
    const curr_count = user_counts[j];

    it("test the systems with " + curr_count + " users", async function () {
      console.log("started working")
      const {mygov, signers, owner} = await getData(curr_count);

      // all users start with 0 MyGov balances, then %90 calls faucet
      for(let i = 0; i< signers.length ; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        expect(balance.toNumber()).to.equal(0);
      }

      // // %90 users with 1 MyGov balances
      for(let i = 0; i<signers.length * 9 / 10; i++){
        // each signer calls faucet once
        await mygov.connect(signers[i]).faucet();
      }

      // %90 users now have 1 MyGov
      for(let i = 0; i<signers.length; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        if(i < signers.length * 9 / 10){
          expect(balance.toNumber()).to.equal(1);
        }else{
          expect(balance.toNumber()).to.equal(0);
        }
      }

      // first %10 of users which already called faucet tries to call it again
      for(let i = 0; i<signers.length * 1 / 10; i++){
        await expect(mygov.connect(signers[i]).faucet()).to.be.revertedWith("you already took a faucet");
      }

      // all users now have 1 MyGov
      for(let i = 0; i<signers.length; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        if(i < signers.length * 9 / 10){
          expect(balance.toNumber()).to.equal(1);
        }
        else{
          expect(balance.toNumber()).to.equal(0);
        }
      }

      console.log('end of faucet stuff')
      // 5 users try to takeSurvey with id=1 but there is no survey, so it reverts
      for(let i = 0; i<5; i++){
        await expect(mygov.connect(signers[i]).takeSurvey(1, [1])).to.be.revertedWith("survey with given id doesn't exist");
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }

      // submit 4 surveys
      let testNow = Date.now();
      await mygov.connect(signers[21]).transfer(await signers[20].getAddress(), 1)
      await mygov.connect(signers[22]).transfer(await signers[20].getAddress(), 1)
      let now = Date.now()
      testNow = now + 1000
      await mygov.connect(signers[20]).submitSurvey("ipfshash", now + 1000, 2, 1, {value: 40000000000000000n});

      let surveyOwner = await mygov.getSurveyOwner(0);
      expect(surveyOwner).to.equal(await signers[20].getAddress());

      expect(await mygov.getNoOfSurveys()).to.equal(1);
      let surveyInfo = await mygov.getSurveyInfo(0)
      expect(surveyInfo[0]).to.equal("ipfshash");
      expect(surveyInfo[1]).to.equal(testNow);
      expect(surveyInfo[2]).to.equal(2);
      expect(surveyInfo[3]).to.equal(1);

      for(let i = 0; i<5; i++){
        if(i == 0){
          await mygov.connect(signers[i]).takeSurvey(0, [0])
        }else{
          await mygov.connect(signers[i]).takeSurvey(0, [1])
        };
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }

      let surveyResults = await mygov.getSurveyResults(0)
      
      //vote count
      expect(surveyResults[0].toString()).to.equal('5')

      // votes to option0
      expect(surveyResults[1][0].toString()).to.equal('1')

      // votes to option1
      expect(surveyResults[1][1].toString()).to.equal('4')

      // await mygov.connect(signers[50]).donateMyGovToken(1);

      // 5 users sends mygov to user7
      await mygov.connect(signers[11]).transfer(await signers[7].getAddress(), 1)
      await mygov.connect(signers[12]).transfer(await signers[7].getAddress(), 1)
      await mygov.connect(signers[10]).transfer(await signers[7].getAddress(), 1)
      await mygov.connect(signers[9]).transfer(await signers[7].getAddress(), 1)
      await mygov.connect(signers[8]).transfer(await signers[7].getAddress(), 1)

      console.log('before submit ptoject proposal')
      
      now = Date.now()
      console.log("before submit project")
      await mygov.connect(signers[7]).submitProjectProposal("ipfshash", now + 1000, [100, 150], [now+5000, now+8000],{ value: 10000000000000000n });
      console.log("after submit project")

      let projectOwner = await mygov.getProjectOwner(0)
      expect(projectOwner).to.equal(await signers[7].getAddress())

      let noOfProjectProposals = await mygov.getNoOfProjectProposals()
      expect(noOfProjectProposals).to.equal(1)

      let projectInfo = await mygov.getProjectInfo(0)
      console.log('project info:'+ projectInfo)
      console.log('project info20:'+ projectInfo[2][0])
      expect(projectInfo[0]).to.equal('ipfshash')
      expect(projectInfo[1]).to.equal(now+1000)
      expect(projectInfo[2][0]).to.equal(100)
      expect(projectInfo[3][1]).to.equal(now+8000)


      // not funded yet, error
      await expect(mygov.getProjectNextPayment(0)).to.be.revertedWith("the project isn't funded")


      // half of people votes yes
      for(let i = 0; i<signers.length * 15 / 16; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        if(balance == 0){
          await expect(mygov.connect(signers[i]).voteForProjectProposal(0, true)).to.be.revertedWith("in order to vote, you should be a member")
        }else{
          await mygov.connect(signers[i]).voteForProjectProposal(0, true)
        }
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }

    console.log('1')
      await expect(mygov.connect(signers[0]).reserveProjectGrant(0)).to.be.revertedWith("only the owner can reserve")
      console.log('2')
      await mygov.connect(signers[7]).reserveProjectGrant(0)
      console.log('3')

      for(let i = 0; i<signers.length * 5 / 10; i++){
        const balance = await mygov.balanceOf(await signers[i].getAddress());
        if(balance == 0){
          await expect(mygov.connect(signers[i]).voteForProjectPayment(0, true)).to.be.revertedWith("in order to vote, you should be a member")
        }else{
          await mygov.connect(signers[i]).voteForProjectPayment(0, true)
        }
      }
      await mygov.connect(signers[7]).withdrawProjectPayment(0)


      // mygov transfer
      expect((await mygov.balanceOf(await signers[0].getAddress()))).to.equal(1)
      expect((await mygov.balanceOf(await signers[1].getAddress()))).to.equal(1)
      await mygov.connect(signers[0]).transfer(await signers[1].getAddress(), 1)
      expect((await mygov.balanceOf(await signers[0].getAddress()))).to.equal(0)
      expect((await mygov.balanceOf(await signers[1].getAddress()))).to.equal(2)
      

      //console.log(await mygov.getProjectNextPayment(0))

      // ex
      // await mygov.connect(signers[0]).reserveProjectGrant(0)

    });
  }

});
