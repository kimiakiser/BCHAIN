pragma solidity ^0.5.1;

contract EZCreditFactory{
    // ToDo: Store these values offchain.
    EZCredit[] public contracts;
    address[] public blockedAddresses;
    
    function requestCredit(uint requestAmountInFinney, uint8 interestPermille, uint8 durationOfContract, uint8 durationPerPayment) public{
        assert(requestAmountInFinney != 0);
        assert(durationOfContract != 0);
        assert(durationPerPayment != 0);
        
        // Make sure the debtor is not blocked.
        for(uint i=0;i<blockedAddresses.length;i++){
            assert(msg.sender != blockedAddresses[i]);
        }
        
        // ToDo: Check the successful credits and debits from the debtor.
        // ToDo: Use oracles to change Ether into FIAT currency.
        
        EZCredit ezCreditContract = new EZCredit(msg.sender, requestAmountInFinney, interestPermille, durationOfContract, durationPerPayment, 20, 0, 0);
        
        contracts.push(ezCreditContract);
        
        // Raise an event with the address of the created contract. This event can be read by an outstander and thus the new contract address can be retrieved.
        emit contractCreated(ezCreditContract);
    }
    
    function blockDebtor(address debtor) public{
        for(uint i=0;i<contracts.length;i++){
            // Only a known contract can block someone.
            if(address(contracts[i]) == msg.sender){
                blockedAddresses.push(debtor);
                return;
            }
        }
    }
    
    event contractCreated(EZCredit ezCreditContract);
}


contract EZCredit {
    uint public requestAmountInFinney;
    uint public amountToPayBack;
    uint public outstandingDebt;
    uint8 public interestPermille;
    uint8 public durationOfContract;
    uint8 public durationPerPayment;
    address payable private debtor;
    address payable private creditor;
    uint public startTime;
    uint public amountPerPeriod;
    uint public commision;
    uint public successfulCredits;
    uint public successfulDebits;
    
    EZCreditFactory private ezCreditFactory;
    
    constructor(address payable _debtor, uint _requestAmountInFinney, uint8 _interestPermille, uint8 _durationOfContract, uint8 _durationPerPayment, uint8 _commision, uint _successfulCredits, uint _successfulDebits) public{
        assert(_debtor != address(0));
        assert(_requestAmountInFinney != 0);
        assert(_durationOfContract != 0);
        assert(_durationPerPayment != 0);
        
        debtor = _debtor;
        commision = _commision;
        successfulDebits = _successfulDebits;
        successfulCredits = _successfulCredits;
        requestAmountInFinney = _requestAmountInFinney;
        interestPermille = _interestPermille;
        durationOfContract = _durationOfContract;
        durationPerPayment = _durationPerPayment;
        
        outstandingDebt = requestAmountInFinney + (requestAmountInFinney * (interestPermille + commision) / 1000);
        amountToPayBack = outstandingDebt;
        amountPerPeriod = amountToPayBack / (durationOfContract / durationPerPayment);
        
        ezCreditFactory = EZCreditFactory(msg.sender);
    }
    
    function giveCredit() public payable {
        assert(creditor == address(0));
        
        startTime = now;
        creditor = msg.sender;
        debtor.transfer(msg.value);
    }
    
    function payback() public payable{
        assert(creditor != address(0));
        assert(outstandingDebt > 0);
        
        uint neededValue = amountToPayBack / (durationOfContract / durationPerPayment);
        
        if(neededValue > outstandingDebt){
            neededValue = outstandingDebt;
        }
        
        assert(msg.value / (1 finney) >= neededValue);
        
        // Don't let the debtor pay too much.
        if(outstandingDebt >= (msg.value / (1 finney))){
            outstandingDebt = outstandingDebt - (msg.value / (1 finney));
            creditor.transfer(msg.value);
        }
        else{
            uint valueToSend = outstandingDebt * (1 finney);
            outstandingDebt = 0;
            creditor.transfer(valueToSend);
            debtor.transfer(msg.value - valueToSend);
        }
    }
    
    function blockDebtor() public{
        assert(debtor != address(0));
        assert(creditor != address(0));
        
        uint paymentsDue = (now - startTime) / durationPerPayment;
        uint ownedAmount = paymentsDue * amountPerPeriod;
        
        // If at this time the debtor has not made enough payments, block him.
        if(amountToPayBack - outstandingDebt < ownedAmount){
            ezCreditFactory.blockDebtor(debtor);
        }
    }
}