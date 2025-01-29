// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2, Vm } from "forge-std/Test.sol";
import {
  MultiClaimsHatter,
  MultiClaimsHatter_HatNotClaimable,
  MultiClaimsHatter_HatNotClaimableFor,
  MultiClaimsHatter_NotAdminOfHat,
  MultiClaimsHatter_NotExplicitlyEligible
} from "../src/MultiClaimsHatter.sol";
import { IHats, HatsModuleFactory, deployModuleInstance } from "hats-module/utils/DeployFunctions.sol";
import { DeployImplementation } from "../script/MultiClaimsHatter.s.sol";
import { TestEligibilityAlwaysEligible, TestEligibilityAlwaysNotEligible } from "./utils/TestModules.sol";
import { AlwaysSucceedsMintHook, AlwaysFailsMintHook } from "./utils/TestMintHooks.sol";

contract Setup is DeployImplementation, Test {
  uint256 public fork;
  // the block number where hats module factory was deployed on Sepolia
  uint256 public constant BLOCK_NUMBER = 5_516_083;
  IHats public constant HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  HatsModuleFactory public constant FACTORY = HatsModuleFactory(0x0a3f85fa597B6a967271286aA0724811acDF5CD9);

  MultiClaimsHatter public instance;
  uint256 public tophat_x;
  uint256 public hat_x_1; // claims hatter hat
  uint256 public hat_x_1_1; // admined by the claims hatter
  uint256 public hat_x_1_1_1; // admined by the claims hatter
  uint256 public hat_x_1_1_1_1; // admined by the claims hatter
  uint256 public hat_x_2; // not admined by the claims hatter
  address public dao = makeAddr("dao");
  address public wearer = makeAddr("wearer");
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  address public bot = makeAddr("bot");

  uint256[] public inputHats;
  address[] public inputWearers;

  uint256 public saltNonce = 1;
  uint256[] public saltNonces = [1, 2, 3];

  // MultiClaimsHatter events
  event HatsClaimabilitySet(uint256[] hatIds, MultiClaimsHatter.ClaimType[] claimTypes);
  event HatClaimabilitySet(uint256 hatId, MultiClaimsHatter.ClaimType claimType);
  event MintHookSet(uint256 hatId, address mintHook);

  // HatsModuleFactory event
  event HatsModuleFactory_ModuleDeployed(
    address implementation, address instance, uint256 hatId, bytes otherImmutableArgs, bytes initData, uint256 saltNonce
  );

  // Hats mint event
  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);

  function deployInstance(bytes memory initData) public returns (MultiClaimsHatter) {
    // deploy the instance
    vm.prank(dao);
    return MultiClaimsHatter(deployModuleInstance(FACTORY, address(implementation), 0, "", initData, saltNonce));
  }

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("sepolia"), BLOCK_NUMBER);

    // deploy via the script
    DeployImplementation.prepare(false, "test");
    DeployImplementation.run();

    // set up hats
    tophat_x = HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    vm.startPrank(dao);
    hat_x_1 = HATS.createHat(tophat_x, "hat_x_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1");
    hat_x_1_1 = HATS.createHat(hat_x_1, "hat_x_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1");
    hat_x_1_1_1 = HATS.createHat(hat_x_1_1, "hat_x_1_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1_1");
    hat_x_1_1_1_1 = HATS.createHat(hat_x_1_1_1, "hat_x_1_1_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1_1_1");
    hat_x_2 = HATS.createHat(tophat_x, "hat_x_2", 50, eligibility, toggle, true, "dao.eth/hat_x_2");
    vm.stopPrank();
  }
}

/*//////////////////////////////////////////////////////////////
      Scenario 1 - Delpoy Claims Hatter without initial hats
  //////////////////////////////////////////////////////////////*/

