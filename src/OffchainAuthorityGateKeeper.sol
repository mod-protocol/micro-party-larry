// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IGateKeeper} from "party-protocol/contracts/gatekeepers/IGateKeeper.sol";
import {IContributionRouter} from "./interfaces/IContributionRouter.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/// @notice A gateKeeper that implements a simple allow list per gate.
contract OffchainAuthorityGateKeeper is IGateKeeper {
    /// @notice The address of the canonical contribution router.
    address public immutable CONTRIBUTION_ROUTER;
    uint96 private _lastId;
    mapping(bytes12 => address) public authorities;
    constructor(address contributionRouter) {
        CONTRIBUTION_ROUTER = contributionRouter;
    }

    /// @inheritdoc IGateKeeper
    /// @param id The ID of the gate to eligibility against.
    /// @param userData The signature received from the offchain authority.
    /// @return true if the participant is allowed to participate, false otherwise.
    function isAllowed(
        address participant,
        bytes12 id,
        bytes memory userData
    ) external view returns (bool) {
        if (participant == CONTRIBUTION_ROUTER) {
            participant = IContributionRouter(payable(CONTRIBUTION_ROUTER))
                .caller();
        }

        // Message is hash of gate id + crowdfund address + participant address
        bytes32 message = keccak256(abi.encode(id, msg.sender, participant));

        address authority = authorities[id];

        // Verify signature
        return
            SignatureChecker.isValidSignatureNow(authority, message, userData);
    }

    /// @notice Create a new gate.
    /// @param authority The offchain authority that can authorize participants.
    /// @return id The ID of the new gate.
    function createGate(address authority) external returns (bytes12 id) {
        uint96 id_ = ++_lastId;
        id = bytes12(id_);
        authorities[id] = authority;
    }
}
