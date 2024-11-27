// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FeeCollectorImpl} from "../src/FeeCollector.sol";
import {ERC20CreatorV3Impl} from "../src/ERC20CreatorV3.sol";
import {ERC20LaunchCrowdfundImpl} from "../src/ERC20LaunchCrowdfund.sol";
import {IWETH} from "erc20-creator/FeeCollector.sol";
import {IERC20Creator} from "party-protocol/utils/IERC20Creator.sol";
import {ITokenDistributor} from "party-protocol/distribution/ITokenDistributor.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";

// Meant for deployment on base mainnet

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployerWallet = 0xd94b86E234BEAEf96A16E5C4ef2859aC0278A61f;
        IWETH weth = IWETH(0x4200000000000000000000000000000000000006);
        INonfungiblePositionManager uniswapV3PositionManager = INonfungiblePositionManager(
                0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
            );
        IGlobals globals = IGlobals(0xcEDe25DF327bD1619Fe25CDa2292e14edAC30717);

        FeeCollectorImpl feeCollector = new FeeCollectorImpl(
            uniswapV3PositionManager,
            payable(deployerWallet),
            5000,
            weth
        );

        /// @param tokenDistributor PartyDao token distributor contract
        /// @param uniswapV3PositionManager Uniswap V3 position manager contract
        /// @param uniswapV3Factory Uniswap V3 factory contract
        /// @param feeCollector Fee collector address which v3 lp positions are transferred to.
        /// @param weth WETH address
        /// @param feeRecipient_ Address that receives fee split of ETH at LP creation
        /// @param feeBasisPoints_ Fee basis points for ETH split on LP creation
        /// @param poolFee Uniswap V3 pool fee in hundredths of a bip
        // constructor(
        //     ITokenDistributor tokenDistributor,
        //     INonfungiblePositionManager uniswapV3PositionManager,
        //     IUniswapV3Factory uniswapV3Factory,
        //     address feeCollector,
        //     address weth,
        //     address feeRecipient_,
        //     uint16 feeBasisPoints_,
        //     uint16 poolFee
        // )

        ERC20CreatorV3Impl erc20CreatorV3 = new ERC20CreatorV3Impl(
            ITokenDistributor(0x6c7d98079023F05c2B57DFc933fa0903A2C95411),
            uniswapV3PositionManager,
            IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD),
            address(feeCollector),
            address(weth),
            deployerWallet,
            5000,
            10000
        );

        // constructor(IGlobals globals, IERC20Creator erc20Creator) InitialETHCrowdfund(globals) {
        //     ERC20_CREATOR = erc20Creator;
        // }

        ERC20LaunchCrowdfundImpl erc20LaunchCrowdFund = new ERC20LaunchCrowdfundImpl(
                globals,
                IERC20Creator(address(erc20CreatorV3))
            );

        vm.stopBroadcast();
    }
}
