// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

contract StealthKeyRegistry {

    // =========================================== Structs ============================================

    struct EncryptedSafeViewPrivateKey {
        bytes encKey;
        address owner;
    }

    // =========================================== Events ============================================

    /// @dev Event emitted when a multisig updates their registered stealth keys
    event StealthSafeKeyChanged(
        address indexed registrant,  // safe address
        uint256 viewingPubKeyPrefix,
        uint256 viewingPubKey,
        address[] owners
    );

    // ======================================= State variables =======================================

    /**
     * @dev Mapping used to store one secp256k1 curve public key used for
   * receiving stealth payments. The mapping records one key, the viewing
   * key, encrypted for the different safe users.
   * The spending key is not needed, as the spending address is the
   * Safe account. View key can be set and read via the `setStealthKeys`
   * and `stealthKey` methods respectively.
   *
   * The mapping associates the safe's address to an array of EncryptedSafeViewPrivateKey.
   * Array contains the owner addresses, with the encrypted view keys of the Safe.
   *
   * For more on secp256k1 public keys and prefixes generally, see:
   * https://github.com/ethereumbook/ethereumbook/blob/develop/04keys-addresses.asciidoc#generating-a-public-key
   */
    mapping(address => EncryptedSafeViewPrivateKey[]) safePrivateKeys;

    mapping(address => mapping(uint256 => uint256)) keys;

    /**
     * @dev We wait until deployment to codify the domain separator because we need the
   * chainId and the contract address
   */
    constructor() {

    }

    // ======================================= Set Keys ===============================================

    /**
     * @notice Sets stealth keys for the caller
   * @param _viewingPubKeyPrefix Prefix of the viewing public key (2 or 3)
   * @param _viewingPubKey The public key to use for encryption
   * @param _safeViewKeyList View key of Safe stored encrypted for each safe viewer
   */
    function setStealthKeys(
        uint256 _viewingPubKeyPrefix,
        uint256 _viewingPubKey,
        EncryptedSafeViewPrivateKey[] calldata _safeViewKeyList
    ) external {
        _setStealthKeys(msg.sender, _viewingPubKeyPrefix, _viewingPubKey, _safeViewKeyList);
    }

    /**
     * @dev Internal method for setting stealth key that must be called after safety
   * check on registrant; see calling method for parameter details
   */
    function _setStealthKeys(
        address _registrant,
        uint256 _viewingPubKeyPrefix,
        uint256 _viewingPubKey,
        EncryptedSafeViewPrivateKey[] calldata _safeViewKeyList
    ) internal {
        // TODO check the msg.sender is actually a valid gnosis safe
        require(
            _safeViewKeyList.length > 0,
            "StealthSafeKeyRegistry: Invalid Keys lenght"
        );
        require(
            (_viewingPubKeyPrefix == 2 || _viewingPubKeyPrefix == 3),
            "StealthKeyRegistry: Invalid ViewingPubKey Prefix"
        );

        // Store viewPubKey

        // Ensure the opposite prefix indices are empty
        delete keys[_registrant][5 - _viewingPubKeyPrefix];

        // Set the appropriate indices to the new key values
        keys[_registrant][_viewingPubKeyPrefix] = _viewingPubKey;

        // store viewPrivateKey
        address[] memory _owners;
        EncryptedSafeViewPrivateKey[] storage pKey = safePrivateKeys[_registrant];

        for (uint i=0; i<_safeViewKeyList.length; ++i) {
            _owners[i] = _safeViewKeyList[i].owner;
            pKey.push(
                EncryptedSafeViewPrivateKey( _safeViewKeyList[i].encKey, _safeViewKeyList[i].owner)
            );
        }

        emit StealthSafeKeyChanged(_registrant, _viewingPubKeyPrefix, _viewingPubKey, _owners);
    }

    // ======================================= Get Keys ===============================================

    /**
     * @notice Returns the stealth key associated with an address.
   * @param _registrant The address whose keys to lookup.
   * @return viewingPubKeyPrefix Prefix of the viewing public key (2 or 3)
   * @return viewingPubKey The public key to use for encryption
   * @return safeViewPrivateKeyList Array of view keys
   */
    function stealthKeys(address _registrant)
    external
    view
    returns (
        uint256 viewingPubKeyPrefix,
        uint256 viewingPubKey,
        EncryptedSafeViewPrivateKey[] memory safeViewPrivateKeyList
    )
    {
        // read view keys
        if (keys[_registrant][2] != 0) {
            viewingPubKeyPrefix = 2;
            viewingPubKey = keys[_registrant][2];
        } else {
            viewingPubKeyPrefix = 3;
            viewingPubKey = keys[_registrant][3];
        }

        // read private keys
        EncryptedSafeViewPrivateKey[] storage _safePrivateKeysStorageRef = safePrivateKeys[_registrant];
        safeViewPrivateKeyList = new EncryptedSafeViewPrivateKey[](_safePrivateKeysStorageRef.length);
        for (uint i = 0; i < _safePrivateKeysStorageRef.length; ++i) {
            safeViewPrivateKeyList[i] = _safePrivateKeysStorageRef[i];
        }

        return (viewingPubKeyPrefix, viewingPubKey, safeViewPrivateKeyList);
    }
}
