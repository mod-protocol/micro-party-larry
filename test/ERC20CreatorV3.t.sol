// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20CreatorV3.sol";
import {ITokenDistributor} from "party-protocol/distribution/ITokenDistributor.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract ERC20CreatorV3ImplTest is Test {
    ERC20CreatorV3Impl creator;

    // Mock addresses
    address mockTokenDistributor = address(0x1);
    address mockPositionManager = address(0x2);
    address mockFactory = address(0x3);
    address mockFeeCollector = address(0x4);
    address mockWeth = address(0x5);
    address mockFeeRecipient = address(0x6);

    uint16 constant FEE_BASIS_POINTS = 500; // 5%
    uint16 constant POOL_FEE = 3000; // 0.3%

    function setUp() public {
        // Create mock contracts with minimal implementation
        vm.mockCall(
            mockFactory,
            abi.encodeWithSelector(
                IUniswapV3Factory.feeAmountTickSpacing.selector,
                POOL_FEE
            ),
            abi.encode(60) // Standard tick spacing for 0.3% fee tier
        );

        creator = new ERC20CreatorV3Impl(
            ITokenDistributor(mockTokenDistributor),
            INonfungiblePositionManager(mockPositionManager),
            IUniswapV3Factory(mockFactory),
            mockFeeCollector,
            mockWeth,
            mockFeeRecipient,
            FEE_BASIS_POINTS,
            POOL_FEE
        );
    }

    function testConstructorInitialization() public {
        // Test MIN_TICK calculation
        // -184216 / 60 * 60 = -184200
        assertEq(creator.MIN_TICK(), -184200);

        // Test MAX_TICK calculation
        // 887272 / 60 * 60 = 887220
        assertEq(creator.MAX_TICK(), 887220);

        // Verify other initialized values
        assertEq(address(creator.TOKEN_DISTRIBUTOR()), mockTokenDistributor);
        assertEq(
            address(creator.UNISWAP_V3_POSITION_MANAGER()),
            mockPositionManager
        );
        assertEq(address(creator.UNISWAP_V3_FACTORY()), mockFactory);
        assertEq(creator.FEE_COLLECTOR(), mockFeeCollector);
        assertEq(creator.WETH(), mockWeth);
        assertEq(creator.feeRecipient(), mockFeeRecipient);
        assertEq(creator.feeBasisPoints(), FEE_BASIS_POINTS);
        assertEq(creator.POOL_FEE(), POOL_FEE);
    }
}
