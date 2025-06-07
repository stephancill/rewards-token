// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GlobalConfig} from "../GlobalConfig.sol";

interface IGlobalConfig {
    function authorityFeeBps() external view returns (uint256);
    function authority() external view returns (address);
}
