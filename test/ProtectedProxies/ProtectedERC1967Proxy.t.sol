// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, UUPSCustomer, UUPSCustomer1} from "../Utils/CostumerContract.sol";
import {ProtectedERC1967Proxy} from "spherex-protect-contracts/ProtectedProxies/ProtectedERC1967Proxy.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {SphereXEngine} from "../../src/SphereXEngine.sol";

contract ProtectedERC1967ProxyTest is SphereXProtectedProxyTest {
    function setUp() public virtual override {
        p_costumer_contract = new UUPSCustomer();
        proxy_contract = new ProtectedERC1967Proxy(
            address(p_costumer_contract),
            ""
        );

        super.setUp();
    }

    function testUpdateTo() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        UUPSUpgradeable(address(proxy_contract)).upgradeTo(address(new_costumer));

        vm.expectCall(address(new_costumer), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
        UUPSCustomer1(address(proxy_contract)).new_func();
    }

    function testUpdateToAndCall() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

        vm.expectCall(address(new_costumer), new_func_data);
        UUPSCustomer1(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
    }

    function test_exactGas() external override activateRuleGASTXF {
        gasNumbersExacts = [uint32(4101)];
        gasExacts.push(
            SphereXEngine.GasExactFunctions(
                uint256(to_int256(costumer_contract.try_allowed_flow.selector)), gasNumbersExacts
            )
        );

        spherex_engine.addGasExactFunctions(gasExacts);

        costumer_contract.try_allowed_flow();
    }

    function test_gasStrikeOuts_fail_after_two_strikes() external override activateRuleGASTXF {
        allowed_cf_storage = [
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector),
            to_int256(costumer_contract.three_gas_usages.selector),
            -to_int256(costumer_contract.three_gas_usages.selector)
        ];
        addAllowedPattern();

        gasNumbersExacts = [uint32(4577)];
        gasExacts.push(
            SphereXEngine.GasExactFunctions(
                uint256(to_int256(costumer_contract.three_gas_usages.selector)), gasNumbersExacts
            )
        );
        spherex_engine.addGasExactFunctions(gasExacts);

        spherex_engine.setGasStrikeOutsLimit(2);

        costumer_contract.three_gas_usages(1);
        costumer_contract.three_gas_usages(2);
        costumer_contract.three_gas_usages(2);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        costumer_contract.three_gas_usages(2);
    }
}
