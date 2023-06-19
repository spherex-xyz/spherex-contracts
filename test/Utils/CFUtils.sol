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
    int16[] allowed_cf_storage;

    /**
     * @dev obtained using `forge inspect --pretty SphereXEngine storage`
     */
    bytes32 constant flowConfigStorageSlot = bytes32(uint256(6));
    bytes8 constant CF = bytes8(uint64(1));
    bytes8 constant PREFIX_TX_FLOW = bytes8(uint64(2));

    function getCurrentCallDepth() internal returns (uint16) {
        return uint16(bytes2(vm.load(address(spherex_engine), flowConfigStorageSlot) << 240));
    }

    function getCurrentPattern() internal returns (uint216) {
        return uint216(bytes27(vm.load(address(spherex_engine), flowConfigStorageSlot)));
    }

    function getCurrentBlockBoundry() internal returns (bytes3) {
        return bytes3(vm.load(address(spherex_engine), flowConfigStorageSlot) << 216);
    }

    function assertFlowStorageSlotsInInitialState() internal {
        assertEq(getCurrentCallDepth(), uint16(1));
        assertEq(getCurrentPattern(), uint216(1));
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
}
