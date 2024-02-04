// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, CustomerBehindProxy1} from "../Utils/CostumerContract.sol";
import {ProtectedTransparentUpgradeableProxy} from "../../src/ProtectedProxies/ProtectedTransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";

contract ProtectedTransparentUpgradeableProxyTest is SphereXProtectedProxyTest {
    address proxy_admin = vm.addr(12345);

    function setUp() public override {
        p_costumer_contract = new CustomerBehindProxy();
        proxy_contract = new ProtectedTransparentUpgradeableProxy(address(p_costumer_contract), proxy_admin, "");

        super.setUp();
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
        assertEq(ITransparentUpgradeableProxy(address(proxy_contract)).implementation(), address(p_costumer_contract));
    }

    function testUserToImpGetter() external {
        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).implementation();
    }

    function testAdminToChangeAdmin() external {
        address new_admin = vm.addr(1);

        vm.prank(proxy_admin);
        ITransparentUpgradeableProxy(address(proxy_contract)).changeAdmin(new_admin);

        vm.expectRevert();
        ITransparentUpgradeableProxy(address(proxy_contract)).admin();

        vm.prank(new_admin);
        assertEq(ITransparentUpgradeableProxy(address(proxy_contract)).admin(), new_admin);
    }

    function testUserToChangeAdmin() external {
        address new_admin = vm.addr(1);

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

    function testSphereXAdminIsProxyAdmin() external {
        assertEq(proxy_contract.sphereXAdmin(), address(this));

        vm.prank(proxy_admin);
        ITransparentUpgradeableProxy(address(proxy_contract)).changeAdmin(address(this));

        // SphereX Management functions works
        address new_operator = vm.addr(1);
        proxy_contract.changeSphereXOperator(new_operator);
        assertEq(proxy_contract.sphereXOperator(), new_operator);

        // Transparent Management functions works
        assertEq(ITransparentUpgradeableProxy(address(proxy_contract)).implementation(), address(p_costumer_contract));

        // Transparent fallback as admin functions does not works
        vm.expectRevert("TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        CustomerBehindProxy(address(proxy_contract)).try_allowed_flow();
    }
}
