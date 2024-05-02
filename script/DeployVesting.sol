// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {Vesting} from "../src/Vesting.sol";

contract DeployVesting is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 token = new MockERC20("Test token", "TST", 18);
        bytes memory initializerData = abi.encodeWithSelector(
            Vesting.initialize.selector,
            address(token),
            deployer,
            10_000e18,
            uint96(block.timestamp + 120)
        );
        address proxy = Upgrades.deployTransparentProxy(
            "Vesting.sol:Vesting",
            deployer,
            initializerData
        );
        token.mint(proxy, 700_000e18);
        vm.stopBroadcast();
    }
}