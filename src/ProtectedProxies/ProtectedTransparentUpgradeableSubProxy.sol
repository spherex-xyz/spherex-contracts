// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {
    TransparentUpgradeableProxy,
    Proxy,
    ERC1967Proxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

import {
    SphereXProtectedSubProxy, SphereXProtectedProxy, ISphereXProtectedSubProxy
} from "../SphereXProtectedSubProxy.sol";

/**
 * @dev TransparentUpgradeableProxy implementation with spherex's protection designed to be under another proxy
 */
contract ProtectedTransparentUpgradeableSubProxy is SphereXProtectedSubProxy, TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        SphereXProtectedSubProxy()
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    /**
     * @dev Like in TransparentUpgradeableProxy._fallback, the spherex's admin is directed to the management functions.
     */
    function _fallback() internal virtual override(Proxy, TransparentUpgradeableProxy) {
        if (msg.sender == sphereXAdmin()) {
            if (msg.sig == ISphereXProtectedSubProxy.subUpgradeTo.selector) {
                address newImplementation = abi.decode(msg.data[4:], (address));
                subUpgradeTo(newImplementation);
            } else if (msg.sig == ISphereXProtectedSubProxy.subUpgradeToAndCall.selector) {
                (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
                subUpgradeToAndCall(newImplementation, data);
            } else {
                revert("ProtectedTransparentUpgradeableSubProxy: admin cannot fallback to sub-proxy target");
            }
        } else {
            TransparentUpgradeableProxy._fallback();
        }
    }

    /**
     * @dev This is used since both SphereXProtectedSubProxy and TransparentUpgradeableProxy implements Proxy.sol _delegate.
     */
    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }

    /**
     * @dev This is used since both SphereXProtectedSubProxy and TransparentUpgradeableProxy implements Proxy.sol _implementation.
     */
    function _implementation()
        internal
        view
        virtual
        override(SphereXProtectedSubProxy, ERC1967Proxy)
        returns (address impl)
    {
        return SphereXProtectedSubProxy._implementation();
    }
}
