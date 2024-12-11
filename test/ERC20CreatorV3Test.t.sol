// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8;

import {Test} from "forge-std/Test.sol";
import {ERC20CreatorV3Impl, ERC20CreatorV3, IERC20, FeeRecipient} from "../src/ERC20CreatorV3.sol";
import {MockUniswapV3Deployer} from "./mock/MockUniswapV3Deployer.t.sol";
import {FeeCollector, IWETH} from "erc20-creator/FeeCollector.sol";
import {MockUniswapNonfungiblePositionManager} from "./mock/MockUniswapNonfungiblePositionManager.t.sol";
import {ITokenDistributor, Party} from "party-protocol/contracts/distribution/ITokenDistributor.sol";
import {MockTokenDistributor} from "./mock/MockTokenDistributor.t.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {MockParty} from "./mock/MockParty.t.sol";
import {console} from "forge-std/console.sol";

contract ERC20CreatorV3Test is Test, MockUniswapV3Deployer {
    UniswapV3Deployment internal uniswap;
    ERC20CreatorV3Impl internal creator;
    ITokenDistributor internal distributor;
    Party internal party;
    FeeCollector internal feeCollector;

    event ERC20Created(
        address indexed token,
        address indexed party,
        address indexed recipient,
        string name,
        string symbol,
        uint256 ethValue,
        ERC20CreatorV3Impl.TokenDistributionConfiguration config
    );

    function setUp() external {
        uniswap.POSITION_MANAGER = address(
            0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
        );
        uniswap.FACTORY = address(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
        uniswap.WETH = payable(
            address(0x4200000000000000000000000000000000000006)
        );

        distributor = ITokenDistributor(address(new MockTokenDistributor()));

        party = Party(payable(address(new MockParty())));
        vm.label(address(party), "Party");

        feeCollector = new FeeCollector(
            INonfungiblePositionManager(uniswap.POSITION_MANAGER),
            payable(this),
            100,
            IWETH(uniswap.WETH)
        );

        creator = new ERC20CreatorV3Impl(
            distributor,
            INonfungiblePositionManager(uniswap.POSITION_MANAGER),
            IUniswapV3Factory(uniswap.FACTORY),
            address(feeCollector),
            uniswap.WETH,
            address(this),
            100,
            10_000
        );
    }

    function testCreatorV3_createToken() public {
        ERC20CreatorV3Impl.TokenDistributionConfiguration memory tokenConfig;
        address feeRecipient = address(0x123);

        tokenConfig.totalSupply = 1e9 * 1e18;

        tokenConfig.numTokensForDistribution =
            (tokenConfig.totalSupply * 3) /
            10;
        tokenConfig.numTokensForRecipient = 0;
        tokenConfig.numTokensForLP = (tokenConfig.totalSupply * 7) / 10;

        uint256 ethForLp = 3 ether;

        vm.deal(address(party), ethForLp);

        uint256 beforeBalanceThis = address(this).balance;

        // vm.expectEmit(false, true, true, true);
        // emit ERC20Created(
        //     address(0),
        //     address(party),
        //     address(this),
        //     "My Test Token",
        //     "MTT",
        //     ethForLp,
        //     tokenConfig
        // );

        vm.prank(address(party));
        IERC20 token = IERC20(
            creator.createToken{value: ethForLp}(
                address(party),
                feeRecipient,
                "My Test Token",
                "MTT",
                tokenConfig,
                address(this)
            )
        );

        address pool = creator.getPool(address(token));

        assertEq(
            address(this).balance,
            beforeBalanceThis + (ethForLp * 100) / 10_000 // Got the fee
        );
        assertEq(
            token.balanceOf(address(this)),
            tokenConfig.numTokensForRecipient
        );
        assertApproxEqRel(
            token.balanceOf(pool),
            tokenConfig.numTokensForLP,
            0.0001e18 // 0.01% = 0.0001 * 100%
        );
        assertEq(
            token.balanceOf(address(distributor)),
            tokenConfig.numTokensForDistribution
        );
        assertEq(
            IERC20(uniswap.WETH).balanceOf(pool),
            ethForLp - (ethForLp * 100) / 10_000
        );

        uint256 tokenId1 = MockUniswapNonfungiblePositionManager(
            uniswap.POSITION_MANAGER
        ).lastTokenId();
        uint256 tokenId2 = tokenId1 - 1;

        FeeRecipient[] memory feeRecipients = feeCollector.getFeeRecipients(
            tokenId1
        );
        assertEq(feeRecipients.length, 1);
        assertEq(
            abi.encode(feeRecipients[0]),
            abi.encode(
                FeeRecipient({recipient: feeRecipient, percentageBps: 10_000})
            )
        );

        feeRecipients = feeCollector.getFeeRecipients(tokenId2);
        assertEq(feeRecipients.length, 1);
        assertEq(
            abi.encode(feeRecipients[0]),
            abi.encode(
                FeeRecipient({recipient: feeRecipient, percentageBps: 10_000})
            )
        );

        (, bytes memory res) = address(token).call(
            abi.encodeWithSignature("totalSupply()")
        );
        uint256 totalSupply = abi.decode(res, (uint256));
        assertEq(totalSupply, tokenConfig.totalSupply);
    }

    function test_constructor_invalidPoolFeeReverts() external {
        ERC20CreatorV3Impl.TokenDistributionConfiguration memory tokenConfig;

        vm.expectRevert(ERC20CreatorV3.InvalidPoolFee.selector);
        creator = new ERC20CreatorV3Impl(
            distributor,
            INonfungiblePositionManager(uniswap.POSITION_MANAGER),
            IUniswapV3Factory(uniswap.FACTORY),
            address(feeCollector),
            uniswap.WETH,
            address(this),
            100,
            10_001
        );
    }

    function test_setFeeRecipient_error_onlyFeeRecipient() external {
        vm.expectRevert(ERC20CreatorV3.OnlyFeeRecipient.selector);
        vm.prank(address(uniswap.POSITION_MANAGER));
        creator.setFeeRecipient(address(this));
    }

    event FeeRecipientUpdated(
        address indexed oldFeeRecipient,
        address indexed newFeeRecipient
    );

    function test_setFeeRecipient_success() external {
        vm.expectEmit();
        emit FeeRecipientUpdated(address(this), address(0));
        creator.setFeeRecipient(address(0));
    }

    function test_setFeeBasisPoints_error_onlyFeeRecipient() external {
        vm.expectRevert(ERC20CreatorV3.OnlyFeeRecipient.selector);
        vm.prank(address(uniswap.POSITION_MANAGER));
        creator.setFeeBasisPoints(2_000);
    }

    event FeeBasisPointsUpdated(
        uint16 oldFeeBasisPoints,
        uint16 newFeeBasisPoints
    );

    function test_setFeeBasisPoints_success() external {
        vm.expectEmit();
        emit FeeBasisPointsUpdated(100, 200);
        creator.setFeeBasisPoints(200);
    }

    receive() external payable {}
}
