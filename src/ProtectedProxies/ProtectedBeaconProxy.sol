// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {BeaconProxy, Proxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";
import {ISphereXEngine} from "../ISphereXEngine.sol";
import {ISphereXBeacon} from "./ISphereXBeacon.sol";

/**
 * @title BeaconProxy implementation with spherex's protection
 */
contract ProtectedBeaconProxy is SphereXProtectedProxy, BeaconProxy {
    constructor(address beacon, bytes memory data)
        SphereXProtectedProxy(msg.sender, address(0), address(0))
        BeaconProxy(beacon, data)
    {}

    /**
     * @dev This is used since both SphereXProtectedProxy and BeaconProxy implements Proxy.sol _delegate.
     */
    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
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
        (address imp, address engine, bool isProtectedFuncSig) = ISphereXBeacon(_getBeacon()).protectionInfo(msg.sig);
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