contract DeployInstance_WithoutInitialHats is Setup {
  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
    vm.stopPrank();

    //bytes memory initData = initHats ? abi.encode(_hats, _claimTypes) : "";
    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract TestDeployInstance_WithoutInitialHats is DeployInstance_WithoutInitialHats {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableFor() public {
    assertEq(instance.isClaimableFor(hat_x_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_2), false);
    assertEq(instance.isClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableBy() public {
    assertEq(instance.isClaimableBy(hat_x_1_1), false);
    assertEq(instance.isClaimableBy(hat_x_1_1_1), false);
    assertEq(instance.isClaimableBy(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableBy(hat_x_2), false);
    assertEq(instance.isClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_initialization() public {
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("");
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }

  function test_reverts_setHatClaimabilityNotAdmin() public {
    vm.expectRevert();

    vm.prank(wearer);
    instance.setHatClaimability(hat_x_2, MultiClaimsHatter.ClaimType.Claimable);
  }
}

contract AddClaimableHats_WithoutInitialHats is DeployInstance_WithoutInitialHats {
  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(dao);
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);
    instance.setHatClaimability(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);

    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1_1, MultiClaimsHatter.ClaimType.ClaimableFor);
    instance.setHatClaimability(hat_x_1_1_1, MultiClaimsHatter.ClaimType.ClaimableFor);

    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1_1_1, MultiClaimsHatter.ClaimType.Claimable);
    instance.setHatClaimability(hat_x_1_1_1_1, MultiClaimsHatter.ClaimType.Claimable);
    vm.stopPrank();
  }
}

contract TestAddClaimableHats_WithoutInitialHats is AddClaimableHats_WithoutInitialHats {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableFor() public {
    assertEq(instance.isClaimableFor(hat_x_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1), true);
    assertEq(instance.isClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_2), false);
    assertEq(instance.isClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableBy() public {
    assertEq(instance.isClaimableBy(hat_x_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_2), false);
    assertEq(instance.isClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), true);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));
    vm.prank(wearer);
    instance.claimHat(hat_x_2);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));

    inputHats = [hat_x_2];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }
}

contract ClaimHat_WithoutInitialHats is AddClaimableHats_WithoutInitialHats {
  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(wearer);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1, 1);
    instance.claimHat(hat_x_1_1);
    vm.stopPrank();

    vm.startPrank(bot);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1_1, 1);
    instance.claimHatFor(hat_x_1_1_1, wearer);
    vm.stopPrank();
  }
}

contract TestClaimHat_WithoutInitialHats is ClaimHat_WithoutInitialHats {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
  }

  function test_reverts_claimHatNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1_1_1);
  }

  function test_reverts_claimHatsNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );

    inputHats = [hat_x_1_1_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}

/*//////////////////////////////////////////////////////////////
      Scenario 2 - Delpoy Claims Hatter with initial hats
//////////////////////////////////////////////////////////////*/

contract DeployInstance_WithInitialHats is Setup {
  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
    vm.stopPrank();

    uint256[] memory initialHats = new uint256[](3);
    MultiClaimsHatter.ClaimType[] memory initialClaimTypes = new MultiClaimsHatter.ClaimType[](3);
    initialHats[0] = hat_x_1_1;
    initialHats[1] = hat_x_1_1_1;
    initialHats[2] = hat_x_1_1_1_1;
    initialClaimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    initialClaimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    initialClaimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;
    bytes memory initData = abi.encode(initialHats, initialClaimTypes);

    vm.expectEmit();
    emit HatsClaimabilitySet(initialHats, initialClaimTypes);
    instance = MultiClaimsHatter(deployInstance(initData));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract TestDeployInstance_WithInitialHats is DeployInstance_WithInitialHats {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_initialization() public {
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("");
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }

  function test_reverts_setHatClaimabilityNotAdmin() public {
    vm.expectRevert();

    vm.prank(wearer);
    instance.setHatClaimability(hat_x_2, MultiClaimsHatter.ClaimType.Claimable);
  }

  function test_isClaimableFor() public {
    assertEq(instance.isClaimableFor(hat_x_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1), true);
    assertEq(instance.isClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_2), false);
    assertEq(instance.isClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableBy() public {
    assertEq(instance.isClaimableBy(hat_x_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_2), false);
    assertEq(instance.isClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), true);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));
    vm.prank(wearer);
    instance.claimHat(hat_x_2);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));

    inputHats = [hat_x_2];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}

contract ClaimHat_WithInitialHats is DeployInstance_WithInitialHats {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
    vm.prank(bot);
    instance.claimHatFor(hat_x_1_1_1, wearer);
  }
}

contract TestClaimHat_WithInitialHats is ClaimHat_WithInitialHats {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
  }

  function test_reverts_claimHatNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1_1_1);
  }

  function test_reverts_claimHatsNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );

    inputHats = [hat_x_1_1_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}

/*//////////////////////////////////////////////////////////////////////////////
    Scenario 2B - Deploy Claims Hatter with initial hats and mint hooks
////////////////////////////////////////////////////////////////////////////*/

