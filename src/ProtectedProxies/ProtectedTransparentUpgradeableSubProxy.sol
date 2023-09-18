// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import "openzeppelin/Proxy/transparent/TransparentUpgradeableProxy.sol";

import {SphereXProtectedSubProxy} from "../SphereXProtectedSubProxy.sol";
import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";


contract ProtectedTransparentUpgradeableSubProxy is SphereXProtectedSubProxy, TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        SphereXProtectedSubProxy(msg.sender, address(0), address(0), _logic, admin_)
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    function _fallback() internal virtual override(Proxy, TransparentUpgradeableProxy) {
        TransparentUpgradeableProxy._fallback();
    }

    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }

    function _implementation() internal view virtual override(SphereXProtectedSubProxy, ERC1967Proxy) returns (address impl) {
        return SphereXProtectedSubProxy._implementation();
    }
}