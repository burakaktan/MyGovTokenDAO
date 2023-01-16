pragma solidity ^0.8.0;
// SPDX-License-Identifier: AGPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract MyGov is ERC20{
    
    string public mymessage ;
    uint tokens_to_mint = 10000000;

    // to make sure every user calls faucet at most once
    mapping(address => bool) public took_faucet;
    address payable owner;
    uint donatedTokens = 0;

    uint tokens_need_to_propose = 5;

    // structure to keep submitted surveys
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

    // survey array
    survey [] surveys;

    // function to submit surveys with required inputs, requirements are enough tokens and deadline set by owner should be in future
    function submitSurvey(string memory ipfshash, uint surveydeadline, uint numchoices, uint atmostchoice) payable public returns (uint surveyid)
    {
        // 2 token, 0.04 ether
        // requires to set deadline in future and make payments
        donateMyGovToken(2);
        require(msg.value == 40000000000000000, "you should pay 0.04 ethers");  
        require(block.timestamp < surveydeadline, "deadline should be after current time");
        survey memory s;
        // assigns inputs to struct fields
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

    // function for users to take survey
    // checks if user is a member
    // checks if survey with given id exists
    // checks if user selected too many options and validity of choices
    function takeSurvey(uint surveyid, uint [] calldata choices) public
    {
        // user must have mygov and be a member
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

    // get survey results after checking if survey with id exits, it returns number of total votes
    // in results array it keep number of votes belonging to each option ad corresponding index of results array
    function getSurveyResults(uint surveyid) public view returns(uint numtaken, uint [] memory results)
    {
        require(surveys.length > surveyid, "survey with given id doesn't exist");
        return (surveys[surveyid].numtaken, surveys[surveyid].choices);
    }

    // get survey info by survey id
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

    // faucet, allowed only once for each user
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
        uint votedeadline; // proposal deadline
        uint [] paymentamounts; // payment amounts for each payment date
        uint [] payschedule; // payment schedule
        uint [] yesCounts_payment; // voting belonging to each payment scheduled, is kept at corresponding index of this array
        uint ongoingPaymentIndex; // index of next payment, this variable lets us know which payment is next and it is correspoding index of next payment in paymentamounts, payschedule, yesCounts_payment
        uint yesCount;
        address owner;
        bool reserved; // is reserveProjectGrant be called successfully
        mapping(address => Voter) voters; // each project has its own mapping to users(voters) and their votes
        uint ethers_received;
        bool withdraw_all_money; // whether payments has end or not
    }

    uint public userCount = 0;
    mapping(uint => ProjectData) public projects;
    uint projectId = 0;

    uint reservedWei = 0;

    uint no_funded = 0;

    // checks if ethers and mygov are enough, and also checks for votedeadline to be in future and payschedule is after votedeadline and incremental
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

    // checks if deadline has passed, checks if voter is a member, checks if voter has already vote or delegated to someone -if someone has delegated to someone did_vote=true-
    function voteForProjectProposal(uint projectid,bool choice) public {
        require(block.timestamp < projects[projectid].votedeadline, "voting deadline is passed");
        require(balanceOf(msg.sender) > 0,"in order to vote, you should be a member"); // should have MyGov to vote
        require(projects[projectid].voters[msg.sender].did_vote == false, "you already have voted, you can't vote again"); // user hasn't voted yet
        // initially users have 0 power, when they vote it gets fixed to 1
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


    // delegate vote to another user
    // a user cant delegate himself
    // a user should be a member to delegate/vote
    // a user cant delegate to someone after voting or delegating to another person
    function delegateVoteTo(address memberaddr, uint projectid) public{
        require(memberaddr != msg.sender, "you can't delegate yourself");
        require(balanceOf(msg.sender) > 0,"in order to delegate vote, you should be a member"); // should have MyGov to vote
        require(!projects[projectid].voters[msg.sender].did_vote, "you already voted");
        projects[projectid].voters[msg.sender].did_vote = true;
        projects[projectid].voters[msg.sender].delegating_to = memberaddr;
        // loop check for chain of delegation
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

    // vote for next payment
    // check for deadline
    // check if user is a member
    function voteForProjectPayment(uint projectid,bool choice) public {
        uint paymentDeadline = projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
        uint paymentAmount = projects[projectid].paymentamounts[projects[projectid].ongoingPaymentIndex];
        require(block.timestamp < paymentDeadline, "voting deadline is passed");
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


    // only owner of project can reserve, deadline shouldn't be passed, checks if it is already reserved, checks for votes and checks if there are enough to reserve
    function reserveProjectGrant(uint projectid) public{
        require(msg.sender==projects[projectid].owner, "only the owner can reserve");
        require(block.timestamp < projects[projectid].votedeadline, "deadline has passed");
        require(!projects[projectid].reserved, "already reserved"); // can not reserve more than once.
        
        require(projects[projectid].yesCount * 10 >= userCount, "not enough vote"); // check if 10% said yes
        
        uint total_payment = 0;
        for(uint i=0; i<projects[projectid].paymentamounts.length; i++){
            total_payment += projects[projectid].paymentamounts[i];
        }

        require(address(this).balance - reservedWei >= total_payment, "not enough wei"); 

        reservedWei += total_payment;
        projects[projectid].reserved = true;
        no_funded++;
    }
    

    // to be able to withdraw, it should be called by owner, project must be funded, project payment must be ongoing - not over, deadline hasn't passed
    // reserved amount is enough, enough vote
    function withdrawProjectPayment(uint projectid) public payable{
        require(msg.sender==projects[projectid].owner, "only the owner can withdraw");
        require(getIsProjectFunded(projectid), "project isn't funded");
        require(!projects[projectid].withdraw_all_money, "project payment is completed");
        uint paymentDeadline = projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
        uint paymentAmount = projects[projectid].paymentamounts[projects[projectid].ongoingPaymentIndex];
        uint yesCount = projects[projectid].yesCounts_payment[projects[projectid].ongoingPaymentIndex];
        
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

    // gets project owner by projectid
    function getProjectOwner(uint projectid) public view returns(address projectowner)
    {
        return projects[projectid].owner;
    }


    // gets project info by projectid
    function getProjectInfo(uint projectid) public view returns(string memory ipfshash, uint votedeadline,uint [] memory paymentamounts, uint [] memory payschedule) 
    {
        return (
            projects[projectid].ipfshash,
            projects[projectid].votedeadline,
            projects[projectid].paymentamounts,
            projects[projectid].payschedule
        );
    }

    // gets nextprojectpayment if it is funded and if it is still ongoing(it didn't receive all payments)
    function getProjectNextPayment(uint projectid) public view returns(uint next)
    {
        require(getIsProjectFunded(projectid), "the project isn't funded");
        require(!projects[projectid].withdraw_all_money,"all payments are finished");
        return projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex];
    }

    // get no of funded prjects
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

    // get if project is funded, checks for if payment is reserved and if next payment is in future, which means if there is a payment that hasn't occured
    // in past due to not enough votes or owner not withdrawing payment we assumed it is not funded and didn't include such projects in funded category
    function getIsProjectFunded (uint projectid) public view returns(bool funded)
    {
        return (projects[projectid].reserved) && (projects[projectid].payschedule[projects[projectid].ongoingPaymentIndex] > block.timestamp);
    }
    
    // get ethers received by project
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
