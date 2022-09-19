// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./utils/AggregatorV3Interface.sol";

contract ICOTokenVesting is ERC20 {

    bool public saleOngoing;
    address public owner;
    uint public maxSupply;
    uint public pricePerToken = 1 * 1e18; // $1 per token;
    uint public currentDate;
    uint public unlockInterval = 30 days;
    uint perUnlockPercentage = 20;
    uint public currentSupply;

    AggregatorV3Interface internal priceFeed;

    constructor(string memory _name, string memory _symbol, address _ethusdPriceFeedAddress, uint _maxSupply) ERC20(_name, _symbol) {
        _mint(msg.sender, 100 * (1e18));
        owner = msg.sender;
        maxSupply = _maxSupply * (1e18);
        priceFeed = AggregatorV3Interface(_ethusdPriceFeedAddress);
        currentDate = block.timestamp;
    }

    struct VestingSchedule {
        address holder;
        uint prevUnlockDate;
        uint nextUnlockDate; // this will update every unlock
        bool vestingInitiated; // is vesting currently ongoing
        uint tokensBought;
        uint tokenBalance;
    }

    mapping(address => VestingSchedule) public addressVestingSchedule;

    modifier ableToUnlock() {
        require(block.timestamp > addressVestingSchedule[msg.sender].nextUnlockDate, "You cannot withdraw before the next unlock");
        addressVestingSchedule[msg.sender].prevUnlockDate = addressVestingSchedule[msg.sender].nextUnlockDate;
        addressVestingSchedule[msg.sender].nextUnlockDate += unlockInterval;
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier isSaleOn() {
        require(saleOngoing == true, "Sale isn't running");
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

    function buyToken(uint _amount) public payable isSaleOn  {
        if (currentSupply == (maxSupply - 1) ){

        }
        require (currentSupply < maxSupply, "Maximum supply reached");
        require(getConversionRate(msg.value) >= _amount, "Not Enough ETH sent");
        addressVestingSchedule[msg.sender] = VestingSchedule(msg.sender, 0, currentDate + unlockInterval, true, _amount, _amount );
        currentSupply += _amount;
    }

    function userWithdrawal() public ableToUnlock payable {
        uint tokenBought = addressVestingSchedule[msg.sender].tokensBought;
        uint ableToClaim = tokenBought / 100 * perUnlockPercentage;
        require(addressVestingSchedule[msg.sender].tokenBalance >= ableToClaim, "You have already unlocked tokens");
        addressVestingSchedule[msg.sender].tokenBalance -= ableToClaim;
        _mint(msg.sender, ableToClaim);
    }


}