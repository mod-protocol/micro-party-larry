// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FeeCollector} from "erc20-creator/FeeCollector.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IWETH} from "erc20-creator/FeeCollector.sol";

contract FeeCollectorImpl is FeeCollector {
    constructor(
        INonfungiblePositionManager _positionManager,
        address payable _partyDao,
        uint16 _partyDaoFeeBps,
        IWETH _weth
    ) FeeCollector(_positionManager, _partyDao, _partyDaoFeeBps, _weth) {}
}