contract DeployInstance_WithInitialHatsAndMintHooks is Setup {
  AlwaysSucceedsMintHook public alwaysSucceedsMintHook;
  AlwaysFailsMintHook public alwaysFailsMintHook;

  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));
    alwaysSucceedsMintHook = new AlwaysSucceedsMintHook();
    alwaysFailsMintHook = new AlwaysFailsMintHook();

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
    vm.stopPrank();

    uint256[] memory initialHats = new uint256[](3);
    MultiClaimsHatter.ClaimType[] memory initialClaimTypes = new MultiClaimsHatter.ClaimType[](3);
    address[] memory initialMintHooks = new address[](3);
    initialHats[0] = hat_x_1_1;
    initialHats[1] = hat_x_1_1_1;
    initialHats[2] = hat_x_1_1_1_1;
    initialClaimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    initialClaimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    initialClaimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;
    initialMintHooks[0] = address(alwaysFailsMintHook);
    initialMintHooks[1] = address(alwaysSucceedsMintHook);
    initialMintHooks[2] = address(0);
    bytes memory initData = abi.encode(initialHats, initialClaimTypes, initialMintHooks);

    vm.expectEmit();
    emit HatsClaimabilitySet(initialHats, initialClaimTypes);
    emit MintHookSet(hat_x_1_1, address(alwaysFailsMintHook));
    emit MintHookSet(hat_x_1_1_1, address(alwaysSucceedsMintHook));
    instance = MultiClaimsHatter(deployInstance(initData));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract TestDeployInstance_WithInitialHatsAndMintHooks is DeployInstance_WithInitialHatsAndMintHooks {
  function test_reverts_initialization() public {
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("");
  }
}

/*//////////////////////////////////////////////////////////////////////////////
    Scenario 3 - Single Batch eligibility creation and hats registration
  ////////////////////////////////////////////////////////////////////////////*/

contract DeployInstance_BatchModuleCreationAndRegistration is Setup {
  function setUp() public virtual override {
    super.setUp();

    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));

    vm.startPrank(dao);
    address predictedNewInatance1 = FACTORY.getHatsModuleAddress(alwaysEligibleModule, 0, "", saltNonce);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysEligibleModule, predictedNewInatance1, 0, "", "", saltNonce);
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);
    address module1 = instance.setHatClaimabilityAndCreateModule(
      FACTORY, alwaysEligibleModule, 0, "", "", saltNonce, hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable
    );

    address predictedNewInatance2 = FACTORY.getHatsModuleAddress(alwaysEligibleModule, 1, "", saltNonce);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysEligibleModule, predictedNewInatance2, 1, "", "", saltNonce);
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1_1, MultiClaimsHatter.ClaimType.ClaimableFor);
    address module2 = instance.setHatClaimabilityAndCreateModule(
      FACTORY, alwaysEligibleModule, 1, "", "", saltNonce, hat_x_1_1_1, MultiClaimsHatter.ClaimType.ClaimableFor
    );

    address predictedNewInatance3 = FACTORY.getHatsModuleAddress(alwaysNotEligibleModule, 2, "", saltNonce);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysNotEligibleModule, predictedNewInatance3, 2, "", "", saltNonce);
    vm.expectEmit();
    emit HatClaimabilitySet(hat_x_1_1_1_1, MultiClaimsHatter.ClaimType.Claimable);
    address module3 = instance.setHatClaimabilityAndCreateModule(
      FACTORY, alwaysNotEligibleModule, 2, "", "", saltNonce, hat_x_1_1_1_1, MultiClaimsHatter.ClaimType.Claimable
    );
    vm.stopPrank();

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, module1);
    HATS.changeHatEligibility(hat_x_1_1_1, module2);
    HATS.changeHatEligibility(hat_x_1_1_1_1, module3);
    HATS.changeHatEligibility(hat_x_2, module1);
    vm.stopPrank();
  }
}

contract TestDeployInstance_BatchModuleCreationAndRegistration is DeployInstance_BatchModuleCreationAndRegistration {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableFor() public {
    assertEq(instance.isClaimableFor(hat_x_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1), true);
    assertEq(instance.isClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_2), false);
    assertEq(instance.isClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableBy() public {
    assertEq(instance.isClaimableBy(hat_x_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_2), false);
    assertEq(instance.isClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), true);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));
    vm.prank(wearer);
    instance.claimHat(hat_x_2);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));

    inputHats = [hat_x_2];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }
}

contract ClaimHat_BatchModuleCreationAndRegistration is DeployInstance_BatchModuleCreationAndRegistration {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
    vm.prank(bot);
    instance.claimHatFor(hat_x_1_1_1, wearer);
  }
}

contract TestClaimHat_BatchModuleCreationAndRegistration is ClaimHat_BatchModuleCreationAndRegistration {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
  }

  function test_reverts_claimHatNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1_1_1);
  }

  function test_reverts_claimHatsNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );

    inputHats = [hat_x_1_1_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}

