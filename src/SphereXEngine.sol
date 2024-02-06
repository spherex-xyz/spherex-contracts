// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {AccessControlDefaultAdminRules} from "openzeppelin/access/AccessControlDefaultAdminRules.sol";
import {ISphereXEngine} from "./ISphereXEngine.sol";
import "forge-std/console.sol";
/**
 * @title SphereX Engine
 * @notice Gathers information about an ongoing transaction and reverts if it seems malicious
 */

contract SphereXEngine is ISphereXEngine, AccessControlDefaultAdminRules {
    // the following are packed together for slot optimization and gas saving
    struct FlowConfiguration {
        uint16 depth;
        uint8 reserved;
        uint8 currentGasStrikes;
        bool enforce;
        uint216 pattern;
    }

    // the following are packed together for slot optimization and gas saving
    struct EngineConfig {
        bytes8 rules;
        // The next variable is not a config but we place it here to save gas
        // Represent bytes16(keccak256(abi.encode(block.number, tx.origin, block.difficulty, block.timestamp)))
        bytes16 txBoundaryHash;
        uint16 gasStrikeOuts;
        // if true we are adding some extra stuff that costs gas for simulation purposes
        // there is no way to turn this on except in simmulation!
        bool isSimulator;
        bytes5 reserved;
    }

    struct GasExactFunctions {
        uint256 functionIndex;
        uint32[] gasExact;
    }

    EngineConfig internal _engineConfig = EngineConfig(0, bytes16(uint128(1)), 0, false, 0);
    mapping(address => bool) internal _allowedSenders;
    mapping(uint216 => bool) internal _allowedPatterns;

    FlowConfiguration internal _flowConfig =
        FlowConfiguration(DEPTH_START, uint8(0), GAS_STRIKES_START, false, PATTERN_START);

    // Please add new storage variables after this point so the tests wont fail!

    mapping(uint256 => bool) internal _enforceFunction;
    mapping(uint256 => bool) internal _allowedFunctionsExactGas;
    mapping(uint256 => bool) internal _includedFunctions;
    uint32[30] internal _currentGasStack;

    uint8 internal constant GAS_STRIKES_START = 0;
    uint216 internal constant PATTERN_START = 1;
    uint16 internal constant DEPTH_START = 1;
    bytes8 internal constant DEACTIVATED = bytes8(0);
    bytes8 internal constant CF = bytes8(uint64(1));
    bytes8 internal constant TXF = bytes8(uint64(2));
    bytes8 internal constant SELECTIVE_TXF = bytes8(uint64(4));
    bytes8 internal constant GAS = bytes8(uint64(8));
    bytes8 internal constant GAS_AND_SELECTIVE_TXF = GAS | SELECTIVE_TXF;
    bytes8 internal constant CF_AND_TXF_TOGETHER = CF | TXF;
    bytes8 internal constant CF_AND_SELECTIVE_TXF_TOGETHER = CF | SELECTIVE_TXF;
    bytes8 internal constant TXF_AND_SELECTIVE_TXF_TOGETHER = TXF | SELECTIVE_TXF;
    bytes8 internal constant FLOW_PROTECTION_MASK = TXF | SELECTIVE_TXF | CF;

    // the index of the addAllowedSenderOnChain in the call flow
    int256 internal constant ADD_ALLOWED_SENDER_ONCHAIN_INDEX = int256(uint256(keccak256("factory.allowed.sender")));

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SENDER_ADDER_ROLE = keccak256("SENDER_ADDER_ROLE");

    constructor() AccessControlDefaultAdminRules(1 days, msg.sender) {
        grantRole(OPERATOR_ROLE, msg.sender);

        for (uint32 i; i < 30; i++) {
            _currentGasStack[i] = 1;
        }
    }

    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "SphereX error: operator required");
        _;
    }

    modifier onlySenderAdderRole() {
        require(hasRole(SENDER_ADDER_ROLE, msg.sender), "SphereX error: sender adder required");
        _;
    }

    event TxStartedAtIrregularDepth();
    event ConfigureRules(bytes8 oldRules, bytes8 newRules);
    event AddedAllowedSenders(address[] senders);
    event AddedAllowedSenderOnchain(address sender);
    event RemovedAllowedSenders(address[] senders);
    event AddedAllowedPatterns(uint216[] patterns);
    event RemovedAllowedPatterns(uint216[] patterns);
    event AddedEnforcedFunctions(uint256[] functions);
    event RemovedEnforcedFunctions(uint256[] functions);
    event AddGasExactFunctions(GasExactFunctions[] gasFunctions);
    event RemoveGasExactFunctions(GasExactFunctions[] gasFunctions);
    event ExcludeFunctionsFromGas(uint256[] functions);
    event InclueFunctionsInGas(uint256[] functions);

    // ============ Management ============

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlDefaultAdminRules, ISphereXEngine)
        returns (bool)
    {
        return interfaceId == type(ISphereXEngine).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * Activate the guardian rules
     * @param rules bytes8 representing the new rules to activate.
     */
    function configureRules(bytes8 rules) external onlyOperator {
        require(CF_AND_TXF_TOGETHER & rules != CF_AND_TXF_TOGETHER, "SphereX error: illegal rules combination");
        require(
            CF_AND_SELECTIVE_TXF_TOGETHER & rules != CF_AND_SELECTIVE_TXF_TOGETHER,
            "SphereX error: illegal rules combination"
        );
        require(
            TXF_AND_SELECTIVE_TXF_TOGETHER & rules != TXF_AND_SELECTIVE_TXF_TOGETHER,
            "SphereX error: illegal rules combination"
        );
        require(uint64(rules) <= uint64(GAS_AND_SELECTIVE_TXF), "SphereX error: illegal rules combination");
        bytes8 oldRules = _engineConfig.rules;
        _engineConfig.rules = rules;
        emit ConfigureRules(oldRules, rules);
    }

    /**
     * Deactivates the engine, the calls will return without being checked
     */
    function deactivateAllRules() external onlyOperator {
        bytes8 oldRules = _engineConfig.rules;
        _engineConfig.rules = DEACTIVATED;
        emit ConfigureRules(oldRules, 0);
    }

    /**
     * Adds addresses that will be served by this engine. An address that was never added will get a revert if it tries to call the engine.
     * @param senders list of address to add to the set of allowed addresses
     */
    function addAllowedSender(address[] calldata senders) external onlyOperator {
        for (uint256 i = 0; i < senders.length; ++i) {
            _allowedSenders[senders[i]] = true;
        }
        emit AddedAllowedSenders(senders);
    }

    /**
     * Removes address so that they will not get served when calling the engine. Transaction from these addresses will get reverted.
     * @param senders list of address to stop service.
     */
    function removeAllowedSender(address[] calldata senders) external onlyOperator {
        for (uint256 i = 0; i < senders.length; ++i) {
            _allowedSenders[senders[i]] = false;
        }
        emit RemovedAllowedSenders(senders);
    }

    /**
     * Adds address that will be served by this engine. An address that was never added will get a revert if it tries to call the engine.
     * @param sender address to add to the set of allowed addresses
     * @notice This function adds elements to the current pattern in order to guard itself from unwanted calls.
     * Lets say the client has a contract with SENDER_ADDER role and we approve only function indexed 1 to call addAllowedSenderOnChain.
     * We will allow the pattern [1, addAllowedSenderOnChain, -addAllowedSenderOnChain ,-1] and by doing so we guarantee no other function
     * will call addAllowedSenderOnChain.
     */
    function addAllowedSenderOnChain(address sender) external onlySenderAdderRole {
        _allowedSenders[sender] = true;
        emit AddedAllowedSenderOnchain(sender);
    }

    function grantSenderAdderRole(address newSenderAdder) external onlyOperator {
        _grantRole(SENDER_ADDER_ROLE, newSenderAdder);
    }

    /**
     * Add allowed patterns - these are representation of allowed flows of transactions, and prefixes of these flows
     * @param patterns list of flows to allow as valid and non-malicious flows
     */
    function addAllowedPatterns(uint216[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            _allowedPatterns[patterns[i]] = true;
        }
        emit AddedAllowedPatterns(patterns);
    }

    /**
     * Remove allowed patterns - these are representation flows of transactions, and prefixes of these flows,
     * that are no longer considered valid and benign
     * @param patterns list of flows that no longer considered valid and non-malicious
     */
    function removeAllowedPatterns(uint216[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            _allowedPatterns[patterns[i]] = false;
        }
        emit RemovedAllowedPatterns(patterns);
    }

    /**
     * Add functions for enforcment (apply to selective txf)
     * @param functions function indexes to enforce flows
     */
    function includeEnforcedFunctions(uint256[] calldata functions) external onlyOperator {
        for (uint256 i = 0; i < functions.length; ++i) {
            _enforceFunction[functions[i]] = true;
        }
        emit AddedEnforcedFunctions(functions);
    }

    /**
     * Remove functions for enforcment (apply to selective txf)
     * @param functions function indexes to stop enforcing flows
     */
    function excludeEnforcedFunctions(uint256[] calldata functions) external onlyOperator {
        for (uint256 i = 0; i < functions.length; ++i) {
            _enforceFunction[functions[i]] = false;
        }
        emit RemovedEnforcedFunctions(functions);
    }

    /**
     * Exclude functions from gas checks during transaction flow.
     * @param functions - list of functions that should be excluded from gas checks
     */
    function excludeFunctionsFromGas(uint256[] calldata functions) external onlyOperator {
        for (uint256 i = 0; i < functions.length; ++i) {
            _includedFunctions[functions[i]] = false;
        }
        emit ExcludeFunctionsFromGas(functions);
    }

    /**
     * Include functions for gas checks during transaction flow.
     * @param functions - list of functions that should be included for gas checks
     */
    function includeFunctionsInGas(uint256[] calldata functions) external onlyOperator {
        for (uint256 i = 0; i < functions.length; ++i) {
            _includedFunctions[functions[i]] = true;
        }
        emit InclueFunctionsInGas(functions);
    }

    /**
     * Add allowed gas exact functions - the allowd gas exact values for each function.
     * each exact gas value will be hashed with the function and be saved as a key to boolean value in _allowedFunctionsExactGas.
     * @param gasFunctions list of functions with their corresponding gas exact values.
     */
    function addGasExactFunctions(GasExactFunctions[] calldata gasFunctions) external onlyOperator {
        for (uint256 i = 0; i < gasFunctions.length; ++i) {
            for (uint256 j = 0; j < gasFunctions[i].gasExact.length; ++j) {
                _allowedFunctionsExactGas[uint256(
                    keccak256(abi.encode(gasFunctions[i].functionIndex, gasFunctions[i].gasExact[j]))
                )] = true;
            }
        }
        emit AddGasExactFunctions(gasFunctions);
    }

    /**
     * Remove allowed gas exact functions - the allowd gas exact values for each function.
     * each exact gas value will be hashed with the function and be saved as a key to boolean value in _allowedFunctionsExactGas.
     * @param gasFunctions list of functions with their corresponding gas exact values.
     */
    function removeGasExactFunctions(GasExactFunctions[] calldata gasFunctions) external onlyOperator {
        for (uint256 i = 0; i < gasFunctions.length; ++i) {
            for (uint256 j = 0; j < gasFunctions[i].gasExact.length; ++j) {
                _allowedFunctionsExactGas[uint256(
                    keccak256(abi.encode(gasFunctions[i].functionIndex, gasFunctions[i].gasExact[j]))
                )] = false;
            }
        }
        emit RemoveGasExactFunctions(gasFunctions);
    }

    /**
     * Set the new strike out liimit for the gas guardien.
     * @param newLimit the new strike out limit for the gas guardien.
     */
    function setGasStrikeOutsLimit(uint16 newLimit) external onlyOperator {
        _engineConfig.gasStrikeOuts = newLimit;
    }

    // ============ Guardians logic ============

    /**
     * Checks if CF is activated.
     */
    function _isCFActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(CF)) > 0;
    }

    /**
     * Checks if selective txf is activated.
     */
    function _isSelectiveTXFActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(SELECTIVE_TXF)) > 0;
    }

    /**
     * Checks if call flow is activated.
     */
    function _isTXFActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(TXF)) > 0;
    }

    /**
     * Checks if call flow is activated.
     */
    function _isFlowProtectionActivated(bytes8 rules) internal view returns (bool) {
        return (rules & FLOW_PROTECTION_MASK) > 0;
    }

    /**
     * Checks if gas function is activated.
     */
    function _isGasFuncActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(GAS)) > 0;
    }

    function _resetStateOnNewTx(bytes8 rules, FlowConfiguration memory flowConfig) private {
        // Upon entry to a new function we should check if we are at the same transaction
        // or a new one.
        bytes16 currentTxBoundaryHash =
            bytes16(keccak256(abi.encode(block.number, tx.origin, block.timestamp, block.difficulty)));
        if (currentTxBoundaryHash != _engineConfig.txBoundaryHash) {
            // in case of a new one we need to reinit the currentPattern, and save
            // the new transaction "boundry" (block.number+tx.origin+block.timestamp+block.difficulty)
            flowConfig.pattern = PATTERN_START;
            flowConfig.enforce = false;
            if (flowConfig.depth != DEPTH_START) {
                // This is an edge case we (and the client) should be able to monitor easily.
                emit TxStartedAtIrregularDepth();
                flowConfig.depth = DEPTH_START;
            }

            flowConfig.currentGasStrikes = GAS_STRIKES_START;
            if (_isGasFuncActivated(rules)) {
                _currentGasStack[0] = 1;
            }

            _engineConfig.txBoundaryHash = currentTxBoundaryHash;
        }
    }

    function _flowProtectionEntryLogic(bytes8 rules, FlowConfiguration memory flowConfig, int num) private {
        if (_isSelectiveTXFActivated(rules)) {
            // if we are not in enforcment mode then check if the current function turns it on
            if (!flowConfig.enforce && _enforceFunction[uint256(num)]) {
                flowConfig.enforce = true;
            }
        }
        flowConfig.pattern = uint216(bytes27(keccak256(abi.encode(num, flowConfig.pattern))));
    }


    function _flowProtectionExitLogic(bytes8 rules, FlowConfiguration memory flowConfig, int num, bool forceCheck) private {
        flowConfig.pattern = uint216(bytes27(keccak256(abi.encode(num, flowConfig.pattern))));

        if ((forceCheck) || (flowConfig.depth == DEPTH_START)) {
            if (_isSelectiveTXFActivated(rules)) {
                if (flowConfig.enforce) {
                    _checkCallFlow(flowConfig.pattern);
                }
            } else {
                _checkCallFlow(flowConfig.pattern);
            }
        }

        // If we are configured to CF then if we reach depth == DEPTH_START we should reinit the
        // currentPattern
        if (flowConfig.depth == DEPTH_START && _isCFActivated(rules)) {
            flowConfig.pattern = PATTERN_START;
        }
    }

    /**
     * update the current CF pattern with a new positive number (signifying function entry),
     * @param num element to add to the flow.
     */
    function _addCfElementFunctionEntry(int256 num) internal {
        uint256 preGasUsage = gasleft();

        bytes8 rules = _engineConfig.rules;
        if (rules == DEACTIVATED) {
            return;
        }
        if (!_engineConfig.isSimulator) {
            require(_allowedSenders[msg.sender], "SphereX error: disallowed sender");
        }
        require(num > 0, "SphereX error: expected positive num");

        FlowConfiguration memory flowConfig = _flowConfig;

        _resetStateOnNewTx(rules, flowConfig);

        if (_isFlowProtectionActivated(rules)) {
            _flowProtectionEntryLogic(rules, flowConfig, num);
        }

        ++flowConfig.depth;
        _flowConfig = flowConfig;

        if (_isGasFuncActivated(rules)) {
            uint256 gas_pos = flowConfig.depth - 2;
            uint32 pre_gas = _currentGasStack[gas_pos];
            pre_gas = pre_gas == 1 ? 0 : pre_gas;
            unchecked {
                pre_gas = pre_gas + uint32(preGasUsage);
                pre_gas = pre_gas - uint32(gasleft());
            }
            _currentGasStack[gas_pos] = pre_gas;
        }
    }

    /**
     * update the current CF pattern with a new negative number (signfying function exit),
     * under some conditions, this will also check the validity of the pattern.
     * @param num element to add to the flow. should be negative.
     * @param forceCheck force the check of the current pattern, even if normal test conditions don't exist.
     */
    function _addCfElementFunctionExit(int256 num, uint256 gas, bool forceCheck) internal {
        uint256 postGasUsage = gasleft();

        EngineConfig memory engineConfig = _engineConfig;

        if (engineConfig.rules == DEACTIVATED) {
            return;
        }
        if (!engineConfig.isSimulator) {
            require(_allowedSenders[msg.sender], "SphereX error: disallowed sender");
        }
        require(num < 0, "SphereX error: expected negative num");

        FlowConfiguration memory flowConfig = _flowConfig;
        --flowConfig.depth;

        if (_isGasFuncActivated(engineConfig.rules)) {
            uint32 gas_sub = _currentGasStack[flowConfig.depth];
            if (gas_sub == 1) {
                gas_sub = 0;
            } else {
                _currentGasStack[flowConfig.depth] = 1;
            }
            if (engineConfig.isSimulator) {
                SphereXEngine(address(this)).measureGas(gas - gas_sub, -num);
            }
            _checkGas(flowConfig, gas - gas_sub, engineConfig.gasStrikeOuts, num);
        }

        if (_isFlowProtectionActivated(engineConfig.rules)) {
            _flowProtectionExitLogic(engineConfig.rules, flowConfig, num, forceCheck);
        }

        _flowConfig = flowConfig;

        if (_isGasFuncActivated(engineConfig.rules)) {
            uint256 gas_pos = flowConfig.depth - 1;
            uint32 post_gas = _currentGasStack[gas_pos];
            post_gas = post_gas == 1 ? uint32(gas) : post_gas + uint32(gas);
            unchecked {
                post_gas = post_gas + uint32(postGasUsage);
                post_gas = post_gas - uint32(gasleft());
            }
            _currentGasStack[gas_pos] = post_gas;
        }
    }

    /**
     * Check if the current call flow pattern (that is, the result of the rolling hash) is an allowed pattern.
     */
    function _checkCallFlow(uint216 pattern) internal view {
        require(_allowedPatterns[pattern], "SphereX error: disallowed tx pattern");
    }

    /**
     * Check if the current function gas usage is allowed, will revert only if gasStrikeOuts is reached.
     */
    function _checkGas(FlowConfiguration memory flowConfig, uint256 gas, uint16 gasStrikeOuts, int256 num)
        internal
        view
    {
        if (!_isGasAllowed(gas, num)) {
            flowConfig.currentGasStrikes += 1;
            if (flowConfig.currentGasStrikes > gasStrikeOuts) {
                revert("SphereX error: disallowed tx gas pattern");
            }
        }
    }

    /**
     * Check if the current function gas usage is allowed, if the function is not included in gas checks
     * the function will allow it regardless of the gas usage.
     */
    function _isGasAllowed(uint256 gas, int256 num) internal view returns (bool) {
        uint256 functionIndex = num >= 0 ? uint256(num) : uint256(-num);
        if (!_includedFunctions[functionIndex]) {
            return true;
        }
        uint256 functionGas = uint256(keccak256(abi.encode(functionIndex, gas)));
        return _allowedFunctionsExactGas[functionGas];
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before the body of the function.
     * This is used only for external call functions.
     * @param num id of function to add. Should be positive
     * @param sender For future use
     * @param data For future use
     * @return result in the future will return instruction on what storage slots to gather, but not used for now
     */
    function sphereXValidatePre(int256 num, address sender, bytes calldata data)
        external
        override
        returns (bytes32[] memory result)
    {
        _addCfElementFunctionEntry(num);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract after the body of the function.
     * This is used only for external call functions (that is, external, and public when called outside the contract).
     * @param num id of function to add. Should be negative
     * @param valuesBefore For future use
     * @param valuesAfter For future use
     */
    function sphereXValidatePost(
        int256 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external override {
        _addCfElementFunctionExit(num, gas, true);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before and after the body of the function.
     * This is used only for internal function calls (internal and private functions).
     * @param num id of function to add.
     */
    function sphereXValidateInternalPre(int256 num) external override returns (bytes32[] memory result) {
        _addCfElementFunctionEntry(num);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before and after the body of the function.
     * This is used only for internal function calls (internal and private functions).
     * @param num id of function to add.
     */
    function sphereXValidateInternalPost(
        int256 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external override {
        _addCfElementFunctionExit(num, gas, false);
    }

    // this function is for simulation purpose only, it does nothing except being...
    function measureGas(uint256 gas, int256 num) external view {}
}
