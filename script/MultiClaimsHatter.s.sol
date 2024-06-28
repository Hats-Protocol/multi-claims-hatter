// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { MultiClaimsHatter } from "../src/MultiClaimsHatter.sol";
// import { HatsModuleFactory } from "hats-module/HatsModuleFactory.sol";

contract DeployInstance is Script {
  address public implementation = 0xB985eA1be961f7c4A4C45504444C02c88c4fdEF9;
  address public instance;
  // HatsModuleFactory public factory = HatsModuleFactory(0xfE661c01891172046feE16D3a57c3Cf456729efA);
  bytes32 public SALT = bytes32(abi.encode(0x4a75));
  uint256 public SALT_NONCE = 1;

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function createInitData() public pure returns (bytes memory) {
    uint256 claimableHat1 = 26_960_769_425_706_497_914_046_077_453_500_346_168_786_499_100_899_720_886_694_455_541_760;
    uint256 claimableHat2 = 26_960_769_425_706_689_475_988_685_689_607_640_962_164_892_889_547_673_229_084_728_492_032;
    uint256[] memory hatIds = new uint256[](2);
    hatIds[0] = claimableHat1;
    hatIds[1] = claimableHat2;

    MultiClaimsHatter.ClaimType claimType = MultiClaimsHatter.ClaimType.Claimable;
    MultiClaimsHatter.ClaimType[] memory claimTypes = new MultiClaimsHatter.ClaimType[](2);
    claimTypes[0] = claimType;
    claimTypes[1] = claimType;

    return abi.encode(hatIds, claimTypes);
  }

  function run() public virtual {
    vm.startBroadcast(deployer());

    // instance = factory.createHatsModule(
    //   implementation,
    //   26_960_769_425_706_402_133_074_773_335_446_698_772_097_302_206_575_744_715_499_319_066_624,
    //   abi.encodePacked(),
    //   createInitData(),
    //   SALT_NONCE
    // );

    vm.stopBroadcast();

    console2.log("Deployed instance at:", instance);
  }
}

contract DeployImplementation is Script {
  MultiClaimsHatter public implementation;
  bytes32 public SALT = bytes32(abi.encode(0x4a75));

  // default values
  bool internal _verbose = true;
  string internal _version = "0.2.0"; // increment this with each new deployment

  /// @dev Override default values, if desired
  function prepare(bool verbose, string memory version) public {
    _verbose = verbose;
    _version = version;
  }

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function _log(string memory prefix) internal view {
    if (_verbose) {
      console2.log(string.concat(prefix, "Module:"), address(implementation));
    }
  }

  /// @dev Deploy the contract to a deterministic address via forge's create2 deployer factory.
  function run() public virtual {
    vm.startBroadcast(deployer());

    /**
     * @dev Deploy the contract to a deterministic address via forge's create2 deployer factory, which is at this
     * address on all chains: `0x4e59b44847b379578588920cA78FbF26c0B4956C`.
     * The resulting deployment address is determined by only two factors:
     *    1. The bytecode hash of the contract to deploy. Setting `bytecode_hash` to "none" in foundry.toml ensures
     *  that
     *       never differs regardless of where its being compiled
     *    2. The provided salt, `SALT`
     */
    // implementation = new MultiClaimsHatter{ salt: SALT }(_version /* insert constructor args here */ );

    vm.stopBroadcast();

    _log("");
  }
}

/// @dev Deploy pre-compiled ir-optimized bytecode to a non-deterministic address
contract DeployPrecompiled is DeployImplementation {
  /// @dev Update SALT and default values in Deploy contract

  function run() public override {
    vm.startBroadcast(deployer());

    bytes memory args = abi.encode( /* insert constructor args here */ );

    /// @dev Load and deploy pre-compiled ir-optimized bytecode.
    implementation = MultiClaimsHatter(deployCode("optimized-out/MultiClaimsHatter.sol/MultiClaimsHatter.json", args));

    vm.stopBroadcast();

    _log("Precompiled ");
  }
}

/* FORGE CLI COMMANDS

## A. Simulate the deployment locally
forge script script/MultiClaimsHatter.s.sol:DeployImplementation -f mainnet

## B. Deploy to real network and verify on etherscan
forge script script/MultiClaimsHatter.s.sol -f mainnet --broadcast --verify

## C. Fix verification issues (replace values in curly braces with the actual values)
forge verify-contract --chain-id 1 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode \
 "constructor({args})" "{arg1}" "{arg2}" "{argN}" ) \ 
 --compiler-version v0.8.19 {deploymentAddress} \
 src/{Counter}.sol:{Counter} --etherscan-api-key $ETHERSCAN_KEY

## D. To verify ir-optimized contracts on etherscan...
  1. Run (C) with the following additional flag: `--show-standard-json-input > etherscan.json`
  2. Patch `etherscan.json`: `"optimizer":{"enabled":true,"runs":100}` =>
`"optimizer":{"enabled":true,"runs":100},"viaIR":true`
  3. Upload the patched `etherscan.json` to etherscan manually

  See this github issue for more: https://github.com/foundry-rs/foundry/issues/3507#issuecomment-1465382107

*/
