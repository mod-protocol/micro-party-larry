// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20LaunchCrowdfund.sol";
import {CrowdfundFactoryImpl} from "../src/CrowdfundFactory.sol";
import "party-protocol/globals/IGlobals.sol";
import "party-protocol/party/Party.sol";
import {PartyFactory} from "party-protocol/party/PartyFactory.sol";

contract ERC20LaunchCrowdfundTestForked is Test {
    struct TokenDistributionConfiguration {
        uint256 totalSupply; // Total supply of the token
        uint256 numTokensForDistribution; // Number of tokens to distribute to the party
        uint256 numTokensForRecipient; // Number of tokens to send to the `tokenRecipient`
        uint256 numTokensForLP; // Number of tokens for the Uniswap V3 LP
    }

    event ERC20Created(
        address indexed token,
        address indexed party,
        address indexed recipient,
        string name,
        string symbol,
        uint256 ethValue,
        TokenDistributionConfiguration config
    );

    ERC20LaunchCrowdfundImpl crowdfund;
    CrowdfundFactoryImpl factory;
    ERC20LaunchCrowdfundImpl launchCrowdfundImpl;
    address mockGlobals;
    address mockERC20Creator;
    address contributor;
    ERC20LaunchCrowdfund.ERC20LaunchOptions tokenOpts;

    function setUp() public {
        // Setup mock contracts and addresses

        mockERC20Creator = address(0x6691fd150746f3d7Deb5e8Be369a3FB9a1235E89);
        contributor = address(0x3);

        factory = new CrowdfundFactoryImpl();

        // Deploy crowdfund implementation contract
        launchCrowdfundImpl = new ERC20LaunchCrowdfundImpl(
            IGlobals(0xcEDe25DF327bD1619Fe25CDa2292e14edAC30717),
            IERC20Creator(mockERC20Creator)
        );

        ERC20LaunchCrowdfund.InitialETHCrowdfundOptions memory crowdfundOpts;
        ERC20LaunchCrowdfund.ETHPartyOptions memory partyOpts;

        partyOpts.name = "Test Party";
        partyOpts.symbol = "TEST";
        partyOpts.governanceOpts.partyImpl = Party(
            payable(0xE34b1b97DdE54DCB82ECa18317025f8e5fBB40Aa)
        );
        partyOpts.governanceOpts.partyFactory = PartyFactory(
            0x68e9fC0e4D7af69Ba64dD6827BFcE5CD230b8F3d
        );
        partyOpts.governanceOpts.voteDuration = 7 days;
        partyOpts.governanceOpts.executionDelay = 1 days;
        partyOpts.governanceOpts.passThresholdBps = 0.5e4;
        partyOpts.governanceOpts.hosts = new address[](1);
        partyOpts.governanceOpts.hosts[0] = address(this);

        crowdfundOpts.maxTotalContributions = 10 ether;
        crowdfundOpts.minTotalContributions = 0.001 ether;
        crowdfundOpts.exchangeRate = 1 ether;
        crowdfundOpts.minContribution = 0.001 ether;
        crowdfundOpts.maxContribution = 2 ether;
        crowdfundOpts.duration = 1 days;
        crowdfundOpts.fundingSplitRecipient = payable(address(this));
        crowdfundOpts.fundingSplitBps = 0.1e4;
        crowdfundOpts.disableContributingForExistingCard = false;

        tokenOpts.name = "Test ERC20";
        tokenOpts.symbol = "TEST";
        tokenOpts.totalSupply = 1e6 ether;
        tokenOpts.recipient = address(0x1234);
        tokenOpts.numTokensForDistribution = 5e4 ether;
        tokenOpts.numTokensForRecipient = 5e4 ether;
        tokenOpts.numTokensForLP = 9e5 ether;
        tokenOpts.lpFeeRecipient = address(0x12345);

        crowdfund = ERC20LaunchCrowdfundImpl(
            address(
                factory.createERC20LaunchCrowdfund(
                    launchCrowdfundImpl,
                    crowdfundOpts,
                    partyOpts,
                    tokenOpts,
                    ""
                )
            )
        );

        // Give contributor some ETH to contribute
        vm.deal(contributor, 10 ether);
    }

    function testPreventMultiplePartyTokens() public {
        // Setup contributor with initial contribution
        vm.startPrank(contributor);
        crowdfund.contribute{value: 1 ether}(contributor, "");
        vm.stopPrank();

        // Attempt second contribution should revert
        vm.startPrank(contributor);
        vm.expectRevert(
            ERC20LaunchCrowdfundImpl
                .ContributorAlreadyHasPartyCardError
                .selector
        );
        crowdfund.contribute{value: 1 ether}(contributor, "");
        vm.stopPrank();
    }

    function testCanContributeWithNoExistingToken() public {
        vm.startPrank(contributor);
        // Should succeed as contributor has no tokens yet
        crowdfund.contribute{value: 1 ether}(0, contributor, "");
        vm.stopPrank();
    }

    function testCanContributeWithSpecificTokenId() public {
        vm.startPrank(contributor);
        // Contributing with specific tokenId should bypass the check
        crowdfund.contribute{value: 1 ether}(contributor, "");
        // Can contribute again with another specific tokenId
        crowdfund.contribute{value: 1 ether}(1, contributor, "");
        vm.stopPrank();
    }

    function testCannotExceedMaxContribution() public {
        vm.startPrank(contributor);

        // Attempt to contribute more than maxContribution (which is 2 ether)
        vm.expectRevert();
        crowdfund.contribute{value: 3 ether}(contributor, "");

        vm.stopPrank();
    }

    function testCannotExceedMaxContributionWithMultipleContributions() public {
        vm.startPrank(contributor);

        // First contribution within the limit
        crowdfund.contribute{value: 1.5 ether}(contributor, "");

        // Second contribution that would exceed the maxContribution (2 ether total)
        vm.expectRevert();
        crowdfund.contribute{value: 1 ether}(contributor, "");

        vm.stopPrank();
    }

    function testTokenDistributionUnderTargetMarketCap() public {
        vm.startPrank(contributor);
        crowdfund.contribute{value: 1.5 ether}(contributor, "");
        vm.stopPrank();

        vm.warp(crowdfund.expiry());

        vm.recordLogs();
        crowdfund.finalize();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find and verify the ERC20Created event
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            // Check if this is the ERC20Created event
            if (
                logs[i].topics[0] !=
                keccak256(
                    "ERC20Created(address,address,address,string,string,uint256,(uint256,uint256,uint256,uint256))"
                )
            ) {
                continue;
            }

            // Decode the event data
            (
                string memory name,
                string memory symbol,
                uint256 ethValue,
                TokenDistributionConfiguration memory config
            ) = abi.decode(
                    logs[i].data,
                    (string, string, uint256, TokenDistributionConfiguration)
                );

            // Verify the configuration values
            assertEq(
                config.totalSupply,
                1_000_000 * 1e18,
                "Incorrect totalSupply"
            );
            assertEq(
                config.numTokensForDistribution,
                25_000 * 1e18,
                "Incorrect numTokensForDistribution"
            );
            assertEq(
                config.numTokensForRecipient,
                50_000 * 1e18,
                "Incorrect numTokensForRecipient"
            );
            assertApproxEqAbs(
                config.numTokensForLP,
                925_000 * 1e18,
                200,
                "Incorrect numTokensForLP"
            );

            foundEvent = true;
            break;
        }

        assertTrue(foundEvent, "ERC20Created event not found");
    }

    function testTokenDistributionOverTargetMarketCap() public {
        // Contribute more than 3 ETH
        vm.startPrank(contributor);
        crowdfund.contribute{value: 2 ether}(contributor, "");
        vm.stopPrank();

        vm.deal(address(0x10), 10 ether);
        vm.startPrank(address(0x10));
        crowdfund.contribute{value: 2 ether}(address(0x10), "");
        vm.stopPrank();

        vm.warp(crowdfund.expiry());

        vm.recordLogs();
        crowdfund.finalize();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find and verify the ERC20Created event
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            // Check if this is the ERC20Created event
            if (
                logs[i].topics[0] !=
                keccak256(
                    "ERC20Created(address,address,address,string,string,uint256,(uint256,uint256,uint256,uint256))"
                )
            ) {
                continue;
            }

            // Decode the event data
            (
                string memory name,
                string memory symbol,
                uint256 ethValue,
                TokenDistributionConfiguration memory config
            ) = abi.decode(
                    logs[i].data,
                    (string, string, uint256, TokenDistributionConfiguration)
                );

            // Verify the configuration values match the original amounts
            assertEq(
                config.totalSupply,
                tokenOpts.totalSupply,
                "Incorrect totalSupply"
            );
            assertEq(
                config.numTokensForDistribution,
                tokenOpts.numTokensForDistribution,
                "Incorrect numTokensForDistribution"
            );
            assertEq(
                config.numTokensForRecipient,
                tokenOpts.numTokensForRecipient,
                "Incorrect numTokensForRecipient"
            );

            assertApproxEqAbs(
                config.numTokensForLP,
                tokenOpts.numTokensForLP,
                200
            );

            foundEvent = true;
            break;
        }

        assertTrue(foundEvent, "ERC20Created event not found");
    }
}
