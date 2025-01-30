// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import {
  MultiClaimsHatter,
  MultiClaimsHatter_ArrayLengthMismatch,
  MultiClaimsHatter_NotAdminOfHat,
  MultiClaimsHatter_NotExplicitlyEligible,
  MultiClaimsHatter_MintHookFailed,
  MultiClaimsHatter_HatNotClaimable,
  MultiClaimsHatter_HatNotClaimableFor
} from "../src/MultiClaimsHatter.sol";
import { Setup } from "./MultiClaimsHatter.t.sol";
import { AlwaysSucceedsMintHook, AlwaysFailsMintHook } from "./utils/TestMintHooks.sol";
import { TestEligibilityAlwaysEligible, TestEligibilityAlwaysNotEligible } from "./utils/TestModules.sol";

contract MintHooksTest is Setup {
  AlwaysSucceedsMintHook public successHook;
  AlwaysFailsMintHook public failHook;
  TestEligibilityAlwaysEligible public alwaysEligible;
  TestEligibilityAlwaysNotEligible public alwaysNotEligible;

  function setUp() public virtual override {
    super.setUp();
    successHook = new AlwaysSucceedsMintHook();
    failHook = new AlwaysFailsMintHook();
    alwaysEligible = new TestEligibilityAlwaysEligible("test");
    alwaysNotEligible = new TestEligibilityAlwaysNotEligible("test");

    // Deploy instance and give it admin hat
    instance = MultiClaimsHatter(deployInstance(""));
    vm.startPrank(dao);
    HATS.mintHat(hat_x_1, address(instance));
    HATS.changeHatEligibility(hat_x_1_1, address(alwaysEligible));
    HATS.changeHatEligibility(hat_x_1_1_1, address(alwaysEligible));
    HATS.changeHatEligibility(hat_x_1_1_1_1, address(alwaysNotEligible));
    vm.stopPrank();

    // deploy the test modules
    alwaysEligible = new TestEligibilityAlwaysEligible("test");
    alwaysNotEligible = new TestEligibilityAlwaysNotEligible("test");
  }
}

contract TestSetMintHook is MintHooksTest {
  function test_setMintHook() public {
    vm.prank(dao);
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1, address(successHook));
    instance.setMintHook(hat_x_1_1, address(successHook));

    assertEq(instance.hatToMintHook(hat_x_1_1), address(successHook));
  }

  function test_reverts_setMintHook_notAdmin() public {
    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setMintHook(hat_x_1_1, address(successHook));
  }
}

contract TestSetMintHooks is MintHooksTest {
  function test_setMintHooks() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    address[] memory hooks = new address[](3);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);
    hooks[2] = address(successHook);

    vm.prank(dao);
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1, address(successHook));
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1_1, address(failHook));
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1_1_1, address(successHook));
    instance.setMintHooks(hatIds, hooks);

    assertEq(instance.hatToMintHook(hat_x_1_1), address(successHook));
    assertEq(instance.hatToMintHook(hat_x_1_1_1), address(failHook));
    assertEq(instance.hatToMintHook(hat_x_1_1_1_1), address(successHook));
  }

  function test_reverts_setMintHooks_arrayLengthMismatch() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    address[] memory hooks = new address[](2);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);

    vm.prank(dao);
    vm.expectRevert(MultiClaimsHatter_ArrayLengthMismatch.selector);
    instance.setMintHooks(hatIds, hooks);
  }

  function test_reverts_setMintHooks_notAdmin() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    address[] memory hooks = new address[](3);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);
    hooks[2] = address(successHook);

    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setMintHooks(hatIds, hooks);
  }
}

contract TestSetHatClaimabilityAndMintHook is MintHooksTest {
  function test_setHatClaimabilityAndMintHook() public {
    vm.prank(dao);
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1, address(successHook));
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);
    instance.setHatClaimabilityAndMintHook(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable, address(successHook));

    assertEq(uint8(instance.hatToClaimType(hat_x_1_1)), uint8(MultiClaimsHatter.ClaimType.Claimable));
    assertEq(instance.hatToMintHook(hat_x_1_1), address(successHook));
  }

  function test_reverts_setHatClaimabilityAndMintHook_notAdmin() public {
    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setHatClaimabilityAndMintHook(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable, address(successHook));
  }
}

