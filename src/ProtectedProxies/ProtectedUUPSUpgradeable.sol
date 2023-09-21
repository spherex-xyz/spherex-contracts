// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {UUPSUpgradeable} from "openzeppelin/Proxy/utils/UUPSUpgradeable.sol";
import {Address} from "openzeppelin/utils/Address.sol";

/**
 * @dev UUPSUpgradeable implementation designed for implementations under SphereX's ProtectedERC1967SubProxy
 */
abstract contract ProtectedUUPSUpgradeable is UUPSUpgradeable {
    address private immutable _self = address(this);

    bytes32 private constant _SPHEREX_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.implementation_slot")) - 1);

    /**
     * Sets an address value in a given storage slot
     * @param slot to insert the given addess in
     * @param newAddress to be inserted in the given slot
     */
    function _setAddress(bytes32 slot, address newAddress) private {
        assembly {
            sstore(slot, newAddress)
        }
    }

    /**
     * Returns an address from an arbitrary slot.
     * @param slot to read an address from
     */
    function _getAddress(bytes32 slot) internal view returns (address addr) {
        assembly {
            addr := sload(slot)
        }
    }

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * the sub-proxy contract with an implementation (as defined in SphereXProtectedSubProxy) pointing to self.
     */
    modifier onlySubProxy() {
        require(address(this) != _self, "Function must be called through delegatecall");
        require(_getAddress(_SPHEREX_IMPLEMENTATION_SLOT) == _self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Return ERC1967 original's slot to pass the old imp ERC1822 check
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Overrid with the same implementation replacing the onlyProxy modifier since is being called under a sub-proxy
     */
    function upgradeTo(address newImplementation) public virtual override onlySubProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Overrid with the same implementation replacing the onlyProxy modifier since is being called under a sub-proxy
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public
        payable
        virtual
        override
        onlySubProxy
    {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * Upgrades the logic in our arbitrary slot
     * @param newImplementation new dst address
     */
    function subUpgradeTo(address newImplementation) external {
        _authorizeUpgrade(newImplementation);
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
    }

    /**
     * Upgrades the logic in our arbitrary slot and delegates to the new implementation
     * @param newImplementation new dst address
     * @param data delegate call's data for the new implementation
     */
    function subUpgradeToAndCall(address newImplementation, bytes memory data) external {
        _authorizeUpgrade(newImplementation);
        _setAddress(_SPHEREX_IMPLEMENTATION_SLOT, newImplementation);
        Address.functionDelegateCall(newImplementation, data);
    }
}
