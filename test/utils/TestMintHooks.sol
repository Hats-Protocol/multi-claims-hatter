// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import { console2 } from "forge-std/Test.sol";
import { IHatMintHook } from "../../src/interfaces/IHatMintHook.sol";

contract AlwaysSucceedsMintHook is IHatMintHook {
  mapping(bytes32 hookHash => bool success) public hookResults;

  function onHatMinted(uint256 _hatId, address _wearer, bytes calldata _hookData) external returns (bool success) {
    hookResults[keccak256(abi.encode(_hatId, _wearer, _hookData))] = true;
    return true;
  }
}

contract AlwaysFailsMintHook is IHatMintHook {
  mapping(bytes32 hookHash => bool success) public hookResults;
  function onHatMinted(uint256, /* hatId */ address, /* to */ bytes calldata /* hookData */ )
    external
    pure
    returns (bool success)
  {
    return false;
  }
}
