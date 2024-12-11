// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ERC20LaunchCrowdfund, ERC20} from "party-protocol/crowdfund/ERC20LaunchCrowdfund.sol";
import {IGlobals} from "party-protocol/globals/IGlobals.sol";
import {IERC20Creator, TokenConfiguration} from "party-protocol/utils/IERC20Creator.sol";
import {LibSafeCast} from "party-protocol/utils/LibSafeCast.sol";
import {LibAddress} from "party-protocol/utils/LibAddress.sol";

contract ERC20LaunchCrowdfundImpl is ERC20LaunchCrowdfund {
    using LibSafeCast for uint256;
    using LibAddress for address payable;

    error ContributorAlreadyHasPartyCardError();
    error ContributionWouldExceedMaxVotingPowerError();

    constructor(
        IGlobals globals,
        IERC20Creator erc20Creator
    ) ERC20LaunchCrowdfund(globals, erc20Creator) {}

    /// @notice Launch the ERC20 token for the Party.
    function launchToken() public override returns (ERC20 token) {
        if (isTokenLaunched) revert TokenAlreadyLaunched();

        CrowdfundLifecycle lc = getCrowdfundLifecycle();
        if (lc != CrowdfundLifecycle.Finalized) revert WrongLifecycleError(lc);

        isTokenLaunched = true;

        // Update the party's total voting power
        uint96 totalContributions_ = totalContributions;

        uint16 fundingSplitBps_ = fundingSplitBps;
        if (fundingSplitBps_ > 0) {
            // Assuming fundingSplitBps_ <= 1e4, this cannot overflow uint96
            totalContributions_ -= uint96(
                (uint256(totalContributions_) * fundingSplitBps_) / 1e4
            );
        }

        address tokenRecipient = tokenOpts.recipient;
        if (tokenRecipient == PARTY_ADDRESS_KEY) {
            tokenRecipient = address(party);
        }

        address lpFeeRecipient = tokenOpts.lpFeeRecipient;
        if (lpFeeRecipient == PARTY_ADDRESS_KEY) {
            lpFeeRecipient = address(party);
        }

        // Create the ERC20 token.
        ERC20LaunchOptions memory _tokenOpts = tokenOpts;

        uint256 minPresaleCap = 3 ether;

        // If less than min presale cap is raised, only distribute amount proportional to the original distribution amount
        // new_distribution_amount = (total_contributions / min_presale_cap) * original_distribution_amount
        // And send remainder of original distribution amount to LP
        // new_lp_amount = original_lp_amount + (original_distribution_amount - new_distribution_amount)
        if (totalContributions < minPresaleCap) {
            uint256 numTokensForDistribution = (totalContributions *
                _tokenOpts.numTokensForDistribution) / minPresaleCap;
            uint256 numTokensForLP = _tokenOpts.numTokensForLP +
                (_tokenOpts.numTokensForDistribution -
                    numTokensForDistribution);
            _tokenOpts.numTokensForDistribution = numTokensForDistribution;
            _tokenOpts.numTokensForLP = numTokensForLP;
        }

        if (
            _tokenOpts.numTokensForDistribution +
                _tokenOpts.numTokensForLP +
                _tokenOpts.numTokensForRecipient >
            _tokenOpts.totalSupply
        ) {
            revert InvalidTokenDistribution();
        }

        token = ERC20_CREATOR.createToken{value: totalContributions_}(
            address(party),
            lpFeeRecipient,
            _tokenOpts.name,
            _tokenOpts.symbol,
            TokenConfiguration({
                totalSupply: _tokenOpts.totalSupply,
                numTokensForDistribution: _tokenOpts.numTokensForDistribution,
                numTokensForRecipient: _tokenOpts.numTokensForRecipient,
                numTokensForLP: _tokenOpts.numTokensForLP
            }),
            tokenRecipient
        );
    }

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
