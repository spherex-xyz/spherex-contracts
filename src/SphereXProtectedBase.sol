// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ISphereXEngine, ModifierLocals} from "./ISphereXEngine.sol";
import {SphereXProtectedBaseUpgradeable} from "./SphereXProtectedBaseUpgradeable.sol";

/**
 * @title SphereX base Customer contract template
 */
abstract contract SphereXProtectedBase is SphereXProtectedBaseUpgradeable {
    /**
     * @dev used when the client doesn't use a proxy
     */
    constructor(address admin, address operator, address engine) {
        __SphereXProtectedBase_init(admin, operator, engine);
    }
}
