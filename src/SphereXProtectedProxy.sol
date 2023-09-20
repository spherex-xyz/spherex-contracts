// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {Proxy} from "openzeppelin/Proxy/Proxy.sol";
import {Address} from "openzeppelin/Utils/Address.sol";

import {SphereXProtectedBase} from "./SphereXProtectedBase.sol";

abstract contract SphereXProtectedProxy is SphereXProtectedBase, Proxy {
    bytes32 private constant PROTECTED_SIG_BASE_POSITION =
        bytes32(uint256(keccak256("eip1967.spherex.protection_sig_base")) - 1);

    event AddedProtectedSigs(bytes4[] patterns);
    event RemovedProtectedSigs(bytes4[] patterns);

    constructor(address admin, address operator, address engine) SphereXProtectedBase(admin, operator, engine) {}

    function _setProtectedSig(bytes4 key, bool value) private {
        bytes32 position = keccak256(abi.encodePacked(key, PROTECTED_SIG_BASE_POSITION));
        assembly {
            sstore(position, value)
        }
    }

    function addProtectedSigs(bytes4[] memory keys) public spherexOnlyOperator {
        for (uint256 i = 0; i < keys.length; ++i) {
            _setProtectedSig(keys[i], true);
        }
        emit AddedProtectedSigs(keys);
    }

    function removeProtectedSigs(bytes4[] memory keys) public spherexOnlyOperator {
        for (uint256 i = 0; i < keys.length; ++i) {
            _setProtectedSig(keys[i], false);
        }
        emit RemovedProtectedSigs(keys);
    }

    function getProtectedSig(bytes4 key) public view returns (bool value) {
        bytes32 position = keccak256(abi.encodePacked(key, PROTECTED_SIG_BASE_POSITION));
        assembly {
            value := sload(position)
        }
    }

    function _protectedDelegate(address implementation)
        private
        sphereXGuardExternal(int256(uint256(uint128(bytes16(msg.sig)))))
        returns (bytes memory)
    {
        return Address.functionDelegateCall(implementation, msg.data);
    }

    function _delegate(address implementation) internal virtual override {
        if (getProtectedSig(msg.sig)) {
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
