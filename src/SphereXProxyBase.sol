// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProxyBaseUpgradeable} from "./SphereXProxyBaseUpgradeable.sol";

contract SphereXProxyBase is SphereXProxyBaseUpgradeable {
    constructor(address admin, address operator, address engine) {
        __SphereXProtectedBase_init(admin, operator, engine);
    }
}
