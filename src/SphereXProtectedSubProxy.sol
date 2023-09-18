// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProtectedProxy} from "./SphereXProtectedProxy.sol";

abstract contract SphereXProtectedSubProxy is SphereXProtectedProxy {

    bytes32 private constant _SPHEREX_IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.spherex.implementation_slot")) - 1);
    bytes32 private constant _SPHEREX_PROXT_ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.spherex.proxy_admin_slot")) - 1);

    constructor(address admin, address operator, address engine, address _logic, address _proxy_admin) SphereXProtectedProxy(admin, operator, engine) {
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, _logic);
        _setAddress(_SPHEREX_PROXT_ADMIN_SLOT, _proxy_admin);
    }

    function _implementation() internal view virtual override returns (address impl) {
        return _getAddress(_SPHEREX_IMPLEMENTATION_SLOT);
    }
}