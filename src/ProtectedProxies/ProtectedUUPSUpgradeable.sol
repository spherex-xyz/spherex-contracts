// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "openzeppelin/Proxy/utils/UUPSUpgradeable.sol";
import {Address} from "openzeppelin/utils/Address.sol";

abstract contract ProtectedUUPSUpgradeable is UUPSUpgradeable {
    // TODO - duplicated code from SphereXProtectedSubProxy (and inherited contracts like base)
    bytes32 private constant _SPHEREX_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.implementation_slot")) - 1);

    function _setAddress(bytes32 slot, address newAddress) private {
        assembly {
            sstore(slot, newAddress)
        }
    }

    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT; // Return ERC1967 original's slot to pass the old imp ERC1822 check
    }

    function upgradeTo(address newImplementation) public virtual override {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual override {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    function subUpgradeTo(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
    }

    function subUpgradeToAndCall(address newImplementation, bytes memory data) external {
        _authorizeUpgrade(newImplementation);
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }
}
