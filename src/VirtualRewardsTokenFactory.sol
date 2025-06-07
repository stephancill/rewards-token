// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";

import {VirtualRewardsToken} from "./VirtualRewardsToken.sol";
import {IGlobalConfig} from "./interfaces/IGlobalConfig.sol";
import {IVirtualRewardsTokenFactory} from "./interfaces/IVirtualRewardsTokenFactory.sol";

contract VirtualRewardsTokenFactory is IVirtualRewardsTokenFactory, Ownable {
    string public constant VERSION = "1.0.0";

    event VirtualRewardsTokenCreated(address indexed token, address indexed owner);

    IGlobalConfig public globalConfig;

    constructor(address _globalConfig) Ownable(msg.sender) {
        globalConfig = IGlobalConfig(_globalConfig);
    }

    function createRewardsToken(
        string memory name,
        string memory symbol,
        address owner,
        address rewardToken,
        uint256 rewardsPerDistributionPeriod
    ) public returns (VirtualRewardsToken) {
        VirtualRewardsToken token =
            new VirtualRewardsToken(name, symbol, owner, rewardToken, rewardsPerDistributionPeriod, this);
        emit VirtualRewardsTokenCreated(address(token), owner);
        return token;
    }

    function setGlobalConfig(address _globalConfig) public onlyOwner {
        globalConfig = IGlobalConfig(_globalConfig);
    }
}
