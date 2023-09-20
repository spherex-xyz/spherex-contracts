// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import {StorageSlot} from "openzeppelin/utils/StorageSlot.sol";

abstract contract SphereXInitializable {
    bytes32 private constant _INITIZLIZED_FLAG_SLOT = bytes32(uint256(keccak256("eip1967.initialized_flag_slot")) - 1);

    modifier initializer() {
        require(!isInitialized(), "SphereXInitializable: contract is already initialized");
        _setInitialized(true);
        _;
    }

    function isInitialized() public view returns (bool) {
        return StorageSlot.getBooleanSlot(_INITIZLIZED_FLAG_SLOT).value;
    }

    function _setInitialized(bool _initialized) internal {
        StorageSlot.getBooleanSlot(_INITIZLIZED_FLAG_SLOT).value = _initialized;
    }

    function _disableInitializers() internal {
        _setInitialized(true);
    }
}
