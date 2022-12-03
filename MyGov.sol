pragma solidity ^0.8.0;
// SPDX-License-Identifier: AGPL-3.0-only

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyGov is ERC20{
    
    string public mymessage ;
    uint tokens_to_mint = 10000000;
    mapping(address => bool) public took_faucet;
    address payable owner;
    uint donatedEthers = 0;
    uint donatedTokens = 0;

    /* constructor */
    constructor(uint tokensupply) ERC20("My Gov Token", "MYG"){
        owner = payable(msg.sender);
        tokens_to_mint = tokensupply;
    }


    function faucet() public{
        require(tokens_to_mint >= 1);
        require(!took_faucet[msg.sender]);
        took_faucet[msg.sender] = true;
        tokens_to_mint -= 1;
        _mint(msg.sender,1);
    }

    function donateEther() public payable
    {
        (bool success,) = owner.call{value: msg.value}("");
        require(success, "Failed to donate ethers");
        donatedEthers += msg.value;
    }

    function donateMyGovToken(uint amount) public 
    {
        (bool success) = transfer(owner,amount);
        require(success, "Failed to donate tokens");
        donatedTokens += amount;
    }

    function message() public view returns (string memory) {
        return(mymessage);
    }

    receive() external payable {}
    fallback() external payable {}

}
