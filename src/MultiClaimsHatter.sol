// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { HatsModule } from "hats-module/HatsModule.sol";
import { HatsModuleFactory } from "hats-module/HatsModuleFactory.sol";
import { IHatMintHook } from "./interfaces/IHatMintHook.sol";

/*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

/// @notice Thrown if the given array parameters are not of equal length
error MultiClaimsHatter_ArrayLengthMismatch();
/// @notice Thrown if the calling account is not an admin of the hat
error MultiClaimsHatter_NotAdminOfHat(address account, uint256 hatId);
/// @notice Thrown if the account is not explicitly eligible for the hat
error MultiClaimsHatter_NotExplicitlyEligible(address account, uint256 hatId);
/// @notice Thrown if the hat is not claimable
error MultiClaimsHatter_HatNotClaimable(uint256 hatId);
/// @notice Thrown if the hat is not claimable on behalf of accounts
error MultiClaimsHatter_HatNotClaimableFor(uint256 hatId);
/// @notice Thrown if the mint hook failed
error MultiClaimsHatter_MintHookFailed(uint256 hatId);

contract MultiClaimsHatter is HatsModule {
  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when the claimability of multiple hats was edited
  event HatsClaimabilitySet(uint256[] hatIds, ClaimType[] claimTypes);
  /// @notice Emitted when the calimability of a hat was edited
  event HatClaimabilitySet(uint256 hatId, ClaimType claimType);
  /// @notice Emitted when a mint hook is set for a hat
  event MintHookSet(uint256 hatId, address mintHook);

  /*//////////////////////////////////////////////////////////////
                            DATA MODELS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Hats claimability types.
   * @param NotClaimable The hat is not claimable
   * @param Claimable The hat is only claimable by the account that will be the hat's wearer
   * @param ClaimableFor The hat is claimable on behalf of accounts (and also by the wearer)
   */
  enum ClaimType {
    NotClaimable,
    Claimable,
    ClaimableFor
  }

  /*//////////////////////////////////////////////////////////////
                            CONSTANTS 
  //////////////////////////////////////////////////////////////*/

  /**
   * This contract is a clone with immutable args, which means that it is deployed with a set of
   * immutable storage variables (ie constants). Accessing these constants is cheaper than accessing
   * regular storage variables (such as those set on initialization of a typical EIP-1167 clone),
   * but requires a slightly different approach since they are read from calldata instead of storage.
   *
   * Below is a table of constants and their location.
   *
   * For more, see here: https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args
   *
   * ----------------------------------------------------------------------+
   * CLONE IMMUTABLE "STORAGE"                                             |
   * ----------------------------------------------------------------------|
   * Offset  | Constant          | Type    | Length  | Source              |
   * ----------------------------------------------------------------------|
   * 0       | IMPLEMENTATION    | address | 20      | HatsModule          |
   * 20      | HATS              | address | 20      | HatsModule          |
   * 40      | hatId             | uint256 | 32      | HatsModule          |
   * ----------------------------------------------------------------------+
   */

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice Maps between hats and their claimability type
  mapping(uint256 hatId => ClaimType claimType) public hatToClaimType;

  /// @notice Maps between hats and their mint hook
  mapping(uint256 hatId => address mintHook) public hatToMintHook;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Deploy the implementation contract and set its version
  /// @dev This is only used to deploy the implementation contract, and should not be used to deploy clones
  constructor(string memory _version) HatsModule(_version) { }

  /*//////////////////////////////////////////////////////////////
                            INITIALIZOR
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc HatsModule
  function _setUp(bytes calldata _initData) internal override {
    if (_initData.length == 0) return;

    // decode first two required arrays
    (uint256[] memory _hatIds, ClaimType[] memory _claimTypes) = abi.decode(_initData, (uint256[], ClaimType[]));

    // set the claimability
    _setHatsClaimabilityMemory(_hatIds, _claimTypes);

    // check if there's data for _mintHooks and set them if so
    /// @dev Since there are two preceeding dynamic arrays, we need:
    /// - 2 * 32 bytes for the dynamic array offsets
    /// - For each dynamicarray:
    ///   - 32 bytes for the length
    ///   - length * 32 bytes for the actual data
    uint256 arrayLength = _hatIds.length;
    uint256 mintHooksStart = 64 + (32 + (arrayLength * 32)) + (32 + (arrayLength * 32));
    if (_initData.length > mintHooksStart) {
      (,, address[] memory _mintHooks) = abi.decode(_initData, (uint256[], ClaimType[], address[]));
      _setMintHooksMemory(_hatIds, _mintHooks);
    }
  }

  /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Change the claimability status of a hat. The caller should be an admin of the hat.
   * @param _hatId The ID of the hat to set claimability for
   * @param _claimType New claimability type for the hat
   */
  function setHatClaimability(uint256 _hatId, ClaimType _claimType) public {
    _setHatClaimability(_hatId, _claimType);

    emit HatClaimabilitySet(_hatId, _claimType);
  }

  /**
   * @notice Change the mint hook for a hat. The caller should be an admin of the hat.
   * @param _hatId The ID of the hat to set the mint hook for
   * @param _mintHook The address of the mint hook to set
   */
  function setMintHook(uint256 _hatId, address _mintHook) public {
    _checkAdmin(_hatId);
    _setMintHook(_hatId, _mintHook);
  }

  /**
   * @notice Change the claimability status of a hat and set its mint hook. The caller should be an admin of the hat.
   * @param _hatId The ID of the hat to set claimability and mint hook for
   * @param _claimType New claimability type for the hat
   * @param _mintHook The address of the mint hook to set
   */
  function setHatClaimabilityAndMintHook(uint256 _hatId, ClaimType _claimType, address _mintHook) public {
    _setMintHook(_hatId, _mintHook);
    _setHatClaimability(_hatId, _claimType);
    emit HatClaimabilitySet(_hatId, _claimType);
  }

  /**
   * @notice Change the claimability status of multiple hats. The caller should be an admin of the hats.
   * @param _hatIds The ID of the hat to set claimability for
   * @param _claimTypes New claimability types for each hat
   */
  function setHatsClaimability(uint256[] calldata _hatIds, ClaimType[] calldata _claimTypes) public {
    uint256 length = _hatIds.length;
    if (_claimTypes.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      _setHatClaimability(_hatIds[i], _claimTypes[i]);
      unchecked {
        ++i;
      }
    }

    emit HatsClaimabilitySet(_hatIds, _claimTypes);
  }

  function setMintHooks(uint256[] calldata _hatIds, address[] calldata _mintHooks) public {
    uint256 length = _hatIds.length;
    if (_mintHooks.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      _checkAdmin(_hatIds[i]);
      _setMintHook(_hatIds[i], _mintHooks[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Change the claimability status of multiple hats and set their mint hooks. The caller should be an admin of
   * the hats.
   * @param _hatIds The IDs of the hats to set claimability and mint hook for
   * @param _claimTypes New claimability types for each hat
   * @param _mintHooks The addresses of the mint hooks to set for each hat
   */
  function setHatsClaimabilityAndMintHooks(
    uint256[] calldata _hatIds,
    ClaimType[] calldata _claimTypes,
    address[] calldata _mintHooks
  ) public {
    uint256 length = _hatIds.length;
    if (_claimTypes.length != length || _mintHooks.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      _setHatClaimability(_hatIds[i], _claimTypes[i]);
      _setMintHook(_hatIds[i], _mintHooks[i]);
      unchecked {
        ++i;
      }
    }

    emit HatsClaimabilitySet(_hatIds, _claimTypes);
  }

  /**
   * @notice Wrapper around a HatsModuleFactory. Deploys a new HatsModule instance and sets a hat's claimability type.
   * @param _factory The HatsModuleFactory instance that will deploy the module
   * @param _implementation The address of the implementation contract of which to deploy a clone
   * @param _moduleHatId The hat for which to deploy a HatsModule.
   * @param _otherImmutableArgs Other immutable args to pass to the clone as immutable storage.
   * @param _initData The encoded data to pass to the `setUp` function of the new HatsModule instance. Leave empty if
   * none.
   * @param _saltNonce The nonce to use when calculating the salt
   * @param _hatId The ID of the hat to set claimability for
   * @param _claimType New claimability type for the hat
   * @return _instance The address of the deployed HatsModule instance
   */
  function setHatClaimabilityAndCreateModule(
    HatsModuleFactory _factory,
    address _implementation,
    uint256 _moduleHatId,
    bytes calldata _otherImmutableArgs,
    bytes calldata _initData,
    uint256 _saltNonce,
    uint256 _hatId,
    ClaimType _claimType
  ) public returns (address _instance) {
    _setHatClaimability(_hatId, _claimType);

    _instance = _factory.createHatsModule(_implementation, _moduleHatId, _otherImmutableArgs, _initData, _saltNonce);

    emit HatClaimabilitySet(_hatId, _claimType);
  }

  /**
   * @notice Wrapper around a HatsModuleFactory. Deploys a new HatsModule instance and sets a hat's claimability type
   * and mint hook.
   * @param _factory The HatsModuleFactory instance that will deploy the modules
   * @param _implementation The address of the implementation contract of which to deploy a clone
   * @param _moduleHatId The hat for which to deploy a HatsModule.
   * @param _otherImmutableArgs Other immutable args to pass to the clone as immutable storage.
   * @param _initData The encoded data to pass to the `setUp` function of the new HatsModule instance. Leave empty if
   * none.
   * @param _saltNonce The nonce to use when calculating the salt
   * @param _hatId The ID of the hat to set claimability for
   * @param _claimType New claimability type for the hat
   * @param _mintHook The address of the mint hook to set
   * @return _instance The address of the deployed HatsModule instance
   */
  function setHatClaimabilityAndMintHookAndCreateModule(
    HatsModuleFactory _factory,
    address _implementation,
    uint256 _moduleHatId,
    bytes calldata _otherImmutableArgs,
    bytes calldata _initData,
    uint256 _saltNonce,
    uint256 _hatId,
    ClaimType _claimType,
    address _mintHook
  ) public returns (address _instance) {
    _setHatClaimability(_hatId, _claimType);
    emit HatClaimabilitySet(_hatId, _claimType);

    _setMintHook(_hatId, _mintHook);

    _instance = _factory.createHatsModule(_implementation, _moduleHatId, _otherImmutableArgs, _initData, _saltNonce);
  }

  /**
   * @notice Wrapper around a HatsModuleFactory. Deploys new HatsModule instances and sets the claimability type of
   * multiple hats.
   * @param _factory The HatsModuleFactory instance that will deploy the modules
   * @param _implementations The addresses of the implementation contracts of which to deploy a clone
   * @param _moduleHatIds The hats for which to deploy a HatsModule.
   * @param _otherImmutableArgsArray Other immutable args to pass to the clones as immutable storage.
   * @param _initDataArray The encoded data to pass to the `setUp` functions of the new HatsModule instances.
   * @param _saltNonces The nonces to use when calculating the salt for each module
   * @param _hatIds The IDs of the hats to set claimability for
   * @param _claimTypes New claimability types for each hat
   * @return success True if all modules were successfully created and the claimability types were set
   */
  function setHatsClaimabilityAndCreateModules(
    HatsModuleFactory _factory,
    address[] calldata _implementations,
    uint256[] calldata _moduleHatIds,
    bytes[] calldata _otherImmutableArgsArray,
    bytes[] calldata _initDataArray,
    uint256[] memory _saltNonces,
    uint256[] memory _hatIds,
    ClaimType[] memory _claimTypes
  ) public returns (bool success) {
    uint256 length = _hatIds.length;
    if (_claimTypes.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      _setHatClaimability(_hatIds[i], _claimTypes[i]);
      unchecked {
        ++i;
      }
    }

    success = _factory.batchCreateHatsModule(
      _implementations, _moduleHatIds, _otherImmutableArgsArray, _initDataArray, _saltNonces
    );

    emit HatsClaimabilitySet(_hatIds, _claimTypes);
  }

  /**
   * @notice Wrapper around a HatsModuleFactory. Deploys new HatsModule instances and sets the claimability type and
   * mint hooks of multiple hats.
   * @param _factory The HatsModuleFactory instance that will deploy the modules
   * @param _implementations The addresses of the implementation contracts of which to deploy a clone
   * @param _moduleHatIds The hats for which to deploy a HatsModule.
   * @param _otherImmutableArgsArray Other immutable args to pass to the clones as immutable storage.
   * @param _initDataArray The encoded data to pass to the `setUp` functions of the new HatsModule instances.
   * @param _saltNonces The nonces to use when calculating the salt for each module
   * @param _hatIds The IDs of the hats to set claimability for
   * @param _claimTypes New claimability types for each hat
   * @param _mintHooks The addresses of the mint hooks to set for each hat
   * @return True if all modules were successfully created and the claimability types and mint hooks were set
   */
  function setHatsClaimabilityAndMintHooksAndCreateModules(
    HatsModuleFactory _factory,
    address[] memory _implementations,
    uint256[] calldata _moduleHatIds,
    bytes[] calldata _otherImmutableArgsArray,
    bytes[] calldata _initDataArray,
    uint256[] memory _saltNonces,
    uint256[] memory _hatIds,
    ClaimType[] memory _claimTypes,
    address[] memory _mintHooks
  ) public returns (bool) {
    uint256 length = _hatIds.length;
    if (_claimTypes.length != length || _mintHooks.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      _setHatClaimability(_hatIds[i], _claimTypes[i]);
      _setMintHook(_hatIds[i], _mintHooks[i]);
      unchecked {
        ++i;
      }
    }

    emit HatsClaimabilitySet(_hatIds, _claimTypes);

    return _factory.batchCreateHatsModule(
      _implementations, _moduleHatIds, _otherImmutableArgsArray, _initDataArray, _saltNonces
    );
  }

  /*//////////////////////////////////////////////////////////////
                        CLAIMING FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Claim a hat.
   * @dev This contract must be wearing an admin hat of the hat to claim or else it will revert
   * @param _hatId The ID of the hat to claim
   */
  function claimHat(uint256 _hatId) public {
    _claimHat(_hatId);
  }

  /**
   * @notice Claim a hat and call its mint hook. Will revert if the mint hook fails.
   * @param _hatId The ID of the hat to claim
   * @param _hookData The data to pass to the mint hook
   */
  function claimHatWithHook(uint256 _hatId, bytes calldata _hookData) public {
    _claimHatWithHook(_hatId, _hookData);
  }

  /**
   * @notice Claim multiple hats.
   * @dev This contract must be wearing an admin hat of the hats to claim or else it will revert
   * @param _hatIds The IDs of the hats to claim
   */
  function claimHats(uint256[] calldata _hatIds) public {
    for (uint256 i; i < _hatIds.length;) {
      _claimHat(_hatIds[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Claim multiple hats and call their mint hooks. Will revert if any mint hook fails.
   * @param _hatIds The IDs of the hats to claim
   * @param _hookDatas The data to pass to the mint hooks
   */
  function claimHatsWithHook(uint256[] calldata _hatIds, bytes[] calldata _hookDatas) public {
    if (_hatIds.length != _hookDatas.length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < _hatIds.length;) {
      _claimHatWithHook(_hatIds[i], _hookDatas[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Claim a hat on behalf of an account
   * @dev This contract must be wearing an admin hat of the hat to claim or else it will revert
   * @param _hatId The ID of the hat to claim for
   * @param _account The account for which to claim
   */
  function claimHatFor(uint256 _hatId, address _account) public {
    _claimHatFor(_hatId, _account);
  }

  /**
   * @notice Claim a hat on behalf of an account and call its mint hook. Will revert if the mint hook fails.
   * @param _hatId The ID of the hat to claim for
   * @param _account The account for which to claim
   * @param _hookData The data to pass to the mint hook
   */
  function claimHatForWithHook(uint256 _hatId, address _account, bytes calldata _hookData) public {
    _claimHatForWithHook(_hatId, _account, _hookData);
  }

  /**
   * @notice Claim multiple hats on behalf of accounts
   * @dev This contract must be wearing an admin hat of the hats to claim or else it will revert
   * @param _hatIds The IDs of the hats to claim for
   * @param _accounts The accounts for which to claim
   */
  function claimHatsFor(uint256[] calldata _hatIds, address[] calldata _accounts) public {
    if (_hatIds.length != _accounts.length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < _hatIds.length;) {
      _claimHatFor(_hatIds[i], _accounts[i]);

      unchecked {
        ++i;
      }
    }
  }

  /**
   * @notice Claim multiple hats on behalf of accounts and call their mint hooks. Will revert if any mint hook fails.
   * @param _hatIds The IDs of the hats to claim for
   * @param _accounts The accounts for which to claim
   * @param _hookDatas The data to pass to the mint hooks
   */
  function claimHatsForWithHooks(uint256[] calldata _hatIds, address[] calldata _accounts, bytes[] calldata _hookDatas)
    public
  {
    if (_hatIds.length != _accounts.length || _hatIds.length != _hookDatas.length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < _hatIds.length;) {
      _claimHatForWithHook(_hatIds[i], _accounts[i], _hookDatas[i]);

      unchecked {
        ++i;
      }
    }
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Checks if a hat is claimable on behalf of an account
   * @param _account The account to claim for
   * @param _hatId The hat to claim
   */
  function canClaimForAccount(address _account, uint256 _hatId) public view returns (bool) {
    return (isClaimableFor(_hatId) && _isExplicitlyEligible(_hatId, _account));
  }

  /**
   * @notice Checks if an account can claim a hat.
   * @param _account The claiming account
   * @param _hatId The hat to claim
   */
  function accountCanClaim(address _account, uint256 _hatId) public view returns (bool) {
    return (isClaimableBy(_hatId) && _isExplicitlyEligible(_hatId, _account));
  }

  /**
   * @notice Checks if a hat is claimable
   * @param _hatId The ID of the hat
   */
  function isClaimableBy(uint256 _hatId) public view returns (bool) {
    return (hatExists(_hatId) && wearsAdmin(_hatId) && hatToClaimType[_hatId] > ClaimType.NotClaimable);
  }

  /**
   * @notice Checks if a hat is claimable on behalf of accounts
   * @param _hatId The ID of the hat
   */
  function isClaimableFor(uint256 _hatId) public view returns (bool) {
    return (hatExists(_hatId) && wearsAdmin(_hatId) && hatToClaimType[_hatId] == ClaimType.ClaimableFor);
  }

  /**
   * @notice Check if this contract is an admin of a hat.
   *   @param _hatId The ID of the hat
   */
  function wearsAdmin(uint256 _hatId) public view returns (bool) {
    return HATS().isAdminOfHat(address(this), _hatId);
  }

  /// @notice Checks if a hat exists
  function hatExists(uint256 _hatId) public view returns (bool) {
    return HATS().getHatMaxSupply(_hatId) > 0;
  }

  /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _mint(uint256 _hatId, address _account) internal {
    // revert if _wearer is not explicitly eligible
    if (!_isExplicitlyEligible(_hatId, _account)) revert MultiClaimsHatter_NotExplicitlyEligible(_account, _hatId);
    // mint the hat to _wearer if eligible. This contract can mint as long as its the hat's admin.
    HATS().mintHat(_hatId, _account);
  }

  function _callMintHook(uint256 _hatId, address _account, bytes calldata _hookData) internal {
    if (!IHatMintHook(hatToMintHook[_hatId]).onHatMinted(_hatId, _account, _hookData)) {
      revert MultiClaimsHatter_MintHookFailed(_hatId);
    }
  }

  function _claimHat(uint256 _hatId) internal {
    if (hatToClaimType[_hatId] == ClaimType.NotClaimable) {
      revert MultiClaimsHatter_HatNotClaimable(_hatId);
    }

    _mint(_hatId, msg.sender);
  }

  function _claimHatWithHook(uint256 _hatId, bytes calldata _hookData) internal {
    _claimHat(_hatId);
    _callMintHook(_hatId, msg.sender, _hookData);
  }

  function _claimHatFor(uint256 _hatId, address _account) internal {
    if (hatToClaimType[_hatId] != ClaimType.ClaimableFor) {
      revert MultiClaimsHatter_HatNotClaimableFor(_hatId);
    }

    _mint(_hatId, _account);
  }

  function _claimHatForWithHook(uint256 _hatId, address _account, bytes calldata _hookData) internal {
    _claimHatFor(_hatId, _account);
    _callMintHook(_hatId, _account, _hookData);
  }

  function _isExplicitlyEligible(uint256 _hatId, address _account) internal view returns (bool eligible) {
    // get the hat's eligibility module address
    address eligibility = HATS().getHatEligibilityModule(_hatId);
    // get _wearer's eligibility status from the eligibility module
    bool standing;
    (bool success, bytes memory returndata) =
      eligibility.staticcall(abi.encodeWithSignature("getWearerStatus(address,uint256)", _account, _hatId));

    /* 
    * if function call succeeds with data of length == 64, then we know the contract exists 
    * and has the getWearerStatus function (which returns two words).
    * But — since function selectors don't include return types — we still can't assume that the return data is two
    booleans, 
    * so we treat it as a uint so it will always safely decode without throwing.
    */
    if (success && returndata.length == 64) {
      // check the returndata manually
      (uint256 firstWord, uint256 secondWord) = abi.decode(returndata, (uint256, uint256));
      // returndata is valid
      if (firstWord < 2 && secondWord < 2) {
        standing = (secondWord == 1) ? true : false;
        // never eligible if in bad standing
        eligible = (standing && firstWord == 1) ? true : false;
      }
      // returndata is invalid
      else {
        // false since _wearer is not explicitly eligible
        eligible = false;
      }
    } else {
      // false since _wearer is not explicitly eligible
      eligible = false;
    }
  }

  /// @dev Internal function to set the claimability of a hat, with admin check. Does not emit an event.
  /// @param _hatId The ID of the hat to set claimability for
  /// @param _claimType The new claimability type for the hat
  function _setHatClaimability(uint256 _hatId, ClaimType _claimType) internal {
    _checkAdmin(_hatId);
    hatToClaimType[_hatId] = _claimType;
  }

  /// @dev Internal function to set the mint hook of a hat, without admin check. Does emit an event.
  /// @param _hatId The ID of the hat to set the mint hook for
  /// @param _mintHook The address of the mint hook to set
  function _setMintHook(uint256 _hatId, address _mintHook) internal {
    hatToMintHook[_hatId] = _mintHook;
    emit MintHookSet(_hatId, _mintHook);
  }

  function _setHatsClaimabilityMemory(uint256[] memory _hatIds, ClaimType[] memory _claimTypes) internal {
    uint256 length = _hatIds.length;
    if (_claimTypes.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    uint256 hatId;
    for (uint256 i; i < length;) {
      hatId = _hatIds[i];
      hatToClaimType[hatId] = _claimTypes[i];
      unchecked {
        ++i;
      }
    }

    emit HatsClaimabilitySet(_hatIds, _claimTypes);
  }

  function _setMintHooksMemory(uint256[] memory _hatIds, address[] memory _mintHooks) internal {
    console2.log("setting mint hooks");
    uint256 length = _hatIds.length;
    if (_mintHooks.length != length) {
      revert MultiClaimsHatter_ArrayLengthMismatch();
    }

    for (uint256 i; i < length;) {
      // set the mint hook if it is not the zero address
      if (_mintHooks[i] != address(0)) {
        console2.log("setting mint hook for hat", _hatIds[i]);
        _setMintHook(_hatIds[i], _mintHooks[i]);
      }
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Internal function that reverts if the caller is not an admin of a hat
  function _checkAdmin(uint256 _hatId) internal view {
    if (!HATS().isAdminOfHat(msg.sender, _hatId)) revert MultiClaimsHatter_NotAdminOfHat(msg.sender, _hatId);
  }
}
