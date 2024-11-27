// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20LaunchCrowdfund} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {IERC20Creator} from "party-protocol/utils/IERC20Creator.sol";

contract ERC20LaunchCrowdfundImpl is ERC20LaunchCrowdfund {
    constructor(
        IGlobals globals,
        IERC20Creator erc20Creator
    ) ERC20LaunchCrowdfund(globals, erc20Creator) {}
}
