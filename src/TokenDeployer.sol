// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CrowdfundFactory} from "party-protocol/crowdfund/CrowdfundFactory.sol";
import {ERC20LaunchCrowdfund} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";
import {InitialETHCrowdfund} from "party-protocol/crowdfund/InitialETHCrowdfund.sol";
import {IGateKeeper} from "party-protocol/gatekeepers/IGateKeeper.sol";
import {Party} from "party-protocol/party/Party.sol";
import {PartyFactory} from "party-protocol/party/PartyFactory.sol";

contract TokenDeployer is Ownable {
    // 1. launch party with deadline
    // 2. end party
    // 3. deploy liquidity
    // 4. distribute tokens

    struct ERC20LaunchOptions {
        string name;
        string symbol;
        address creator;
    }

    event Deployed(
        address indexed crowdfund,
        string name,
        string symbol,
        address indexed creator
    );

    uint96 public MAX_CONTRIBUTION = 10000000000000000;
    uint96 public MIN_CONTRIBUTION = 1000000000000000;
    uint256 public LAUNCH_TOTAL_SUPPLY = 1e9; // 1 billion
    uint256 public LAUNCH_DISTRIBUTION_SUPPLY_BPS = 500; // 5%, rest goes to LP
    uint256 public PARTY_DURATION = 900; // 15 minutes

    CrowdfundFactory public crowdfundFactory;
    ERC20LaunchCrowdfund public crowdfundImpl;
    Party public partyImpl;
    PartyFactory public partyFactory;
    address public lpFeeRecipient;

    constructor(
        address _crowdfundFactory,
        address _crowdfundImpl,
        address _partyFactory,
        address payable _partyImpl,
        address _lpFeeRecipient
    ) Ownable(msg.sender) {
        crowdfundFactory = CrowdfundFactory(_crowdfundFactory);
        crowdfundImpl = ERC20LaunchCrowdfund(_crowdfundImpl);
        partyImpl = Party(_partyImpl);
        partyFactory = PartyFactory(_partyFactory);
        lpFeeRecipient = _lpFeeRecipient;
    }

    function deploy(
        ERC20LaunchOptions memory options
    ) public returns (ERC20LaunchCrowdfund) {
        InitialETHCrowdfund.InitialETHCrowdfundOptions
            memory crowdfundOpts = InitialETHCrowdfund
                .InitialETHCrowdfundOptions({
                    initialContributor: payable(address(0)),
                    initialDelegate: payable(address(0)),
                    minContribution: MIN_CONTRIBUTION,
                    maxContribution: MAX_CONTRIBUTION,
                    disableContributingForExistingCard: true,
                    minTotalContributions: MIN_CONTRIBUTION,
                    maxTotalContributions: MAX_CONTRIBUTION,
                    exchangeRate: 1000000000000000000,
                    fundingSplitBps: 0,
                    fundingSplitRecipient: payable(options.creator),
                    duration: PARTY_DURATION, // 15 minunutes
                    gateKeeper: IGateKeeper(address(0)),
                    gateKeeperId: bytes12(0)
                });

        InitialETHCrowdfund.ETHPartyOptions memory partyOpts;
        partyOpts.governanceOpts.partyImpl = partyImpl;
        partyOpts.governanceOpts.partyFactory = partyFactory;
        partyOpts.governanceOpts.voteDuration = 1 days;
        partyOpts.governanceOpts.executionDelay = 1 days;
        partyOpts.governanceOpts.passThresholdBps = 5000;

        ERC20LaunchCrowdfund.ERC20LaunchOptions memory tokenOpts;
        tokenOpts.name = options.name;
        tokenOpts.symbol = options.symbol;
        tokenOpts.recipient = options.creator;
        tokenOpts.totalSupply = LAUNCH_TOTAL_SUPPLY;
        tokenOpts.numTokensForDistribution =
            (LAUNCH_TOTAL_SUPPLY * LAUNCH_DISTRIBUTION_SUPPLY_BPS) /
            10000;
        tokenOpts.numTokensForLP =
            (LAUNCH_TOTAL_SUPPLY * (10000 - LAUNCH_DISTRIBUTION_SUPPLY_BPS)) /
            10000;
        tokenOpts.lpFeeRecipient = lpFeeRecipient;

        bytes memory createGateCallData;

        ERC20LaunchCrowdfund deployed = crowdfundFactory
            .createERC20LaunchCrowdfund(
                crowdfundImpl,
                crowdfundOpts,
                partyOpts,
                tokenOpts,
                createGateCallData
            );

        emit Deployed(
            address(deployed),
            options.name,
            options.symbol,
            options.creator
        );

        return deployed;
    }

    function setMaxContribution(uint96 _maxContribution) external onlyOwner {
        MAX_CONTRIBUTION = _maxContribution;
    }

    function setMinContribution(uint96 _minContribution) external onlyOwner {
        MIN_CONTRIBUTION = _minContribution;
    }

    function setLaunchTotalSupply(
        uint256 _launchTotalSupply
    ) external onlyOwner {
        LAUNCH_TOTAL_SUPPLY = _launchTotalSupply;
    }

    function setLaunchDistributionSupplyBps(
        uint256 _launchDistributionSupplyBps
    ) external onlyOwner {
        require(
            _launchDistributionSupplyBps <= 10000,
            "Distribution BPS cannot exceed 10000"
        );
        LAUNCH_DISTRIBUTION_SUPPLY_BPS = _launchDistributionSupplyBps;
    }

    function setLpFeeRecipient(address _lpFeeRecipient) external onlyOwner {
        require(_lpFeeRecipient != address(0), "Cannot set to zero address");
        lpFeeRecipient = _lpFeeRecipient;
    }

    function setPartyImpl(address payable _partyImpl) external onlyOwner {
        require(_partyImpl != address(0), "Cannot set to zero address");
        partyImpl = Party(_partyImpl);
    }

    function setPartyFactory(address _partyFactory) external onlyOwner {
        require(_partyFactory != address(0), "Cannot set to zero address");
        partyFactory = PartyFactory(_partyFactory);
    }

    function setPartyDuration(uint256 _partyDuration) external onlyOwner {
        require(_partyDuration > 0, "Duration must be greater than 0");
        PARTY_DURATION = _partyDuration;
    }
}

