// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGlobalConfig} from "./IGlobalConfig.sol";

interface IVirtualRewardsTokenFactory {
    function globalConfig() external view returns (IGlobalConfig);
}
