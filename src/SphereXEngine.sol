// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;
// import "forge-std/console.sol";
import {
    AccessControlDefaultAdminRules, IERC165
} from "openzeppelin-contracts/access/AccessControlDefaultAdminRules.sol";
import {ISphereXEngine} from "./ISphereXEngine.sol";

/**
 * @title SphereX Engine
 * @notice Gathers information about an ongoing transaction and reverts if it seems malicious
 */
contract SphereXEngine is ISphereXEngine, AccessControlDefaultAdminRules {
    struct FlowConfiguration {
        uint16 depth;
        // Represent bytes3(keccak256(abi.encode(block.number, tx.origin, block.difficulty, block.timestamp)))
        bytes3 txBoundaryHash;
        uint16 currentGasStrikes;
        uint200 pattern;
    }

    struct ThesisConfiguration {
        bytes8 engineRules; // By default the contract will be deployed with no guarding rules activated
        uint16 gasStrikeOuts;
    }

    struct PatternConfig {
        bool allowed;
        bool gasBypass;
        uint32 minGas;
        uint32 maxGas;
    }

    struct GasRangePatterns {
        uint200 pattern;
        uint32 minGas;
        uint32 maxGas;
    }

    struct GasExactPatterns {
        uint200 pattern;
        uint32[] gasExact;
    }

    mapping(address => bool) internal _allowedSenders;
    mapping(uint200 => PatternConfig) internal _allowedPatterns;
    mapping(uint256 => bool) internal _allowedPatternsExactGas;
    ThesisConfiguration internal _thesisConfig;

    FlowConfiguration internal _flowConfig =
        FlowConfiguration(DEPTH_START, bytes3(uint24(1)), GAS_STRIKES_START, PATTERN_START);

    // We initialize the next variables to 1 and not 0 to save gas costs on future transactions
    uint16 internal constant GAS_STRIKES_START = 0;
    uint200 internal constant PATTERN_START = 1;
    uint16 internal constant DEPTH_START = 1;
    bytes32 internal constant DEACTIVATED = bytes32(0);
    uint64 internal constant RULE_GAS = 4;
    uint64 internal constant RULE_TXF = 2;
    uint64 internal constant RULE_CF = 1;


    // the index of the addAllowedSenderOnChain in the call flow
    int256 internal constant ADD_ALLOWED_SENDER_ONCHAIN_INDEX = int256(uint256(keccak256("factory.allowed.sender")));

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SENDER_ADDER_ROLE = keccak256("SENDER_ADDER_ROLE");

    constructor() AccessControlDefaultAdminRules(1 days, msg.sender) {
        grantRole(OPERATOR_ROLE, msg.sender);
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
    event AddedAllowedPatterns(uint200[] patterns);
    event RemovedAllowedPatterns(uint200[] patterns);
    event ChangeGasRangePatterns(GasRangePatterns[] gasPatterns);
    event AddGasExactPatterns(GasExactPatterns[] gasPatterns);
    event RemoveGasExactPatterns(GasExactPatterns[] gasPatterns);
    event ExcludePatternsFromGas(uint200[] patterns);
    event IncluePatternsInGas(uint200[] patterns);

    modifier returnsIfNotActivated() {
        if (_thesisConfig.engineRules == DEACTIVATED) {
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
        override(AccessControlDefaultAdminRules, IERC165)
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
        require(
            (RULE_CF + RULE_GAS) & uint64(rules) != (RULE_CF + RULE_GAS), "SphereX error: illegal rules combination"
        );

        bytes8 oldRules = _thesisConfig.engineRules;
        _thesisConfig.engineRules = rules;
        emit ConfigureRules(oldRules, _thesisConfig.engineRules);
    }

    /**
     * Deactivates the engine, the calls will return without being checked
     */
    function deactivateAllRules() external onlyOperator {
        bytes8 oldRules = _thesisConfig.engineRules;
        _thesisConfig.engineRules = bytes8(uint64(0));
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
    function addAllowedSenderOnChain(address sender) external returnsIfNotActivated onlySenderAdderRole {
        _addCfElementFunctionEntry(ADD_ALLOWED_SENDER_ONCHAIN_INDEX);
        uint256 gas = gasleft();
        _allowedSenders[sender] = true;
        emit AddedAllowedSenderOnchain(sender);

        _addCfElementFunctionExit(-ADD_ALLOWED_SENDER_ONCHAIN_INDEX, gas - gasleft(), true);
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
    function addAllowedPatterns(uint200[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            PatternConfig memory patternConfig = _allowedPatterns[patterns[i]];
            patternConfig.allowed = true;
            _allowedPatterns[patterns[i]] = patternConfig;
        }
        emit AddedAllowedPatterns(patterns);
    }

    /**
     * Remove allowed patterns - these are representation flows of transactions, and prefixes of these flows,
     * that are no longer considered valid and benign
     * @param patterns list of flows that no longer considered valid and non-malicious
     */
    function removeAllowedPatterns(uint200[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            PatternConfig memory patternConfig = _allowedPatterns[patterns[i]];
            patternConfig.allowed = false;
            _allowedPatterns[patterns[i]] = patternConfig;
        }
        emit RemovedAllowedPatterns(patterns);
    }

    /**
     * Exclude allowed patterns from gas checks during transaction flow.
     * @param patterns list of flows that should be excluded from gas checks
     */
    function excludePatternsFromGas(uint200[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            PatternConfig memory patternConfig = _allowedPatterns[patterns[i]];
            patternConfig.gasBypass = true;
            _allowedPatterns[patterns[i]] = patternConfig;
        }
        emit ExcludePatternsFromGas(patterns);
    }

    /**
     * Include allowed patterns for gas checks during transaction flow.
     * @param patterns list of flows that should be included for gas checks
     */
    function incluePatternsInGas(uint200[] calldata patterns) external onlyOperator {
        for (uint256 i = 0; i < patterns.length; ++i) {
            PatternConfig memory patternConfig = _allowedPatterns[patterns[i]];
            patternConfig.gasBypass = false;
            _allowedPatterns[patterns[i]] = patternConfig;
        }
        emit IncluePatternsInGas(patterns);
    }

    /**
     * Add allowed gas range patterns
     * @param gasPatterns list of patterns with their corresponding gas range.
     */
    function changeGasRangePatterns(GasRangePatterns[] calldata gasPatterns) external onlyOperator {
        for (uint256 i = 0; i < gasPatterns.length; ++i) {
            PatternConfig memory patternConfig = _allowedPatterns[gasPatterns[i].pattern];
            patternConfig.minGas = gasPatterns[i].minGas;
            patternConfig.maxGas = gasPatterns[i].maxGas;
            _allowedPatterns[gasPatterns[i].pattern] = patternConfig;
        }
        emit ChangeGasRangePatterns(gasPatterns);
    }

    /**
     * Add allowed gas exact patterns - the allowd gas exact values for each pattern.
     * each exact gas value will be hashed with the pattern and be saved as a key to boolean value in _allowedPatternsExactGas.
     * @param gasPatterns list of patterns with their corresponding gas exact values.
     */
    function addGasExactPatterns(GasExactPatterns[] calldata gasPatterns) external onlyOperator {
        for (uint256 i = 0; i < gasPatterns.length; ++i) {
            for (uint256 j = 0; j < gasPatterns[i].gasExact.length; ++j) {
                _allowedPatternsExactGas[uint256(keccak256(abi.encode(gasPatterns[i].pattern, gasPatterns[i].gasExact[j])))] = true;
            }
        }
        emit AddGasExactPatterns(gasPatterns);
    }

    /**
     * Remove allowed gas exact patterns - the allowd gas exact values for each pattern.
     * each exact gas value will be hashed with the pattern and be saved as a key to boolean value in _allowedPatternsExactGas.
     * @param gasPatterns list of patterns with their corresponding gas exact values.
     */
    function removeGasExactPatterns(GasExactPatterns[] calldata gasPatterns) external onlyOperator {
        for (uint256 i = 0; i < gasPatterns.length; ++i) {
            for (uint256 j = 0; j < gasPatterns[i].gasExact.length; ++j) {
                _allowedPatternsExactGas[uint256(keccak256(abi.encode(gasPatterns[i].pattern, gasPatterns[i].gasExact[j])))] = false;
            }
        }
        emit RemoveGasExactPatterns(gasPatterns);
    }
    
    /**
     * Set the new strike out liimit for the gas thesis.
     * @param newLimit the new strike out limit for the gas thesis.
     */
    function setGasStrikeOutsLimit(uint16 newLimit) external onlyOperator {
        _thesisConfig.gasStrikeOuts = newLimit;
    }

    function grantSenderAdderRole(address newSenderAdder) external onlyOperator {
        _grantRole(SENDER_ADDER_ROLE, newSenderAdder);
    }

    // ============ Protect logic ============

    /**
     * Checks if rule1 is activated.
     */
    function _isCfActivated() internal view returns (bool) {
        return (_thesisConfig.engineRules & bytes8(uint64(1))) > 0;
    }

    /**
     * Checks if rule3 is activated.
     */
    function _isGasActivated() internal view returns (bool) {
        return (_thesisConfig.engineRules & bytes8(uint64(4))) > 0;
    }

    /**
     * Returns the number of strike outs allowed for a tx under gas enforcment.
     */
    function _getGasStirkeOuts() internal view returns (uint16) {
        return _thesisConfig.gasStrikeOuts;
    }

    /**
     * update the current CF pattern with a new positive number (signifying function entry),
     * @param num element to add to the flow.
     */
    function _addCfElementFunctionEntry(int256 num) internal {
        require(num > 0, "SphereX error: expected positive num");
        FlowConfiguration memory flowConfig = _flowConfig;

        // Upon entry to a new function we should check if we are at the same transaction
        // or a new one. in case of a new one we need to reinit the currentPattern, and save
        // the new transaction "boundry" (block.number+tx.origin+block.timestamp+block.difficulty)
        bytes3 currentTxBoundaryHash =
            bytes3(keccak256(abi.encode(block.number, tx.origin, block.timestamp, block.difficulty)));
        if (currentTxBoundaryHash != flowConfig.txBoundaryHash) {
            flowConfig.pattern = PATTERN_START;
            flowConfig.txBoundaryHash = currentTxBoundaryHash;
            flowConfig.currentGasStrikes = GAS_STRIKES_START;
            if (flowConfig.depth != DEPTH_START) {
                // This is an edge case we (and the client) should be able to monitor easily.
                emit TxStartedAtIrregularDepth();
                flowConfig.depth = DEPTH_START;
            }
        }

        flowConfig.pattern = uint200(bytes25(keccak256(abi.encode(num, flowConfig.pattern))));
        ++flowConfig.depth;

        _flowConfig = flowConfig;
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

        flowConfig.pattern = uint200(bytes25(keccak256(abi.encode(num, flowConfig.pattern))));
        --flowConfig.depth;

        if ((forceCheck) || (flowConfig.depth == DEPTH_START)) {
            _checkCallFlow(flowConfig, gas);
        }

        // If we are configured to CF then if we reach depth == DEPTH_START we should reinit the
        // currentPattern
        if (flowConfig.depth == DEPTH_START && _isCfActivated()) {
            flowConfig.pattern = PATTERN_START;
        }

        _flowConfig = flowConfig;
    }

    /**
     * Check if the current call flow pattern (that is, the result of the rolling hash) is an allowed pattern.
     */
    function _checkCallFlow(FlowConfiguration memory flowConfig, uint256 gas) internal view {
        PatternConfig memory patternState = _allowedPatterns[flowConfig.pattern];
        require(patternState.allowed, "SphereX error: disallowed tx pattern");

        if (_isGasActivated() && !isGasAllowed(flowConfig.pattern, patternState, gas)) {
            flowConfig.currentGasStrikes += 1;
            if (flowConfig.currentGasStrikes > _getGasStirkeOuts()) {
                revert("SphereX error: disallowed tx gas pattern");
            }
        }
    }

    function isGasAllowed(uint200 pattern, PatternConfig memory patternConfig, uint256 gas) internal view returns (bool) {
        if (patternConfig.gasBypass) {
            return true;
        }
        uint256 patternGas = uint256(keccak256(abi.encode(pattern, gas)));
        if (_allowedPatternsExactGas[patternGas]) {
            return true;
        }
        if (gas > patternConfig.maxGas) {
            return false;
        }
        if (gas < patternConfig.minGas) {
            return false;
        }
        return true;
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
        // console.logUint(gas);
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
}
