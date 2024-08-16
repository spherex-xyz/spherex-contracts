// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ISphereXEngine, ModifierLocals} from "./ISphereXEngine.sol";

/**
 * @title SphereX base Customer contract template
 */
/// @custom:oz-upgrades-unsafe-allow constructor
abstract contract SphereXConfiguration {
    /**
     * @dev we would like to avoid occupying storage slots
     * @dev to easily incorporate with existing contracts
     */
    bytes32 private constant SPHEREX_ADMIN_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.spherex")) - 1);
    bytes32 private constant SPHEREX_PENDING_ADMIN_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.pending")) - 1);
    bytes32 private constant SPHEREX_OPERATOR_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.operator")) - 1);
    bytes32 private constant SPHEREX_ENGINE_STORAGE_SLOT =
        bytes32(uint256(keccak256("eip1967.spherex.spherex_engine")) - 1);

    event ChangedSpherexOperator(address oldSphereXAdmin, address newSphereXAdmin);
    event ChangedSpherexEngineAddress(address oldEngineAddress, address newEngineAddress);
    event SpherexAdminTransferStarted(address currentAdmin, address pendingAdmin);
    event SpherexAdminTransferCompleted(address oldAdmin, address newAdmin);
    event NewAllowedSenderOnchain(address sender);

    /**
     * @dev used when the client doesn't use a proxy
     */
    constructor(address admin, address operator, address engine) {
        __SphereXProtectedBase_init(admin, operator, engine);
    }

    /**
     * @dev used when the client uses a proxy - should be called by the inhereter initialization
     */
    function __SphereXProtectedBase_init(address admin, address operator, address engine) internal virtual {
        _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, admin);
        emit SpherexAdminTransferCompleted(address(0), admin);

        _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, operator);
        emit ChangedSpherexOperator(address(0), operator);

        _checkSphereXEngine(engine);
        _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, engine);
        emit ChangedSpherexEngineAddress(address(0), engine);
    }

    // ============ Helper functions ============

    function _sphereXEngine() internal view returns (ISphereXEngine) {
        return ISphereXEngine(_getAddress(SPHEREX_ENGINE_STORAGE_SLOT));
    }

    /**
     * Stores a new address in an arbitrary slot
     * @param slot where to store the address
     * @param newAddress address to store in given slot
     */
    function _setAddress(bytes32 slot, address newAddress) internal {
        // solhint-disable-next-line no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            sstore(slot, newAddress)
        }
    }

    /**
     * Returns an address from an arbitrary slot.
     * @param slot to read an address from
     */
    function _getAddress(bytes32 slot) internal view returns (address addr) {
        // solhint-disable-next-line no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            addr := sload(slot)
        }
    }

    // ============ Local modifiers ============

    modifier onlySphereXAdmin() {
        require(msg.sender == _getAddress(SPHEREX_ADMIN_STORAGE_SLOT), "SphereX error: admin required");
        _;
    }

    modifier onlySpherexOperator() {
        require(msg.sender == _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT), "SphereX error: operator required");
        _;
    }

    modifier returnsIfNotActivated() {
        if (address(_sphereXEngine()) == address(0)) {
            return;
        }

        _;
    }

    // ============ Management ============

    /**
     * Returns the currently pending admin address, the one that can call acceptSphereXAdminRole to become the admin.
     * @dev Could not use OZ Ownable2Step because the client's contract might use it.
     */
    function pendingSphereXAdmin() public view returns (address) {
        return _getAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT);
    }

    /**
     * Returns the current admin address, the one that can call acceptSphereXAdminRole to become the admin.
     * @dev Could not use OZ Ownable2Step because the client's contract might use it.
     */
    function sphereXAdmin() public view returns (address) {
        return _getAddress(SPHEREX_ADMIN_STORAGE_SLOT);
    }

    /**
     * Returns the current operator address.
     */
    function sphereXOperator() public view returns (address) {
        return _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT);
    }

    /**
     * Returns the current engine address.
     */
    function sphereXEngine() public view returns (address) {
        return _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
    }

    /**
     * Setting the address of the next admin. this address will have to accept the role to become the new admin.
     * @dev Could not use OZ Ownable2Step because the client's contract might use it.
     */
    function transferSphereXAdminRole(address newAdmin) public virtual onlySphereXAdmin {
        _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, newAdmin);
        emit SpherexAdminTransferStarted(sphereXAdmin(), newAdmin);
    }

    /**
     * Accepting the admin role and completing the transfer.
     * @dev Could not use OZ Ownable2Step because the client's contract might use it.
     */
    function acceptSphereXAdminRole() public virtual {
        require(pendingSphereXAdmin() == msg.sender, "SphereX error: not the pending account");
        address oldAdmin = sphereXAdmin();
        _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, msg.sender);
        _setAddress(SPHEREX_PENDING_ADMIN_STORAGE_SLOT, address(0));
        emit SpherexAdminTransferCompleted(oldAdmin, msg.sender);
    }

    /**
     *
     * @param newSphereXOperator new address of the new operator account
     */
    function changeSphereXOperator(address newSphereXOperator) external onlySphereXAdmin {
        address oldSphereXOperator = _getAddress(SPHEREX_OPERATOR_STORAGE_SLOT);
        _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, newSphereXOperator);
        emit ChangedSpherexOperator(oldSphereXOperator, newSphereXOperator);
    }

    /**
     * Checks the given address implements ISphereXEngine or is address(0)
     * @param newSphereXEngine new address of the spherex engine
     */
    function _checkSphereXEngine(address newSphereXEngine) private view {
        require(
            newSphereXEngine == address(0)
                || ISphereXEngine(newSphereXEngine).supportsInterface(type(ISphereXEngine).interfaceId),
            "SphereX error: not a SphereXEngine"
        );
    }

    /**
     *
     * @param newSphereXEngine new address of the spherex engine
     * @dev this is also used to actually enable the defense
     * (because as long is this address is 0, the protection is disabled).
     */
    function changeSphereXEngine(address newSphereXEngine) external onlySpherexOperator {
        _checkSphereXEngine(newSphereXEngine);
        address oldEngine = _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
        _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, newSphereXEngine);
        emit ChangedSpherexEngineAddress(oldEngine, newSphereXEngine);
    }
    // ============ Engine interaction ============

    function _addAllowedSenderOnChain(address newSender) internal {
        ISphereXEngine engine = _sphereXEngine();
        if (address(engine) != address(0)) {
            engine.addAllowedSenderOnChain(newSender);
            emit NewAllowedSenderOnchain(newSender);
        }
    }
}
