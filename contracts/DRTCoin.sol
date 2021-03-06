pragma solidity ^0.4.11;

import "./StandardToken.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

/* DomRaiderToken Contract */
contract DRTCoin is StandardToken, Ownable {
	/* Overriding some ERC20 variables */
	string public constant name      = "DomRaiderToken";
	string public constant symbol    = "DRT";
	uint256 public constant decimals = 8;
	/* DRT specific variables */
	// Max amount of tokens minted - Exact value inputed avec strech goals and before deploying contract
	uint256 public constant MAX_SUPPLY_NBTOKEN    = 1000000000 * 10 ** decimals;
	// Freeze duration for advisors accounts
	// uint256 public constant START_ICO_TIMESTAMP   = 1501595111;
	uint256 public START_ICO_TIMESTAMP   = 1501595111; // not constant for testing (overwritten in the constructor)
	uint public constant DEFROST_PERIOD           = 6; // month in minutes  (1month = 43200 min)
	uint public constant DEFROST_MONTHLY_PERCENT_OWNER  = 5 ; // 5% per month is automaticaly defrosted
	uint public constant DEFROST_INITIAL_PERCENT_OWNER  = 10 ; // 90% locked
	uint public constant DEFROST_MONTHLY_PERCENT  = 10 ; // 10% per month is automaticaly defrosted
	uint public constant DEFROST_INITIAL_PERCENT  = 20 ; // 80% locked

	// Fields that can be changed by functions
	address[] icedBalances ;
  	// mapping (address => bool) icedBalances; //Initial implementation as a mapping
	mapping (address => uint256) icedBalances_frosted;
	mapping (address => uint256) icedBalances_defrosted;
	uint256 ownerFrosted;
	uint256 ownerDefrosted;

	// Variable usefull for verifying that the assignedSupply matches that totalSupply
	uint256 public assignedSupply;
	//Boolean to allow or not the initial assignement of token (batch)
	bool public batchAssignStopped = false;

	/**
	* @dev Contructor that gives msg.sender all of existing tokens.
	*/
	function DRTCoin() {
		owner                = msg.sender;
		uint256 amount       = MAX_SUPPLY_NBTOKEN / 2;
		uint256 amount2assign = amount * DEFROST_INITIAL_PERCENT_OWNER / 100;
		balances[owner]  = amount2assign;
		ownerDefrosted = amount2assign;
		ownerFrosted   = amount - amount2assign;

		totalSupply          = MAX_SUPPLY_NBTOKEN;
		assignedSupply       = MAX_SUPPLY_NBTOKEN / 2;
		// for test only: set START_ICO to contract creation timestamp
		// +600 => add 10 minutes (so defrost start 10 min later, too)
		START_ICO_TIMESTAMP = now + 600;
	}

	/**
	* @dev Transfer tokens in batches (of adresses)
	* @param _vaddr address The address which you want to send tokens from
	* @param _vamounts address The address which you want to transfer to
	*/
	function batchAssignTokens(address[] _vaddr, uint[] _vamounts, bool[] _vIcedBalance ) onlyOwner {
		require ( batchAssignStopped == false );
		require ( _vaddr.length == _vamounts.length );
		//Looping into input arrays to assign target amount to each given address
		for (uint index=0; index<_vaddr.length; index++) {
			address toAddress = _vaddr[index];
			uint amount = _vamounts[index] * 10 ** decimals;
			bool isIced = _vIcedBalance[index];
			if (balances[toAddress] == 0) {
				// In case it's filled two times, it only increments once
				// Assigns the balance
				assignedSupply += amount ;
				if (  isIced  == false ) {
					// Normal account
					balances[toAddress] = amount;
					// TODO allowance ??
				}
				else {
					// Iced account. The balance is not affected here
					icedBalances.push(toAddress) ;
					uint256 amount2assign 		  = amount * DEFROST_INITIAL_PERCENT / 100;
					balances[toAddress]               = amount2assign;
					icedBalances_defrosted[toAddress] = amount2assign;
					icedBalances_frosted[toAddress]   = amount - amount2assign;
				}
			}
		}
	}

	function canDefrost() onlyOwner constant returns (bool bCanDefrost){
		bCanDefrost = now > START_ICO_TIMESTAMP;
	}

	function getBlockTimestamp() constant returns (uint256){
		return now;
	}


	/**
   	* @dev Defrost token (for advisors)
	* Method called by the owner once per defrost period (1 month)
   	*/
	function defrostToken() {
		require(now > START_ICO_TIMESTAMP) ;
		// Looping into the iced accounts
		for (uint index=0; index<icedBalances.length; index++) {
			address currentAddress  = icedBalances[index];
			uint256 amountTotal     = icedBalances_frosted[currentAddress]+ icedBalances_defrosted[currentAddress];
			//uint256 amountToRelease = amountTotal * DEFROST_MONTHLY_PERCENT / 100;
			uint256 targetDeFrosted = (SafeMath.minimum(100,DEFROST_INITIAL_PERCENT + elapedMonthsFromICOStart()*DEFROST_MONTHLY_PERCENT)) * amountTotal / 100;
			uint256 amountToRelease = targetDeFrosted - icedBalances_defrosted[currentAddress];
			if ( amountToRelease > 0 ) {
				icedBalances_frosted[currentAddress]   = icedBalances_frosted[currentAddress] - amountToRelease;
				icedBalances_defrosted[currentAddress] = icedBalances_defrosted[currentAddress] + amountToRelease;
				balances[currentAddress]               = balances[currentAddress] + amountToRelease;
			}
		}

	}
        /**
	* Defrost for the owner of the contract
	*/
 	function defrostOwner() {
		if(now<START_ICO_TIMESTAMP){
			return;
		}
		uint256 amountTotal     = ownerFrosted + ownerDefrosted;
		uint256 targetDeFrosted = (SafeMath.minimum(100,DEFROST_INITIAL_PERCENT_OWNER + elapedMonthsFromICOStart()*DEFROST_MONTHLY_PERCENT_OWNER)) * amountTotal / 100;
		uint256 amountToRelease = targetDeFrosted - ownerDefrosted;
		if ( amountToRelease > 0 ) {
			ownerFrosted   = ownerFrosted - amountToRelease;
			ownerDefrosted = ownerDefrosted + amountToRelease;
			balances[owner] = balances[owner] + amountToRelease;
		}
	}

	function elapedMonthsFromICOStart() constant returns (uint elapsed) {
		elapsed = ((now-START_ICO_TIMESTAMP)/60)/DEFROST_PERIOD ;
	}

	function stopBatchAssign() onlyOwner {
		require ( batchAssignStopped == false);
		batchAssignStopped = true;
	}

	function getAddressBalance(address addr) constant returns (uint256 balance)  {
		balance = balances[addr];
	}

	function getAddressAndBalance(address addr) constant returns (address _address, uint256 _amount)  {
		_address = addr;
		_amount = balances[addr];
	}

	function getIcedAddresses() constant returns (address[] vaddr)  {
		vaddr = icedBalances;
	}

	function getIcedInfos(address addr) constant returns (address icedaddr, uint256 balance, uint256 frosted, uint256 defrosted)  {
		icedaddr = addr;
		balance = balances[addr];
		frosted = icedBalances_frosted[addr];
		defrosted = icedBalances_defrosted[addr];
	}

	function getOwnerInfos() constant returns (address owneraddr, uint256 balance, uint256 frosted, uint256 defrosted)  {
		owneraddr= owner;
		balance = balances[owneraddr];
		frosted = ownerFrosted;
		defrosted = ownerDefrosted;
	}

	function killContract() onlyOwner {
		suicide(owner);
	}

}
