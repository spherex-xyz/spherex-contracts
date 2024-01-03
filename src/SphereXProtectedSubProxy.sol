// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {Address} from "openzeppelin/utils/Address.sol";

import {SphereXProtectedProxy} from "./SphereXProtectedProxy.sol";
import {SphereXInitializable} from "./Utils/SphereXInitializable.sol";

/**
 * @title Interface for SphereXProtectedSubProxy - upgrade logic
 */
interface ISphereXProtectedSubProxy {
    function subUpgradeTo(address newImplementation) external;
    function subUpgradeToAndCall(address newImplementation, bytes memory data) external;
}

/**
 * @title A version of SphereX's proxy implementation designed to be under another proxy,
 *        Enabled using a different arbitrary slot for the imp to avoid clashing with the first proxy,
 *        and adding initializing and sub-uprade logic to SphereXProtectedSubProxy.
 */
abstract contract SphereXProtectedSubProxy is SphereXProtectedProxy, SphereXInitializable {
    bytes32 private constant _SPHEREX_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.implementation_slot")) - 1);

    /**
     * @dev Prevents initialization of the implementation contract itself,
     * as extra protection to prevent an attacker from initializing it.
     * SEE: https://forum.openzeppelin.com/t/what-does-disableinitializers-function-mean/28730/2
     */
    constructor() SphereXProtectedProxy(address(0), address(0), address(0)) {
        _disableInitializers();
    }

    /**
     * Used when the client uses a proxy - should be called by the inhereter initialization
     */
    function __SphereXProtectedSubProXy_init(
        address admin,
        address operator,
        address engine,
        address _logic,
        bytes memory data
    ) external initializer {
        __SphereXProtectedBase_init(admin, operator, engine);
        subUpgradeToAndCall(_logic, data);
    }

    /**
     * Override Proxy.sol _implementation and retrieve the imp address from the another arbitrary slot.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return _getAddress(_SPHEREX_IMPLEMENTATION_SLOT);
    }

    /**
     * Upgrades the logic in our arbitrary slot
     * @param newImplementation new dst address
     */
    function subUpgradeTo(address newImplementation) internal {
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
    }

    /**
     * Upgrades the logic in our arbitrary slot and delegates to the new implementation
     * @param newImplementation new dst address
     * @param data delegate call's data for the new implementation
     */
    function subUpgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
}
