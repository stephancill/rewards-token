// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GlobalConfig} from "../GlobalConfig.sol";

interface IRewardsTokenFactoryV1 {
    function globalConfig() external view returns (GlobalConfig);
}
