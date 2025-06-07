// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GlobalConfig} from "../src/GlobalConfig.sol";
import {VirtualRewardsTokenFactory} from "../src/VirtualRewardsTokenFactory.sol";

contract DeployScript is Script {
    address public authority = 0xF04F510019604b10469dedAf1A944e3f00846D3c; // Safe Wallet
    uint256 public authorityFeeBps = 100; // 1%
    address public rewardToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC
    address public globalConfigAddress = 0x97F570C867d715b90b146C5165e9907221e33c44;
    address public virtualRewardsTokenFactoryAddress = 0x34aF63F98808C3D9323786662Beb3b814FD0a331;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        GlobalConfig globalConfig;
        VirtualRewardsTokenFactory virtualRewardsTokenFactory;

        if (globalConfigAddress == address(0)) {
            // Create a new GlobalConfig
            globalConfig = new GlobalConfig(authorityFeeBps, authority);
        } else {
            globalConfig = GlobalConfig(globalConfigAddress);
        }

        if (virtualRewardsTokenFactoryAddress == address(0)) {
            // Create a new VirtualRewardsTokenFactory
            virtualRewardsTokenFactory = new VirtualRewardsTokenFactory(address(globalConfig));
        } else {
            virtualRewardsTokenFactory = VirtualRewardsTokenFactory(virtualRewardsTokenFactoryAddress);
        }

        // Create a new VirtualRewardsToken
        virtualRewardsTokenFactory.createRewardsToken(
            "Test Token",
            "TEST",
            authority,
            rewardToken,
            5 * 1e6 // 5 USDC
        );

        vm.stopBroadcast();
    }
}
