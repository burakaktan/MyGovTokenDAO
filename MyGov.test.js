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

  user_counts = [50];


  for(let j = 0; j < user_counts.length; j++){
    const curr_count = user_counts[j];

    it("test faucet with " + curr_count + " users", async function () {
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
      // 5 users try to takeSurvey with id=1 but there is no survey, so it reverts
      for(let i = 0; i<5; i++){
        await expect(mygov.connect(signers[i]).takeSurvey(1, [1])).to.be.revertedWith("survey with given id doesn't exist");
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }

      // submit 4 surveys
      let testNow = Date.now();
      for(let i = 0; i < 4; i++){
        let now = Date.now();
        if(i==1){
          testNow = now + 100
        }
        
        await mygov.submitSurvey("ipfshash", now + 100, 2, 1);
        // expect(surveysLength.to.equal(i));
      }

      let surveyOwner = await mygov.getSurveyOwner(1);
      expect(surveyOwner).to.equal(await signers[0].getAddress());

      expect(await mygov.getNoOfSurveys()).to.equal(4);
      let surveyInfo = await mygov.getSurveyInfo(1)
      expect(surveyInfo[0]).to.equal("ipfshash");
      expect(surveyInfo[1]).to.equal(testNow);
      expect(surveyInfo[2]).to.equal(2);
      expect(surveyInfo[3]).to.equal(1);

      for(let i = 0; i<5; i++){
        if(i == 0){
          await mygov.connect(signers[i]).takeSurvey(1, [0])
        }else{
          await mygov.connect(signers[i]).takeSurvey(1, [1])
        };
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }

      let surveyResults = await mygov.getSurveyResults(1)
      
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

      now = Date.now()
      await mygov.connect(signers[7]).submitProjectProposal("ipfshash", now + 100, [100, 150], [now+500, now+800])
      
      let projectOwner = await mygov.getProjectOwner(0)
      expect(projectOwner).to.equal(await signers[7].getAddress())

      let noOfProjectProposals = await mygov.getNoOfProjectProposals()
      expect(noOfProjectProposals).to.equal(1)

      let projectInfo = await mygov.getProjectInfo(0)
      expect(projectInfo[0]).to.equal('ipfshash')
      expect(projectInfo[1]).to.equal(now+100)
      expect(projectInfo[2][0]).to.equal(100)
      expect(projectInfo[3][1]).to.equal(now+800)


      // not funded yet, error
      await expect(mygov.getProjectNextPayment(0)).to.be.revertedWith("the project isn't funded")


      // half of people votes yes
      for(let i = 0; i<signers.length * 5 / 10; i++){
        await mygov.connect(signers[i]).voteForProjectProposal(0, true)
        // expect().to.be.revertedWith("revert survey with given id doesn't exist");
      }


      await expect(mygov.connect(signers[0]).reserveProjectGrant(0)).to.be.revertedWith("only the owner can reserve")
      await expect(mygov.connect(signers[7]).reserveProjectGrant(0)).to.be.revertedWith("not enough wei")


      // mygov transfer
      expect((await mygov.balanceOf(await signers[0].getAddress()))).to.equal(1)
      expect((await mygov.balanceOf(await signers[1].getAddress()))).to.equal(1)
      await mygov.connect(signers[0]).transfer(await signers[1].getAddress(), 1)
      expect((await mygov.balanceOf(await signers[0].getAddress()))).to.equal(0)
      expect((await mygov.balanceOf(await signers[1].getAddress()))).to.equal(2)
      

      // console.log(await mygov.getProjectNextPayment(0))

      // ex
      // await mygov.connect(signers[0]).reserveProjectGrant(0)

    });
  }

});
