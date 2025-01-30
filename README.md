# MultiClaimsHatter

A Hats Protocol hatter contract enabling explicitly eligible wearers to claim a hat.

## Overview & Usage

In [Hats Protocol](https://github.com/hats-protocol/hats-protocol), hats are typically issued by admins minting them to wearers. While often that is the desired behavior, there are cases where it is desirable to allow wearers to claim a hat themselves, assuming they are eligible to wear them. MultiClaimsHatter enables DAOs to optionally make hats claimable by eligible wearers.

### Prerequisites

A MultiClaimsHatter instance can make multiple hats claimable. To do so, it has to be an admin of each of the hats. Thus, a claimable hat must have an admin hat that is worn by a MultiClaimsHatter instance.
One common option is creating a designated hat for the MultiClaimsHatter. Once the MultiClaimsHatter instance wears this hat, it can set any hats that are under its branch as claimable.

For example, if in normal operations a hat tree would look like this...

```lua
   +-------------+
   | 1) Top Hat  |
   +-------------+
        |
   +---------------+
   | 1.1) Role Hat |
   +---------------+
```

... then to make the Role Hat claimable, another hat needs to exist in between:

```lua
   +-------------+
   | 1) Top Hat  |
   +-------------+
        |
   +-----------------+
   | 1.1) Hatter Hat |
   +-----------------+
        |
   +---------------+
   | 1.2) Role Hat |
   +---------------+
```

Second, each of the claimable hats must have a [mechanistic eligibility module](https://github.com/Hats-Protocol/hats-protocol/#eligibility), i.e. one that implements the [IHatsEligibility](https://github.com/Hats-Protocol/hats-protocol/blob/main/src/Interfaces/IHatsEligibility.sol) interface. Only such modules can create the required "explicit eligibility".

### Creating a new MultiClaimsHatter instance

New instances of MultiClaimsHatter are deployed via the [HatsModuleFactory](https://github.com/Hats-Protocol/hats-module/blob/main/src/HatsModuleFactory.sol), by using the `createHatsModule` function.
HatsModuleFactory is a clone factory that enables cheap creation of new module instances.

The MultiClaimsHatter instance can be optionally created with initial claimable hats, by using the `_initData` parameter:

```solidity
bytes memory _initData = abi.encode(initialHats, initialClaimTypes);
```

Note that MultiClaimsHatter doesn't use additional immutable arguments and so the `_otherImmutableArgs` parameter for the `createHatsModule` function should be empty.

### Mint or transfer an admin hat of the claimable hats to the MultiClaimsHatter instance

MultiClaimsHatter is a "hatter" contract, which is a type of contract designed to wear an admin hat. When wearing an admin hat (such as the "Hatter Hat" in the second diagram above), it gains admin authorities over the child hat(s) below it (such as the "Role Hat"). In MultiClaimsHatter's case, this includes the ability to mint those hat(s).

To enable MultiClaimsHatter to mint hats, it must be wearing an admin hat of the hat/s to claim. This can be done by minting (or transferring, as relevant) the admin hat to the MultiClaimsHatter instance.

### Making hats claimable

Once the MultiClaimsHatter instance is setup and wears a proper admin hat, it can make any hats that it admins claimable. To do so, the following functions can be used:

- `setHatClaimability` is used in order to make a signle hat claimable
- `setHatsClaimability` is used in order to make multiple hats claimable in one transaction
- `setHatClaimabilityAndCreateModule` is used in order to make a hat claimable and deploy a new eligibility module in one transaction
- `setHatsClaimabilityAndCreateModules` is used in order to make multiple hats claimable and deploy new eligibility modules in one transaction

### Claiming

Once a hat is made claimable, explicitly eligible wearers can now claim the hat! They can do this simply by calling the `claimHat` or `claimHats` functions with the desired hat/s as an argument.

### Claiming on behalf of a wearer

In some cases, it may be desirable to allow a third party — such as a bot network — to claim a hat on behalf of a wearer. DAOs can optionally enable "claiming for" by setting the claimability type of hats as `ClaimType.ClaimableFor`.

Once set, anybody can then claim on behalf of eligible wearer/s by calling the `claimHatFor` or `claimHatsFor` functions, with the desired wearer/s and hat/s as arguments.

### Hooks

MultiClaimsHatter supports optional mint hooks for claimable hats. These hooks are called when a hat is claimed, and can be used to bundle additional logic with the claim.

A mint hook is a contract that implements the [IHatMintHook](../src/Interfaces/IHatMintHook.sol) interface:

```solidity
interface IHatMintHook {
  function onHatMinted(uint256 _hatId, address _wearer, bytes calldata _hookData) external returns (bool success);
}
```

The `onHatMinted` function is called when a hat is claimed, and executes the logic of the hook. It returns a boolean indicating whether the hook was successful. If the hook fails, the claim will revert.

## Development

This repo uses Foundry for development and testing. To get started:

1. Fork the project
2. Install [Foundry](https://book.getfoundry.sh/getting-started/installation)
3. To compile the contracts, run `forge build`
4. To test, run `forge test`
