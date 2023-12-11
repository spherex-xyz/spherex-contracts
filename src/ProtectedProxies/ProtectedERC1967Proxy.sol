// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ERC1967Proxy, Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {SphereXProtectedProxy} from "../SphereXProtectedProxy.sol";

/**
 * @title ERC1967Proxy implementation with spherex's protection
 */
contract ProtectedERC1967Proxy is SphereXProtectedProxy, ERC1967Proxy {
    constructor(address _logic, bytes memory _data)
        SphereXProtectedProxy(msg.sender, address(0), address(0))
        ERC1967Proxy(_logic, _data)
    {}

    /**
     * @dev This is used since both SphereXProtectedProxy and ERC1967Proxy implements Proxy.sol _delegate.
     */
    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }
}
