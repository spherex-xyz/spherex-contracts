// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {Proxy} from "openzeppelin/proxy/Proxy.sol";
import {Address} from "openzeppelin/utils/Address.sol";

import {SphereXProtectedBase} from "./SphereXProtectedBase.sol";

/**
 * @title SphereX abstract proxt contract which implements OZ's Proxy intereface.
 */
abstract contract SphereXProtectedProxy is SphereXProtectedBase, Proxy {
    /**
     * @dev As we dont want to conflict with the imp's storage we implenment the protected
     * @dev functions map in an arbitrary slot.
     */
    bytes32 private constant PROTECTED_FUNC_SIG_BASE_POSITION =
        bytes32(uint256(keccak256("eip1967.spherex.protection_sig_base")) - 1);

    event AddedProtectedFuncSigs(bytes4[] patterns);
    event RemovedProtectedFuncSigs(bytes4[] patterns);

    constructor(address admin, address operator, address engine) SphereXProtectedBase(admin, operator, engine) {}

    /**
     * Sets the value of a functions signature in the protected functions map stored in an arbitrary slot
     * @param func_sig of the wanted function
     * @param value bool value to set for the given function signature
     */
    function _setProtectedFuncSig(bytes4 func_sig, bool value) private {
        bytes32 position = keccak256(abi.encodePacked(func_sig, PROTECTED_FUNC_SIG_BASE_POSITION));
        assembly {
            sstore(position, value)
        }
    }

    /**
     * Adds several functions' signature to the protected functions map stored in an arbitrary slot
     * @param keys of the functions added to the protected map
     */
    function addProtectedFuncSigs(bytes4[] memory keys) public spherexOnlyOperator {
        for (uint256 i = 0; i < keys.length; ++i) {
            _setProtectedFuncSig(keys[i], true);
        }
        emit AddedProtectedFuncSigs(keys);
    }

    /**
     * Removes given functions' signature from the protected functions map
     * @param keys of the functions removed from the protected map
     */
    function removeProtectedFuncSigs(bytes4[] memory keys) public spherexOnlyOperator {
        for (uint256 i = 0; i < keys.length; ++i) {
            _setProtectedFuncSig(keys[i], false);
        }
        emit RemovedProtectedFuncSigs(keys);
    }

    /**
     * Getter for a specific function signature in the protected map
     * @param func_sig of the wanted function
     */
    function isProtectedFuncSig(bytes4 func_sig) public view returns (bool value) {
        bytes32 position = keccak256(abi.encodePacked(func_sig, PROTECTED_FUNC_SIG_BASE_POSITION));
        assembly {
            value := sload(position)
        }
    }

    /**
     * The main point of the contract, wrap the delegate operation with SphereX's protection modfifier
     * @param implementation delegate dst
     */
    function _protectedDelegate(address implementation)
        private
        sphereXGuardExternal(int256(uint256(uint32(msg.sig))))
        returns (bytes memory)
    {
        return Address.functionDelegateCall(implementation, msg.data);
    }

    /**
     * Override Proxy.sol _delegate to make every inheriting proxy delegate with sphere'x protection
     * @param implementation delegate dst
     */
    function _delegate(address implementation) internal virtual override {
        if (isProtectedFuncSig(msg.sig)) {
            bytes memory ret_data = _protectedDelegate(implementation);
            uint256 ret_size = ret_data.length;

            assembly {
                return(add(ret_data, 0x20), ret_size)
            }
        } else {
            super._delegate(implementation);
        }
    }
}
