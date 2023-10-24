// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXProtectedSubProxy} from "spherex-protect-contracts/SphereXProtectedSubProxy.sol";
import {ProtectedUUPSUpgradeable} from "spherex-protect-contracts/ProtectedProxies/ProtectedUUPSUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {CustomerBehindProxy} from "../Utils/CostumerContract.sol";
import {
    UUPSCustomerUnderProtectedERC1967SubProxy,
    UUPSCustomerUnderProtectedERC1967SubProxy1,
    UUPSCustomer1,
    CustomerBehindProxy
} from "../Utils/CostumerContract.sol";

contract SphereXProtectedSubProxyTest is SphereXProtectedProxyTest {
    ERC1967Proxy public main_proxy;
    SphereXProtectedSubProxy public protected_proxy_contract;
    UUPSCustomerUnderProtectedERC1967SubProxy public uups_costumer_contract;

    function setUp() public virtual override {
        uups_costumer_contract = new UUPSCustomerUnderProtectedERC1967SubProxy();
        protected_proxy_contract = new SphereXProtectedSubProxy();

        bytes memory imp_initialize_data =
            abi.encodeWithSelector(CustomerBehindProxy.initialize.selector, address(this));

        bytes memory initialize_data = abi.encodeWithSelector(
            SphereXProtectedSubProxy.initialize.selector,
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

    function testReInitialize() external {
        vm.expectRevert("SphereXInitializable: contract is already initialized");
        SphereXProtectedSubProxy(payable(proxy_contract)).initialize(
            address(this), address(0), address(0), address(0), new bytes(0)
        );
    }

    function testInitializeImp() external {
        assertEq(CustomerBehindProxy(address(proxy_contract)).getOwner(), address(this));
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
}
