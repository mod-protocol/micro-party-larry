// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Party.sol";
import "party-protocol/globals/IGlobals.sol";
import {Strings} from "party-protocol/contracts/utils/vendor/Strings.sol";

contract PartyTest is Test {
    using Strings for uint256;
    using Strings for address;

    PartyImpl party;
    address mockGlobals;

    function setUp() public {
        // Setup mock globals
        mockGlobals = address(new MockGlobals());
        party = new PartyImpl(IGlobals(mockGlobals));
    }

    function testTokenURI() public {
        uint256 tokenId = 123;
        string memory expectedURI = string.concat(
            "https://roundtrip.wtf/api/metadata",
            "/",
            address(party).toHexString(),
            "/",
            "123"
        );

        assertEq(party.tokenURI(tokenId), expectedURI);
    }

    function testTokenURIDifferentIds() public {
        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;

        string memory uri1 = party.tokenURI(tokenId1);
        string memory uri2 = party.tokenURI(tokenId2);

        assertTrue(keccak256(bytes(uri1)) != keccak256(bytes(uri2)));
    }
}

// Mock contract for testing
contract MockGlobals is IGlobals {
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
