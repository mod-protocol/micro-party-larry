// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TokenDistributor} from "party-protocol/distribution/TokenDistributor.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";

contract TokenDistributorImpl is TokenDistributor {
    constructor(
        IGlobals globals,
        uint40 emergencyDisabledTimestamp
    ) TokenDistributor(globals, emergencyDisabledTimestamp) {}
}
