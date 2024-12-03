// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/NeynarScoreGateKeeper.sol";
import "../lib/party-protocol/contracts/crowdfund/ContributionRouter.sol";
import "./TestUtils.sol";

contract NeynarScoreGateKeeperTest is Test {
    NeynarScoreGateKeeper gk;
    MockNeynarUserScoresReader mockReader;
    address mockContributionRouter;

    function setUp() public {
        mockContributionRouter = address(0);
        mockReader = new MockNeynarUserScoresReader();
        gk = new NeynarScoreGateKeeper(
            mockContributionRouter,
            INeynarUserScoresReader(address(mockReader))
        );
    }

    function testUniqueGateIds() public {
        bytes12 gateId1 = gk.createGate();
        bytes12 gateId2 = gk.createGate();
        assertTrue(gateId1 != gateId2);
    }

    function testIsAllowedHighScore() public {
        address participant = address(0x123);
        bytes12 gateId = bytes12(uint96(9000));

        mockReader.setScore(participant, 950_000);

        assertTrue(gk.isAllowed(participant, gateId, ""));
    }

    function testIsAllowedLowScore() public {
        address participant = address(0x123);
        bytes12 gateId = bytes12(uint96(9000));

        mockReader.setScore(participant, 800_000);

        assertFalse(gk.isAllowed(participant, gateId, ""));
    }
}

// Mock contract for testing
contract MockNeynarUserScoresReader is INeynarUserScoresReader {
    mapping(address => uint24) private scores;

    function setScore(address user, uint24 score) public {
        scores[user] = score;
    }

    function getScore(address verifier) external view returns (uint24) {
        return scores[verifier];
    }

    function getScoreWithEvent(address verifier) external returns (uint24) {
        return scores[verifier];
    }

    function getScores(
        address[] calldata verifiers
    ) external view returns (uint24[] memory) {
        uint24[] memory result = new uint24[](verifiers.length);
        for (uint i = 0; i < verifiers.length; i++) {
            result[i] = scores[verifiers[i]];
        }
        return result;
    }

    function getScore(uint256 fid) external view returns (uint24) {
        // Implement logic if needed
        return 0;
    }

    function getScoreWithEvent(uint256 fid) external returns (uint24) {
        // Implement logic if needed
        return 0;
    }

    function getScores(
        uint256[] calldata fids
    ) external view returns (uint24[] memory) {
        // Implement logic if needed
        return new uint24[](fids.length);
    }
}