// 1	crowdfundImpl	address	0xf79b1AF78b5768AC431A97cB8cC97a42aF5D90C4
// 1	crowdfundOpts.initialContributor	address	0x0000000000000000000000000000000000000000
// 1	crowdfundOpts.initialDelegate	address	0x0000000000000000000000000000000000000000
// 1	crowdfundOpts.minContribution	uint96
// 10000000000000000
// 1	crowdfundOpts.maxContribution	uint96
// 10000000000000000000
// 1	crowdfundOpts.disableContributingForExistingCard	bool
// true
// 1	crowdfundOpts.minTotalContributions	uint96
// 10000000000000000
// 1	crowdfundOpts.maxTotalContributions	uint96
// 1000000000000000000000000
// 1	crowdfundOpts.exchangeRate	uint160
// 1000000000000000000
// 1	crowdfundOpts.fundingSplitBps	uint16
// 0
// 1	crowdfundOpts.fundingSplitRecipient	address	0x8d25687829D6b85d9e0020B8c89e3Ca24dE20a89
// 1	crowdfundOpts.duration	uint40
// 604800
// 1	crowdfundOpts.gateKeeper	address	0x0000000000000000000000000000000000000000
// 1	crowdfundOpts.gateKeeperId	bytes12
// 0x000000000000000000000000
// 2	partyOpts.name	string
// rick Party
// 2	partyOpts.symbol	string
// 2	partyOpts.customizationPresetId	uint256
// 1
// 2	partyOpts.governanceOpts	tuple	0x5e86bd1664EEC67A808A85e65fAF16A99c83AF8C,0x68e9fC0e4D7af69Ba64dD6827BFcE5CD230b8F3d,0x8d25687829D6b85d9e0020B8c89e3Ca24dE20a89,604800,604800,2500,250,0xF498fd75Ee8D35294952343f1A77CAE5EA5aF6AA
// 2	partyOpts.proposalEngineOpts	tuple	true,true,true,1
// 2	partyOpts.preciousTokens	address
// 2	partyOpts.preciousTokenIds	uint256[]
// 2	partyOpts.rageQuitTimestamp	uint40
// 0
// 2	partyOpts.authorities	address[]
// 0x4a4D5126F99e58466Ceb051d17661bAF0BE2Cf93,0xD665c633920c79cD1cD184D08AAC2cDB2711073c
// 3	tokenOpts.name	string
// rick
// 3	tokenOpts.symbol	string
// rick
// 3	tokenOpts.recipient	address	0x8d25687829D6b85d9e0020B8c89e3Ca24dE20a89
// 3	tokenOpts.totalSupply	uint256
// 1000000000000000000000000000
// 3	tokenOpts.numTokensForDistribution	uint256
// 495000000000000000000000000
// 3	tokenOpts.numTokensForRecipient	uint256
// 10000000000000000000000000
// 3	tokenOpts.numTokensForLP	uint256
// 495000000000000000000000000
// 3	tokenOpts.lpFeeRecipient	address	0x06F2c702bC606FeC2AA87074F5522Fc344657d18
// 5	customMetadataProvider	address	0x39244498E639C4B24910E73DFa3622881D456724
// 6	customMetadata	bytes
// 0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000002a000000000000000000000000000000000000000000000000000000000000002c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000035697066733a2f2f516d63526a52446361756832437a484c7836655345487572555161554735564a563641446a31744a675831457935000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
// 7	createGateCallData	bytes
// 0x0000000000000000000000000000000000000000
