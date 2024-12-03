// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {FeeCollectorImpl} from "../src/FeeCollector.sol";
import {ERC20CreatorV3Impl} from "../src/ERC20CreatorV3.sol";
import {ERC20LaunchCrowdfundImpl} from "../src/ERC20LaunchCrowdfund.sol";
import {CrowdfundFactoryImpl} from "../src/CrowdfundFactory.sol";
import {TokenDistributorImpl} from "../src/TokenDistributor.sol";
import {NeynarScoreGateKeeper} from "../src/NeynarScoreGateKeeper.sol";
import {IWETH} from "erc20-creator/FeeCollector.sol";
import {IERC20Creator} from "party-protocol/utils/IERC20Creator.sol";
import {ITokenDistributor} from "party-protocol/distribution/ITokenDistributor.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {INeynarUserScoresReader} from "../src/interfaces/INeynarUserScoresReader.sol";

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
        INeynarUserScoresReader neynarUserScoresReader = INeynarUserScoresReader(
                0xd3C43A38D1D3E47E9c420a733e439B03FAAdebA8
            );
        address contributionsRouter = 0xD9F65f0d2135BeE238db9c49558632Eb6030CAa7;

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

        TokenDistributorImpl tokenDistributor = new TokenDistributorImpl(
            globals,
            1743003499
        );

        ERC20CreatorV3Impl erc20CreatorV3 = new ERC20CreatorV3Impl(
            tokenDistributor,
            uniswapV3PositionManager,
            IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD),
            address(feeCollector),
            address(weth),
            deployerWallet,
            0,
            10000
        );

        // constructor(IGlobals globals, IERC20Creator erc20Creator) InitialETHCrowdfund(globals) {
        //     ERC20_CREATOR = erc20Creator;
        // }
        ERC20LaunchCrowdfundImpl erc20LaunchCrowdFund = new ERC20LaunchCrowdfundImpl(
                globals,
                IERC20Creator(address(erc20CreatorV3))
            );

        CrowdfundFactoryImpl crowdfundFactory = new CrowdfundFactoryImpl();

        // NeynarScoreGateKeeper neynarScoreGateKeeper = new NeynarScoreGateKeeper(
        //     contributionsRouter,
        //     neynarUserScoresReader
        // );

        vm.stopBroadcast();
    }
}

/**

forge verify-contract \
    --chain-id 8453 \
    --watch \
    --etherscan-api-key 3UM3QPZJ8XAJJE9IXJD5ESUZEDRGGGIKXE \
    0x52e506B58ef5f60Ae74bD04C9bc37A63863Dfe5d \
    src/CrowdfundFactory.sol:CrowdfundFactoryImpl
 */
