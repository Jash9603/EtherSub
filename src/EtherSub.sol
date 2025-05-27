// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract EtherSub {
    // ===== State Variables =====
    address public immutable owner;

    AggregatorV3Interface public s_priceFeed;
    // Sepolia ETH/USD price feed address (static)
    address constant SEPOLIA_ETH_USD_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    bool private locked;

    // ===== Events =====
    event Subscribed(address indexed user, string planName, uint256 amount);
    event Cancelled(address indexed user, string planName, uint256 refund);
    event PlanCreated(string planName, uint256 price);
    event Withdrawn(address indexed owner, uint256 amount);

    // ===== Modifiers =====
    modifier onlyOwner() {
        require(owner == msg.sender, "Only contract owner can call this");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    // ===== Structs =====
    struct Subscription {
        address subscriber;
        string planName;
        uint256 amountPaid;
        uint256 startTime;
        uint256 duration;
    }

    struct Plan {
        string name;
        uint256 amountPerMonth; // stored in USD with 18 decimals
    }

    // ===== Mappings & Arrays =====
    mapping(string => Plan) public plans;
    string[] public planNames;
    mapping(address => mapping(string => Subscription)) public subscriptions;

    // ===== Constructor =====
    constructor() {
        owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(SEPOLIA_ETH_USD_FEED);
    }

    // ===== Price Feed & Conversion Functions =====
    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = s_priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price); // price with 8 decimals
    }

    function getEthAmountFromUsd(uint256 usdAmount) public view returns (uint256) {
        uint256 ethPrice = getLatestPrice(); // 8 decimals
        // Convert USD amount (18 decimals) to ETH (wei) with proper decimals adjustment
        return (usdAmount * 1e18) / (ethPrice * 1e10);
    }

    // ===== Plan Management =====
    function createPlan(string memory name, uint256 amountInUsd) public onlyOwner {
        require(plans[name].amountPerMonth == 0, "Plan already exists");
        uint256 amountPerMonth = amountInUsd * 1e18;
        plans[name] = Plan(name, amountPerMonth);
        planNames.push(name);

        emit PlanCreated(name, amountPerMonth);
    }

    // ===== Subscription Functions =====
    function subscribe(string memory planName) public payable {
        Plan storage plan = plans[planName];
        require(plan.amountPerMonth > 0, "Plan does not exist");

        uint256 requiredEth = getEthAmountFromUsd(plan.amountPerMonth);
        require(msg.value == requiredEth, "Incorrect ETH amount sent");

        Subscription storage subscription = subscriptions[msg.sender][planName];
        require(subscription.startTime == 0, "Already subscribed to this plan");

        subscription.subscriber = msg.sender;
        subscription.planName = planName;
        subscription.amountPaid = msg.value;
        subscription.startTime = block.timestamp;
        subscription.duration = 30 days;

        emit Subscribed(msg.sender, planName, msg.value);
    }

    function checkSubscription(string memory planName) public view returns (Subscription memory, uint256 timeLeft) {
        Subscription storage subscription = subscriptions[msg.sender][planName];
        require(subscription.startTime != 0, "No active subscription for this plan");

        uint256 timeElapsed = block.timestamp - subscription.startTime;
        timeLeft = subscription.duration > timeElapsed ? subscription.duration - timeElapsed : 0;

        return (subscription, timeLeft);
    }

    function cancelSubscription(string memory planName) public noReentrancy {
        Subscription storage subscription = subscriptions[msg.sender][planName];
        require(subscription.startTime != 0, "No active subscription");

        uint256 timeElapsed = block.timestamp - subscription.startTime;
        uint256 timeLeft = subscription.duration > timeElapsed ? subscription.duration - timeElapsed : 0;
        uint256 refundAmount = (subscription.amountPaid * timeLeft) / subscription.duration;

        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }

        delete subscriptions[msg.sender][planName];

        emit Cancelled(msg.sender, planName, refundAmount);
    }

    // ===== Utility Functions =====
    function viewPlans() public view returns (Plan[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < planNames.length; i++) {
            if (plans[planNames[i]].amountPerMonth > 0) {
                count++;
            }
        }

        Plan[] memory allPlans = new Plan[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < planNames.length; i++) {
            if (plans[planNames[i]].amountPerMonth > 0) {
                allPlans[index] = plans[planNames[i]];
                index++;
            }
        }

        return allPlans;
    }

    // ===== Owner-only Withdraw =====
    function withdraw() public onlyOwner noReentrancy {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);

        emit Withdrawn(msg.sender, balance);
    }
}
