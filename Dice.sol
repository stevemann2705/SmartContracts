pragma solidity ^0.4.18;

contract Etheroll is usingOraclize, DSSafeAddSub {
    
     using strings for *;

    /*
     * checks player profit, bet size and player number is within range
    */
    modifier betIsValid(uint _betSize, uint _playerNumber) {      
        if(((((_betSize * (100-(safeSub(_playerNumber,1)))) / (safeSub(_playerNumber,1))+_betSize))*houseEdge/houseEdgeDivisor)-_betSize > maxProfit || _betSize < minBet || _playerNumber < minNumber || _playerNumber > maxNumber) revert();        
		_;
    }

    /*
     * checks game is currently active
    */
    modifier gameIsActive {
        if(gamePaused == true) revert();
		_;
    }    

    /*
     * checks payouts are currently active
    */
    modifier payoutsAreActive {
        if(payoutsPaused == true) revert();
		_;
    }    

    /*
     * checks only Oraclize address is calling
    */
    modifier onlyOraclize {
        if (msg.sender != oraclize_cbAddress()) revert();
        _;
    }

    /*
     * checks only owner address is calling
    */
    modifier onlyOwner {
         if (msg.sender != owner) revert();
         _;
    }

    /*
     * checks only treasury address is calling
    */
    modifier onlyTreasury {
         if (msg.sender != treasury) revert();
         _;
    }    

    /*
     * game vars
    */ 
    uint constant public maxProfitDivisor = 1000000;
    uint constant public houseEdgeDivisor = 1000;    
    uint constant public maxNumber = 99; 
    uint constant public minNumber = 2;
	bool public gamePaused;
    uint32 public gasForOraclize;
    address public owner;
    bool public payoutsPaused; 
    address public treasury;
    uint public contractBalance;
    uint public houseEdge;     
    uint public maxProfit;   
    uint public maxProfitAsPercentOfHouse;                    
    uint public minBet; 

    address tokenAddress;
    

    //init discontinued contract data         
    int public totalBets = 138472;
    uint public maxPendingPayouts;
    //init discontinued contract data         
    uint public totalWeiWon = 61779454774685332087870;
    //init discontinued contract data  
    uint public totalWeiWagered = 213696169063866525745355;    

    /*
     * player vars
    */
    mapping (bytes32 => address) playerAddress;
    mapping (bytes32 => address) playerTempAddress;
    mapping (bytes32 => bytes32) playerBetId;
    mapping (bytes32 => uint) playerBetValue;
    mapping (bytes32 => uint) playerTempBetValue;       
    mapping (bytes32 => uint) playerDieResult;
    mapping (bytes32 => uint) playerNumber;
    mapping (address => uint) playerPendingWithdrawals;      
    mapping (bytes32 => uint) playerProfit;
    mapping (bytes32 => uint) playerTempReward;           

    /*
     * events
    */
    /* log bets + output to web3 for precise 'payout on win' field in UI */
    event LogBet(bytes32 indexed BetID, address indexed PlayerAddress, uint indexed RewardValue, uint ProfitValue, uint BetValue, uint PlayerNumber);      
    /* output to web3 UI on bet result*/
    /* Status: 0=lose, 1=win, 2=win + failed send, 3=refund, 4=refund + failed send*/
	event LogResult(uint indexed ResultSerialNumber, bytes32 indexed BetID, address indexed PlayerAddress, uint PlayerNumber, uint DiceResult, uint Value, int Status, bytes Proof);   
    /* log manual refunds */
    event LogRefund(bytes32 indexed BetID, address indexed PlayerAddress, uint indexed RefundValue);
    /* log owner transfers */
    event LogOwnerTransfer(address indexed SentToAddress, uint indexed AmountTransferred);               


    /*
     * init
    */
    function Etheroll(address _tokenAddress) {

        owner = msg.sender;
        treasury = msg.sender;

        tokenAddress = _tokenAddress;

        oraclize_setNetwork(networkID_auto);        
        /* use TLSNotary for oraclize call */
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
        /* init 990 = 99% (1% houseEdge)*/
        ownerSetHouseEdge(990);
        /* init 10,000 = 1%  */
        ownerSetMaxProfitAsPercentOfHouse(10000);
        /* init min bet (0.1 ether) */
        ownerSetMinBet(100000000000000000);        
        /* init gas for oraclize */        
        gasForOraclize = 235000;        

    }

    function deposit(uint value) returns(uint) {
        ERC20 token = ERC20(tokenAddress);
        require(token.balanceOf(msg.sender) > value);
        token.transferFrom(msg.sender, this, value);
        safeAdd(contractBalance, value);
        return(value);
        
    }

    /*
     * public function
     * player submit bet
     * only if game is active & bet is valid can query oraclize and set player vars     
    */
    function playerRollDice(uint rollUnder, uint value) public 
        gameIsActive
        betIsValid(value, rollUnder)
	{       
        require(contractBalance >= value);

        /*
        * assign partially encrypted query to oraclize
        * only the apiKey is encrypted 
        * integer query is in plain text
        */               
        bytes32 rngId = oraclize_query("nested", "[URL] ['json(https://api.random.org/json-rpc/1/invoke).result.random[\"serialNumber\",\"data\"]', '\\n{\"jsonrpc\":\"2.0\",\"method\":\"generateSignedIntegers\",\"params\":{\"apiKey\":${[decrypt] BK8UxIEHLaY8JEQDl1sjK73+fDZaze2oRyp3OzgI3Q1Xbz7xFGJ7pKtmKXdyiML5e26HYeoxO4fOFoVQ7iHBVd3Olm0gowJ60oIiC+OfrOB+dsoobaztcFmEKMgh7bLXREL9ORAb7rUD4DVlH4NpxQ4mfkgKvtE=},\"n\":1,\"min\":1,\"max\":100,\"replacement\":true,\"base\":10${[identity] \"}\"},\"id\":1${[identity] \"}\"}']", gasForOraclize);
        	    
        /* map bet id to this oraclize query */
		playerBetId[rngId] = rngId;
        /* map player lucky number to this oraclize query */
		playerNumber[rngId] = rollUnder;
        /* map value of wager to this oraclize query */
        playerBetValue[rngId] = value;
        /* map player address to this oraclize query */
        playerAddress[rngId] = msg.sender;
        /* safely map player profit to this oraclize query */                     
        playerProfit[rngId] = ((((value * (100-(safeSub(rollUnder,1)))) / (safeSub(rollUnder,1))+value))*houseEdge/houseEdgeDivisor)-value;        
        /* safely increase maxPendingPayouts liability - calc all pending payouts under assumption they win */
        maxPendingPayouts = safeAdd(maxPendingPayouts, playerProfit[rngId]);
        /* check contract can payout on win */
        if(maxPendingPayouts >= contractBalance) throw;
        /* provides accurate numbers for web3 and allows for manual refunds in case of no oraclize __callback */
        LogBet(playerBetId[rngId], playerAddress[rngId], safeAdd(playerBetValue[rngId], playerProfit[rngId]), playerProfit[rngId], playerBetValue[rngId], playerNumber[rngId]);          

    }   
             

    /*
    * semi-public function - only oraclize can call
    */
    /*TLSNotary for oraclize call */
	function __callback(bytes32 myid, string result, bytes proof) public   
		onlyOraclize
		payoutsAreActive
	{  

        /* player address mapped to query id does not exist */
        if (playerAddress[myid]==0x0) throw;
        
        /* keep oraclize honest by retrieving the serialNumber from random.org result */
        var sl_result = result.toSlice();
        sl_result.beyond("[".toSlice()).until("]".toSlice());
        uint serialNumberOfResult = parseInt(sl_result.split(', '.toSlice()).toString());          

	    /* map result to player */
        playerDieResult[myid] = parseInt(sl_result.beyond("[".toSlice()).until("]".toSlice()).toString());
        
        /* get the playerAddress for this query id */
        playerTempAddress[myid] = playerAddress[myid];
        /* delete playerAddress for this query id */
        delete playerAddress[myid];

        /* map the playerProfit for this query id */
        playerTempReward[myid] = playerProfit[myid];
        /* set  playerProfit for this query id to 0 */
        playerProfit[myid] = 0; 

        /* safely reduce maxPendingPayouts liability */
        maxPendingPayouts = safeSub(maxPendingPayouts, playerTempReward[myid]);         

        /* map the playerBetValue for this query id */
        playerTempBetValue[myid] = playerBetValue[myid];
        /* set  playerBetValue for this query id to 0 */
        playerBetValue[myid] = 0; 

        /* total number of bets */
        totalBets += 1;

        /* total wagered */
        totalWeiWagered += playerTempBetValue[myid];                                                           

        /*
        * refund
        * if result is 0 result is empty or no proof refund original bet value
        * if refund fails save refund value to playerPendingWithdrawals
        */
        if(playerDieResult[myid]==0 || bytes(result).length == 0 || bytes(proof).length == 0){                                                     

             LogResult(serialNumberOfResult, playerBetId[myid], playerTempAddress[myid], playerNumber[myid], playerDieResult[myid], playerTempBetValue[myid], 3, proof);            

            /*
            * send refund - external call to an untrusted contract
            * if send fails map refund value to playerPendingWithdrawals[address]
            * for withdrawal later via playerWithdrawPendingTransactions
            */
            if(!playerTempAddress[myid].send(playerTempBetValue[myid])){
                LogResult(serialNumberOfResult, playerBetId[myid], playerTempAddress[myid], playerNumber[myid], playerDieResult[myid], playerTempBetValue[myid], 4, proof);              
                /* if send failed let player withdraw via playerWithdrawPendingTransactions */
                playerPendingWithdrawals[playerTempAddress[myid]] = safeAdd(playerPendingWithdrawals[playerTempAddress[myid]], playerTempBetValue[myid]);                        
            }

            return;
        }

        /*
        * pay winner
        * update contract balance to calculate new max bet
        * send reward
        * if send of reward fails save value to playerPendingWithdrawals        
        */
        if(playerDieResult[myid] < playerNumber[myid]){ 

            /* safely reduce contract balance by player profit */
            contractBalance = safeSub(contractBalance, playerTempReward[myid]); 

            /* update total wei won */
            totalWeiWon = safeAdd(totalWeiWon, playerTempReward[myid]);              

            /* safely calculate payout via profit plus original wager */
            playerTempReward[myid] = safeAdd(playerTempReward[myid], playerTempBetValue[myid]); 

            LogResult(serialNumberOfResult, playerBetId[myid], playerTempAddress[myid], playerNumber[myid], playerDieResult[myid], playerTempReward[myid], 1, proof);                            

            /* update maximum profit */
            setMaxProfit();
            
            /*
            * send win - external call to an untrusted contract
            * if send fails map reward value to playerPendingWithdrawals[address]
            * for withdrawal later via playerWithdrawPendingTransactions
            */
            if(!playerTempAddress[myid].send(playerTempReward[myid])){
                LogResult(serialNumberOfResult, playerBetId[myid], playerTempAddress[myid], playerNumber[myid], playerDieResult[myid], playerTempReward[myid], 2, proof);                   
                /* if send failed let player withdraw via playerWithdrawPendingTransactions */
                playerPendingWithdrawals[playerTempAddress[myid]] = safeAdd(playerPendingWithdrawals[playerTempAddress[myid]], playerTempReward[myid]);                               
            }

            return;

        }

        /*
        * no win
        * send 1 wei to a losing bet
        * update contract balance to calculate new max bet
        */
        if(playerDieResult[myid] >= playerNumber[myid]){

            LogResult(serialNumberOfResult, playerBetId[myid], playerTempAddress[myid], playerNumber[myid], playerDieResult[myid], playerTempBetValue[myid], 0, proof);                                

            /*  
            *  safe adjust contractBalance
            *  setMaxProfit
            *  send 1 wei to losing bet
            */
            contractBalance = safeAdd(contractBalance, (playerTempBetValue[myid]-1));                                                                         

            /* update maximum profit */
            setMaxProfit(); 

            /*
            * send 1 wei - external call to an untrusted contract                  
            */
            if(!playerTempAddress[myid].send(1)){
                /* if send failed let player withdraw via playerWithdrawPendingTransactions */                
               playerPendingWithdrawals[playerTempAddress[myid]] = safeAdd(playerPendingWithdrawals[playerTempAddress[myid]], 1);                                
            }                                   

            return;

        }

    }
    
    /*
    * public function
    * in case of a failed refund or win send
    */
    function playerWithdrawPendingTransactions() public 
        payoutsAreActive
        returns (bool)
     {
        uint withdrawAmount = playerPendingWithdrawals[msg.sender];
        playerPendingWithdrawals[msg.sender] = 0;
        /* external call to untrusted contract */
        if (msg.sender.call.value(withdrawAmount)()) {
            return true;
        } else {
            /* if send failed revert playerPendingWithdrawals[msg.sender] = 0; */
            /* player can try to withdraw again later */
            playerPendingWithdrawals[msg.sender] = withdrawAmount;
            return false;
        }
    }

    /* check for pending withdrawals  */
    function playerGetPendingTxByAddress(address addressToCheck) public constant returns (uint) {
        return playerPendingWithdrawals[addressToCheck];
    }

    /*
    * internal function
    * sets max profit
    */
    function setMaxProfit() internal {
        maxProfit = (contractBalance*maxProfitAsPercentOfHouse)/maxProfitDivisor;  
    }   

    /*
    * owner/treasury address only functions
    */
    function ()
        onlyTreasury
    {
        
        /* safely update contract balance */
        //contractBalance = safeAdd(contractBalance, msg.value); 
        deposit(0);       
        /* update the maximum profit */
        setMaxProfit();
    } 

    /* set gas for oraclize query */
    function ownerSetOraclizeSafeGas(uint32 newSafeGasToOraclize) public 
		onlyOwner
	{
    	gasForOraclize = newSafeGasToOraclize;
    }

    /* only owner adjust contract balance variable (only used for max profit calc) */
    function ownerUpdateContractBalance(uint newContractBalanceInWei) public 
		onlyOwner
    {        
       contractBalance = newContractBalanceInWei;
    }    

    /* only owner address can set houseEdge */
    function ownerSetHouseEdge(uint newHouseEdge) public 
		onlyOwner
    {
        houseEdge = newHouseEdge;
    }

    /* only owner address can set maxProfitAsPercentOfHouse */
    function ownerSetMaxProfitAsPercentOfHouse(uint newMaxProfitAsPercent) public 
		onlyOwner
    {
        /* restrict each bet to a maximum profit of 1% contractBalance */
        if(newMaxProfitAsPercent > 10000) throw;
        maxProfitAsPercentOfHouse = newMaxProfitAsPercent;
        setMaxProfit();
    }

    /* only owner address can set minBet */
    function ownerSetMinBet(uint newMinimumBet) public 
		onlyOwner
    {
        minBet = newMinimumBet;
    }       

    /* only owner address can transfer ether */
    function ownerTransferEther(address sendTo, uint amount) public 
		onlyOwner
    {        
        /* safely update contract balance when sending out funds*/
        contractBalance = safeSub(contractBalance, amount);		
        /* update max profit */
        setMaxProfit();
        if(!tokenAddress.transfer(amount)) throw;
        LogOwnerTransfer(sendTo, amount); 
    }

    /* only owner address can do manual refund
    * used only if bet placed + oraclize failed to __callback
    * filter LogBet by address and/or playerBetId:
    * LogBet(playerBetId[rngId], playerAddress[rngId], safeAdd(playerBetValue[rngId], playerProfit[rngId]), playerProfit[rngId], playerBetValue[rngId], playerNumber[rngId]);
    * check the following logs do not exist for playerBetId and/or playerAddress[rngId] before refunding:
    * LogResult or LogRefund
    * if LogResult exists player should use the withdraw pattern playerWithdrawPendingTransactions 
    */
    function ownerRefundPlayer(bytes32 originalPlayerBetId, address sendTo, uint originalPlayerProfit, uint originalPlayerBetValue) public 
		onlyOwner
    {        
        /* safely reduce pendingPayouts by playerProfit[rngId] */
        maxPendingPayouts = safeSub(maxPendingPayouts, originalPlayerProfit);
        /* send refund */
        if(!tokenAddress.transfer(originalPlayerBetValue)) throw;
        /* log refunds */
        LogRefund(originalPlayerBetId, sendTo, originalPlayerBetValue);        
    }    

    /* only owner address can set emergency pause #1 */
    function ownerPauseGame(bool newStatus) public 
		onlyOwner
    {
		gamePaused = newStatus;
    }

    /* only owner address can set emergency pause #2 */
    function ownerPausePayouts(bool newPayoutStatus) public 
		onlyOwner
    {
		payoutsPaused = newPayoutStatus;
    } 

    /* only owner address can set treasury address */
    function ownerSetTreasury(address newTreasury) public 
		onlyOwner
	{
        treasury = newTreasury;
    }         

    /* only owner address can set owner address */
    function ownerChangeOwner(address newOwner) public 
		onlyOwner
	{
        owner = newOwner;
    }

    /* only owner address can suicide - emergency */
    function ownerkill() public 
		onlyOwner
	{
		suicide(owner);
	}    


}
