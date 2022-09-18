// SPDX-License-Identifier: Null

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
        uint nextUnlockDate; // this will update every unlock
        bool vestingInitiated; // is vesting currently ongoing
    }

    mapping(address => VestingSchedule) public addressVestingSchedule;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier isSaleOn() {
        require(saleOngoing == true, "Sale isn't running");
        _;
    }

    modifier isUnlockTime() {
        
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
        require(getConversionRate(msg.value) >= _amount, "Not Enough ETH sent");
        addressVestingSchedule[msg.sender] = VestingSchedule(msg.sender,currentDate + unlockInterval, true );
        currentSupply += _amount;
    }

    function userWithdrawal(uint _amount) public payable {
        
    }


}