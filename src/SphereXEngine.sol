// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.0;

import "./engine_deps/AccessControlDefaultAdminRules.sol";
import "./ISphereXEngine.sol";

/**
 * @title SphereX Engine
 * @notice Gathers information about an ongoing transaction and reverts if it seems malicious
 */
contract SphereXEngine is ISphereXEngine, AccessControlDefaultAdminRules {
    bytes8 private _engineRules; // By default the contract will be deployed with no guarding rules activated
    mapping(address => bool) private _allowedSenders;
    mapping(uint256 => bool) private _allowedPatterns;

    // We initialize the next variables to 1 and not 0 to save gas costs on future transactions
    uint256 private _currentPattern = PATTERN_START;
    uint256 private _callDepth = DEPTH_START;

    // Represent keccak256(abi.encode(block.number, tx.origin))
    bytes32 private _currentBlockOriginHash = bytes32(uint256(1));

    uint256 private constant PATTERN_START = 1;
    uint256 private constant DEPTH_START = 1;
    bytes32 private constant DEACTIVATED = bytes32(0);

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    constructor() AccessControlDefaultAdminRules(1 days, msg.sender) {
        grantRole(OPERATOR_ROLE, msg.sender);
    }

    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Operator Required");
        _;
    }

    modifier returnsIfNotActivated() {
        if (_engineRules == DEACTIVATED) {
            return;
        }

        _;
    }

    modifier onlyApprovedSenders() {
        require(_allowedSenders[msg.sender], "!SX:SENDERS");
        _;
    }

    // ============ Management ============

    /**
     * Activate the guardian rules
     * @param rules bytes8 representing the new rules to activate.
     */
    function activateRules(bytes8 rules) external onlyOperator {
        _engineRules = rules;
    }

    /**
     * Deactivates the engine, the calls will return without being checked
     */
    function deactivateRules() external onlyOperator {
        _engineRules = bytes8(uint64(0));
    }

    /**
     * Adds addresses that will be served by this engine. An address that was never added will get a revert if it tries to call the engine.
     * @param senders list of address to add to the set of allowed addresses
     */
    function addAllowedSender(address[] calldata senders) external onlyOperator {
        for (uint256 i = 0; i < senders.length; ++i) {
            _allowedSenders[senders[i]] = true;
        }
    }

    /**
     * Removes address so that they will not get served when calling the engine. Transaction from these addresses will get reverted.
     * @param senders list of address to stop service.
     */
    function removeAllowedSender(address[] calldata senders) external onlyOperator {
        for (uint256 i = 0; i < senders.length; ++i) {
            _allowedSenders[senders[i]] = false;
        }
    }

    /**
     * Add allowed patterns - these are representation of allowed flows of transactions, and prefixes of these flows
     * @param patterns list of flows to allow as valid and non-malicious flows
     */
    function addAllowedPatterns(uint256[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            _allowedPatterns[patterns[i]] = true;
        }
    }

    /**
     * Remove allowed patterns - these are representation flows of transactions, and prefixes of these flows,
     * that are no longer considered valid and benign
     * @param patterns list of flows that no longer considered valid and non-malicious
     */
    function removeAllowedPatterns(uint256[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            _allowedPatterns[patterns[i]] = false;
        }
    }

    // ============ CF ============

    /**
     * Checks if rule1 is activated.
     */
    function _isRule1Activated() private view returns (bool) {
        return (_engineRules & bytes8(uint64(1))) > 0;
    }

    /**
     * Checks if rule2 us activated.
     */
    function _isRule2Activated() private view returns (bool) {
        return (_engineRules & bytes8(uint64(2))) > 0;
    }

    /**
     * update the current CF pattern with a new number,
     * when exiting a function we check the validity of the pattern.
     * @param num element to add to the flow. Poistive number represents start of function, negative exit.
     * @param forceCheck force the check of the current pattern, even if normal test conditions don't exist.
     */
    function _addCFElement(int16 num, bool forceCheck) private {
        // Upon entry to a new function if we are configured to PrefixTxFlow we should check if we are at the same transaction
        // or a new one. in case of a new one we need to reinit the _currentPattern, and save
        // the new transaction "hash" (block.number+tx.origin)
        if (num > 0 && _isRule2Activated()) {
            bytes32 currentBlockOriginHash = keccak256(abi.encode(block.number, tx.origin));
            if (currentBlockOriginHash != _currentBlockOriginHash) {
                _currentPattern = PATTERN_START;
                _currentBlockOriginHash = currentBlockOriginHash;
            }
        }

        _currentPattern = uint256(keccak256(abi.encode(num, _currentPattern)));

        if (num > 0) {
            ++_callDepth;
        } else if (num < 0) {
            --_callDepth;
        } else {
            revert("!SX:ERROR");
        }

        if ((_callDepth == DEPTH_START) || (forceCheck)) {
            _checkCallFlow();
        }

        // If we are configured to CF then if we reach depth == DEPTH_START we should reinit the
        // _currentPattern
        if (_isRule1Activated() && _callDepth == DEPTH_START) {
            _currentPattern = PATTERN_START;
        }
    }

    /**
     * Check if the current call flow pattern (that is, the result of the rolling hash) is an allowed pattern.
     */
    function _checkCallFlow() private view {
        require(_allowedPatterns[_currentPattern], "!SX:DETECTED");
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before the body of the function.
     * This is used only for external call functions.
     * @param num id of function to add. Should be positive
     * @param sender For future use
     * @param data For future use
     * @return result in the future will return insturction on what storage slots to gather, but not used for now
     */
    function sphereXValidatePre(int16 num, address sender, bytes calldata data)
        external
        override
        returnsIfNotActivated // may return empty bytes32[]
        onlyApprovedSenders
        returns (bytes32[] memory result)
    {
        _addCFElement(num, false);
        return result;
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract after the body of the function.
     * This is used only for external call functions (that is, external, and public when called outside the contract).
     * @param num id of function to add. Should be negative
     * @param valuesBefore For future use
     * @param valuesAfter For future use
     */
    function sphereXValidatePost(
        int16 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external override returnsIfNotActivated onlyApprovedSenders {
        _addCFElement(num, true);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before and after the body of the function.
     * This is used only for internal function calls (internal and private functions).
     * @param num id of function to add.
     */
    function sphereXValidateInternalPre(int16 num) external override returnsIfNotActivated onlyApprovedSenders {
        _addCFElement(num, false);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before and after the body of the function.
     * This is used only for internal function calls (internal and private functions).
     * @param num id of function to add.
     */
    function sphereXValidateInternalPost(int16 num, uint256 gas)
        external
        override
        returnsIfNotActivated
        onlyApprovedSenders
    {
        _addCFElement(num, false);
    }
}
