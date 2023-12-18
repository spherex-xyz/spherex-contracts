// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {AccessControlDefaultAdminRules} from "openzeppelin-contracts/access/AccessControlDefaultAdminRules.sol";
import {ISphereXEngine} from "spherex-protect-contracts/ISphereXEngine.sol";
/**
 * @title SphereX Engine
 * @notice Gathers information about an ongoing transaction and reverts if it seems malicious
 */

contract SphereXEngine is ISphereXEngine, AccessControlDefaultAdminRules {
    struct FlowConfiguration {
        uint8 depth;
        // Represent bytes3(keccak256(abi.encode(block.number, tx.origin, block.difficulty, block.timestamp)))
        bytes3 txBoundaryHash;
        uint8 currentGasStrikes;
        uint216 pattern;
    }

    struct GuardienConfiguration {
        bytes8 engineRules; // By default the contract will be deployed with no guarding rules activated
        uint16 gasStrikeOuts;
        // if true we are adding some extra stuff that costs gas for simulation purposes
        // there is no way to turn this on except in simmulation!
        bool isSimulator;
    }

    struct GasExactFunctions {
        uint256 functionIndex;
        uint32[] gasExact;
    }

    mapping(address => bool) internal _allowedSenders;
    mapping(uint216 => bool) internal _allowedPatterns;
    mapping(uint256 => bool) internal _allowedFunctionsExactGas;
    GuardienConfiguration internal _guardienConfig;

    FlowConfiguration internal _flowConfig =
        FlowConfiguration(DEPTH_START, bytes3(uint24(1)), GAS_STRIKES_START, PATTERN_START);

    // Please add new storage variables after this point so the tests wont fail!

    mapping(uint256 => bool) internal _includedFunctions;
    uint32[30] internal _currentGasStack;

    uint8 internal constant GAS_STRIKES_START = 0;
    uint216 internal constant PATTERN_START = 1;
    uint8 internal constant DEPTH_START = 1;
    bytes32 internal constant DEACTIVATED = bytes32(0);
    uint64 internal constant RULE_GAS_FUNCTION = 4;
    uint64 internal constant RULE_TXF = 2;
    uint64 internal constant RULE_CF = 1;

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
    event AddGasExactFunctions(GasExactFunctions[] gasFunctions);
    event RemoveGasExactFunctions(GasExactFunctions[] gasFunctions);
    event ExcludeFunctionsFromGas(uint256[] functions);
    event InclueFunctionsInGas(uint256[] functions);

    modifier returnsIfNotActivated() {
        if (_guardienConfig.engineRules == DEACTIVATED) {
            return;
        }

        _;
    }

    modifier onlyApprovedSenders() {
        require(_allowedSenders[msg.sender], "SphereX error: disallowed sender");
        _;
    }

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
        require(
            (RULE_CF + RULE_TXF) & uint64(rules) != (RULE_CF + RULE_TXF), "SphereX error: illegal rules combination"
        );

        bytes8 oldRules = _guardienConfig.engineRules;
        _guardienConfig.engineRules = rules;
        emit ConfigureRules(oldRules, _guardienConfig.engineRules);
    }

    /**
     * Deactivates the engine, the calls will return without being checked
     */
    function deactivateAllRules() external onlyOperator {
        bytes8 oldRules = _guardienConfig.engineRules;
        _guardienConfig.engineRules = bytes8(uint64(0));
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
        _guardienConfig.gasStrikeOuts = newLimit;
    }

    function grantSenderAdderRole(address newSenderAdder) external onlyOperator {
        _grantRole(SENDER_ADDER_ROLE, newSenderAdder);
    }

    // ============ Protect logic ============

    /**
     * Checks if call flow is activated.
     */
    function _isCfActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(RULE_CF)) > 0;
    }

    /**
     * Checks if call flow is activated.
     */
    function _isTxfActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(RULE_TXF)) > 0;
    }

    /**
     * Checks if gas function is activated.
     */
    function _isGasFuncActivated(bytes8 rules) internal view returns (bool) {
        return (rules & bytes8(RULE_GAS_FUNCTION)) > 0;
    }

    /**
     * update the current CF pattern with a new positive number (signifying function entry),
     * @param num element to add to the flow.
     */
    function _addCfElementFunctionEntry(int256 num) internal {
        require(num > 0, "SphereX error: expected positive num");
        uint256 preGasUsage = gasleft();

        FlowConfiguration memory flowConfig = _flowConfig;
        bytes8 rules = _guardienConfig.engineRules;

        // Upon entry to a new function we should check if we are at the same transaction
        // or a new one. in case of a new one we need to reinit the currentPattern, and save
        // the new transaction "boundry" (block.number+tx.origin+block.timestamp+block.difficulty)
        bytes3 currentTxBoundaryHash =
            bytes3(keccak256(abi.encode(block.number, tx.origin, block.timestamp, block.difficulty)));
        if (currentTxBoundaryHash != flowConfig.txBoundaryHash) {
            flowConfig.pattern = PATTERN_START;
            flowConfig.txBoundaryHash = currentTxBoundaryHash;
            flowConfig.currentGasStrikes = GAS_STRIKES_START;
            if (_isGasFuncActivated(rules)) {
                _currentGasStack[0] = 1;
            }

            if (flowConfig.depth != DEPTH_START) {
                // This is an edge case we (and the client) should be able to monitor easily.
                emit TxStartedAtIrregularDepth();
                flowConfig.depth = DEPTH_START;
            }
        }

        if (_isCfActivated(rules) || _isTxfActivated(rules)) {
            flowConfig.pattern = uint216(bytes27(keccak256(abi.encode(num, flowConfig.pattern))));
        }

        ++flowConfig.depth;
        _flowConfig = flowConfig;

        if (_isGasFuncActivated(rules)) {
            uint32 pre_gas = _currentGasStack[flowConfig.depth - 2];
            pre_gas = pre_gas == 1 ? 0 : pre_gas; 
            pre_gas += uint32(preGasUsage - gasleft());
            _currentGasStack[flowConfig.depth - 2] = pre_gas;
        }
    }

    /**
     * update the current CF pattern with a new negative number (signfying function exit),
     * under some conditions, this will also check the validity of the pattern.
     * @param num element to add to the flow. should be negative.
     * @param forceCheck force the check of the current pattern, even if normal test conditions don't exist.
     */
    function _addCfElementFunctionExit(int256 num, uint256 gas, bool forceCheck) internal {
        require(num < 0, "SphereX error: expected negative num");
        FlowConfiguration memory flowConfig = _flowConfig;
        GuardienConfiguration memory guardienConfig = _guardienConfig;
        uint256 postGasUsage = gasleft();

        --flowConfig.depth;

        if (_isGasFuncActivated(guardienConfig.engineRules)) {
            uint32 gas_sub = _currentGasStack[flowConfig.depth];
            gas_sub = gas_sub == 1 ? 0 : gas_sub; 
            _currentGasStack[flowConfig.depth] = 1;
            if (guardienConfig.isSimulator) {
                SphereXEngine(address(this)).measureGas(gas - gas_sub, -num);
            }
            _checkGas(flowConfig, gas - gas_sub, guardienConfig.gasStrikeOuts, num);
        }

        if (_isCfActivated(guardienConfig.engineRules) || _isTxfActivated(guardienConfig.engineRules)) {
            flowConfig.pattern = uint216(bytes27(keccak256(abi.encode(num, flowConfig.pattern))));

            if ((forceCheck) || (flowConfig.depth == DEPTH_START)) {
                _checkCallFlow(flowConfig.pattern);
            }

            // If we are configured to CF then if we reach depth == DEPTH_START we should reinit the
            // currentPattern
            if (flowConfig.depth == DEPTH_START && _isCfActivated(guardienConfig.engineRules)) {
                flowConfig.pattern = PATTERN_START;
            }
        }

        _flowConfig = flowConfig;

        if (_isGasFuncActivated(guardienConfig.engineRules)) {
            uint32 post_gas = _currentGasStack[flowConfig.depth - 1];
            post_gas = post_gas == 1 ? uint32(gas) : post_gas + uint32(gas);
            post_gas += uint32(postGasUsage - gasleft());
            _currentGasStack[flowConfig.depth - 1] = post_gas;
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
        returnsIfNotActivated // may return empty bytes32[]
        onlyApprovedSenders
        returns (bytes32[] memory result)
    {
        _addCfElementFunctionEntry(num);
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
        int256 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external override returnsIfNotActivated onlyApprovedSenders {
        _addCfElementFunctionExit(num, gas, true);
    }

    /**
     * This is the function that is actually called by the modifier of the protected contract before and after the body of the function.
     * This is used only for internal function calls (internal and private functions).
     * @param num id of function to add.
     */
    function sphereXValidateInternalPre(int256 num)
        external
        override
        returnsIfNotActivated
        onlyApprovedSenders
        returns (bytes32[] memory result)
    {
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
    ) external override returnsIfNotActivated onlyApprovedSenders {
        _addCfElementFunctionExit(num, gas, false);
    }

    // this function is for simulation purpose only, it does nothing except being...
    function measureGas(uint256 gas, int256 num) external view {}
}
