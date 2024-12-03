// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Party} from "party-protocol/contracts/party/Party.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {Strings} from "party-protocol/contracts/utils/vendor/Strings.sol";

contract PartyImpl is Party {
    using Strings for uint256;
    using Strings for string;
    using Strings for address;

    constructor(IGlobals globals) Party(globals) {}

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return
            string.concat(
                "https://roundtrip.wtf/api/metadata",
                "/",
                address(this).toHexString(),
                "/",
                tokenId.toString()
            );
    }
}