/*//////////////////////////////////////////////////////////////////////////////
    Scenario 4 - Multi Batch eligibility creation and hats registration
  ////////////////////////////////////////////////////////////////////////////*/

contract DeployInstance_BatchMultiModuleCreationAndRegistration is Setup {
  function setUp() public virtual override {
    super.setUp();

    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));

    // Batch multi modules creation and hats registration
    vm.startPrank(dao);
    address[] memory _implementations = new address[](3);
    _implementations[0] = alwaysEligibleModule;
    _implementations[1] = alwaysEligibleModule;
    _implementations[2] = alwaysNotEligibleModule;
    uint256[] memory _moduleHatIds = new uint256[](3);
    _moduleHatIds[0] = 0;
    _moduleHatIds[1] = 1;
    _moduleHatIds[2] = 2;
    bytes[] memory _otherImmutableArgsArray = new bytes[](3);
    _otherImmutableArgsArray[0] = "";
    _otherImmutableArgsArray[1] = "";
    _otherImmutableArgsArray[2] = "";
    bytes[] memory _initDataArray = new bytes[](3);
    _initDataArray[0] = "";
    _initDataArray[1] = "";
    _initDataArray[2] = "";
    uint256[] memory _hatIds = new uint256[](3);
    _hatIds[0] = hat_x_1_1;
    _hatIds[1] = hat_x_1_1_1;
    _hatIds[2] = hat_x_1_1_1_1;
    MultiClaimsHatter.ClaimType[] memory _claimTypes = new MultiClaimsHatter.ClaimType[](3);
    _claimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    _claimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    _claimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;

    // expected module factory events
    address predictedNewInatance1 = FACTORY.getHatsModuleAddress(alwaysEligibleModule, 0, "", saltNonces[0]);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysEligibleModule, predictedNewInatance1, 0, "", "", saltNonces[0]);
    address predictedNewInatance2 = FACTORY.getHatsModuleAddress(alwaysEligibleModule, 1, "", saltNonces[1]);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysEligibleModule, predictedNewInatance2, 1, "", "", saltNonces[1]);
    address predictedNewInatance3 = FACTORY.getHatsModuleAddress(alwaysNotEligibleModule, 2, "", saltNonces[2]);
    vm.expectEmit();
    emit HatsModuleFactory_ModuleDeployed(alwaysNotEligibleModule, predictedNewInatance3, 2, "", "", saltNonces[2]);

    // expected claims hatter event
    vm.expectEmit();
    emit HatsClaimabilitySet(_hatIds, _claimTypes);
    vm.recordLogs();
    vm.getRecordedLogs();
    instance.setHatsClaimabilityAndCreateModules(
      FACTORY,
      _implementations,
      _moduleHatIds,
      _otherImmutableArgsArray,
      _initDataArray,
      saltNonces,
      _hatIds,
      _claimTypes
    );
    // get created modules addresses
    Vm.Log[] memory entries = vm.getRecordedLogs();
    (, address module1,,,,) = abi.decode(entries[1].data, (address, address, uint256, bytes, bytes, uint256));
    (, address module2,,,,) = abi.decode(entries[3].data, (address, address, uint256, bytes, bytes, uint256));
    (, address module3,,,,) = abi.decode(entries[5].data, (address, address, uint256, bytes, bytes, uint256));

    HATS.changeHatEligibility(hat_x_1_1, module1);
    HATS.changeHatEligibility(hat_x_1_1_1, module2);
    HATS.changeHatEligibility(hat_x_1_1_1_1, module3);
    HATS.changeHatEligibility(hat_x_2, module1);
    vm.stopPrank();
  }
}

contract TestDeployInstance_BatchMultiModuleCreationAndRegistration is
  DeployInstance_BatchMultiModuleCreationAndRegistration
{
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableFor() public {
    assertEq(instance.isClaimableFor(hat_x_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_1_1_1), true);
    assertEq(instance.isClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.isClaimableFor(hat_x_2), false);
    assertEq(instance.isClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_isClaimableBy() public {
    assertEq(instance.isClaimableBy(hat_x_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_1_1_1_1), true);
    assertEq(instance.isClaimableBy(hat_x_2), false);
    assertEq(instance.isClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), true);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));
    vm.prank(wearer);
    instance.claimHat(hat_x_2);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));

    inputHats = [hat_x_2];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }
}

