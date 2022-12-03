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
    }

    receive() external payable {}
    fallback() external payable {}

}
