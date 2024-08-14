// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXProtectedSubProxyTest} from "./SphereXProtectedSubProxy.t.sol";
import {CustomerBehindProxy, CustomerBehindProxy1} from "../Utils/CostumerContract.sol";

import {
    ProtectedTransparentUpgradeableSubProxy,
    ISphereXProtectedSubProxy
} from "../../src/ProtectedProxies/ProtectedTransparentUpgradeableSubProxy.sol";
import {SphereXProtectedSubProxy} from "../../src/SphereXProtectedSubProxy.sol";

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";

contract ProtectedTransparentUpgradeableSubProxyTest is SphereXProtectedSubProxyTest {
    TransparentUpgradeableProxy public main_proxy;
    address proxy_admin = vm.addr(1);
    address spherex_admin = vm.addr(2);

    ProtectedTransparentUpgradeableSubProxy public protected_proxy_contract;

    function setUp() public virtual override {
        p_costumer_contract = new CustomerBehindProxy();
        protected_proxy_contract =
            new ProtectedTransparentUpgradeableSubProxy(address(p_costumer_contract), spherex_admin, bytes(""));

        bytes memory imp_initialize_data =
            abi.encodeWithSelector(CustomerBehindProxy.initialize.selector, address(this));

        bytes memory sub_initialize_data = abi.encodeWithSelector(
            SphereXProtectedSubProxy.__SphereXProtectedSubProXy_init.selector,
            address(this), // admin
            address(this), //  operator
            address(0), // engine
            address(p_costumer_contract), // logic
            imp_initialize_data // init data for imp
        );

        main_proxy = new TransparentUpgradeableProxy(
            address(protected_proxy_contract), address(proxy_admin), sub_initialize_data
        );
        proxy_contract = SphereXProtectedSubProxy(payable(main_proxy));

        super.setUp();

        // Since in ProtectedTransparentUpgradeableSubProxy admin (address(this)) cannot fallback
        SphereXProtectedSubProxy(payable(main_proxy)).transferSphereXAdminRole(spherex_admin);
        vm.prank(spherex_admin);
        SphereXProtectedSubProxy(payable(main_proxy)).acceptSphereXAdminRole();
    }

    // Overrided from SphereXProtect.t.sol since spherex admin here is not address(this)
    function test_changeSphereXAdmin() external override {
        address otherAddress = address(3);

        vm.prank(spherex_admin);
        costumer_contract.transferSphereXAdminRole(otherAddress);
        vm.prank(otherAddress);
        costumer_contract.acceptSphereXAdminRole();

        vm.expectRevert("SphereX error: admin required");
        costumer_contract.transferSphereXAdminRole(address(this));
        vm.prank(otherAddress);
        costumer_contract.transferSphereXAdminRole(address(this));

        vm.prank(otherAddress);
        vm.expectRevert("SphereX error: not the pending account");
        costumer_contract.acceptSphereXAdminRole();

        costumer_contract.acceptSphereXAdminRole();

        assertFlowStorageSlotsInInitialState();
    }

    function testAdminToFallback() external {
        vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        vm.prank(proxy_admin);
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
    }

    function testAdminToAdminGetter() external {
        vm.prank(proxy_admin);
        assertEq(ITransparentUpgradeableProxy(address(proxy_contract)).admin(), proxy_admin);
    }

    function testUserToAdminGetter() external {
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).admin();
    }

    function testAdminToImpGetter() external {
        vm.prank(proxy_admin);
        assertEq(
            ITransparentUpgradeableProxy(address(proxy_contract)).implementation(), address(protected_proxy_contract)
        );
    }

    function testUserToImpGetter() external {
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).implementation();
    }

    function testAdminToChangeAdmin() external {
        address new_admin = vm.addr(4);

        vm.prank(proxy_admin);
        ITransparentUpgradeableProxy(address(proxy_contract)).changeAdmin(new_admin);

        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).admin();

        vm.prank(new_admin);
        assertEq(ITransparentUpgradeableProxy(address(proxy_contract)).admin(), new_admin);
    }

    function testUserToChangeAdmin() external {
        address new_admin = vm.addr(4);

        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).changeAdmin(new_admin);
    }

    function testAdminToUpdateTo() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        vm.prank(proxy_admin);
        ITransparentUpgradeableProxy(address(proxy_contract)).upgradeTo(address(new_costumer));

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
        CustomerBehindProxy1(address(proxy_contract)).new_func();
    }

    function testUserToUpdateTo() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();

        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).upgradeTo(address(new_costumer));
    }

    function testAdminToUpdateToAndCall() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        bytes memory new_func_data = abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector);

        vm.prank(proxy_admin);
        vm.expectCall(address(new_costumer), new_func_data);
        ITransparentUpgradeableProxy(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
    }

    function testUserToUpdateToAndCall() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        bytes memory new_func_data = abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector);

        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).upgradeToAndCall(address(new_costumer), new_func_data);
    }

    function testProtectedTransparentAdminBehavior() external {
        vm.expectRevert("ProtectedTransparentUpgradeableSubProxy: admin cannot fallback to sub-proxy target");
        vm.prank(spherex_admin);
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
    }

    function testSubUpdate() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        vm.prank(spherex_admin);
        ISphereXProtectedSubProxy(address(proxy_contract)).subUpgradeTo(address(new_costumer));

        vm.expectCall(address(new_costumer), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
        CustomerBehindProxy1(address(proxy_contract)).new_func();
    }

    function testSubUpdateAndCall() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        bytes memory new_func_data = abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector);

        vm.prank(spherex_admin);
        vm.expectCall(address(new_costumer), new_func_data);
        ISphereXProtectedSubProxy(address(proxy_contract)).subUpgradeToAndCall(address(new_costumer), new_func_data);
    }

    function test_changeSphereXEngine_from_protected_function_engine_on() public override {}
}
