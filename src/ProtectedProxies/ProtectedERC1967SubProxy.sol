// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ERC1967Proxy, Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC1822Proxiable} from "openzeppelin/interfaces/draft-IERC1822.sol";

import {SphereXProtectedSubProxy, SphereXProtectedProxy} from "../SphereXProtectedSubProxy.sol";

/**
 * @dev ERC1967Proxy implementation with spherex's protection designed to be under another proxy
 */
contract ProtectedERC1967SubProxy is SphereXProtectedSubProxy, ERC1967Proxy, IERC1822Proxiable {
    constructor(address _logic, bytes memory _data) SphereXProtectedSubProxy() ERC1967Proxy(_logic, _data) {}

    /**
     * @dev Return ERC1967 original's slot to pass the old imp ERC1822 check
     */
    function proxiableUUID() external view virtual override returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev This is used since both SphereXProtectedSubProxy and ERC1967Proxy implements Proxy.sol _delegate.
     */
    function _delegate(address implementation) internal virtual override(Proxy, SphereXProtectedProxy) {
        SphereXProtectedProxy._delegate(implementation);
    }

    /**
     * @dev This is used since both SphereXProtectedSubProxy and ERC1967Proxy implements Proxy.sol _implementation.
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
