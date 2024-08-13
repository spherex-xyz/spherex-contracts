// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXEngine} from "../../src/SphereXEngine.sol";
import {SphereXProtectedProxy} from "../../src/SphereXProtectedProxy.sol";
import {CustomerBehindProxy, CostumerContract, SomeContract} from "../Utils/CostumerContract.sol";
import {SphereXProtectedTest} from "../SphereXProtected.t.sol";

abstract contract SphereXProtectedProxyTest is SphereXProtectedTest {
    SphereXProtectedProxy public proxy_contract;
    CustomerBehindProxy public p_costumer_contract;

    bytes4[] protected_sigs;

    function setUp() public virtual override {
        require(
            address(proxy_contract) != address(0),
            "SphereXProtectedProxyTest.setUp must be called as super from another setUp, and proxy_contract must be set before"
        );

        spherex_engine = new SphereXEngine();
        proxy_contract.changeSphereXOperator(address(this));

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
        proxy_contract.addProtectedFuncSigs(protected_sigs);

        allowed_senders.push(address(proxy_contract));
        spherex_engine.addAllowedSender(allowed_senders);

        spherex_engine.configureRules(CF);
        proxy_contract.changeSphereXEngine(address(spherex_engine));

        costumer_contract = CostumerContract(address(proxy_contract));
    }

    function testStaticMethod() external {
        assertEq(CustomerBehindProxy(address(costumer_contract)).static_method(), 5);
    }

    function testAddStaticMethod() external virtual {
        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.static_method.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert();
        CustomerBehindProxy(address(costumer_contract)).static_method();
    }

    function testAddAlreadyExistsProtectedFuncSig() external virtual {
        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.try_allowed_flow.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        costumer_contract.try_allowed_flow();
        assertFlowStorageSlotsInInitialState();
    }

    function testAddNewProtectedFuncSig() external virtual {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }

    function testAddTwoNewProtectedFuncSig() external virtual {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs
        CustomerBehindProxy(address(proxy_contract)).to_block_3(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](2);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        new_protected_sigs[1] = (CustomerBehindProxy.to_block_3.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_3();
    }

    function testRemoveProtectedFuncSig() external virtual {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.try_blocked_flow.selector);
        proxy_contract.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();
    }

    function testRemoveTwoProtectedFuncSig() external virtual {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs
        CustomerBehindProxy(address(proxy_contract)).to_block_3(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](2);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        new_protected_sigs[1] = (CustomerBehindProxy.to_block_3.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_3();

        proxy_contract.removeProtectedFuncSigs(new_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).to_block_2();
        CustomerBehindProxy(address(proxy_contract)).to_block_3();
    }

    function testRemoveAlreadyRemovedProtectedFuncSig() external virtual {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        proxy_contract.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }

    function testPartialRevertAllowedFlow() external override {
        allowed_cf_storage =
            [to_int256(costumer_contract.call_inner.selector), -to_int256(costumer_contract.call_inner.selector)];
        addAllowedPattern();
        costumer_contract.call_inner();

        assertFlowStorageSlotsInInitialState();
    }

    function testPartialRevertNotAllowedFlow() external override {
        // create an allowed cf [3,4,5,-5,-4,-3]
        allowed_cf_storage = [
            to_int256(costumer_contract.call_inner.selector),
            to_int256(costumer_contract.reverts.selector),
            -to_int256(costumer_contract.reverts.selector),
            -to_int256(costumer_contract.call_inner.selector)
        ];
        addAllowedPattern();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.call_inner();

        assertFlowStorageSlotsInInitialState();
    }

    // It is a redundent test for proxy but it would fail if not overrided
    function testExternalCallsInternalFunction() external override {}
    function testPublicCallsPublic() external override {}
    function testPublicCallsSamePublic() external override {}
    function test_factorySetup() public override {}
    function test_factoryAllowedSender() public override {}
    function test_factoryfailsAllowedSender() public override {}
    function test_factory_callCreatedContract() public override {}
    function test_factoryEngineDisabled() public override {}
    function test_grantSenderAdderRoleOnlyOperator() public override {}

    function test_changeSphereXEngine_from_protected_function_engine_on() public virtual override {
        spherex_engine.configureRules(CF);
        allowed_cf_storage =
            [to_int256(costumer_contract.setEngine.selector), -to_int256(costumer_contract.setEngine.selector)];
        addAllowedPattern();
        allowed_cf_storage = [
            to_int256(costumer_contract.publicFunction.selector),
            -to_int256(costumer_contract.publicFunction.selector)
        ];
        addAllowedPattern();
        // call the publicFunction and see it doesnt revert
        costumer_contract.publicFunction();

        SphereXEngine spherex_engine_2 = new SphereXEngine();
        spherex_engine_2.configureRules(CF);
        allowed_senders.push(address(costumer_contract));
        spherex_engine_2.addAllowedSender(allowed_senders);

        costumer_contract.changeSphereXOperator(address(proxy_contract));
        costumer_contract.setEngine(address(spherex_engine_2));

        // after successfully cahging the engine call the publicFunction function and expect revert
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.publicFunction();
    }
}
