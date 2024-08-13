// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";

/**
 * @title SphereX minimal proxy contract (cannot be upgraded) which implements OZ's Proxy intereface.
 */
contract ProtetedMinimalProxy is SphereXProtectedProxy {
    address immutable _imp;

    constructor(address admin, address operator, address engine, address implementation)
        SphereXProtectedProxy(admin, operator, engine)
    {
        _imp = implementation;
    }

    /**
     * Overrider the _implementation method from proxy
     */
    function _implementation() internal view virtual override returns (address) {
        return _imp;
    }
}
