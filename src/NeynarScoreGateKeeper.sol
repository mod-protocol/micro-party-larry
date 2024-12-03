// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IGateKeeper} from "party-protocol/contracts/gatekeepers/IGateKeeper.sol";
import {IContributionRouter} from "./interfaces/IContributionRouter.sol";
import {INeynarUserScoresReader} from "./interfaces/INeynarUserScoresReader.sol";

/// @notice A gateKeeper that implements a simple allow list per gate.
contract NeynarScoreGateKeeper is IGateKeeper {
    /// @notice The address of the canonical contribution router.
    address public immutable CONTRIBUTION_ROUTER;
    uint96 private _lastId;
    INeynarUserScoresReader public NEYNAR_USER_SCORES_READER;

    constructor(
        address contributionRouter,
        INeynarUserScoresReader neynarUserScoresReader
    ) {
        CONTRIBUTION_ROUTER = contributionRouter;
        NEYNAR_USER_SCORES_READER = neynarUserScoresReader;
    }

    /// @inheritdoc IGateKeeper
    /// @param id The ID is converted into a score threshold by multiplication by 100.
    function isAllowed(
        address participant,
        bytes12 id,
        bytes memory userData
    ) external view returns (bool) {
        if (participant == CONTRIBUTION_ROUTER) {
            participant = IContributionRouter(payable(CONTRIBUTION_ROUTER))
                .caller();
        }
        uint256 score = NEYNAR_USER_SCORES_READER.getScore(participant);

        // Convert bytes12 to uint256 by first converting to uint96
        return score > (uint256(uint96(bytes12(id))) * 100);
    }

    /// @notice Create a new gate.
    /// @return id The ID of the new gate.
    function createGate() external returns (bytes12 id) {
        uint96 id_ = ++_lastId;
        id = bytes12(id_);
    }
}
