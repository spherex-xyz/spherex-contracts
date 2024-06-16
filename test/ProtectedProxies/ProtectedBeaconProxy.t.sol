// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";

import {CustomerBehindProxy, CustomerBehindProxy1, CostumerContract} from "../Utils/CostumerContract.sol";
import {MockEngine} from "../Utils/MockEngine.sol";
import {SphereXProtectedProxyTest} from "./SphereXProtectedProxy.t.sol";
import {ProtectedBeaconProxy} from "../../src/ProtectedProxies/ProtectedBeaconProxy.sol";
import {SphereXProtectedProxy} from "../../src/SphereXProtectedProxy.sol";
import {SphereXUpgradeableBeacon} from "../../src/ProtectedProxies/SphereXUpgradeableBeacon.sol";
import {SphereXEngine} from "../../src/SphereXEngine.sol";

contract ProtectedBeaconProxyTest is SphereXProtectedProxyTest {
    SphereXUpgradeableBeacon public beacon;

    function setUp() public virtual override {
        spherex_engine = new SphereXEngine();

        p_costumer_contract = new CustomerBehindProxy();
        beacon = new SphereXUpgradeableBeacon(address(p_costumer_contract), address(this), address(this), address(0));
        proxy_contract = SphereXProtectedProxy(payable(new ProtectedBeaconProxy(address(beacon), bytes(""))));

        allowed_patterns.push(calc_pattern_by_selector(CustomerBehindProxy.try_allowed_flow.selector));
        spherex_engine.addAllowedPatterns(allowed_patterns);

        protected_sigs.push(CustomerBehindProxy.initialize.selector);
        protected_sigs.push(CustomerBehindProxy.try_allowed_flow.selector);
        protected_sigs.push(CustomerBehindProxy.try_blocked_flow.selector);
        protected_sigs.push(CustomerBehindProxy.call_inner.selector);
        protected_sigs.push(CustomerBehindProxy.reverts.selector);
        protected_sigs.push(CustomerBehindProxy.publicFunction.selector);
        protected_sigs.push(CustomerBehindProxy.publicCallsPublic.selector);
        protected_sigs.push(CustomerBehindProxy.publicCallsSamePublic.selector);
        protected_sigs.push(CustomerBehindProxy.changex.selector);
        protected_sigs.push(CustomerBehindProxy.arbitraryCall.selector);
        protected_sigs.push(CustomerBehindProxy.externalCallsExternal.selector);
        protected_sigs.push(CustomerBehindProxy.externalCallee.selector);
        protected_sigs.push(CustomerBehindProxy.factory.selector);
        beacon.addProtectedFuncSigs(protected_sigs);

        allowed_senders.push(address(proxy_contract));
        spherex_engine.addAllowedSender(allowed_senders);

        spherex_engine.configureRules(CF);
        beacon.changeSphereXEngine(address(spherex_engine));

        costumer_contract = CostumerContract(address(proxy_contract));
    }

    function testUpdate() external {
        CustomerBehindProxy1 new_costumer = new CustomerBehindProxy1();
        beacon.upgradeTo(address(new_costumer));

        protected_sigs.push(CustomerBehindProxy1.new_func.selector);
        beacon.addProtectedFuncSigs(protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy1(address(proxy_contract)).new_func();

        allowed_patterns.push(calc_pattern_by_selector(CustomerBehindProxy1.new_func.selector));
        spherex_engine.addAllowedPatterns(allowed_patterns);

        vm.expectCall(address(proxy_contract), abi.encodeWithSelector(CustomerBehindProxy1.new_func.selector));
        CustomerBehindProxy1(address(proxy_contract)).new_func();
    }

    function test_changeSphereXEngine_disable_engine() external virtual override {
        // this test covers enable->disable (by default the engine is enabled in the set up)
        beacon.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_disable_enable() external virtual override {
        beacon.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        beacon.changeSphereXEngine(address(spherex_engine));
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_disable_disable() external virtual override {
        beacon.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        beacon.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_enable_enable() external override {
        // the setup function is enabling the engine by default so we only need to
        // enable once
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        beacon.changeSphereXEngine(address(spherex_engine));
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXAdmin() external virtual override {
        address otherAddress = address(1);

        beacon.transferSphereXAdminRole(otherAddress);
        vm.prank(otherAddress);
        beacon.acceptSphereXAdminRole();

        vm.expectRevert("SphereX error: admin required");
        beacon.transferSphereXAdminRole(address(this));
        vm.prank(otherAddress);
        beacon.transferSphereXAdminRole(address(this));

        vm.prank(otherAddress);
        vm.expectRevert("SphereX error: not the pending account");
        beacon.acceptSphereXAdminRole();

        assertFlowStorageSlotsInInitialState();
    }

    function test_readSlot() external virtual override {
        MockEngine mock_spherex_engine = new MockEngine();
        uint256 before = costumer_contract.slot0();
        beacon.changeSphereXEngine(address(mock_spherex_engine));
        costumer_contract.changex();
        assertEq(mock_spherex_engine.stor(0), before);
        assertEq(mock_spherex_engine.stor(1), costumer_contract.slot0());

        assertFlowStorageSlotsInInitialState();
    }

    function testAddStaticMethod() external virtual override {
        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.static_method.selector);
        beacon.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert();
        CustomerBehindProxy(address(costumer_contract)).static_method();
    }

    function testAddAlreadyExistsProtectedFuncSig() external virtual override {
        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.try_allowed_flow.selector);
        beacon.addProtectedFuncSigs(new_protected_sigs);

        costumer_contract.try_allowed_flow();
        assertFlowStorageSlotsInInitialState();
    }

    function testAddNewProtectedFuncSig() external virtual override {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        beacon.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }

    function testAddTwoNewProtectedFuncSig() external virtual override {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs
        CustomerBehindProxy(address(proxy_contract)).to_block_3(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](2);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        new_protected_sigs[1] = (CustomerBehindProxy.to_block_3.selector);
        beacon.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_3();
    }

    function testRemoveProtectedFuncSig() external virtual override {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.try_blocked_flow.selector);
        beacon.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();
    }

    function testRemoveTwoProtectedFuncSig() external virtual override {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs
        CustomerBehindProxy(address(proxy_contract)).to_block_3(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](2);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        new_protected_sigs[1] = (CustomerBehindProxy.to_block_3.selector);
        beacon.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_3();

        beacon.removeProtectedFuncSigs(new_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).to_block_2();
        CustomerBehindProxy(address(proxy_contract)).to_block_3();
    }

    function testRemoveAlreadyRemovedProtectedFuncSig() external virtual override {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        beacon.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }

    function test_changeSphereXEngine_from_protected_function_engine_on() public override {}
}
