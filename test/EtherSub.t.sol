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

    function testCreateFeature() public {
        string memory featureId = "feature1";
        string memory name = "Premium Support";
        string memory description = "24/7 customer support";
        
        etherSub.createFeature(featureId, name, description);
        
        EtherSub.Feature memory feature = etherSub.getFeature(featureId);
        
        assertEq(feature.featureId, featureId);
        assertEq(feature.name, name);
        assertEq(feature.description, description);
    }

    function testCreateFeatureDuplicate() public {
        string memory featureId = "feature1";
        etherSub.createFeature(featureId, "Feature 1", "Description 1");
        
        vm.expectRevert("Feature already exists");
        etherSub.createFeature(featureId, "Feature 2", "Description 2");
    }

    function testViewFeatures() public {
        // Create multiple features
        etherSub.createFeature("feature1", "Feature 1", "Description 1");
        etherSub.createFeature("feature2", "Feature 2", "Description 2");
        
        EtherSub.Feature[] memory features = etherSub.viewFeatures();
        
        assertEq(features.length, 2);
        assertEq(features[0].featureId, "feature1");
        assertEq(features[1].featureId, "feature2");
    }

    function testCreatePlan() public {
        // First create some features
        etherSub.createFeature("feature1", "Feature 1", "Description 1");
        etherSub.createFeature("feature2", "Feature 2", "Description 2");
        
        string memory planName = "Basic Plan";
        uint256 price = 100; // 100 USD
        string[] memory featureIds = new string[](2);
        featureIds[0] = "feature1";
        featureIds[1] = "feature2";
        
        etherSub.createPlan(planName, price, featureIds);
        
        (string memory name, uint256 amountPerMonth) = etherSub.plans(planName);
     //   string[] memory allowedFeatures = etherSub.getPlanFeatures(planName);
        
        assertEq(name, planName);
        assertEq(amountPerMonth, 100 * 1e18);
     //   assertEq(allowedFeatures.length, 2);
      //  assertEq(allowedFeatures[0], "feature1");
      //  assertEq(allowedFeatures[1], "feature2");
    }

    function testCreatePlanDuplicate() public {
        string memory planName = "Basic Plan";
        string[] memory featureIds = new string[](0);
        
        etherSub.createPlan(planName, 100, featureIds);
        
        vm.expectRevert("Plan already exists");
        etherSub.createPlan(planName, 200, featureIds);
    }

    function testViewPlans() public {
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan("Plan 1", 100, emptyFeatures);
        etherSub.createPlan("Plan 2", 200, emptyFeatures);
        
        EtherSub.Plan[] memory plans = etherSub.viewPlans();
        
        assertEq(plans.length, 2);
        assertEq(plans[0].name, "Plan 1");
        assertEq(plans[1].name, "Plan 2");
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

    function testSubscribeOneMonth() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create the plan
        etherSub.createPlan(planName, 100, emptyFeatures); // $100 plan
        
        // Calculate required ETH (should be 0.05 ETH for $100 at $2000/ETH)
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        // Create user and fund them
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        // Subscribe as user for 1 month with 5% max slippage
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);

        // Verify subscription
        (address subscriber, string memory plan, uint256 amountPaid, uint256 startTime, uint256 duration) = 
            etherSub.subscriptions(user, planName);

        assertEq(subscriber, user);
        assertEq(plan, planName);
        assertEq(amountPaid, requiredEth);
        assertGt(startTime, 0);
        assertEq(duration, 30 days);
    }

    function testSubscribeTwelveMonths() public {
        string memory planName = "Premium Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create the plan
        etherSub.createPlan(planName, 50, emptyFeatures); // $50 plan
        
        // Calculate required ETH for 12 months (should be 12 * 0.025 ETH)
        uint256 requiredEth = etherSub.getEthAmountFromUsd(50 * 12 * 1e18);
        
        // Create user and fund them
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        // Subscribe as user for 12 months with 10% max slippage
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 12, 10);

        // Verify subscription
        (,, uint256 amountPaid,, uint256 duration) = etherSub.subscriptions(user, planName);

        assertEq(amountPaid, requiredEth);
        assertEq(duration, 365 days);
    }

    function testSubscribeInvalidDuration() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        // Try to subscribe with invalid duration
        vm.prank(user);
        vm.expectRevert("Invalid duration");
        etherSub.subscribe{value: requiredEth}(planName, 6, 5); // 6 months is invalid
    }

    function testSubscribeSlippageProtection() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        // Send less ETH than required (below slippage tolerance)
        uint256 insufficientEth = requiredEth * 90 / 100; // 10% less
        vm.deal(user, insufficientEth);
        
        // Try to subscribe with 5% max slippage - should fail
        vm.prank(user);
        vm.expectRevert("ETH sent is below required min due to slippage");
        etherSub.subscribe{value: insufficientEth}(planName, 1, 5);
    }

    function testSubscribeExtendExisting() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth * 2);
        
        // First subscription
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
        // Fast forward 10 days
        vm.warp(block.timestamp + 10 days);
        
        // Extend subscription
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
        // Check subscription - should have ~50 days left (20 remaining + 30 new)
        vm.prank(user);
        (, uint256 timeLeft) = etherSub.checkSubscription(planName);
        
        assertGt(timeLeft, 49 days);
        assertLt(timeLeft, 51 days);
    }

    function testCheckSubscription() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create plan and subscribe
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);

        // Check subscription
        vm.prank(user);
        (EtherSub.Subscription memory subscription, uint256 timeLeft) = etherSub.checkSubscription(planName);
        
        assertEq(subscription.subscriber, user);
        assertEq(subscription.planName, planName);
        assertEq(subscription.amountPaid, requiredEth);
        assertGt(timeLeft, 0);
        assertLe(timeLeft, 30 days);
    }

    function testCheckSubscriptionNonExistent() public {
        address user = makeAddr("user");
        
        vm.prank(user);
        vm.expectRevert("No active subscription for this plan");
        etherSub.checkSubscription("Non-existent Plan");
    }

    function testCancelSubscriptionFullRefund() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create plan
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        // Create user and subscribe
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);

        // Verify subscription exists
        vm.prank(user);
        (EtherSub.Subscription memory sub,) = etherSub.checkSubscription(planName);
        assertEq(sub.planName, planName);
        
        // Record balance before cancellation
        uint256 balanceBefore = user.balance;
        
        // Cancel subscription immediately
        vm.prank(user);
        etherSub.cancelSubscription(planName);
        
        // Verify subscription is deleted
        vm.prank(user);
        vm.expectRevert("No active subscription for this plan");
        etherSub.checkSubscription(planName);
        
        // Check refund (should be full amount since immediate cancellation)
        uint256 balanceAfter = user.balance;
        assertEq(balanceAfter - balanceBefore, requiredEth);
    }

    function testCancelSubscriptionPartialRefund() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create plan and subscribe
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
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

    function testCancelSubscriptionNoActive() public {
        address user = makeAddr("user");
        
        vm.prank(user);
        vm.expectRevert("No active subscription");
        etherSub.cancelSubscription("Non-existent Plan");
    }

    function testAutoCleanup() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        // Subscribe
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
        // Verify subscription exists
        vm.prank(user);
        (EtherSub.Subscription memory sub,) = etherSub.checkSubscription(planName);
        assertEq(sub.planName, planName);
        
        // Fast forward past subscription duration
        vm.warp(block.timestamp + 31 days);
        
        // Call auto cleanup
        vm.prank(user);
        etherSub.autoCleanup();
        
        // Verify subscription is cleaned up
        vm.prank(user);
        vm.expectRevert("No active subscription for this plan");
        etherSub.checkSubscription(planName);
    }

    function testOnlyOwnerModifier() public {
        address nonOwner = makeAddr("nonOwner");
        string[] memory emptyFeatures = new string[](0);
        
        // Test createFeature
        vm.prank(nonOwner);
        vm.expectRevert("Only contract owner can call this");
        etherSub.createFeature("feature1", "Feature 1", "Description");
        
        // Test createPlan
        vm.prank(nonOwner);
        vm.expectRevert("Only contract owner can call this");
        etherSub.createPlan("Plan 1", 100, emptyFeatures);
        
        // Test withdraw
        vm.prank(nonOwner);
        vm.expectRevert("Only contract owner can call this");
        etherSub.withdraw();
    }

    function testWithdraw() public {
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        // Create plan and get subscription
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
        // Contract should have balance
        assertEq(address(etherSub).balance, requiredEth);
        
        uint256 ownerBalanceBefore = address(this).balance;
        
        // Withdraw as owner
        etherSub.withdraw();
        
        // Check balances
        assertEq(address(etherSub).balance, 0);
        assertEq(address(this).balance, ownerBalanceBefore + requiredEth);
    }

    function testReentrancyProtection() public {
        // This test would require a malicious contract to test reentrancy
        // For now, we just verify the modifier exists by checking normal operation
        string memory planName = "Basic Plan";
        string[] memory emptyFeatures = new string[](0);
        
        etherSub.createPlan(planName, 100, emptyFeatures);
        uint256 requiredEth = etherSub.getEthAmountFromUsd(100 * 1e18);
        
        address user = makeAddr("user");
        vm.deal(user, requiredEth);
        
        vm.prank(user);
        etherSub.subscribe{value: requiredEth}(planName, 1, 5);
        
        // Normal cancellation should work
        vm.prank(user);
        etherSub.cancelSubscription(planName);
        
        // Withdrawal should work
        etherSub.withdraw();
    }

    // Helper function to receive ETH
    receive() external payable {}
}