// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20LaunchCrowdfund} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {IERC20Creator} from "party-protocol/utils/IERC20Creator.sol";

contract ERC20LaunchCrowdfundImpl is ERC20LaunchCrowdfund {
    error ContributorAlreadyHasPartyCardError();
    error ContributionWouldExceedMaxVotingPowerError();

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
}
