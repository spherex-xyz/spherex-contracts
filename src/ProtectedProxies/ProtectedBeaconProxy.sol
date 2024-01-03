// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {BeaconProxy, Proxy} from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import {Address} from "openzeppelin/utils/Address.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";
import {ISphereXEngine, ModifierLocals} from "../ISphereXEngine.sol";
import {ISphereXBeacon} from "./ISphereXBeacon.sol";

/**
 * @title BeaconProxy implementation with spherex's protection
 */
contract ProtectedBeaconProxy is BeaconProxy {
    constructor(address beacon, bytes memory data) BeaconProxy(beacon, data) {}

    /**
     * Internal function that reads values from given storage slots and returns them
     * @param storageSlots list of storage slots to read
     * @return list of values read from the various storage slots
     */
    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 arrayLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](arrayLength);
        // create the return array data

        for (uint256 i = 0; i < arrayLength; i++) {
            bytes32 slot = storageSlots[i];
            bytes32 temp_value;
            // solhint-disable-next-line no-inline-assembly
            // slither-disable-next-line assembly
            assembly {
                temp_value := sload(slot)
            }

            values[i] = temp_value;
        }
        return values;
    }

    function _before(address engine) private returns (ModifierLocals memory locals) {
        locals.storageSlots =
            ISphereXEngine(engine).sphereXValidatePre(int256(uint256(uint32(msg.sig))), msg.sender, msg.data);
        locals.valuesBefore = _readStorage(locals.storageSlots);
        locals.gas = gasleft();

        return locals;
    }

    function _after(address engine, ModifierLocals memory locals) private {
        uint256 gas = locals.gas - gasleft();
        bytes32[] memory valuesAfter;
        valuesAfter = _readStorage(locals.storageSlots);

        ISphereXEngine(engine).sphereXValidatePost(
            -int256(uint256(uint32(msg.sig))), gas, locals.valuesBefore, valuesAfter
        );
    }

    function _fallback() internal virtual override {
        (address imp, address engine, bool isProtectedFuncSig) =
            ISphereXBeacon(_getBeacon()).protectedImplementation(msg.sig);
        if (isProtectedFuncSig && engine != address(0)) {
            ModifierLocals memory locals = _before(engine);
            bytes memory ret_data = Address.functionDelegateCall(imp, msg.data);
            _after(engine, locals);

            uint256 ret_size = ret_data.length;
            assembly {
                return(add(ret_data, 0x20), ret_size)
            }
        } else {
            super._delegate(imp);
        }
    }
}
