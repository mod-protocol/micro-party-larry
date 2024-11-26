// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {TokenDeployer} from "../src/TokenDeployer.sol";
import {CrowdfundFactory} from "party-protocol/crowdfund/CrowdfundFactory.sol";
import {ERC20LaunchCrowdfund} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";

contract TokenDeployerTest is Test {
    TokenDeployer public deployer;
    address public constant MOCK_CROWDFUND_FACTORY =
        address(0x00d908a177E442CFaB88F4023EEfA2A22e14AF80);
    address public constant MOCK_CROWDFUND_IMPL =
        address(0xf79b1AF78b5768AC431A97cB8cC97a42aF5D90C4);
    address public constant MOCK_PARTY_FACTORY =
        address(0x68e9fC0e4D7af69Ba64dD6827BFcE5CD230b8F3d);
    address payable public constant MOCK_PARTY_IMPL =
        payable(address(0x5e86bd1664EEC67A808A85e65fAF16A99c83AF8C));
    address public constant MOCK_LP_FEE_RECIPIENT = address(0x4);
    address public constant MOCK_CREATOR = address(0x5);

    function setUp() public {
        deployer = new TokenDeployer(
            MOCK_CROWDFUND_FACTORY,
            MOCK_CROWDFUND_IMPL,
            MOCK_PARTY_FACTORY,
            MOCK_PARTY_IMPL,
            MOCK_LP_FEE_RECIPIENT
        );
    }

    function test_Deploy() public {
        // Mock the CrowdfundFactory behavior
        // vm.mockCall(
        //     MOCK_CROWDFUND_FACTORY,
        //     abi.encodeWithSelector(
        //         CrowdfundFactory.createERC20LaunchCrowdfund.selector
        //     ),
        //     abi.encode(ERC20LaunchCrowdfund(address(0x6)))
        // );

        TokenDeployer.ERC20LaunchOptions memory options = TokenDeployer
            .ERC20LaunchOptions({
                name: "Test Token",
                symbol: "TEST",
                creator: MOCK_CREATOR
            });

        // Start recording all logs
        vm.recordLogs();

        ERC20LaunchCrowdfund crowdfund = deployer.deploy(options);

        // Get all recorded logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Optional: Print all logs for inspection
        for (uint i = 0; i < entries.length; i++) {
            console.log("Log", i);
            console.log("Address:", entries[i].emitter);
            console.logBytes32(entries[i].topics[0]); // Event signature
            // If you want to see additional topics
            for (uint j = 1; j < entries[i].topics.length; j++) {
                console.logBytes32(entries[i].topics[j]);
            }
            console.logBytes(entries[i].data); // Event data
        }

        assertNotEq(address(crowdfund), address(0x0));
    }

    function test_SetMaxContribution() public {
        uint96 newMax = 20000000000000000;
        deployer.setMaxContribution(newMax);
        assertEq(deployer.MAX_CONTRIBUTION(), newMax);
    }

    function test_SetMinContribution() public {
        uint96 newMin = 500000000000000;
        deployer.setMinContribution(newMin);
        assertEq(deployer.MIN_CONTRIBUTION(), newMin);
    }

    function test_SetLaunchTotalSupply() public {
        uint256 newSupply = 2e9;
        deployer.setLaunchTotalSupply(newSupply);
        assertEq(deployer.LAUNCH_TOTAL_SUPPLY(), newSupply);
    }

    function test_SetLaunchDistributionSupplyBps() public {
        uint256 newBps = 1000; // 10%
        deployer.setLaunchDistributionSupplyBps(newBps);
        assertEq(deployer.LAUNCH_DISTRIBUTION_SUPPLY_BPS(), newBps);
    }

    function testFail_SetLaunchDistributionSupplyBpsExceedsMax() public {
        deployer.setLaunchDistributionSupplyBps(10001); // Should fail
    }

    function test_SetLpFeeRecipient() public {
        address newRecipient = address(0x7);
        deployer.setLpFeeRecipient(newRecipient);
        assertEq(deployer.lpFeeRecipient(), newRecipient);
    }

    function testFail_SetLpFeeRecipientZeroAddress() public {
        deployer.setLpFeeRecipient(address(0)); // Should fail
    }

    function test_SetPartyImpl() public {
        address payable newPartyImpl = payable(address(0x9));
        deployer.setPartyImpl(newPartyImpl);
        assertEq(address(deployer.partyImpl()), newPartyImpl);
    }

    function testFail_SetPartyImplZeroAddress() public {
        deployer.setPartyImpl(payable(address(0))); // Should fail
    }

    function test_SetPartyFactory() public {
        address newPartyFactory = address(0x10);
        deployer.setPartyFactory(newPartyFactory);
        assertEq(address(deployer.partyFactory()), newPartyFactory);
    }

    function testFail_SetPartyFactoryZeroAddress() public {
        deployer.setPartyFactory(address(0)); // Should fail
    }

    function test_SetPartyDuration() public {
        uint256 newDuration = 7 days;
        deployer.setPartyDuration(newDuration);
        assertEq(deployer.PARTY_DURATION(), newDuration);
    }

    function testFail_SetPartyDurationZero() public {
        deployer.setPartyDuration(0); // Should fail
    }

    function testFail_OnlyOwnerFunctions() public {
        vm.prank(address(0x8)); // Switch to non-owner address

        // All these should fail
        deployer.setMaxContribution(1);
        deployer.setMinContribution(1);
        deployer.setLaunchTotalSupply(1);
        deployer.setLaunchDistributionSupplyBps(1);
        deployer.setLpFeeRecipient(address(1));
        deployer.setPartyImpl(payable(address(1)));
        deployer.setPartyFactory(address(1));
        deployer.setPartyDuration(1);
    }
}
