// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHatMintHook {
  function onHatMinted(uint256 hatId, address wearer, bytes calldata hookData) external returns (bool success);
}
