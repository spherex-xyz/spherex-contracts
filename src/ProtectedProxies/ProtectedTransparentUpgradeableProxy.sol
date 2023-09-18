// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/Proxy/transparent/TransparentUpgradeableProxy.sol";

import {SphereXProtectedBase} from "../SphereXProtectedBase.sol";


contract ProtectedTransparentUpgradeableProxy is SphereXProtectedBase, TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        SphereXProtectedBase(msg.sender, address(0), address(0))
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    bytes32 private constant PROTECTED_SIG_BASE_POSITION = bytes32(uint256(keccak256("eip1967.spherex.protection_sig_base")) - 1);

    function _setProtectedSig(bytes4 key, bool value) private {
        bytes32 position = keccak256(abi.encodePacked(key, PROTECTED_SIG_BASE_POSITION));
        assembly {
            sstore(position, value)
        }
    }

    function _getProtectedSig(bytes4 key) private view returns (bool value) {
        bytes32 position = keccak256(abi.encodePacked(key, PROTECTED_SIG_BASE_POSITION));
        assembly {
            value := sload(position)
        }
    }

    function setProtectedSigs(bytes4 key, bool value) public spherexOnlyOperator {
        _setProtectedSig(key, value);
    }

    function protectedSigs(bytes4 key) public view returns (bool) {
        return _getProtectedSig(key);
    }

    function _protectedDelegate(address implementation) private sphereXGuardExternal(int256(uint256(bytes32(msg.sig)))) returns (bytes memory) {
        return Address.functionDelegateCall(implementation, msg.data);
    }

    function _delegate(address implementation) internal override {
        if (protectedSigs(msg.sig)) {
            bytes memory ret_data = _protectedDelegate(implementation);
            uint256 ret_size = ret_data.length;

            assembly {
                return(add(ret_data, 0x20), ret_size)
            }
        }
        else {
            super._delegate(implementation);
        }
    }
}