// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "../lib/forge-std/src/Test.sol";

import {EtherSub} from "../src/EtherSub.sol";

contract EtherSubTest is Test {
   
    EtherSub public etherSub;
    address public constant PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // Set up the test environment
    function setUp() public {
        // Deploy the contract
        etherSub = new EtherSub();
        
        // Mock the price feed to return a realistic ETH/USD price
        // Let's say 1 ETH = $2000 USD
     
        vm.mockCall(
            PRICE_FEED,
            abi.encodeWithSignature("latestRoundData()"),
            abi.encode(
                uint80(1), // roundId
                int256(200000000000), // price: $2000 with 8 decimals
                uint256(block.timestamp), // startedAt
                uint256(block.timestamp), // updatedAt
                uint80(1) // answeredInRound
            )
        );
    }

    function testConstructor() public {
        assertEq(etherSub.owner(), address(this));
        assertEq(address(etherSub.s_priceFeed()), PRICE_FEED);
    }

    function testCreatePlan() public {
        string memory PlanName = "Basic Plan";
        uint256 price = 100; // 100 USD
        
        etherSub.createPlan(PlanName, price);
        
        (string memory name, uint256 amountPerMonth) = etherSub.plans(PlanName);
        
        assertEq(name, PlanName);
        assertEq(amountPerMonth, 100 * 1e18);
    }

    function testGetLatestPrice() public {
        uint256 price = etherSub.getLatestPrice();
        assertEq(price, 200000000000); // $2000 with 8 decimals
    }

    function testGetEthAmountFromUsd() public {
        // Test: How much ETH for $100?
        // With ETH at $2000, $100 should be 0.05 ETH
        uint256 ethAmount = etherSub.getEthAmountFromUsd(100 * 1e18);
        uint256 expectedEth = 0.05 * 1e18; // 0.05 ETH in wei
        assertEq(ethAmount, expectedEth);
    }

    function testSubscribe() public {
        string memory planName = "Basic Plan";
        
        // Create the plan
        etherSub.createPlan(planName, 100); // $100 plan
        
        // Calculate required ETH (should be 0.05 ETH for $100 at $2000/ETH)
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        // Create user and fund them
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        // Subscribe as user
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName);

        // Verify subscription
        (address subscriber, string memory plan, uint256 amountPaid, uint256 startTime, uint256 duration) = 
            etherSub.subscriptions(user, planName);

        assertEq(subscriber, user);
        assertEq(plan, planName);
        assertEq(amountPaid, requiredEth);
        assertGt(startTime, 0);
        assertEq(duration, 30 days);
    }

    function testCheckSubscription() public {
        string memory planName = "Basic Plan";
        
        // Create plan and subscribe
        etherSub.createPlan(planName, 100);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName);

        // Check subscription
        vm.prank(user);
        (EtherSub.Subscription memory subscription, uint256 timeLeft) = etherSub.checkSubscription(planName);
        
        assertEq(subscription.subscriber, user);
        assertEq(subscription.planName, planName);
        assertEq(subscription.amountPaid, requiredEth);
        assertGt(timeLeft, 0);
        assertLe(timeLeft, 30 days);
    }

    function testCancelSubscription() public {
        string memory planName = "Basic Plan";
        
        // Create plan
        etherSub.createPlan(planName, 100);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        // Create user and subscribe
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName);

        // Verify subscription exists
        (,string memory subName, uint256 amountPaid,,) = etherSub.subscriptions(user, planName);
        assertEq(subName, planName);
        assertGt(amountPaid, 0);
        
        // Record balance before cancellation
        uint256 balanceBefore = user.balance;
        
        // Cancel subscription
        vm.prank(user);
        etherSub.cancelSubscription(planName);
        
        // Verify subscription is deleted - checkSubscription should revert
        vm.prank(user);
        vm.expectRevert("No active subscription for this plan");
        etherSub.checkSubscription(planName);
        
        // Verify subscription data is cleared
        (,string memory clearedName, uint256 clearedAmount,,) = etherSub.subscriptions(user, planName);
        assertEq(clearedName, "");
        assertEq(clearedAmount, 0);
        
        // Check refund (should be full amount since immediate cancellation)
        uint256 balanceAfter = user.balance;
        assertGt(balanceAfter, balanceBefore, "User should receive refund");
        // The refund should equal the required ETH amount
        assertEq(balanceAfter - balanceBefore, requiredEth, "Refund should equal subscription amount");
        // Ensure the user received the full refund
        assertEq(balanceAfter, balanceBefore + requiredEth, "User should receive full refund");
        // Check that the contract's balance is reduced by the refund amount
        uint256 contractBalance = address(etherSub).balance;
        assertEq(contractBalance, 0, "Contract should have no balance after refund");

    }

    function testCancelPartialRefund() public {
        string memory planName = "Basic Plan";
        
        // Create plan and subscribe
        etherSub.createPlan(planName, 100);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName);
        
        // Fast forward 15 days (half the subscription period)
        vm.warp(block.timestamp + 15 days);
        
        uint256 balanceBefore = user.balance;
        
        // Cancel subscription
        vm.prank(user);
        etherSub.cancelSubscription(planName);
        
        // Should get approximately 50% refund
        uint256 balanceAfter = user.balance;
        uint256 refund = balanceAfter - balanceBefore;
        
        // Refund should be approximately half (allowing for small rounding differences)
        assertGt(refund, requiredEth * 45 / 100); // At least 45%
        assertLt(refund, requiredEth * 55 / 100); // At most 55%
    }

    receive() external payable {}
}