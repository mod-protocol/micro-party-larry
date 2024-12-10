// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "party-protocol/globals/IGlobals.sol";

contract GlobalsMock is IGlobals {
    function multiSig() external pure returns (address) {
        return address(0);
    }

    function getBytes32(uint256 key) external pure returns (bytes32) {
        return bytes32(0);
    }

    function getUint256(uint256 key) external pure returns (uint256) {
        return 0;
    }

    function getBool(uint256 key) external pure returns (bool) {
        return false;
    }

    function getAddress(uint256 key) external pure returns (address) {
        return address(0);
    }

    function getImplementation(
        uint256 key
    ) external pure returns (Implementation) {
        return Implementation(address(0));
    }

    function getIncludesBytes32(
        uint256 key,
        bytes32 value
    ) external pure returns (bool) {
        return false;
    }

    function getIncludesUint256(
        uint256 key,
        uint256 value
    ) external pure returns (bool) {
        return false;
    }

    function getIncludesAddress(
        uint256 key,
        address value
    ) external pure returns (bool) {
        return false;
    }

    function setBytes32(uint256 key, bytes32 value) external pure {}

    function setUint256(uint256 key, uint256 value) external pure {}

    function setBool(uint256 key, bool value) external pure {}

    function setAddress(uint256 key, address value) external pure {}

    function setIncludesBytes32(
        uint256 key,
        bytes32 value,
        bool isIncluded
    ) external pure {}

    function setIncludesUint256(
        uint256 key,
        uint256 value,
        bool isIncluded
    ) external pure {}

    function setIncludesAddress(
        uint256 key,
        address value,
        bool isIncluded
    ) external pure {}
}
