// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineGasThesisTests is Test, CFUtils {
    SphereXEngine.GasRangePatterns[] gasRanges;
    SphereXEngine.GasExactPatterns[] gasExacts;
    uint32[] gasNumbersExacts;

    function setUp() public virtual override {
        super.setUp();
        spherex_engine.configureRules(GAS);
    }
    //  ============ Test for the management functions  ============

    function test_addAllowedPatterns_noGasData_revert_expected() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_changeGasRangePatterns() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        gasRanges.push(SphereXEngine.GasRangePatterns(allowed_cf_hash, 399, 401));

        spherex_engine.changeGasRangePatterns(gasRanges);

        sendDataToEngine(allowed_cf_storage[0], 400);
        sendDataToEngine(allowed_cf_storage[1], 400);

        gasRanges.pop();
    }

    function test_addGasExactPatterns() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactPatterns(allowed_cf_hash, gasNumbersExacts));

        spherex_engine.addGasExactPatterns(gasExacts);

        sendDataToEngine(allowed_cf_storage[0], 400);
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_removeGasExactPatterns() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactPatterns(allowed_cf_hash, gasNumbersExacts));

        spherex_engine.addGasExactPatterns(gasExacts);

        sendDataToEngine(allowed_cf_storage[0], 400);
        sendDataToEngine(allowed_cf_storage[1], 400);

        spherex_engine.removeGasExactPatterns(gasExacts);
        vm.roll(2);

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_excludeFromGasChecks() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.excludePatternsFromGas(allowed_patterns);

        sendDataToEngine(allowed_cf_storage[0], 400);
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_includeFromGasChecks() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        spherex_engine.incluePatternsInGas(allowed_patterns);

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_setGasStrikeOutsLimit() public {
        allowed_cf_storage = [int256(1), -1];
        uint200 allowed_cf_hash = addAllowedPattern();
        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        spherex_engine.incluePatternsInGas(allowed_patterns);

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);

        spherex_engine.setGasStrikeOutsLimit(1);
        sendDataToEngine(allowed_cf_storage[1], 400);
    }
}
