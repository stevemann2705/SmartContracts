pragma solidity ^0.4.16;

contract ERC20Token {
     uint256 public totalSupply;
     function balanceOf(address who) public constant returns (uint256);
     function transfer(address to, uint256 value) public returns (bool);
     function allowance(address owner, address spender) public constant returns (uint256);
     function transferFrom(address from, address to, uint256 value) public returns (bool);
     function approve(address spender, uint256 value) public returns (bool);
}

contract ReferenceContract{
    
    uint public tokensListCount;
    mapping (uint => address) public tokensList;
    
    function ReferenceContract(address _prevReferenceTokenList){
        ReferenceContract rc = ReferenceContract(_addr);
        for(uint a=0; a<rc.tokensListCount(); a++){
            tokensList[a] = rc.tokensList(a);
        }
        tokensListCount = rc.tokensListCount();
    }
    
    function addToken(address _token_address, bool validity) returns(uint index){
        ERC20Token token = ERC20Token(_token_address);
        
        if(token.totalSupply() == 0){
            revert();
        }
        
        //index = tokensListCount++;
        tokensList[tokensListCount++] = _token_address;
     }
     
     function getToken(address _token_address) returns(ERC20Token token) {
         token = ERC20Token(_token_address);
     }
     
     function addOneToken(){
         
     }
     
     function getAllTokens() {
         
     }
     
     function isValidToken(address _token_address) constant returns(bool isValid){
         
         for(uint a=0; a<tokensListCount; a++){
             if (sha3(_token_address) == sha3(tokensList[a])){
                 isValid = true;
             }
         }
         
     }

     //NEEDS TO BE REVIEWED
     function removeToken(address _token_address){
         for(uint a=0; a<tokensListCount; a++){
             if (sha3(_token_address) == sha3(tokensList[a])){
                 delete tokensList[a];
             }
         }
      
     }
}
