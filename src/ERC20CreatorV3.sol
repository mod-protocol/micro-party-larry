// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "erc20-creator/ERC20CreatorV3.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {IWETH} from "v2-periphery/interfaces/IWETH.sol";
import {FixedPointMathLib} from "./libs/FixedPointMathLib.sol";

contract ERC20CreatorV3Impl is ERC20CreatorV3 {
    using TickMath for int24;

    struct PoolVars {
        uint256 lpTokenTokenId;
        uint256 lpEthTokenId;
        uint256 initialPrice;
        uint256 ethAmount;
    }

    int24 public immutable TICK_SPACING;

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
    {
        TICK_SPACING = UNISWAP_V3_FACTORY.feeAmountTickSpacing(poolFee);
    }

    function createToken(
        address party,
        address lpFeeRecipient,
        string memory name,
        string memory symbol,
        TokenDistributionConfiguration memory config,
        address tokenRecipientAddress
    ) external payable override returns (address) {
        return
            createTokenWithInitialPrice(
                party,
                lpFeeRecipient,
                name,
                symbol,
                config,
                tokenRecipientAddress
            );
    }

    /// @notice Creates a new ERC20 token, LP the eth from MIN_TICK to the initial price,
    /// LP the token from the initial price to MAX_TICK, and distributes some of the new token to party members.
    /// @dev The party is assumed to be `msg.sender`
    /// @param party The party to allocate the token distribution to
    /// @param lpFeeRecipient The address to receive the LP fee
    /// @param name The name of the new token
    /// @param symbol The symbol of the new token
    /// @param config Token distribution configuration. See above for additional information.
    /// @param tokenRecipientAddress The address to receive the tokens allocated for the token recipient
    /// @return token The address of the newly created token
    function createTokenWithInitialPrice(
        address party,
        address lpFeeRecipient,
        string memory name,
        string memory symbol,
        TokenDistributionConfiguration memory config,
        address tokenRecipientAddress
    ) public payable returns (address) {
        PoolVars memory poolVars;

        // Require that tokens are fully distributed
        if (
            config.numTokensForDistribution +
                config.numTokensForRecipient +
                config.numTokensForLP !=
            config.totalSupply ||
            config.totalSupply > type(uint112).max
        ) {
            revert InvalidTokenDistribution();
        }

        // We use a changing salt to ensure address changes every block. If the LP position already exists, the TX will revert.
        // Can be tried again the next block.
        IERC20 token = IERC20(
            address(
                new GovernableERC20{
                    salt: keccak256(
                        abi.encode(blockhash(block.number - 1), msg.sender)
                    )
                }(name, symbol, config.totalSupply, address(this))
            )
        );

        if (config.numTokensForDistribution > 0) {
            // Create distribution
            token.transfer(
                address(TOKEN_DISTRIBUTOR),
                config.numTokensForDistribution
            );
            TOKEN_DISTRIBUTOR.createErc20Distribution(
                token,
                Party(payable(party)),
                payable(address(0)),
                0
            );
        }

        // Take fee // (msg.value * feeBasisPoints) / 1e4
        uint256 feeAmount = (msg.value * feeBasisPoints) / 1e4;

        poolVars.ethAmount = msg.value - feeAmount;

        // Initial price is based on the presale price
        poolVars.initialPrice = ((poolVars.ethAmount * 1e18) /
            (config.totalSupply - config.numTokensForLP));

        IUniswapV3Pool pool = IUniswapV3Pool(
            UNISWAP_V3_FACTORY.createPool(
                address(token),
                address(WETH),
                POOL_FEE
            )
        );

        // Initialize the pool
        {
            if (address(token) < address(WETH)) {
                // decimal(wad) price to sqrtPriceX96
                (uint160 sqrtPriceX96, ) = _toPriceX96(
                    poolVars.initialPrice,
                    TICK_SPACING,
                    false
                );

                // initialize the pool
                pool.initialize(sqrtPriceX96);
            } else {
                // the price of WETH enominated by token is 1/poolVars.initialPrice
                (uint160 sqrtPriceX96, ) = _toPriceX96(
                    FixedPointMathLib.divWad(1 ether, poolVars.initialPrice),
                    TICK_SPACING,
                    true
                );

                // initialize the pool
                pool.initialize(sqrtPriceX96);
            }
        }

        // Let's create two positions
        //  - position 1: WITH only ETH, raised ETH added to the concentrated range around the initial price
        //  - position 2: Token only, the remaining supply of the token to the range of [initial price , +inf]

        // prepare
        IWETH(WETH).deposit{value: poolVars.ethAmount}();
        IERC20(WETH).approve(
            address(UNISWAP_V3_POSITION_MANAGER),
            poolVars.ethAmount
        );
        token.approve(
            address(UNISWAP_V3_POSITION_MANAGER),
            config.numTokensForLP
        );

        // ETH only position
        {
            // token is token0
            if (address(token) < address(WETH)) {
                // decimal(wad) price to sqrtPriceX96
                (, int24 tick) = _toPriceX96(
                    poolVars.initialPrice,
                    TICK_SPACING,
                    false
                );

                // we should add liquidity to  the range of [tick - tickSpacing, tick]
                // This is the most concentrated range around the initial price
                // The liquidity should be the raised ETH
                (poolVars.lpEthTokenId, , , ) = UNISWAP_V3_POSITION_MANAGER
                    .mint(
                        INonfungiblePositionManager.MintParams({
                            token0: address(token),
                            token1: address(WETH),
                            fee: POOL_FEE,
                            tickLower: tick - TICK_SPACING,
                            tickUpper: tick,
                            amount0Desired: 0,
                            amount1Desired: poolVars.ethAmount,
                            amount0Min: 0,
                            amount1Min: 0,
                            recipient: address(this),
                            deadline: block.timestamp
                        })
                    );
            } else {
                // token is token1
                // the price of WETH enominated by token is 1/initialPrice
                (, int24 tick) = _toPriceX96(
                    FixedPointMathLib.divWad(1 ether, poolVars.initialPrice),
                    TICK_SPACING,
                    true
                );

                // we should add liquidity to  the range of [tick, tick + tickSpacing]
                // This is the most concentrated range around the initial price
                // The liquidity should be raised ETH
                (poolVars.lpEthTokenId, , , ) = UNISWAP_V3_POSITION_MANAGER
                    .mint(
                        INonfungiblePositionManager.MintParams({
                            token0: address(WETH),
                            token1: address(token),
                            fee: POOL_FEE,
                            tickLower: tick,
                            tickUpper: tick + TICK_SPACING,
                            amount0Desired: poolVars.ethAmount,
                            amount1Desired: 0,
                            amount0Min: 0,
                            amount1Min: 0,
                            recipient: address(this),
                            deadline: block.timestamp
                        })
                    );
            }
        }

        // step3: Token only position
        {
            // token is token0
            if (address(token) < address(WETH)) {
                // decimal(wad) price to sqrtPriceX96
                (, int24 tick) = _toPriceX96(
                    poolVars.initialPrice,
                    TICK_SPACING,
                    true
                );

                // we should add liquidity to  the range of [tick, MAX_TICK]
                // The liquidity should be the remaining supply of the token
                (poolVars.lpTokenTokenId, , , ) = UNISWAP_V3_POSITION_MANAGER
                    .mint(
                        INonfungiblePositionManager.MintParams({
                            token0: address(token),
                            token1: address(WETH),
                            fee: POOL_FEE,
                            tickLower: tick,
                            tickUpper: _snapToTickSpacing(
                                TickMath.MAX_TICK,
                                TICK_SPACING,
                                false
                            ),
                            amount0Desired: config.numTokensForLP,
                            amount1Desired: 0,
                            amount0Min: 0,
                            amount1Min: 0,
                            recipient: address(this),
                            deadline: block.timestamp
                        })
                    );
            } else {
                // token is token1
                // the price of WETH enominated by token is 1/initialPrice
                (, int24 tick) = _toPriceX96(
                    FixedPointMathLib.divWad(1 ether, poolVars.initialPrice),
                    TICK_SPACING,
                    false
                );

                // we should add liquidity to  the range of [MIN_TICK, tick]
                // The liquidity should be the remaining supply of the token
                (poolVars.lpTokenTokenId, , , ) = UNISWAP_V3_POSITION_MANAGER
                    .mint(
                        INonfungiblePositionManager.MintParams({
                            token0: address(WETH),
                            token1: address(token),
                            fee: POOL_FEE,
                            tickLower: _snapToTickSpacing(
                                TickMath.MIN_TICK,
                                TICK_SPACING,
                                true
                            ),
                            tickUpper: tick,
                            amount0Desired: 0,
                            amount1Desired: config.numTokensForLP,
                            amount0Min: 0,
                            amount1Min: 0,
                            recipient: address(this),
                            deadline: block.timestamp
                        })
                    );
            }
        }

        // Transfer tokens to token recipient
        if (config.numTokensForRecipient > 0) {
            token.transfer(tokenRecipientAddress, config.numTokensForRecipient);
        }

        // Refund any remaining dust of the token to the party
        {
            uint256 remainingTokenBalance = token.balanceOf(address(this));
            if (remainingTokenBalance > 0) {
                // Adjust the numTokensForLP to reflect the actual amount used
                config.numTokensForLP -= remainingTokenBalance;
                token.transfer(party, remainingTokenBalance);
            }
        }

        // Transfer fee
        if (feeAmount > 0) {
            feeRecipient.call{value: feeAmount, gas: 100_000}("");
        }

        // Transfer remaining ETH to the party
        if (address(this).balance > 0) {
            payable(party).call{value: address(this).balance, gas: 100_000}("");
        }

        FeeRecipient[] memory recipients = new FeeRecipient[](1);
        recipients[0] = FeeRecipient({
            recipient: payable(lpFeeRecipient),
            percentageBps: 10_000
        });

        // Transfer LPs to fee collector contract
        UNISWAP_V3_POSITION_MANAGER.safeTransferFrom(
            address(this),
            FEE_COLLECTOR,
            poolVars.lpEthTokenId,
            abi.encode(recipients)
        );
        UNISWAP_V3_POSITION_MANAGER.safeTransferFrom(
            address(this),
            FEE_COLLECTOR,
            poolVars.lpTokenTokenId,
            abi.encode(recipients)
        );

        emit ERC20Created(
            address(token),
            party,
            tokenRecipientAddress,
            name,
            symbol,
            msg.value,
            config
        );

        return address(token);
    }

    function _toPriceX96(
        uint256 price,
        int24 tickSpacing,
        bool roundup
    ) internal pure returns (uint160 sqrtPriceX96, int24 tick) {
        uint256 sqrtWad = FixedPointMathLib.sqrtWad(price);
        if (roundup) {
            sqrtWad += 1 wei;
        } else {
            sqrtWad -= 1 wei;
        }

        sqrtPriceX96 = uint160((sqrtWad << 96) / (1 ether));

        // round to multiple of tickSpacing

        tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        tick = _snapToTickSpacing(tick, tickSpacing, roundup);
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
    }

    function _snapToTickSpacing(
        int24 tick,
        int24 tickSpacing,
        bool up
    ) internal pure returns (int24) {
        int24 rounded = (tick / tickSpacing) * tickSpacing;
        if (up && rounded < tick) rounded += tickSpacing;
        if (!up && rounded > tick) rounded -= tickSpacing;
        return rounded;
    }
}
