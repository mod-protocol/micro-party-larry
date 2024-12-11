// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20LaunchCrowdfund} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {IERC20Creator} from "party-protocol/utils/IERC20Creator.sol";
import {LibSafeCast} from "party-protocol/utils/LibSafeCast.sol";
import {LibAddress} from "party-protocol/utils/LibAddress.sol";

contract ERC20LaunchCrowdfundImpl is ERC20LaunchCrowdfund {
    using LibSafeCast for uint256;
    using LibAddress for address payable;

    error ContributorAlreadyHasPartyCardError();
    error ContributionWouldExceedMaxVotingPowerError();

    event RefundedEarly(
        address indexed contributor,
        uint256 tokenId,
        uint96 amount
    );

    constructor(
        IGlobals globals,
        IERC20Creator erc20Creator
    ) ERC20LaunchCrowdfund(globals, erc20Creator) {}

    function _contribute(
        address payable contributor,
        address delegate,
        uint96 amount,
        uint256 tokenId,
        bytes memory gateData
    ) internal override returns (uint96 votingPower) {
        if (tokenId == 0) {
            uint256 balance = party.balanceOf(contributor);
            if (balance > 0) {
                revert ContributorAlreadyHasPartyCardError();
            }
        } else {
            // Check voting power of existing card
            uint256 currentVotingPower = party.votingPowerByTokenId(tokenId);
            uint96 newVotingPower = _calculateContributionToVotingPower(amount);
            uint96 maxVotingPower = _calculateContributionToVotingPower(
                maxContribution
            );
            if (uint256(currentVotingPower + newVotingPower) > maxVotingPower) {
                revert ContributionWouldExceedMaxVotingPowerError();
            }
        }

        return
            super._contribute(contributor, delegate, amount, tokenId, gateData);
    }

    /// @notice Refund the owner of a party card and burn it. Only available if
    ///         crowdfund is active.
    ///         Can only be called by the owner of the party card.
    /// @param tokenId The ID of the party card to refund the owner of then burn.
    /// @return amount The amount of ETH refunded to the contributor.
    function earlyRefund(uint256 tokenId) external returns (uint96 amount) {
        // Check crowdfund lifecycle.
        {
            CrowdfundLifecycle lc = getCrowdfundLifecycle();
            if (lc != CrowdfundLifecycle.Active) {
                revert WrongLifecycleError(lc);
            }
        }

        // Check that the caller is the owner of the party card.
        if (party.ownerOf(tokenId) != msg.sender) {
            revert NotOwnerError(tokenId);
        }

        // Get amount to refund.
        uint96 votingPower = party
            .votingPowerByTokenId(tokenId)
            .safeCastUint256ToUint96();
        amount = convertVotingPowerToContribution(votingPower);

        if (amount > 0) {
            // Get contributor to refund.
            address payable contributor = payable(party.ownerOf(tokenId));

            // Burn contributor's party card.
            party.burn(tokenId);

            // Refund contributor.
            contributor.transferEth(amount);

            emit RefundedEarly(contributor, tokenId, amount);
        }
    }
}
