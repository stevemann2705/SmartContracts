pragma solidity ^0.4.18;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract RateOracle is Ownable{
    mapping(string => uint256) rates;
    uint timestamp;
    
    function RateOracle(){
        owner = msg.sender;
    }
    
    function setRate(string currency, uint256 rate) onlyOwner returns(bool){
        rates[currency] = rate;
        timestamp = now;
        return true;
    }
    
    function getRate(string currency) constant returns(uint256){
        return rates[currency];
    }
    
    function getTimestamp() constant returns(uint){
        return timestamp;
    }
}
