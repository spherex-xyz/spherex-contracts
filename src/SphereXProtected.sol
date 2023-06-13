// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {ISphereXEngine} from "./ISphereXEngine.sol";

/**
 * @title SphereX base Customer contract template
 * @dev notice this is an abstract
 */
abstract contract SphereXProtected {
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

    /**
     * @dev this struct is used to reduce the stack usage of the modifiers.
     */
    struct ModifierLocals {
        bytes32[] storageSlots;
        bytes32[] valuesBefore;
        uint256 gas;
    }

    event ChangedSpherexOperator(address oldSphereXAdmin, address newSphereXAdmin);
    event ChangedSpherexEngineAddress(address oldEngineAddress, address newEngineAddress);
    event SpherexAdminTransferStarted(address currentAdmin, address pendingAdmin);
    event SpherexAdminTransferCompleted(address oldAdmin, address newAdmin);

    /**
     * @dev used when the client doesn't use a proxy
     * @notice constructor visibility is required to support all compiler versions
     */
    constructor() internal {
        __SphereXProtected_init();
    }

    /**
     * @dev used when the client uses a proxy - should be called by the inhereter initialization
     */
    function __SphereXProtected_init() internal {
        if (_getAddress(SPHEREX_ADMIN_STORAGE_SLOT) == address(0)) {
            _setAddress(SPHEREX_ADMIN_STORAGE_SLOT, msg.sender);
            emit SpherexAdminTransferCompleted(address(0), msg.sender);
        }
        if (_getAddress(SPHEREX_OPERATOR_STORAGE_SLOT) == address(0)) {
            _setAddress(SPHEREX_OPERATOR_STORAGE_SLOT, msg.sender);
            emit ChangedSpherexOperator(address(0), msg.sender);
        }
    }

    // ============ Helper functions ============

    function _sphereXEngine() private view returns (ISphereXEngine) {
        return ISphereXEngine(_getAddress(SPHEREX_ENGINE_STORAGE_SLOT));
    }

    /**
     * Stores a new address in an arbitrary slot
     * @param slot where to store the address
     * @param newAddress address to store in given slot
     */
    function _setAddress(bytes32 slot, address newAddress) private {
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
    function _getAddress(bytes32 slot) private view returns (address addr) {
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

    modifier onlyOperator() {
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
     *
     * @param newSphereXEngine new address of the spherex engine
     * @dev this is also used to actually enable the defense
     * (because as long is this address is 0, the protection is disabled).
     */
    function changeSphereXEngine(address newSphereXEngine) external onlyOperator {
        require(
            newSphereXEngine == address(0)
                || ISphereXEngine(newSphereXEngine).supportsInterface(type(ISphereXEngine).interfaceId),
            "!SX: Not a SphereXEngine"
        );
        address oldEngine = _getAddress(SPHEREX_ENGINE_STORAGE_SLOT);
        _setAddress(SPHEREX_ENGINE_STORAGE_SLOT, newSphereXEngine);
        emit ChangedSpherexEngineAddress(oldEngine, newSphereXEngine);
    }

    // ============ Hoo ks ============

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called before the code of a function.
     * @param num function identifier
     * @param isExternalCall set to true if this was called externally
     *  or a 'public' function from another address
     */
    function _sphereXValidatePre(int256 num, bool isExternalCall)
        private
        returnsIfNotActivated
        returns (ModifierLocals memory locals)
    {
        ISphereXEngine sphereXEngine = _sphereXEngine();
        if (isExternalCall) {
            locals.storageSlots = sphereXEngine.sphereXValidatePre(num, msg.sender, msg.data);
            locals.valuesBefore = _readStorage(locals.storageSlots);
        } else {
            sphereXEngine.sphereXValidateInternalPre(num);
        }
        locals.gas = gasleft();
        return locals;
    }

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called after the code of a function.
     * @param num function identifier
     * @param isExternalCall set to true if this was called externally
     *  or a 'public' function from another address
     */
    function _sphereXValidatePost(int256 num, bool isExternalCall, ModifierLocals memory locals)
        private
        returnsIfNotActivated
    {
        uint256 gas = locals.gas - gasleft();
        ISphereXEngine sphereXEngine = _sphereXEngine();
        if (isExternalCall) {
            bytes32[] memory valuesAfter;
            valuesAfter = _readStorage(locals.storageSlots);
            sphereXEngine.sphereXValidatePost(num, gas, locals.valuesBefore, valuesAfter);
        } else {
            sphereXEngine.sphereXValidateInternalPost(num, gas);
        }
    }

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called before the code of a function.
     * @param num function identifier
     * @return gas used before calling the original function body
     */
    function _sphereXValidateInternalPre(int256 num) private returnsIfNotActivated returns(uint256){
        _sphereXEngine().sphereXValidateInternalPre(num);
        return gasleft();
    }

    /**
     * @dev internal function for engine communication. We use it to reduce contract size.
     *  Should be called after the code of a function.
     * @param num function identifier
     * @param gas the gas saved before the original function body run
     */
    function _sphereXValidateInternalPost(int256 num, uint256 gas) private returnsIfNotActivated {
        _sphereXEngine().sphereXValidateInternalPost(num, gas - gasleft());
    }

    /**
     *  @dev Modifier to be incorporated in all internal protected non-view functions
     */
    modifier sphereXGuardInternal(int256 num) {
        uint256 gas = _sphereXValidateInternalPre(num);
        _;
        _sphereXValidateInternalPost(-num, gas);
    }

    /**
     *  @dev Modifier to be incorporated in all external protected non-view functions
     */
    modifier sphereXGuardExternal(int256 num) {
        ModifierLocals memory locals = _sphereXValidatePre(num, true);
        _;
        _sphereXValidatePost(-num, true, locals);
    }

    /**
     *  @dev Modifier to be incorporated in all public protected non-view functions
     */
    modifier sphereXGuardPublic(int256 num, bytes4 selector) {
        ModifierLocals memory locals = _sphereXValidatePre(num, msg.sig == selector);
        _;
        _sphereXValidatePost(-num, msg.sig == selector, locals);
    }

    // ============ Internal Storage logic ============

    /**
     * Internal function that reads values from given storage slots and returns them
     * @param storageSlots list of storage slots to read
     * @return list of values read from the various storage slots
     */
    function _readStorage(bytes32[] memory storageSlots) internal view returns (bytes32[] memory) {
        uint256 arrayLength = storageSlots.length;
        bytes32[] memory values = new bytes32[](arrayLength);
        // create the return array data

        for (uint256 i = 0; i < arrayLength; i++) {
            bytes32 slot = storageSlots[i];
            bytes32 temp_value;
            // solhint-disable-next-line no-inline-assembly
            // slither-disable-next-line assembly
            assembly {
                temp_value := sload(slot)
            }

            values[i] = temp_value;
        }
        return values;
    }
}