contract TestSetHatsClaimabilityAndMintHooks is MintHooksTest {
  function test_setHatsClaimabilityAndMintHooks() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    MultiClaimsHatter.ClaimType[] memory claimTypes = new MultiClaimsHatter.ClaimType[](3);
    claimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    claimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    claimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;

    address[] memory hooks = new address[](3);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);
    hooks[2] = address(successHook);

    vm.prank(dao);
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1, address(successHook));
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1_1, address(failHook));
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1_1_1, address(successHook));
    vm.expectEmit();
    emit HatsClaimabilitySet(hatIds, claimTypes);
    instance.setHatsClaimabilityAndMintHooks(hatIds, claimTypes, hooks);

    assertEq(uint8(instance.hatToClaimType(hat_x_1_1)), uint8(MultiClaimsHatter.ClaimType.Claimable));
    assertEq(uint8(instance.hatToClaimType(hat_x_1_1_1)), uint8(MultiClaimsHatter.ClaimType.ClaimableFor));
    assertEq(uint8(instance.hatToClaimType(hat_x_1_1_1_1)), uint8(MultiClaimsHatter.ClaimType.Claimable));
    assertEq(instance.hatToMintHook(hat_x_1_1), address(successHook));
    assertEq(instance.hatToMintHook(hat_x_1_1_1), address(failHook));
    assertEq(instance.hatToMintHook(hat_x_1_1_1_1), address(successHook));
  }

  function test_reverts_setHatsClaimabilityAndMintHooks_arrayLengthMismatch() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    MultiClaimsHatter.ClaimType[] memory claimTypes = new MultiClaimsHatter.ClaimType[](3);
    claimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    claimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    claimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;

    address[] memory hooks = new address[](2);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);

    vm.prank(dao);
    vm.expectRevert(MultiClaimsHatter_ArrayLengthMismatch.selector);
    instance.setHatsClaimabilityAndMintHooks(hatIds, claimTypes, hooks);
  }

  function test_reverts_setHatsClaimabilityAndMintHooks_notAdmin() public {
    uint256[] memory hatIds = new uint256[](3);
    hatIds[0] = hat_x_1_1;
    hatIds[1] = hat_x_1_1_1;
    hatIds[2] = hat_x_1_1_1_1;

    MultiClaimsHatter.ClaimType[] memory claimTypes = new MultiClaimsHatter.ClaimType[](3);
    claimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    claimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    claimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;

    address[] memory hooks = new address[](3);
    hooks[0] = address(successHook);
    hooks[1] = address(failHook);
    hooks[2] = address(successHook);

    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setHatsClaimabilityAndMintHooks(hatIds, claimTypes, hooks);
  }
}

contract TestSetHatClaimabilityAndMintHookAndCreateModule is MintHooksTest {
  function test_setHatClaimabilityAndMintHookAndCreateModule() public {
    uint256 moduleHatId = hat_x_1_1;
    bytes memory otherImmutableArgs = "";
    bytes memory initData = "";
    uint256 saltNonce = 0;

    address expectedModuleAddress =
      FACTORY.getHatsModuleAddress(address(alwaysEligible), moduleHatId, otherImmutableArgs, saltNonce);

    vm.prank(dao);
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);
    vm.expectEmit();
    emit MintHookSet(hat_x_1_1, address(successHook));
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(
      address(alwaysEligible), expectedModuleAddress, moduleHatId, otherImmutableArgs, initData, saltNonce
    );
    address moduleInstance = instance.setHatClaimabilityAndMintHookAndCreateModule(
      FACTORY,
      address(alwaysEligible),
      moduleHatId,
      otherImmutableArgs,
      initData,
      saltNonce,
      hat_x_1_1,
      MultiClaimsHatter.ClaimType.Claimable,
      address(successHook)
    );

    assertEq(uint8(instance.hatToClaimType(hat_x_1_1)), uint8(MultiClaimsHatter.ClaimType.Claimable));
    assertEq(instance.hatToMintHook(hat_x_1_1), address(successHook));
    assertTrue(moduleInstance != address(0));
    assertEq(moduleInstance, expectedModuleAddress);
    assertEq(MultiClaimsHatter(moduleInstance).hatId(), moduleHatId);
    assertEq(address(MultiClaimsHatter(moduleInstance).HATS()), address(HATS));
  }

  function test_reverts_setHatClaimabilityAndMintHookAndCreateModule_notAdmin() public {
    uint256 moduleHatId = hat_x_1_1;
    bytes memory otherImmutableArgs = "";
    bytes memory initData = "";
    uint256 saltNonce = 0;

    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setHatClaimabilityAndMintHookAndCreateModule(
      FACTORY,
      address(alwaysEligible),
      moduleHatId,
      otherImmutableArgs,
      initData,
      saltNonce,
      hat_x_1_1,
      MultiClaimsHatter.ClaimType.Claimable,
      address(successHook)
    );
  }
}

