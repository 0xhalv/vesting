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
        token = new MockERC20("Test token", "TST", 18);

        token.mint(owner, 700_000e18); // mint 700,000 tokens

        bytes memory initializerData = abi.encodeWithSelector(
            Vesting.initialize.selector,
            address(token),
            owner,
            700_000e18,
            10_000e18,
            block.timestamp + 1
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
}