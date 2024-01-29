// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "./Utils/CostumerContract.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineGasThesisTests is Test, CFUtils {
    SphereXEngine.GasExactFunctions[] gasExacts;
    uint32[] gasNumbersExacts;
    uint256[] includedFunctionsInGas;

    function setUp() public virtual override {
        super.setUp();
        spherex_engine.configureRules(GAS_FUNCTION);
        includedFunctionsInGas = [1];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);
    }

    function test_functionWithNoGasData_revert_expected() public {
        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_addGasExactFunctions() public {
        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));

        spherex_engine.addGasExactFunctions(gasExacts);

        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
    }

    function test_removeGasExactFunctions() public {
        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);

        spherex_engine.removeGasExactFunctions(gasExacts);
        vm.roll(2);

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_excludeFunctionsFromGas() public {
        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
    }

    function test_includeFunctionsInGas_one_function() public {
        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
    }

    function test_includeFunctionsInGas_two_functions_first_include_second_exclude() public {
        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);
        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
    }

    function test_includeFunctionsInGas_two_functions_first_exclude_second_include() public {
        gasNumbersExacts = [uint32(500)];
        gasExacts.push(SphereXEngine.GasExactFunctions(2, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);
        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
    }

    function test_includeFunctionsInGas_two_functions_both_excluded() public {
        gasNumbersExacts = [uint32(500)];
        gasExacts.push(SphereXEngine.GasExactFunctions(2, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);
        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);
        spherex_engine.excludeFunctionsFromGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
    }

    function test_includeFunctionsInGas_two_functions_both_included() public {
        gasNumbersExacts = [uint32(500)];
        gasExacts.push(SphereXEngine.GasExactFunctions(2, gasNumbersExacts));
        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 400);
        sendDataToEngine(-1, 400);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
    }
    
    function test_includeFunctionsInGas_two_functions_both_included_first_wrong() public {
        gasNumbersExacts = [uint32(500)];
        gasExacts.push(SphereXEngine.GasExactFunctions(2, gasNumbersExacts));
        gasNumbersExacts = [uint32(300)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);
        sendDataToEngine(-1, 300);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
    }

    function test_includeFunctionsInGas_function_calls_inner() public {
        // in this test we simulate as if 1 calls 2.
        // the gas usage of 2 is 500 and 1 is 3059 (net usage)
        // in the call to the engine we will send 500 with 2 and 9000 with 1

        // this is for the tracing to know how much gas we need to feed the engine - stupid but works
        vm.store(
            address(spherex_engine),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000006),
            bytes32(0x0000000000000000000000000000000000000000000100000000000000000004)
        );

        gasNumbersExacts = [uint32(500)];
        gasExacts.push(SphereXEngine.GasExactFunctions(2, gasNumbersExacts));
        gasNumbersExacts = [uint32(2460)];
        gasExacts.push(SphereXEngine.GasExactFunctions(1, gasNumbersExacts));
        spherex_engine.addGasExactFunctions(gasExacts);

        // exculde publicFunction from gas check
        includedFunctionsInGas = [2];
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        // nothing should fail
        sendDataToEngine(1, 9000);
        sendDataToEngine(2, 500);
        sendDataToEngine(-2, 500);
        sendDataToEngine(-1, 9000);
    }

    function test_setGasStrikeOutsLimit() public {
        spherex_engine.includeFunctionsInGas(includedFunctionsInGas);

        sendDataToEngine(1, 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(-1, 400);

        spherex_engine.setGasStrikeOutsLimit(1);
        sendDataToEngine(-1, 400);
    }
}
