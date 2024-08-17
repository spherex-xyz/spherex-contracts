// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ISphereXEngine, ModifierLocals} from "./ISphereXEngine.sol";
import {SphereXConfiguration} from "./SphereXConfiguration.sol";

/**
 * @title SphereX base Customer contract template
 */
/// @custom:oz-upgrades-unsafe-allow constructor 
abstract contract SphereXProtectedBase is SphereXConfiguration {
    constructor(address admin, address operator, address engine) SphereXConfiguration(admin, operator, engine) {}

    // ============ Hooks ============

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called before the code of a function.
     * @param num function identifier
     * @param isExternalCall set to true if this was called externally
     *  or a 'public' function from another address
     */
    function _sphereXValidatePre(int256 num, bool isExternalCall)
        private
        returnsIfNotActivated
        returns (ModifierLocals memory locals)
    {
        ISphereXEngine engine = _sphereXEngine();
        if (isExternalCall) {
            locals.storageSlots = engine.sphereXValidatePre(num, msg.sender, msg.data);
        } else {
            locals.storageSlots = engine.sphereXValidateInternalPre(num);
        }
        locals.valuesBefore = _readStorage(locals.storageSlots);
        locals.gas = gasleft();
        locals.engine = address(engine);
        return locals;
    }

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called after the code of a function.
     * @param num function identifier
     * @param isExternalCall set to true if this was called externally
     *  or a 'public' function from another address
     */
    function _sphereXValidatePost(int256 num, bool isExternalCall, ModifierLocals memory locals) private {
        ISphereXEngine engine = ISphereXEngine(locals.engine);

        if (address(engine) == address(0)) {
            return;
        }

        uint256 gas = locals.gas - gasleft();

        bytes32[] memory valuesAfter;
        valuesAfter = _readStorage(locals.storageSlots);

        if (isExternalCall) {
            engine.sphereXValidatePost(num, gas, locals.valuesBefore, valuesAfter);
        } else {
            engine.sphereXValidateInternalPost(num, gas, locals.valuesBefore, valuesAfter);
        }
    }

    // ============ Modifiers ============

    /**
     *  @dev Modifier to be incorporated in all internal protected non-view functions
     */
    modifier sphereXGuardInternal(int256 num) {
        ModifierLocals memory locals = _sphereXValidatePre(num, false);
        _;
        _sphereXValidatePost(-num, false, locals);
    }

    /**
     *  @dev Modifier to be incorporated in all external protected non-view functions
     */
    modifier sphereXGuardExternal(int256 num) {
        ModifierLocals memory locals = _sphereXValidatePre(num, true);
        _;
        _sphereXValidatePost(-num, true, locals);
    }

    /**
     *  @dev Modifier to be incorporated in all public protected non-view functions
     */
    modifier sphereXGuardPublic(int256 num, bytes4 selector) {
        ModifierLocals memory locals = _sphereXValidatePre(num, msg.sig == selector);
        _;
        _sphereXValidatePost(-num, msg.sig == selector, locals);
    }

    // ============ Internal Storage logic ============

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
}
