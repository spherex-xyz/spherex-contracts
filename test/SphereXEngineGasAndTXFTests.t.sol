// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "./Utils/CostumerContract.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineGasAndTxfTests is Test, CFUtils {
    SphereXEngine.GasExactFunctions[] gasExacts;
    uint32[] gasNumbersExacts;

    function setUp() public virtual override {
        super.setUp();
        spherex_engine.configureRules(GAS_FUNCTION_AND_TXF);
    }

    function test_AllowedPatterns_AndGas() public {

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector),
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        gasNumbersExacts = [uint32(400)];
        gasExacts.push(
            SphereXEngine.GasExactFunctions(
                uint256(to_int256(CostumerContract.try_allowed_flow.selector)), gasNumbersExacts
            )
        );
        spherex_engine.addGasExactFunctions(gasExacts);

        sendDataToEngine(allowed_cf_storage[0], 400);
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_AllowedPatterns_NoGas() public {
        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector),
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_NotAllowedPatterns_NoGas() public {
        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_AllowedPatterns_excludeFromGasChecks() public {
        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();
        calcPatternHash();
        spherex_engine.excludePatternsFromGas(allowed_patterns);

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector),
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();
        

        sendDataToEngine(allowed_cf_storage[0], 400);
        // no revert here because we excluded it from gas check
        sendDataToEngine(allowed_cf_storage[1], 400);
        sendDataToEngine(allowed_cf_storage[2], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[3], 400);
    }

    function test_includeFromGasChecks() public {
        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();
        calcPatternHash();
        spherex_engine.excludePatternsFromGas(allowed_patterns);
        spherex_engine.incluePatternsInGas(allowed_patterns);

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector),
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);
    }

    function test_setGasStrikeOutsLimit() public {
        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();
        calcPatternHash();

        allowed_cf_storage = [
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector),
            to_int256(CostumerContract.try_allowed_flow.selector),
            -to_int256(CostumerContract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        sendDataToEngine(allowed_cf_storage[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[1], 400);

        spherex_engine.setGasStrikeOutsLimit(1);
        sendDataToEngine(allowed_cf_storage[1], 400);
        sendDataToEngine(allowed_cf_storage[2], 400);
        
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf_storage[3], 400);
    }
}
