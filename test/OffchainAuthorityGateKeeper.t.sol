// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "../src/OffchainAuthorityGateKeeper.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "forge-std/console.sol";

contract OffchainAuthorityGateKeeperTest is Test {
    OffchainAuthorityGateKeeper gk;
    address mockContributionRouter;
    address mockAuthority;
    uint256 authorityPrivateKey;

    function setUp() public {
        mockContributionRouter = address(0x1);
        // Generate a private key and derive the authority address from it
        authorityPrivateKey = 0x12345; // You can use any number here
        mockAuthority = vm.addr(authorityPrivateKey);
        gk = new OffchainAuthorityGateKeeper(mockContributionRouter);
    }

    function testCreateGate() public {
        bytes12 gateId = gk.createGate(mockAuthority);
        assertEq(gk.authorities(gateId), mockAuthority);
    }

    function testIsAllowedWithValidSignature() public {
        bytes12 gateId = gk.createGate(mockAuthority);
        address participant = address(0x123);

        // Create the message hash
        bytes32 message = keccak256(
            abi.encode(gateId, address(this), participant)
        );

        // Sign the message hash with the authority's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorityPrivateKey, message);
        bytes memory signature = abi.encodePacked(r, s, v);

        assertTrue(gk.isAllowed(participant, gateId, signature));
    }

    function testIsNotAllowedWithInvalidSignature() public {
        bytes12 gateId = gk.createGate(mockAuthority);
        address participant = address(0x123);

        // Create the message hash
        bytes32 message = keccak256(abi.encode(gateId, participant));

        // Sign with a different private key to create an invalid signature
        uint256 wrongPrivateKey = 0x67890;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, message);
        bytes memory signature = abi.encodePacked(v, r, s);

        assertFalse(gk.isAllowed(participant, gateId, signature));
    }
}