contract ClaimHat_BatchMultiModuleCreationAndRegistration is DeployInstance_BatchMultiModuleCreationAndRegistration {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
    vm.prank(bot);
    instance.claimHatFor(hat_x_1_1_1, wearer);
  }
}

contract TestClaimHat_BatchMultiModuleCreationAndRegistration is ClaimHat_BatchMultiModuleCreationAndRegistration {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
  }

  function test_reverts_claimHatNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1_1_1);
  }

  function test_reverts_claimHatsNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );

    inputHats = [hat_x_1_1_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}

/*//////////////////////////////////////////////////////////////
      Scenario 5 - Multi claiming test 
  //////////////////////////////////////////////////////////////*/

contract DeployInstance_BatchClaimHatsSetup is Setup {
  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysEligibleModule);
    vm.stopPrank();

    uint256[] memory initialHats = new uint256[](3);
    MultiClaimsHatter.ClaimType[] memory initialClaimTypes = new MultiClaimsHatter.ClaimType[](3);
    initialHats[0] = hat_x_1_1;
    initialHats[1] = hat_x_1_1_1;
    initialHats[2] = hat_x_1_1_1_1;
    initialClaimTypes[0] = MultiClaimsHatter.ClaimType.Claimable;
    initialClaimTypes[1] = MultiClaimsHatter.ClaimType.Claimable;
    initialClaimTypes[2] = MultiClaimsHatter.ClaimType.Claimable;
    bytes memory initData = abi.encode(initialHats, initialClaimTypes);

    vm.expectEmit();
    emit HatsClaimabilitySet(initialHats, initialClaimTypes);
    instance = MultiClaimsHatter(deployInstance(initData));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract ClaimHats_BatchClaimHatsSetup is DeployInstance_BatchClaimHatsSetup {
  function setUp() public virtual override {
    super.setUp();

    // prepare hats to claims array
    uint256[] memory hatsToClaim = new uint256[](3);
    hatsToClaim[0] = hat_x_1_1;
    hatsToClaim[1] = hat_x_1_1_1;
    hatsToClaim[2] = hat_x_1_1_1_1;

    // claim all hats
    vm.startPrank(wearer);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1, 1);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1_1, 1);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1_1_1, 1);
    instance.claimHats(hatsToClaim);
    vm.stopPrank();
  }
}

contract TestClaimHat_BatchClaimHatsSetup is ClaimHats_BatchClaimHatsSetup {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1_1), true);
  }
}

/*//////////////////////////////////////////////////////////////
      Scenario 6 - Multi claiming for test 
  //////////////////////////////////////////////////////////////*/

contract DeployInstance_BatchClaimHatsForSetup is Setup {
  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysEligibleModule);
    vm.stopPrank();

    uint256[] memory initialHats = new uint256[](3);
    MultiClaimsHatter.ClaimType[] memory initialClaimTypes = new MultiClaimsHatter.ClaimType[](3);
    initialHats[0] = hat_x_1_1;
    initialHats[1] = hat_x_1_1_1;
    initialHats[2] = hat_x_1_1_1_1;
    initialClaimTypes[0] = MultiClaimsHatter.ClaimType.ClaimableFor;
    initialClaimTypes[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    initialClaimTypes[2] = MultiClaimsHatter.ClaimType.ClaimableFor;
    bytes memory initData = abi.encode(initialHats, initialClaimTypes);

    vm.expectEmit();
    emit HatsClaimabilitySet(initialHats, initialClaimTypes);
    instance = MultiClaimsHatter(deployInstance(initData));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract ClaimHats_BatchClaimHatsForSetup is DeployInstance_BatchClaimHatsForSetup {
  function setUp() public virtual override {
    super.setUp();

    // prepare hats and accounts arrays
    uint256[] memory hatsToClaim = new uint256[](3);
    hatsToClaim[0] = hat_x_1_1;
    hatsToClaim[1] = hat_x_1_1_1;
    hatsToClaim[2] = hat_x_1_1_1_1;
    address[] memory accountsToClaimFor = new address[](3);
    accountsToClaimFor[0] = wearer;
    accountsToClaimFor[1] = wearer;
    accountsToClaimFor[2] = wearer;

    // claim all hats
    vm.startPrank(bot);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1, 1);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1_1, 1);
    vm.expectEmit();
    emit TransferSingle(address(instance), address(0), wearer, hat_x_1_1_1_1, 1);
    instance.claimHatsFor(hatsToClaim, accountsToClaimFor);
    vm.stopPrank();
  }
}

contract TestClaimHat_BatchClaimHatsForSetup is ClaimHats_BatchClaimHatsForSetup {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1_1), true);
  }
}
