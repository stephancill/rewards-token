// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin-contracts-5.3.0/access/Ownable.sol";

contract GlobalConfig is Ownable {
    uint256 public authorityFeeBps;
    address public authority;

    event AuthorityFeeBpsUpdated(uint256 newAuthorityFeeBps);
    event AuthorityUpdated(address newAuthority);

    constructor(
        uint256 _authorityFeeBps,
        address _authority
    ) Ownable(msg.sender) {
        authorityFeeBps = _authorityFeeBps;
        authority = _authority;
    }

    function setAuthorityFeeBps(uint256 _authorityFeeBps) public onlyOwner {
        authorityFeeBps = _authorityFeeBps;
        emit AuthorityFeeBpsUpdated(_authorityFeeBps);
    }

    function setAuthority(address _authority) public onlyOwner {
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }
}
