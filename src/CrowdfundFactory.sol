// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {CrowdfundFactory} from "party-protocol/crowdfund/CrowdfundFactory.sol";

contract CrowdfundFactoryImpl is CrowdfundFactory {
    constructor() CrowdfundFactory() {}
}
