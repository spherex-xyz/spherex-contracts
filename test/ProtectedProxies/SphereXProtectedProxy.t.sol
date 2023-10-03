// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import {SphereXEngine} from "../../src/SphereXEngine.sol";
import {SphereXProtectedProxy} from "spherex-protect-contracts/SphereXProtectedProxy.sol";
import {CustomerBehindProxy, CostumerContract} from "../Utils/CostumerContract.sol";
import {SphereXProtectedTest} from "../SphereXProtected.t.sol";

abstract contract SphereXProtectedProxyTest is SphereXProtectedTest {
    SphereXProtectedProxy public proxy_contract;
    CustomerBehindProxy public p_costumer_contract;

    bytes4[] protected_sigs;

    function calc_allowed_cf(bytes4 func_selector) internal pure returns (uint216) {
        int256 func_hash = int256(uint256(uint32(func_selector)));
        int256[2] memory allowed_cf = [func_hash, -func_hash];

        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        return allowed_cf_hash;
    }

    function setUp() public virtual override {
        require(
            address(proxy_contract) != address(0),
            "SphereXProtectedProxyTest.setUp must be called as super from another setUp."
        );

        spherex_engine = new SphereXEngine();
        proxy_contract.changeSphereXOperator(address(this));

        allowed_patterns.push(calc_allowed_cf(CustomerBehindProxy.try_allowed_flow.selector));
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

    function testAddAlreadyExistsProtectedFuncSig() external {
        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.try_allowed_flow.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        costumer_contract.try_allowed_flow();
        assertFlowStorageSlotsInInitialState();
    }

    function testAddNewProtectedFuncSig() external {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory new_protected_sigs = new bytes4[](1);
        new_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        proxy_contract.addProtectedFuncSigs(new_protected_sigs);

        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }

    function testRemoveProtectedFuncSig() external {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.try_blocked_flow.selector);
        proxy_contract.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).try_blocked_flow();
    }

    function testRemoveAlreadyRemovedProtectedFuncSig() external {
        CustomerBehindProxy(address(proxy_contract)).to_block_2(); // Should work since it is not in protected sigs

        bytes4[] memory remove_protected_sigs = new bytes4[](1);
        remove_protected_sigs[0] = (CustomerBehindProxy.to_block_2.selector);
        proxy_contract.removeProtectedFuncSigs(remove_protected_sigs);

        CustomerBehindProxy(address(proxy_contract)).to_block_2();
    }
}
