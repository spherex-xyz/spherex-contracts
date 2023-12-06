// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXProtectedSubProxyTest} from "./SphereXProtectedSubProxy.t.sol";
import {CustomerBehindProxy, CustomerBehindProxy1} from "../Utils/CostumerContract.sol";

import {
    UUPSCustomerUnderProtectedERC1967SubProxy,
    UUPSCustomerUnderProtectedERC1967SubProxy1,
    UUPSCustomer1
} from "../Utils/CostumerContract.sol";
import {
    ProtectedERC1967SubProxy,
    SphereXProtectedSubProxy
} from "spherex-protect-contracts/ProtectedProxies/ProtectedERC1967SubProxy.sol";
import {ProtectedUUPSUpgradeable} from "spherex-protect-contracts/ProtectedProxies/ProtectedUUPSUpgradeable.sol";

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import {SphereXEngine} from "../../src/SphereXEngine.sol";

contract ProtectedERC1967SubProxyTest is SphereXProtectedSubProxyTest {
    ERC1967Proxy public main_proxy;
    ProtectedERC1967SubProxy public protected_proxy_contract;
    UUPSCustomerUnderProtectedERC1967SubProxy public uups_costumer_contract;

    function setUp() public virtual override {
        uups_costumer_contract = new UUPSCustomerUnderProtectedERC1967SubProxy();
        protected_proxy_contract = new ProtectedERC1967SubProxy(address(uups_costumer_contract), bytes(""));

        bytes memory imp_initialize_data =
            abi.encodeWithSelector(CustomerBehindProxy.initialize.selector, address(this));

        bytes memory initialize_data = abi.encodeWithSelector(
            SphereXProtectedSubProxy.__SphereXProtectedSubProXy_init.selector,
            address(this), // admin
            address(this), // operator
            address(0), // engine
            address(uups_costumer_contract), // logic
            imp_initialize_data // init data for imp
        );

        main_proxy = new ERC1967Proxy(address(protected_proxy_contract), initialize_data);
        proxy_contract = SphereXProtectedSubProxy(payable(main_proxy));

        super.setUp();
    }

    function testSubUpdate() external {
        UUPSCustomerUnderProtectedERC1967SubProxy1 new_costumer = new UUPSCustomerUnderProtectedERC1967SubProxy1();
        ProtectedUUPSUpgradeable(address(proxy_contract)).subUpgradeTo(address(new_costumer));

        vm.expectCall(address(new_costumer), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
        UUPSCustomerUnderProtectedERC1967SubProxy1(address(proxy_contract)).new_func();
    }

    function testSubUpdateAndCall() external {
        UUPSCustomerUnderProtectedERC1967SubProxy1 new_costumer = new UUPSCustomerUnderProtectedERC1967SubProxy1();
        bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

        vm.expectCall(address(new_costumer), new_func_data);
        UUPSCustomerUnderProtectedERC1967SubProxy1(address(proxy_contract)).subUpgradeToAndCall(
            address(new_costumer), new_func_data
        );
    }

    function testUpdateTo() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        ProtectedUUPSUpgradeable(address(proxy_contract)).upgradeTo(address(new_costumer));

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()")))));
        UUPSCustomer1(address(proxy_contract)).new_func();
    }

    function testUpdateToAndCall() external {
        UUPSCustomer1 new_costumer = new UUPSCustomer1();
        bytes memory new_func_data = abi.encodeWithSelector(bytes4(keccak256(bytes("new_func()"))));

        vm.expectCall(address(new_costumer), new_func_data);
        UUPSUpgradeable(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
    }

    function test_exactGas() external override activateRuleGASTXF {
        gasNumbersExacts = [uint32(4181)];
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
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        allowed_cf_storage = [
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector),
            to_int256(costumer_contract.try_allowed_flow.selector),
            -to_int256(costumer_contract.try_allowed_flow.selector)
        ];
        addAllowedPattern();

        gasNumbersExacts = [uint32(4181)];
        gasExacts.push(
            SphereXEngine.GasExactFunctions(
                uint256(to_int256(costumer_contract.try_allowed_flow.selector)), gasNumbersExacts
            )
        );
        spherex_engine.addGasExactFunctions(gasExacts);

        spherex_engine.setGasStrikeOutsLimit(2);

        costumer_contract.try_allowed_flow();
        costumer_contract.try_allowed_flow();
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        costumer_contract.try_allowed_flow();
    }
}
