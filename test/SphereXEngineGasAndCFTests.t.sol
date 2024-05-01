// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "./Utils/CostumerContract.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineGasAndCfTests is Test, CFUtils {
    SphereXEngine.GasExactFunctions[] gasExacts;
    uint32[] gasNumbersExacts;
    uint256[] includedFunctionsInGas;

    function setUp() public virtual override {
        super.setUp();
        spherex_engine.configureRules(GAS_FUNCTION_AND_CF);
        includedFunctionsInGas = [1];

        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);
    }

    function test_AllowedPatterns_AndGas() public {
        allowed_cf_storage = [int256(1), -1];

        addAllowedPattern();

        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
    }

    function test_AllowedPatterns_NoGas() public {
        allowed_cf_storage = [int256(1), -1];
        addAllowedPattern();

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_NotAllowedPatterns_NoGas() public {
        allowed_cf_storage = [int256(1), -1];

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_AllowedPatterns_excludeFunctionsFromGas() public {
        allowed_cf_storage = [int256(1), -1];

        addAllowedPattern();

        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
    }

    function test_AllowedPatterns_includeFunctionsInGas() public {
        allowed_cf_storage = [int256(1), -1];

        addAllowedPattern();
        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_setGasStrikeOutsLimit() public {
        allowed_cf_storage = [int256(1), -1];

        addAllowedPattern();
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);

        spherex_engine.setGasStrikeOutsLimit(1);
        sendDataToEngine(-1, 400);
    }
}
