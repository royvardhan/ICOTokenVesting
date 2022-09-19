// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./utils/AggregatorV3Interface.sol";

contract ICOTokenVesting is ERC20 {

    event SaleToggled(bool _bool);
    event lastBuy(address indexed _address, uint128 _amount, uint256 _ethSpent);
    event lastClaim(address indexed _address, uint128 _amount);

    uint public constant pricePerToken = 1 * 1e18; // $1 per token;
    uint private constant unlockInterval = 30 days;
    uint private currentDate;
    uint private prevUnlockDate;
    uint private nextUnlockDate; 
    uint public maxSupply;
    uint public currentSupply;
    uint128 private constant perUnlockPercentage = 20;
    bool public saleOngoing;
    address private owner;

    AggregatorV3Interface internal priceFeed;

    constructor(string memory _name, string memory _symbol, address _ethusdPriceFeedAddress, uint _maxSupply) ERC20(_name, _symbol) {
        owner = msg.sender;
        maxSupply = _maxSupply * (1e18);
        priceFeed = AggregatorV3Interface(_ethusdPriceFeedAddress);
        currentDate = block.timestamp;
        nextUnlockDate = currentDate + unlockInterval;
        emit SaleToggled(true);
    }

    struct VestingSchedule {
        uint128 tokensBought;
        uint128 currentBalance;
    }

    mapping(address => VestingSchedule) public addressVestingSchedule;

    modifier ableToUnlock() {
        require(block.timestamp > nextUnlockDate, "You cannot withdraw before the next unlock");
        if (prevUnlockDate != nextUnlockDate) {
        prevUnlockDate = nextUnlockDate;
        nextUnlockDate += unlockInterval;
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier isSaleOn() {
        require(saleOngoing == true, "Sale is over");
        _;
    }
    
    // This gets you the ETH price

    function getEthPrice() public view returns(uint){
        (,int256 price,,,)  = priceFeed.latestRoundData();
        return uint(price * 1e10);
    }

    // This will convert any amount of ETH into its USD value

    function getConversionRate(uint _ethAmount) public view returns(uint) {
        uint ethPrice = getEthPrice();
        uint ethAmountInUsd = (ethPrice * _ethAmount) / 1e18;
        return ethAmountInUsd;
    }


    function toggleSale(bool _bool) public onlyOwner returns(bool) {
        saleOngoing = _bool;
        return saleOngoing;
    }

    function buyToken(uint128 _amount) public payable isSaleOn  {
        if ((currentSupply + _amount) > maxSupply){
            revert();
        }
        require (currentSupply < maxSupply, "Maximum supply reached");
        require(getConversionRate(msg.value) >= _amount, "Not Enough ETH sent");
        addressVestingSchedule[msg.sender] = VestingSchedule(_amount, _amount );
        currentSupply += _amount;
        if(currentSupply == (maxSupply - 1)) {
            saleOngoing = false;
        }
        emit lastBuy(msg.sender, _amount, msg.value);
    }

    function userWithdrawal() public ableToUnlock payable {
        require(addressVestingSchedule[msg.sender].currentBalance > 0, "You dont have any tokens");
        uint128 tokenBought = addressVestingSchedule[msg.sender].tokensBought;
        uint128 ableToClaim = tokenBought / 100 * perUnlockPercentage;
        require(addressVestingSchedule[msg.sender].currentBalance >= ableToClaim, "You have already unlocked tokens");
        addressVestingSchedule[msg.sender].currentBalance -= ableToClaim;
        _mint(msg.sender, ableToClaim);
        emit lastClaim(msg.sender, ableToClaim);
    }


    //////////////// Helper Functions ////////////////

    function getBalance() public view returns(uint128) {
        return addressVestingSchedule[msg.sender].currentBalance;
    }

    function getBalanceByAddress(address _address) public view returns(uint128) {
        return addressVestingSchedule[_address].currentBalance;
    }


}