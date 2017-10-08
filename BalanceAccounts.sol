pragma solidity ^0.4.0;

contract Test{
    address owner;
    mapping(address=>uint) balances;
    
    function Test(){
        owner = msg.sender;
    }
    
    function getBalance() constant returns(uint){
        return balances[msg.sender];
    }
    
    function setBalance(uint bal){
        balances[msg.sender] = bal;
    }
    
    function addBalance(uint bal){
        balances[msg.sender] += bal;
    }
    
    function setBalance(address addr, uint bal) isOwner{
        balances[addr] = bal;
    }
    
    function addBalance(address addr, uint bal) isOwner{
        balances[addr] += bal;
    }
    
    function kill() isOwner{
        suicide(owner);
    }
    
    modifier isOwner(){
        require(msg.sender == owner);
        _;
    }
}
