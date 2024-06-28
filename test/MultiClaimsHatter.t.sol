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
import {IHats} from "hats-module/interfaces/IHatsModule.sol";
import {Hats} from "hats-protocol/Hats.sol";
import { DeployImplementation } from "../script/MultiClaimsHatter.s.sol";
import { TestEligibilityAlwaysEligible, TestEligibilityAlwaysNotEligible } from "./utils/TestModules.sol";
import { MultiClaimsHatterFactory} from "src/MultiClaimsHatterFactory.sol";

contract Setup is DeployImplementation, Test {
  uint256 public fork;
  // the block number where hats module factory was deployed on Sepolia
  uint256 public constant BLOCK_NUMBER = 5_516_083;
  // Deploy hats
  string internal constant x = "Hats Protocol v1";
  string internal constant y = "";
  IHats public HATS = new Hats{salt: bytes32(abi.encode(0x4a75))}(x, y); // v1.hatsprotocol.eth

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

  // HatsModuleFactory event
  event HatsModuleFactory_ModuleDeployed(
    address implementation, address instance, uint256 hatId, bytes otherImmutableArgs, bytes initData, uint256 saltNonce
  );

  // Hats mint event
  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);

  function deployInstance(bytes memory initData) public returns (MultiClaimsHatter) {
    MultiClaimsHatterFactory factory = new MultiClaimsHatterFactory();
    // deploy the instance
    vm.prank(dao);
    return MultiClaimsHatter(factory.deployMultiClaimsHatter(0, address(HATS), initData, saltNonce));
  }

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER

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

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test", address(0), 0));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test", address(0), 0));

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

  // Returns nothing
  // function test_reverts_initialization() public {
  //   vm.expectRevert("Initializable: contract is already initialized");
  //   instance.setUp("");
  // }

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

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test",  address(0), 0));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test",  address(0), 0));

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

  // function test_reverts_initialization() public {
  //   vm.expectRevert("Initializable: contract is already initialized");
  //   instance.setUp("");
  // }

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
// 
// /*//////////////////////////////////////////////////////////////////////////////
//     Scenario 3 - Single Batch eligibility creation and hats registration
//   ////////////////////////////////////////////////////////////////////////////*/
// 
contract DeployInstance_BatchModuleCreationAndRegistration is Setup {
  function getHatsModuleAddress(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce) internal returns (address addr) {
    bytes memory args = abi.encodePacked(_hatId, _hat, _initData);
    bytes32 salt = keccak256(abi.encodePacked(args, block.chainid, _saltNonce));
    bytes memory bytecode = type(MultiClaimsHatter).creationCode;
    assembly {
      addr := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }

  }
  function setUp() public virtual override {
    super.setUp();

    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test", address(0), 0));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test", address(0), 0));

    vm.startPrank(dao);
	uint256[] memory myArray = new uint256[](4);
	myArray[0] = hat_x_1_1;
    myArray[1] =  hat_x_1_1_1;
    myArray[2] =  hat_x_1_1_1_1;
    myArray[3] =  hat_x_2;

	MultiClaimsHatter.ClaimType[] memory myArray1 = new MultiClaimsHatter.ClaimType[](4);
	myArray1[0] = MultiClaimsHatter.ClaimType.Claimable;
    myArray1[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    myArray1[2] = MultiClaimsHatter.ClaimType.Claimable;
    myArray1[3] = MultiClaimsHatter.ClaimType.NotClaimable;


	instance.setHatsClaimability(myArray, myArray1);
    vm.stopPrank();

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
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

// /*//////////////////////////////////////////////////////////////////////////////
//     Scenario 4 - Multi Batch eligibility creation and hats registration
//   ////////////////////////////////////////////////////////////////////////////*/
// 
contract DeployInstance_BatchMultiModuleCreationAndRegistration is Setup {
  function setUp() public virtual override {
    super.setUp();

    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test", address(0), 0));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test", address(0), 0));

    // Batch multi modules creation and hats registration
    vm.startPrank(dao);
	uint256[] memory myArray = new uint256[](4);
	myArray[0] = hat_x_1_1;
    myArray[1] =  hat_x_1_1_1;
    myArray[2] =  hat_x_1_1_1_1;
    myArray[3] =  hat_x_2;

	MultiClaimsHatter.ClaimType[] memory myArray1 = new MultiClaimsHatter.ClaimType[](4);
	myArray1[0] = MultiClaimsHatter.ClaimType.Claimable;
    myArray1[1] = MultiClaimsHatter.ClaimType.ClaimableFor;
    myArray1[2] = MultiClaimsHatter.ClaimType.Claimable;
    myArray1[3] = MultiClaimsHatter.ClaimType.NotClaimable;


	instance.setHatsClaimability(myArray, myArray1);


    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1,  alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
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

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test", address(0), 0));

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
// 
// /*//////////////////////////////////////////////////////////////
//       Scenario 6 - Multi claiming for test 
//   //////////////////////////////////////////////////////////////*/
// 
contract DeployInstance_BatchClaimHatsForSetup is Setup {
  function setUp() public virtual override {
    super.setUp();

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test",  address(0), 0));

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
