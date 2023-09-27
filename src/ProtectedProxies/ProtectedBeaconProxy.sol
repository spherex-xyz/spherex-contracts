// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {BeaconProxy, Proxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";

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
}
