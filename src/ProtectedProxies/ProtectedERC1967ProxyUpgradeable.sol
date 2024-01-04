// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ERC1967Upgrade} from "openzeppelin/proxy/ERC1967/ERC1967Upgrade.sol";

import {SphereXProtectedProxyUpgradeable} from "../SphereXProtectedProxyUpgradeable.sol";

import {SphereXInitializable} from "../Utils/SphereXInitializable.sol";

/**
 * @title ERC1967Proxy implementation with spherex's protection
 */
contract ProtectedERC1967ProxyUpgradeable is SphereXProtectedProxyUpgradeable, ERC1967Upgrade, SphereXInitializable {
    function initialize(address _logic, bytes calldata _data) external payable initializer {
        require(_implementation() == address(0), "already initialized");
        __SphereXProtectedBase_init(tx.origin, address(0), address(0));
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}
