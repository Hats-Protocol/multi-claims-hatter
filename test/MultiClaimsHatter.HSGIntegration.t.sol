// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { MultiClaimsHatter } from "../src/MultiClaimsHatter.sol";
import { DeployInstance_WithoutInitialHats } from "./MultiClaimsHatter.t.sol";
import { ModuleProxyFactory } from "../lib/hats-zodiac/lib/zodiac/contracts/factory/ModuleProxyFactory.sol";
import { HSGMintHook, IHatsSignerGate } from "./utils/HSGMintHook.sol";
import { ISafe } from "../lib/hats-zodiac/src/HatsSignerGate.sol";

contract HSGIntegrationTest is DeployInstance_WithoutInitialHats {
  IHatsSignerGate public hsg;
  HSGMintHook public mintHook;
  ISafe public safe;
  uint256 public signerHat;

  // HSG events
  event HSGInitialized(
    address safe, uint256 ownerHat, uint256[] validSignerHats, IHatsSignerGate.ThresholdConfig config
  );

  function setUp() public override {
    // Set up base test state from parent
    super.setUp();

    // set up HSG factory and implementation
    address ZODIAC_FACTORY = 0x000000000000aDdB49795b0f9bA5BC298cDda236;
    address HSG_IMPLEMENTATION = 0x148057884AC910Bdd93693F230C5c35a8c47CA3b;

    // signer hat is a child of the hat that MCH wears
    signerHat = hat_x_1_1;

    // Set up HSG init params
    uint256[] memory validSignerHats = new uint256[](1);
    validSignerHats[0] = signerHat;

    IHatsSignerGate.ThresholdConfig memory config = IHatsSignerGate.ThresholdConfig({
      thresholdType: IHatsSignerGate.TargetThresholdType.ABSOLUTE,
      min: 1,
      target: 2
    });

    IHatsSignerGate.SetupParams memory setupParams = IHatsSignerGate.SetupParams({
      ownerHat: tophat_x,
      signerHats: validSignerHats,
      safe: address(0), // Deploy new Safe
      thresholdConfig: config,
      locked: false,
      claimableFor: true,
      implementation: HSG_IMPLEMENTATION,
      hsgGuard: address(0),
      hsgModules: new address[](0)
    });

    bytes memory initData = abi.encode(setupParams);

    // Deploy HSG instance
    hsg = IHatsSignerGate(
      ModuleProxyFactory(ZODIAC_FACTORY).deployModule(
        HSG_IMPLEMENTATION, abi.encodeWithSignature("setUp(bytes)", initData), 1
      )
    );
    safe = hsg.safe();

    // Deploy mint hook
    mintHook = new HSGMintHook();

    // Configure MCH instance with claimability and hook
    vm.prank(dao);
    instance.setHatClaimabilityAndMintHook(signerHat, MultiClaimsHatter.ClaimType.ClaimableFor, address(mintHook));
  }

  function test_fullFlow() public {
    // Verify initial state
    assertFalse(HATS.isWearerOfHat(wearer, signerHat));
    assertFalse(hsg.isValidSigner(wearer));
    assertFalse(safe.isOwner(wearer));

    // Claim signer hat as wearer, with the hook
    vm.prank(wearer);
    instance.claimHatWithHook(signerHat, abi.encode(address(hsg)));

    // Verify final state
    assertTrue(HATS.isWearerOfHat(wearer, signerHat));
    assertTrue(hsg.isValidSigner(wearer));
    assertTrue(safe.isOwner(wearer));
  }
}