contract TestSetHatsClaimabilityAndMintHooksAndCreateModules is MintHooksTest {
  struct TestData {
    address[] moduleImplementations;
    uint256[] hatIds;
    MultiClaimsHatter.ClaimType[] claimTypes;
    address[] hooks;
    uint256[] moduleHatIds;
    bytes[] otherImmutableArgs;
    bytes[] initData;
    uint256[] saltNonces;
    address[] expectedModuleAddresses;
  }

  function _setupTestData() internal view returns (TestData memory data) {
    data.moduleImplementations = new address[](3);
    data.moduleImplementations[0] = address(alwaysEligible);
    data.moduleImplementations[1] = address(alwaysEligible);
    data.moduleImplementations[2] = address(alwaysEligible);

    data.hatIds = new uint256[](3);
    data.hatIds[0] = hat_x_1_1;
    data.hatIds[1] = hat_x_1_1_1;
    data.hatIds[2] = hat_x_1_1_1_1;

    data.claimTypes = new MultiClaimsHatter.ClaimType[](3);
    data.claimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    data.claimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    data.claimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;

    data.hooks = new address[](3);
    data.hooks[0] = address(successHook);
    data.hooks[1] = address(failHook);
    data.hooks[2] = address(successHook);

    data.moduleHatIds = new uint256[](3);
    data.moduleHatIds[0] = hat_x_1_1;
    data.moduleHatIds[1] = hat_x_1_1_1;
    data.moduleHatIds[2] = hat_x_1_1_1_1;

    data.otherImmutableArgs = new bytes[](3);
    data.otherImmutableArgs[0] = "";
    data.otherImmutableArgs[1] = "";
    data.otherImmutableArgs[2] = "";

    data.initData = new bytes[](3);
    data.initData[0] = "";
    data.initData[1] = "";
    data.initData[2] = "";

    data.saltNonces = new uint256[](3);
    data.saltNonces[0] = 0;
    data.saltNonces[1] = 1;
    data.saltNonces[2] = 2;

    data.expectedModuleAddresses = new address[](3);
    for (uint256 i = 0; i < 3; i++) {
      data.expectedModuleAddresses[i] = FACTORY.getHatsModuleAddress(
        data.moduleImplementations[i], data.moduleHatIds[i], data.otherImmutableArgs[i], data.saltNonces[i]
      );
    }
  }

  function test_setHatsClaimabilityAndMintHooksAndCreateModules() public {
    TestData memory data = _setupTestData();

    vm.prank(dao);
    for (uint256 i = 0; i < 3; i++) {
      vm.expectEmit();
      emit MintHookSet(data.hatIds[i], data.hooks[i]);
    }
    vm.expectEmit();
    emit HatsClaimabilitySet(data.hatIds, data.claimTypes);
    for (uint256 i = 0; i < 3; i++) {
      vm.expectEmit();
      emit HatsModuleFactory_ModuleDeployed(
        data.moduleImplementations[i],
        data.expectedModuleAddresses[i],
        data.moduleHatIds[i],
        data.otherImmutableArgs[i],
        data.initData[i],
        data.saltNonces[i]
      );
    }
    bool success = instance.setHatsClaimabilityAndMintHooksAndCreateModules(
      FACTORY,
      data.moduleImplementations,
      data.moduleHatIds,
      data.otherImmutableArgs,
      data.initData,
      data.saltNonces,
      data.hatIds,
      data.claimTypes,
      data.hooks
    );

    assertTrue(success);
    for (uint256 i = 0; i < 3; i++) {
      assertEq(uint8(instance.hatToClaimType(data.hatIds[i])), uint8(data.claimTypes[i]));
      assertEq(instance.hatToMintHook(data.hatIds[i]), data.hooks[i]);
      assertEq(MultiClaimsHatter(payable(data.expectedModuleAddresses[i])).hatId(), data.moduleHatIds[i]);
      assertEq(address(MultiClaimsHatter(payable(data.expectedModuleAddresses[i])).HATS()), address(HATS));
    }
  }

  function test_reverts_setHatsClaimabilityAndMintHooksAndCreateModules_arrayLengthMismatch() public {
    TestData memory data = _setupTestData();

    // Create a shorter hooks array to trigger the mismatch
    address[] memory shortHooks = new address[](2);
    shortHooks[0] = address(successHook);
    shortHooks[1] = address(failHook);

    vm.prank(dao);
    vm.expectRevert(MultiClaimsHatter_ArrayLengthMismatch.selector);
    instance.setHatsClaimabilityAndMintHooksAndCreateModules(
      FACTORY,
      data.moduleImplementations,
      data.moduleHatIds,
      data.otherImmutableArgs,
      data.initData,
      data.saltNonces,
      data.hatIds,
      data.claimTypes,
      shortHooks
    );
  }

  function test_reverts_setHatsClaimabilityAndMintHooksAndCreateModules_notAdmin() public {
    TestData memory data = _setupTestData();

    vm.prank(wearer);
    vm.expectRevert(abi.encodeWithSelector(MultiClaimsHatter_NotAdminOfHat.selector, wearer, hat_x_1_1));
    instance.setHatsClaimabilityAndMintHooksAndCreateModules(
      FACTORY,
      data.moduleImplementations,
      data.moduleHatIds,
      data.otherImmutableArgs,
      data.initData,
      data.saltNonces,
      data.hatIds,
      data.claimTypes,
      data.hooks
    );
  }
}
