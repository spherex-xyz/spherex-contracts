// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy, Proxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";

/**
 * @title TransparentUpgradeableProxy implementation with spherex's protection
 */
contract ProtectedTransparentUpgradeableProxy is SphereXProtectedProxy, TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        SphereXProtectedProxy(msg.sender, address(0), address(0))
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    /**
     * @dev This is used since both SphereXProtectedProxy and TransparentUpgradeableProxy implements Proxy.sol _fallback.
     */
    function _fallback() internal virtual override(Proxy, TransparentUpgradeableProxy) {
        TransparentUpgradeableProxy._fallback();
    }

    /**
     * @dev This is used since both SphereXProtectedProxy and TransparentUpgradeableProxy implements Proxy.sol _delegate.
     */
    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }
}
