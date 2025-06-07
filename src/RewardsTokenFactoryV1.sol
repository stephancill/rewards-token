// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";

import {RewardsTokenV1} from "./RewardsTokenV1.sol";
import {GlobalConfig} from "./GlobalConfig.sol";
import {IRewardsTokenFactoryV1} from "./interfaces/IRewardsTokenFactoryV1.sol";

contract RewardsTokenFactoryV1 is IRewardsTokenFactoryV1, Ownable {
    event RewardsTokenCreated(address indexed token, address indexed owner);

    GlobalConfig public globalConfig;

    constructor(address _globalConfig) Ownable(msg.sender) {
        globalConfig = GlobalConfig(_globalConfig);
    }

    function createRewardsToken(
        string memory name,
        string memory symbol,
        address owner,
        address rewardToken,
        uint256 rewardsPerDistributionPeriod
    ) public returns (RewardsTokenV1) {
        RewardsTokenV1 token = new RewardsTokenV1(
            name,
            symbol,
            owner,
            rewardToken,
            rewardsPerDistributionPeriod,
            this
        );
        emit RewardsTokenCreated(address(token), owner);
        return token;
    }

    function setGlobalConfig(address _globalConfig) public onlyOwner {
        globalConfig = GlobalConfig(_globalConfig);
    }
}
