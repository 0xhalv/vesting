// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ProxyAdmin} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Vesting} from "../src/Vesting.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract VestingHarness is Vesting {
    function percentInEpoch_HARNESS(uint256 _epoch) public view returns (uint256) {
        return super.percentInEpoch(_epoch);
    }
}

contract VestingTest is Test {
    Vesting vesting;
    MockERC20 token;
    address owner = address(0x1337);

    function setUp() external {
         // change decimals to test with different values
        uint8 decimals = 18;
        token = new MockERC20("Test token", "TST", decimals);

        token.mint(owner, 700_000e18);

        bytes memory initializerData = abi.encodeWithSelector(
            Vesting.initialize.selector,
            address(token),
            owner,
            with_decimals(700_000, decimals),
            with_decimals(10_000, decimals),
            uint96(block.timestamp)
        );

        vm.startPrank(owner);
        address proxy = Upgrades.deployTransparentProxy("Vesting.sol:Vesting", owner, initializerData);
        vesting = Vesting(proxy);
        token.transfer(proxy, 700_000e18);
        vm.stopPrank();
    }

    function testDeploy() external {
        assertEq(vesting.owner(), owner);
    }

    function testCannotInitializeTwice() external {
        vm.expectRevert();
        vesting.initialize(
            address(token),
            owner,
            with_decimals(700_000, 18),
            with_decimals(10_000, 18),
            uint96(block.timestamp)
        );
    }

    function testTimestampToEpoch() external {
        uint256 first_month = block.timestamp + 1;
        uint256 second_month = first_month + 30 days;
        uint256 third_month = second_month + 30 days;
        assertEq(vesting.timestampToEpoch(first_month), 1);
        assertEq(vesting.timestampToEpoch(second_month), 2);
        assertEq(vesting.timestampToEpoch(third_month), 3);

        vm.expectRevert();
        vesting.timestampToEpoch(first_month - 1 days);
    }

    function testPercentageInEpoch() external {
        VestingHarness harness = new VestingHarness();
        // year 1
        assertEq(harness.percentInEpoch_HARNESS(1), 0.1 ether);
        assertEq(harness.percentInEpoch_HARNESS(12), 0.1 ether);
        
        // year 2
        assertEq(harness.percentInEpoch_HARNESS(13), 0.25 ether);
        assertEq(harness.percentInEpoch_HARNESS(24), 0.25 ether);

        // year 3
        assertEq(harness.percentInEpoch_HARNESS(25), 0.5 ether);
        assertEq(harness.percentInEpoch_HARNESS(36), 0.5 ether);

        // year 4
        assertEq(harness.percentInEpoch_HARNESS(37), 1 ether);
        assertEq(harness.percentInEpoch_HARNESS(48), 1 ether);

        // year 5-8
        assertEq(harness.percentInEpoch_HARNESS(49), 0.5 ether);
        assertEq(harness.percentInEpoch_HARNESS(96), 0.5 ether);

        // year 9-12
        assertEq(harness.percentInEpoch_HARNESS(97), 0.25 ether);
        assertEq(harness.percentInEpoch_HARNESS(144), 0.25 ether);

        // year 13-16
        assertEq(harness.percentInEpoch_HARNESS(12 * 12 + 1), 0.125 ether);
        assertEq(harness.percentInEpoch_HARNESS(16 * 12), 0.125 ether);

        // year 17-20
        assertEq(harness.percentInEpoch_HARNESS(16 * 12 + 1), 0.0625 ether);
        assertEq(harness.percentInEpoch_HARNESS(20 * 12), 0.0625 ether);

        // year 21-24
        assertEq(harness.percentInEpoch_HARNESS(20 * 12 + 1), 0.03125 ether);
        assertEq(harness.percentInEpoch_HARNESS(24 * 12), 0.03125 ether);

        // year 25-28
        assertEq(harness.percentInEpoch_HARNESS(24 * 12 + 1), 0.015625 ether);
        assertEq(harness.percentInEpoch_HARNESS(28 * 12), 0.015625 ether);

        // year 29-32
        assertEq(harness.percentInEpoch_HARNESS(28 * 12 + 1), 0.0078125 ether);
        assertEq(harness.percentInEpoch_HARNESS(32 * 12), 0.0078125 ether);
    }

    function testClaimableInEpoch() external {
        uint256 decimals = token.decimals();
        // year 1
        assertEq(vesting.claimableInEpoch(1), with_decimals(1000));
        assertEq(vesting.claimableInEpoch(12), with_decimals(1000));
        // year 2
        assertEq(vesting.claimableInEpoch(13), with_decimals(2500));
        assertEq(vesting.claimableInEpoch(24), with_decimals(2500));
        // year 3
        assertEq(vesting.claimableInEpoch(25), with_decimals(5000));
        assertEq(vesting.claimableInEpoch(36), with_decimals(5000));
        // year 4
        assertEq(vesting.claimableInEpoch(37), with_decimals(10000));
        assertEq(vesting.claimableInEpoch(48), with_decimals(10000));
        // year 9-12
        assertEq(vesting.claimableInEpoch(97), with_decimals(2500));
        assertEq(vesting.claimableInEpoch(144), with_decimals(2500));
        // year 21-24
        assertEq(vesting.claimableInEpoch(20 * 12 + 1), with_decimals(3125, decimals - 1));
        assertEq(vesting.claimableInEpoch(24 * 12), with_decimals(3125, decimals - 1));

        // should revert on year 29+
        vm.expectRevert("vesting finished");
        vesting.claimableInEpoch(28 * 12 + 1);
    }

    function testOnlyOwnerCanClaim() external {
        address user1 = address(0x1338);
        vm.expectRevert();
        vesting.claim(1);
    }

    function testClaim() external {
        uint256 startTime = block.timestamp;
        // year 1, month 1
        uint256 epoch = vesting.timestampToEpoch(startTime);
        uint256 claimable = vesting.claimableInEpoch(epoch);
        assertEq(claimable, with_decimals(1000));

        vm.startPrank(owner);
        vesting.claim(with_decimals(100));
        vesting.claim(with_decimals(500));
        vesting.claim(with_decimals(300));
        vesting.claim(with_decimals(100));
        assertEq(token.balanceOf(owner), with_decimals(1000));

        vm.expectRevert("claiming too much");
        vesting.claim(1);

        // year 1, month 2
        vm.warp(startTime + 31 days);
        vesting.claim(with_decimals(1000));
        vm.expectRevert("claiming too much");
        vesting.claim(1);

        // year 4, month 1
        vm.warp(startTime + 1080 days);
        vesting.claim(with_decimals(10000));
        vm.expectRevert("claiming too much");
        vesting.claim(1);

        // year 10, month 1
        vm.warp(startTime + 3600 days);
        vesting.claim(with_decimals(2500));
        vm.expectRevert("claiming too much");
        vesting.claim(1);
    }

    function testClaimForEpoch() external {
        vm.startPrank(owner);

        uint256 startTime = block.timestamp;

        vm.warp(startTime + 360 days);
        vesting.claimForEpoch(1, with_decimals(1000));
        vm.expectRevert("claiming too much");
        vesting.claimForEpoch(1, 1);

        vesting.claimForEpoch(2, with_decimals(1000));
        vm.expectRevert("claiming too much");
        vesting.claimForEpoch(2, 1);

        vesting.claimForEpoch(3, with_decimals(1000));
        vm.expectRevert("claiming too much");
        vesting.claimForEpoch(2, 1);
    }

    function testCannotClaimFutureEpochs() external {
        vm.startPrank(owner);

        uint256 futureEpoch = vesting.timestampToEpoch(block.timestamp + 30 days);
        vm.expectRevert("epoch in future");
        vesting.claimForEpoch(futureEpoch, 1);
    }

    function testCannotClaimAfterVestingFinishes() external {
        vm.startPrank(owner);

        vm.warp(block.timestamp + 10800 days); // 30 years
        vm.expectRevert("vesting finished");
        vesting.claim(1);
    }

    function testWithdrawAll() external {
        vm.startPrank(owner);

        vm.expectRevert("vesting didnt finish");
        vesting.withdrawAll();
        
        vm.warp(block.timestamp + 10800 days); // 30 years
        vesting.withdrawAll();
        assertEq(token.balanceOf(owner), with_decimals(700_000));
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function with_decimals(uint256 amount) internal view returns (uint256) {
        uint256 decimals = token.decimals();
        return amount * (10 ** decimals);
    }

    function with_decimals(uint256 amount, uint256 decimals) internal view returns (uint256) {
        return amount * (10 ** decimals);
    }
}