// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../../src/SphereXEngine.sol";

contract CFUtils is Test {
    SphereXEngine public spherex_engine;
    address[] allowed_senders;
    uint216[] allowed_patterns;

    // This variable exists so we can use memory int16[] parameters in functions
    // it will be used locally in each tests and wont have any meaning between tests.
    int256[] allowed_cf_storage;
    address random_address = 0x6A08098568eE90b71dD757F070D79364197f944B;

    /**
     * @dev obtained using `forge inspect --pretty SphereXEngine storage`
     */
    bytes32 constant flowConfigStorageSlot = bytes32(uint256(6));
    bytes32 constant engineConfigStorageSlot = bytes32(uint256(3));
    bytes8 constant CF = bytes8(uint64(1));
    bytes8 constant PREFIX_TX_FLOW = bytes8(uint64(2));
    bytes8 constant SELECTIVE_TXF = bytes8(uint64(4));
    bytes8 constant GAS_FUNCTION = bytes8(uint64(8));
    bytes8 constant GAS_FUNCTION_AND_CF = bytes8(uint64(9));
    bytes8 constant GAS_FUNCTION_AND_TXF = bytes8(uint64(10));

    function setUp() public virtual {
        spherex_engine = new SphereXEngine();
        allowed_senders.push(address(this));
        spherex_engine.addAllowedSender(allowed_senders);
    }

    function sendNumberToEngine(int256 num) internal {
        if (num > 0) {
            spherex_engine.sphereXValidateInternalPre(num);
        } else {
            bytes32[] memory emptyArray = new bytes32[](0);
            spherex_engine.sphereXValidateInternalPost(num, 0, emptyArray, emptyArray);
        }
    }

    function sendDataToEngine(int256 num, uint256 gas) internal {
        if (num > 0) {
            spherex_engine.sphereXValidateInternalPre(num);
        } else {
            bytes32[] memory emptyArray = new bytes32[](0);
            spherex_engine.sphereXValidateInternalPost(num, gas, emptyArray, emptyArray);
        }
    }

    function to_int256(bytes4 func_selector) internal pure returns (int256) {
        return int256(uint256(uint32(func_selector)));
    }

    function calc_pattern_by_selector(bytes4 func_selector) internal pure returns (uint216) {
        int256 func_hash = to_int256(func_selector);
        int256[2] memory allowed_cf = [func_hash, -func_hash];

        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        return allowed_cf_hash;
    }

    function calc_pattern_by_selectors(bytes4[] memory func_selectors) internal pure returns (uint216) {
        uint216 allowed_cf_hash = 1;

        for (uint256 i = 0; i < func_selectors.length; i++) {
            int256 func_hash = int256(uint256(uint32(func_selectors[i])));
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(func_hash, allowed_cf_hash))));
        }

        for (int256 i = int256(func_selectors.length) - 1; i >= 0; i--) {
            int256 func_hash = -int256(uint256(uint32(func_selectors[uint256(i)])));
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(func_hash, allowed_cf_hash))));
        }

        return allowed_cf_hash;
    }

    function getCurrentCallDepth() internal returns (uint8) {
        return uint8(bytes1(vm.load(address(spherex_engine), flowConfigStorageSlot) << 248));
    }

    function getCurrentPattern() internal returns (uint216) {
        return uint216(bytes27(vm.load(address(spherex_engine), flowConfigStorageSlot)));
    }

    function getCurrentBlockBoundry() internal returns (bytes2) {
        return bytes2(vm.load(address(spherex_engine), engineConfigStorageSlot) << 64);
    }

    function getCurrentGasStrikes() internal returns (uint8) {
        return uint8(bytes1(vm.load(address(spherex_engine), flowConfigStorageSlot) << 216));
    }

    function assertFlowStorageSlotsInInitialState() internal {
        assertEq(getCurrentCallDepth(), uint8(1));
        assertEq(getCurrentPattern(), uint216(1));
        assertEq(getCurrentGasStrikes(), uint8(0));
    }

    // helper function to add an allowed pattern (read the array from
    // allowed_cf_storage) to the engine.
    function addAllowedPattern() internal returns (uint216) {
        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            allowed_cf_hash = uint216(bytes27((keccak256(abi.encode(int256(allowed_cf_storage[i]), allowed_cf_hash)))));
        }
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);
        return allowed_cf_hash;
    }

    function sendInternalNumberToEngine(int256 num) internal {
        if (num > 0) {
            spherex_engine.sphereXValidateInternalPre(num);
        } else {
            bytes32[] memory emptyArray = new bytes32[](0);
            spherex_engine.sphereXValidateInternalPost(num, 0, emptyArray, emptyArray);
        }
    }

    // helper function to calc pattern hash (read the array from
    // allowed_cf_storage) into allowed_patterns.
    function calcPatternHash() internal {
        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            allowed_cf_hash = uint216(bytes27((keccak256(abi.encode(int256(allowed_cf_storage[i]), allowed_cf_hash)))));
        }
        allowed_patterns = [allowed_cf_hash];
    }
}
