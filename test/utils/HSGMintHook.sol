// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IHatsSignerGate } from "../../lib/hats-zodiac/src/interfaces/IHatsSignerGate.sol";
import { IHatMintHook } from "../../src/interfaces/IHatMintHook.sol";

/// @notice Custom mint hook that claims signer permissions on HSG when a signer hat is minted
contract HSGMintHook is IHatMintHook {
  function onHatMinted(uint256 _hatId, address _wearer, bytes calldata _hookData) external returns (bool) {
    // get the HSG instance address from the hookData
    address hsg = abi.decode(_hookData, (address));
    // Claim signer permissions for the wearer
    IHatsSignerGate(hsg).claimSignerFor(_hatId, _wearer);
    return true;
  }
}
