pragma solidity ^0.8.0;
// SPDX-License-Identifier: AGPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract MyGov is ERC20{
    
    string public mymessage ;
    uint tokens_to_mint = 10000000;
    mapping(address => bool) public took_faucet;
    address payable owner;
    uint donatedTokens = 0;

    uint tokens_need_to_propose = 5;

    struct survey
    {
        address owner;
        string ipfshash;
        uint surveydeadline;
        uint numchoices;
        uint atmostchoice;
        uint [] choices; // stores how many votes each choice obtained
        uint numtaken;
    }

    survey [] surveys;


    function submitSurvey(string memory ipfshash, uint surveydeadline, uint numchoices, uint atmostchoice) payable public returns (uint surveyid)
    {
        // 2 token, 0.04 ether
        donateMyGovToken(2);
        require(msg.value == 40000000000000000, "you should pay 0.04 ethers");  

        require(block.timestamp < surveydeadline, "deadline should be after current time");
        survey memory s;
        s.ipfshash = ipfshash;
        s.surveydeadline = surveydeadline;
        s.numchoices = numchoices;
        s.choices = new uint[](s.numchoices);
        s.atmostchoice = atmostchoice;
        s.owner = msg.sender;
        s.numtaken = 0;
        surveys.push(s);
        return surveys.length;
    }

    function takeSurvey(uint surveyid, uint [] calldata choices) public
    {
        require(balanceOf(msg.sender) > 0, "you aren't a member");
        require(surveys.length > surveyid, "survey with given id doesn't exist");
        require(choices.length <= surveys[surveyid].atmostchoice, "you selected so many choices");
        uint i = 0;
        for(i = 0; i < choices.length; i++)
        {
            require(choices[i] < surveys[surveyid].numchoices, "choices should be valid numbers");
            surveys[surveyid].choices[choices[i]]++;
        }
        surveys[surveyid].numtaken++;
    }

    function getSurveyResults(uint surveyid) public view returns(uint numtaken, uint [] memory results)
    {
        require(surveys.length > surveyid, "survey with given id doesn't exist");
        return (surveys[surveyid].numtaken, surveys[surveyid].choices);
    }

    function getSurveyInfo(uint surveyid) public view returns(string memory ipfshash, uint surveydeadline,uint numchoices, uint atmostchoice)
    {
        require(surveys.length > surveyid, "survey with given id doesn't exist");
        return (
                surveys[surveyid].ipfshash,
                surveys[surveyid].surveydeadline,
                surveys[surveyid].numchoices,
                surveys[surveyid].atmostchoice
        );
    }

    function getSurveyOwner(uint surveyid) public view returns(address surveyowner) 
    {
        require(surveys.length > surveyid, "survey with given id doesn't exist");
        return surveys[surveyid].owner;
    }

    function getNoOfSurveys() public view returns(uint numsurveys)
    {
        return surveys.length;
    }

    /* constructor */
    constructor(uint tokensupply) ERC20("My Gov Token", "MYG") payable{
        owner = payable(msg.sender);
        tokens_to_mint = tokensupply;
    }


    function faucet() public{
        require(tokens_to_mint >= 1, "minting limit is suceeded");
        require(!took_faucet[msg.sender], "you already took a faucet");
        took_faucet[msg.sender] = true;
        tokens_to_mint -= 1;
        _mint(msg.sender,1);
        userCount++;
    }

    function donateEther() public payable
    {
    }

    function donateMyGovToken(uint amount) public 
    {
       (bool success) = transfer(payable(address(this)),amount);
        require(success, "Failed to donate tokens");
        donatedTokens += amount;

        // if user has no MyGov, then it is not included in voting portion calculation.
        if(balanceOf(msg.sender) == 0){
            userCount--;
        }
    }

    // structure for storing voter information
    struct Voter
    {
        address delegating_to;
        bool did_vote;
        mapping(uint => bool) paymentVoting;
        uint power;
        bool choice;
    }


    // structure for storing project data
    struct ProjectData { 
        string ipfshash;
        uint votedeadline;
        uint [] paymentamounts;
        uint [] payschedule;
        uint [] yesCounts_payment;
        uint ongoingPaymentIndex; // bugun 5 araliksa 10 araliktaki odemenin indexi
        uint yesCount;
        address owner;
        bool reserved;
        mapping(address => Voter) voters;
        uint ethers_received;
        bool withdraw_all_money; // whether payments has end or not
    }

    uint public userCount = 0; // q: what about the owner? a: At the beginning he hasn't any tokens so not a member
    mapping(uint => ProjectData) public projects;
    uint projectId = 0;

    uint reservedWei = 0;

    uint no_funded = 0;

    // TODO: check whether payschedule is incremental and after votedeadline
    function submitProjectProposal(string memory ipfshash, uint votedeadline,uint [] memory paymentamounts, uint [] memory payschedule) public payable returns (uint projectid) {
        require(block.timestamp < votedeadline, "deadline is already passed");
        //payments --> 5 token, 0.01 ether
        donateMyGovToken(tokens_need_to_propose);
        require(msg.value == 10000000000000000, "you should pay 0.01 ethers");  

        // give an ID to the project
        projectid = projectId;
        projectId++;

        //store project data in projects array
        projects[projectid].ipfshash = ipfshash;
        projects[projectid].votedeadline = votedeadline;
        projects[projectid].paymentamounts = paymentamounts;
        projects[projectid].payschedule = payschedule;
        projects[projectid].yesCounts_payment = new uint[](payschedule.length);
        projects[projectid].owner = msg.sender;

        return projectid;
    }

    function voteForProjectProposal(uint projectid,bool choice) public {
        require(block.timestamp < projects[projectid].votedeadline, "voting deadline is passed");
        // require(block.timestamp < votedeadline);
        require(balanceOf(msg.sender) > 0,"in order to vote, you should be a member"); // should have MyGov to vote
        require(projects[projectid].voters[msg.sender].did_vote == false, "you already have voted, you can't vote again"); // user hasn't voted yet
        if(projects[projectid].voters[msg.sender].power == 0)
        {
            projects[projectid].voters[msg.sender].power = 1;
        }
        projects[projectid].voters[msg.sender].choice = choice;
        projects[projectid].voters[msg.sender].did_vote = true;
        if(choice){
            projects[projectid].yesCount += projects[projectid].voters[msg.sender].power;
        }
    }

    function delegateVoteTo(address memberaddr, uint projectid) public{
        require(memberaddr != msg.sender, "you can't delegate yourself");
        require(balanceOf(msg.sender) > 0,"in order to delegate vote, you should be a member"); // should have MyGov to vote
        require(!projects[projectid].voters[msg.sender].did_vote, "you already voted");
        projects[projectid].voters[msg.sender].did_vote = true;
        projects[projectid].voters[msg.sender].delegating_to = memberaddr;
        // loop check
        address ptr = projects[projectid].voters[msg.sender].delegating_to;
        while(projects[projectid].voters[ptr].delegating_to != address(0))
        {
            ptr = projects[projectid].voters[ptr].delegating_to;
            require(ptr != msg.sender, "loop detected");
        }
        projects[projectid].voters[msg.sender].delegating_to = ptr;
        if(projects[projectid].voters[ptr].power == 0){
            projects[projectid].voters[ptr].power = 1;
        }
        projects[projectid].voters[ptr].power += 1;
        // did delegated person vote
        if(projects[projectid].voters[ptr].did_vote)
        {
            if(projects[projectid].voters[ptr].choice)
                projects[projectid].yesCount += projects[projectid].voters[msg.sender].power;
        }
        else
        {
            projects[projectid].voters[ptr].power += projects[projectid].voters[msg.sender].power;
        }
    }



    // debug etmek icin return yesCount yapip bakmak kolay oluyor
    function voteForProjectPayment(uint projectid,bool choice) public {
        uint paymentDeadline = projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
        uint paymentAmount = projects[projectid].paymentamounts[projects[projectid].ongoingPaymentIndex];
        require(block.timestamp < paymentDeadline, "voting deadline is passed");
        // require(block.timestamp < votedeadline);
        require(balanceOf(msg.sender) > 0,"in order to vote, you should be a member"); // should have MyGov to vote
        require(projects[projectid].voters[msg.sender].paymentVoting[projects[projectid].ongoingPaymentIndex] == false, "you already have voted, you can't vote again"); // user hasn't voted yet
        // if power isn't initialized, it is 1 (every one has one voting power at the beginning)
        if(projects[projectid].voters[msg.sender].power == 0)
        {
            projects[projectid].voters[msg.sender].power = 1;
        }
        projects[projectid].voters[msg.sender].choice = choice;
        projects[projectid].voters[msg.sender].paymentVoting[projects[projectid].ongoingPaymentIndex] = true;
        if(choice){
            projects[projectid].yesCounts_payment[projects[projectid].ongoingPaymentIndex] += projects[projectid].voters[msg.sender].power;
        }
    }


    function reserveProjectGrant(uint projectid) public{
        require(msg.sender==projects[projectid].owner, "only the owner can reserve");
        require(block.timestamp < projects[projectid].votedeadline);
        require(!projects[projectid].reserved); // can not reserve more than once.
        
        require(projects[projectid].yesCount * 10 >= userCount); // check if 10% said yes
        
        uint total_payment = 0;
        for(uint i=0; i<projects[projectid].paymentamounts.length; i++){
            total_payment += projects[projectid].paymentamounts[i];
        }

        // TODO: time trigger??

        require(address(this).balance - reservedWei >= total_payment); 

        reservedWei += total_payment;
        projects[projectid].reserved = true;
        no_funded++;
    }
    

    function withdrawProjectPayment(uint projectid) public payable returns (uint a){
        require(msg.sender==projects[projectId].owner, "only the owner can reserve");
        require(getIsProjectFunded(projectid), "project isn't funded");
        require(!projects[projectid].withdraw_all_money, "project payment is completed");
        uint paymentDeadline = projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
        uint paymentAmount = projects[projectid].paymentamounts[projects[projectid].ongoingPaymentIndex];
        uint yesCount = projects[projectid].yesCounts_payment[projects[projectid].ongoingPaymentIndex];
        
        // deadline gecmeden withdrawlamali?
        require(block.timestamp < paymentDeadline, "payment deadline has passed");
        require(reservedWei >= paymentAmount, "reserve is not enough");
        require(yesCount * 100 >= userCount, "not enough vote for withdrawing (payschedule)");

        payable(msg.sender).transfer(paymentAmount);
        reservedWei -= paymentAmount;

        projects[projectid].ethers_received += paymentAmount;
        projects[projectid].ongoingPaymentIndex++;
        if(projects[projectid].ongoingPaymentIndex == projects[projectid].payschedule.length)
            projects[projectid].withdraw_all_money = true;
    }

    function getProjectOwner(uint projectid) public view returns(address projectowner)
    {
        return projects[projectid].owner;
    }
    function getProjectInfo(uint projectid) public view returns(string memory ipfshash, uint votedeadline,uint paymentamounts, uint [] memory payschedule) 
    {
        return (
            projects[projectid].ipfshash,
            projects[projectid].votedeadline,
            projects[projectid].paymentamounts[0],
            projects[projectid].payschedule
        );
    }

    function getProjectNextPayment(uint projectid) public view returns(uint next)
    {
        require(getIsProjectFunded(projectid), "the project isn't funded");
        require(!projects[projectid].withdraw_all_money,"all payments are finished");
        return projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
    }


    function getNoOfFundedProjects () public view returns(uint numfunded)
    {
        // previously the implemenation was 1 line to avoid for loops:return no_funded;
        /*
        however, it wasn't sufficient. Why?
        note that there isn't enough vote for PAYSCHEDULE (1/100 of members), the funding is lost (the project isn't funded anymore)
        to also check this condition while finding out number of funded projects, getIsProject funded should be called for
        every project. Therefore, a for loop is needed here
        */
        uint ans = 0;
        for(uint p = 0;p < projectId; p++)
        {
            if(getIsProjectFunded(p))
            {
                ans++;
            }
        }
        return ans; 
    }

    function getIsProjectFunded (uint projectid) public view returns(bool funded)
    {
        return (projects[projectid].reserved) && (projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex] < block.timestamp);
    }
    
    function getEtherReceivedByProject (uint projectid) public view returns(uint amount)
    {
        return projects[projectid].ethers_received;
    }

    function getNoOfProjectProposals () public view returns (uint numproposals)
    {
        return projectId;
    }

    function getBlockTimestamp() public view returns (uint time)
    {
        return block.timestamp;
    }


    receive() external payable {}
    fallback() external payable {}

}
