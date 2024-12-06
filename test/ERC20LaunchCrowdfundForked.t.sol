// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ERC20LaunchCrowdfund.sol";
import {CrowdfundFactoryImpl} from "../src/CrowdfundFactory.sol";
import {GlobalsMock} from "./mocks/GlobalsMock.sol";
import "party-protocol/globals/IGlobals.sol";
import "party-protocol/party/Party.sol";
import {PartyFactory} from "party-protocol/party/PartyFactory.sol";

contract ERC20LaunchCrowdfundTestForked is Test {
    ERC20LaunchCrowdfundImpl crowdfund;
    CrowdfundFactoryImpl factory;
    ERC20LaunchCrowdfundImpl launchCrowdfundImpl;
    address mockGlobals;
    address mockERC20Creator;
    address contributor;

    function setUp() public {
        // Setup mock contracts and addresses
        mockERC20Creator = address(0x2);
        contributor = address(0x3);

        factory = new CrowdfundFactoryImpl();

        // Deploy crowdfund implementation contract
        launchCrowdfundImpl = new ERC20LaunchCrowdfundImpl(
            IGlobals(0xcEDe25DF327bD1619Fe25CDa2292e14edAC30717),
            IERC20Creator(mockERC20Creator)
        );

        ERC20LaunchCrowdfund.InitialETHCrowdfundOptions memory crowdfundOpts;
        ERC20LaunchCrowdfund.ETHPartyOptions memory partyOpts;
        ERC20LaunchCrowdfund.ERC20LaunchOptions memory tokenOpts;

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
        tokenOpts.recipient = address(0);
        tokenOpts.numTokensForDistribution = 5e4 ether;
        tokenOpts.numTokensForRecipient = 5e4 ether;
        tokenOpts.numTokensForLP = 9e5 ether;
        tokenOpts.lpFeeRecipient = address(0);

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
}
