// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import "openzeppelin/Proxy/transparent/TransparentUpgradeableProxy.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";

contract ProtectedTransparentUpgradeableProxy is SphereXProtectedProxy, TransparentUpgradeableProxy {
    constructor(address _logic, address admin_, bytes memory _data)
        SphereXProtectedProxy(msg.sender, address(0), address(0))
        TransparentUpgradeableProxy(_logic, admin_, _data)
    {}

    function _fallback() internal virtual override(Proxy, TransparentUpgradeableProxy) {
        TransparentUpgradeableProxy._fallback();
    }

    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }
}
