// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Party.sol";
import {GlobalsMock} from "./mock/GlobalsMock.sol";
import "party-protocol/globals/IGlobals.sol";
import {Strings} from "party-protocol/contracts/utils/vendor/Strings.sol";

contract PartyTest is Test {
    using Strings for uint256;
    using Strings for address;

    PartyImpl party;
    address mockGlobals;

    function setUp() public {
        // Setup mock globals
        mockGlobals = address(new GlobalsMock());
        party = new PartyImpl(IGlobals(mockGlobals));
    }

    function testTokenURI() public {
        uint256 tokenId = 123;
        string memory expectedURI = string.concat(
            "https://larry.club/api/metadata",
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
