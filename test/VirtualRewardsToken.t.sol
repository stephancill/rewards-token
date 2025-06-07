// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin-contracts-5.3.0/token/ERC20/ERC20.sol";
import {VirtualRewardsToken} from "../src/VirtualRewardsToken.sol";
import {IVirtualRewardsTokenFactory} from "../src/interfaces/IVirtualRewardsTokenFactory.sol";
import {IGlobalConfig} from "../src/interfaces/IGlobalConfig.sol";

contract VirtualRewardsTokenTest is Test {
    VirtualRewardsToken public rewardsToken;
    address mockRewardToken = address(0x1);
    address mockRewardsTokenFactory = address(0x2);
    address mockGlobalConfig = address(0x3);
    address mockOwner = address(0x4);
    address mockAppCaller = address(0x5);

    function setUp() public {
        rewardsToken = new VirtualRewardsToken(
            "Test Token",
            "TEST",
            mockOwner,
            mockRewardToken,
            1000 * 1e18,
            IVirtualRewardsTokenFactory(mockRewardsTokenFactory)
        );

        // Mock the factory
        vm.mockCall(
            mockRewardsTokenFactory,
            abi.encodeWithSelector(IVirtualRewardsTokenFactory.globalConfig.selector),
            abi.encode(mockGlobalConfig)
        );

        // Mock the global config
        vm.mockCall(mockGlobalConfig, abi.encodeWithSelector(IGlobalConfig.authorityFeeBps.selector), abi.encode(100));
        vm.mockCall(
            mockGlobalConfig, abi.encodeWithSelector(IGlobalConfig.authority.selector), abi.encode(address(this))
        );
        vm.mockCall(mockRewardToken, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
    }

    function test_constructor() public {
        assertEq(rewardsToken.name(), "Test Token");
        assertEq(rewardsToken.symbol(), "TEST");
        assertEq(rewardsToken.owner(), mockOwner);
        assertEq(address(rewardsToken.rewardToken()), mockRewardToken);
        assertEq(rewardsToken.rewardsPerDistributionPeriod(), 1000 * 1e18);
    }

    function test_transferFromNoAllowance() public {
        vm.prank(mockAppCaller);
        vm.expectRevert();
        rewardsToken.transferFrom(address(mockOwner), address(0x123), 1000 * 1e18);
    }

    function test_transferFromOwnerWithAllowance() public {
        vm.prank(mockOwner);
        rewardsToken.approve(mockAppCaller, 1000 * 1e18);

        uint256 totalSupplyBefore = rewardsToken.totalSupply();

        vm.prank(mockAppCaller);
        rewardsToken.transferFrom(mockOwner, address(0x123), 1000 * 1e18);

        assertEq(rewardsToken.balanceOf(address(0x123)), 1000 * 1e18);
        assertEq(rewardsToken.totalSupply(), totalSupplyBefore + 1000 * 1e18);
    }

    function test_transferFromNotOwner() public {
        vm.prank(address(0x123));
        vm.expectRevert();
        rewardsToken.transferFrom(address(0x123), address(0x456), 1000 * 1e18);
    }

    function test_distributeRewardsNotDistributable() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);
        rewardsToken.transfer(address(0x456), 2000 * 1e18);
        rewardsToken.transfer(address(0x789), 10000 * 1e18);
        vm.stopPrank();

        vm.expectRevert();
        rewardsToken.distributeReward(address(0x123));
    }

    function test_distributeRewards() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);
        rewardsToken.transfer(address(0x456), 4000 * 1e18);
        rewardsToken.transfer(address(0x789), 10000 * 1e18);
        vm.stopPrank();

        helper_startDistribution();

        vm.mockCall(mockRewardToken, abi.encodeWithSelector(IERC20.transferFrom.selector, mockOwner), abi.encode(true));
        uint256 reward = rewardsToken.calculateReward(address(0x123));
        vm.expectCall(mockRewardToken, abi.encodeCall(IERC20.transferFrom, (mockOwner, address(0x123), reward)));
        rewardsToken.distributeReward(address(0x123));
        assertEq(rewardsToken.balanceOf(address(0x123)), 0);

        rewardsToken.distributeReward(address(0x456));
        assertEq(rewardsToken.balanceOf(address(0x456)), 0);

        rewardsToken.distributeReward(address(0x789));
        assertEq(rewardsToken.balanceOf(address(0x789)), 0);
    }

    function test_transferDuringDistribution() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);

        helper_startDistribution();

        vm.expectRevert();
        rewardsToken.transfer(address(0x456), 1000 * 1e18);
    }

    function test_calculateReward() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);
        rewardsToken.transfer(address(0x456), 4000 * 1e18);
        rewardsToken.transfer(address(0x789), 5000 * 1e18);
        vm.stopPrank();

        // 0x789 is expected to receive half of the rewards minus fees
        uint256 distributionAmount = rewardsToken.rewardsPerDistributionPeriod();
        uint256 fees = (distributionAmount * 100) / 10000;
        uint256 reward = distributionAmount - fees;
        assertEq(rewardsToken.calculateReward(address(0x789)), reward / 2);
    }

    function test_stopDistribution() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);
        rewardsToken.transfer(address(0x456), 4000 * 1e18);
        rewardsToken.transfer(address(0x789), 5000 * 1e18);
        vm.stopPrank();

        uint256 distributionId = rewardsToken.currentDistributionId();

        helper_startDistribution();

        rewardsToken.distributeReward(address(0x123));

        vm.prank(mockOwner);
        rewardsToken.stopDistribution();

        vm.expectRevert();
        rewardsToken.distributeReward(address(0x456));

        assertEq(rewardsToken.currentDistributionId(), distributionId + 1);
    }

    function test_noRewardsIfMissedDistribution() public {
        vm.startPrank(mockOwner);
        rewardsToken.transfer(address(0x123), 1000 * 1e18);
        vm.stopPrank();

        helper_startDistribution();

        vm.prank(mockOwner);
        rewardsToken.stopDistribution();

        helper_startDistribution();

        // Expect transferFrom to not be called
        vm.expectCall(mockRewardToken, abi.encodeWithSelector(IERC20.transferFrom.selector, mockOwner), 0);
        rewardsToken.distributeReward(address(0x123));

        // Existing tokens should also be burned
        assertEq(rewardsToken.balanceOf(address(0x123)), 0);
    }

    function test_feeCalculation() public {
        // With rewardsPerDistributionPeriod set to 1000 * 1e18 in setUp
        uint256 expectedFee = (1000 * 1e18 * 100) / 10000; // 1% of 1000 * 1e18
        assertEq(rewardsToken.calculateFees(), expectedFee);

        // Verify the fee is exactly 1% of the rewards pool
        assertEq(rewardsToken.calculateFees(), 10 * 1e18); // 1% of 1000 * 1e18 = 10 * 1e18
    }

    // -- Helper functions --

    function helper_startDistribution() public {
        vm.mockCall(
            mockRewardToken, abi.encodeWithSelector(IERC20.balanceOf.selector, mockOwner), abi.encode(100000 * 1e18)
        );
        vm.mockCall(mockRewardToken, abi.encodeWithSelector(IERC20.transferFrom.selector, mockOwner), abi.encode(true));
        rewardsToken.startDistribution();
    }
}
