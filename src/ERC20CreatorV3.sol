// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20CreatorV3} from "erc20-creator/ERC20CreatorV3.sol";
import {ITokenDistributor} from "party-protocol/distribution/ITokenDistributor.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract ERC20CreatorV3Impl is ERC20CreatorV3 {
    /// @param tokenDistributor PartyDao token distributor contract
    /// @param uniswapV3PositionManager Uniswap V3 position manager contract
    /// @param uniswapV3Factory Uniswap V3 factory contract
    /// @param feeCollector Fee collector address which v3 lp positions are transferred to.
    /// @param weth WETH address
    /// @param feeRecipient_ Address that receives fee split of ETH at LP creation
    /// @param feeBasisPoints_ Fee basis points for ETH split on LP creation
    /// @param poolFee Uniswap V3 pool fee in hundredths of a bip
    constructor(
        ITokenDistributor tokenDistributor,
        INonfungiblePositionManager uniswapV3PositionManager,
        IUniswapV3Factory uniswapV3Factory,
        address feeCollector,
        address weth,
        address feeRecipient_,
        uint16 feeBasisPoints_,
        uint16 poolFee
    )
        ERC20CreatorV3(
            tokenDistributor,
            uniswapV3PositionManager,
            uniswapV3Factory,
            feeCollector,
            weth,
            feeRecipient_,
            feeBasisPoints_,
            poolFee
        )
    {}
}
