pragma solidity ^0.4.16;

contract ReferenceContract{
    
    uint public tokensListCount;
    mapping (uint => address) public tokensList;
    
    function addToken(address _token_address, bool validity) returns(uint);
     
     //function getToken(address _token_address) returns(ERC20Token);
     
     function getAllTokens();
     
     function isValidToken(address _token_address) constant returns(bool);

     //NEEDS TO BE REVIEWED
     function removeToken(address _token_address);
}

contract ReferenceCaller{
    ReferenceContract rc;
    
    function ReferenceCaller(address _ref){
        rc = ReferenceContract(_ref);
    }
    
    function changeReferenceContract(address _ref){
        rc = ReferenceContract(_ref);
    }
    
    function getPrint(uint r) constant returns(address enable){
        enable = rc.tokensList(r);
    }
    
    function getCount() constant returns(uint c){
        c = rc.tokensListCount();
    }
}
