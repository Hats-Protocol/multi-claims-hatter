// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { MultiClaimsHatter } from "./MultiClaimsHatter.sol";

contract MultiClaimsHatterFactory {
  // should the version be higher here
  string public constant VERSION = "0.6.0-zksync";

  event ModuleDeployed(
    address implementation, address instance, uint256 hatId, bytes otherImmutableArgs, bytes initData, uint256 saltNonce
  );

  function deployMultiClaimsHatter(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce)
    external
    returns (address)
  {
    bytes memory args = abi.encodePacked(_hatId, _hat, _initData);
    bytes32 salt = _calculateSalt(args, _saltNonce);
    // TODO: Test situate where contract exitsts
    MultiClaimsHatter instance = new MultiClaimsHatter{ salt: salt }(VERSION, _hat, _hatId);
    instance.setUp(_initData);
    emit ModuleDeployed(
      address(instance), address(instance), _hatId, abi.encodePacked(_hat, _initData), _initData, _saltNonce
    );
    return address(instance);
  }

  function _calculateSalt(bytes memory _args, uint256 _saltNonce) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(_args, block.chainid, _saltNonce));
  }

  function _getAddress(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce)
    internal
    returns (address addr)
  {
    bytes memory args = abi.encodePacked(_hatId, _hat, _initData);
    bytes32 salt = _calculateSalt(args, _saltNonce);
    bytes memory bytecode = type(MultiClaimsHatter).creationCode;
    assembly {
      addr := create2(0, add(bytecode, 32), mload(bytecode), salt)
    }
  }
}
