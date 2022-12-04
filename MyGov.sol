pragma solidity ^0.8.0;
// SPDX-License-Identifier: AGPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract MyGov is ERC20{
    
    string public mymessage ;
    uint tokens_to_mint = 10000000;
    mapping(address => bool) public took_faucet;
    address payable owner;
    uint donatedEthers = 0;
    uint donatedTokens = 0;

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
        donateEther(40000000000000000); // 4*(10**16) --> 0.04 ether
        require(block.timestamp > surveydeadline, "deadline should be after current time");
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

    function donateEther(uint amount) public payable returns(uint amount2)
    {
        bool status = payable(address(this)).send(amount);
        require(status, "Failed to donate ethers");
        donatedEthers += amount;
        return amount;
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

    struct Voter
    {
        address delegating_to;
        bool did_vote;
        uint power;
        bool choice;
    }


    struct ProjectData { 
        string ipfshash;
        uint votedeadline;
        uint [] paymentamounts;
        uint [] yesCounts_payment;
        uint [] payschedule;
        uint yesCount;
        address owner;
        bool reserved;
        mapping(address => Voter) voters;
        uint ethers_received;
    }

    uint public userCount = 0; // TODO: what about the owner?
    mapping(uint => ProjectData) public projects;
    uint projectId = 0;

    uint reservedWei = 0;

    uint no_funded = 0;

    // TODO: check whether payschedule is incremental and after votedeadline
    function submitProjectProposal(string memory ipfshash, uint votedeadline,uint [] memory paymentamounts, uint [] memory payschedule) public payable returns (uint projectid) {
        require(2 < votedeadline);
        // require(block.timestamp < votedeadline);
        //payments --> 5 token, 0.01 ether
        donateMyGovToken(5);
        require(msg.value == 10000000000000000, "you should pay 0.01 ethers");  
        donateEther(10000000000000000); // 4*(10**16) --> 0.04 ether
        projectid = projectId;
        projectId++;
        projects[projectid].ipfshash = ipfshash;
        projects[projectid].votedeadline = votedeadline;
        projects[projectid].paymentamounts = paymentamounts;
        projects[projectid].payschedule = payschedule;
        projects[projectid].yesCounts_payment = new uint[](payschedule.length);
        projects[projectid].owner = msg.sender;

        return projectid;
    }

    function voteForProjectProposal(uint projectid,bool choice) public{
        require(2 < projects[projectid].votedeadline, "voting deadline is passed");
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


    function voteForProjectPayment(uint projectid,bool choice) public{


    }


    function reserveProjectGrant(uint projectid) public{
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


    function withdrawProjectPayment(uint projectid) public{

    }

    function getProjectOwner(uint projectid) public view returns(address projectowner)
    {
        return projects[projectid].owner;
    }

    function getProjectInfo(uint projectid) public view returns(string memory ipfshash, uint votedeadline,uint [] memory paymentamounts, uint [] memory payschedule) 
    {
        return (
            projects[projectid].ipfshash,
            projects[projectid].votedeadline,
            projects[projectid].paymentamounts,
            projects[projectid].payschedule
        );
    }

    function getNoOfProjectProposals() public view returns(uint numproposals)
    {
        /*
        because projectId is initially 0 and increments by one after each project proposal submission,
        it can be considered as number of project proposals 
        */
        return projectId; 
    }

    function getIsProjectFunded(uint projectid) public view returns(bool funded)
    {
        return projects[projectid].reserved;
    }

    function getProjectNextPayment(uint projectid) public view returns(uint next)
    {
        require(projects[projectid].reserved, "the project isn't funded");
        uint i = 0;
        for(i = 0; i < projects[projectid].payschedule.length;i++)
        {
            if(projects[projectid].payschedule[i] > block.timestamp)
                return projects[projectid].payschedule[i];
        }
        /*
        if control reaches here, there is no future payments
        */
        require(false,"no future payments");
    }

    function getNoOfFundedProjects () public view returns(uint numfunded)
    {
        return no_funded;
    }

    function getEtherReceivedByProject (uint projectid) public view returns(uint amount)
    {
        return projects[projectid].ethers_received;
    }


    receive() external payable {}
    fallback() external payable {}

}
