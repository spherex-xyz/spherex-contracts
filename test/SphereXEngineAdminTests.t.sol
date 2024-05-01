// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineAdminFunctionsTests is Test, CFUtils {
    //  ============ Test for the management functions  ============

    function test_passOwnership() public {
        spherex_engine.beginDefaultAdminTransfer(random_address);
        vm.warp(block.timestamp + 2 days);
        vm.prank(random_address);
        spherex_engine.acceptDefaultAdminTransfer();
    }

    function test_onlyAdminCanGrantOperatorRoles() public {
        bytes32 OPERATOR_ROLE = spherex_engine.OPERATOR_ROLE();

        vm.prank(random_address);
        vm.expectRevert();
        spherex_engine.grantRole(OPERATOR_ROLE, random_address);

        spherex_engine.grantRole(OPERATOR_ROLE, random_address);
    }

    function test_addAndRemoveOperator() public {
        vm.prank(random_address);
        vm.expectRevert("SphereX error: operator required");
        spherex_engine.addAllowedSender(allowed_senders);

        spherex_engine.grantRole(spherex_engine.OPERATOR_ROLE(), random_address);
        vm.prank(random_address);
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);

        spherex_engine.revokeRole(spherex_engine.OPERATOR_ROLE(), random_address);
        vm.prank(random_address);
        vm.expectRevert("SphereX error: operator required");
        spherex_engine.addAllowedSender(allowed_senders);
    }

    function test_addAllowedSender() public {
        allowed_senders = [random_address];
        spherex_engine.addAllowedSender(allowed_senders);

        // this is done just to activate the engine, the specific rule does not matter
        spherex_engine.configureRules(bytes8(uint64(1)));

        vm.prank(random_address);
        sendNumberToEngine(1);
    }

    function test_removeAllowedSender() public {
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);

        // this is done just to activate the engine, the specific rule does not matter
        spherex_engine.configureRules(bytes8(uint64(1)));

        vm.expectRevert("SphereX error: disallowed sender");
        sendNumberToEngine(1);

        assertFlowStorageSlotsInInitialState();
    }

    // ============ Modifiers  ============

    function test_badRulesConfig() public {
        vm.expectRevert("SphereX error: illegal rules combination");
        spherex_engine.configureRules(bytes8(uint64(3)));
    }

    function test_onlyOwner() public {
        vm.expectRevert("SphereX error: operator required");
        // change caller to random address
        vm.prank(random_address);
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);
    }

    function test_onlyApprovedSenders_sphereXValidateInternalPre() public {
        spherex_engine.configureRules(CF);
        vm.expectRevert("SphereX error: disallowed sender");
        vm.prank(random_address);
        sendNumberToEngine(1);
    }

    function test_onlyApprovedSenders_sphereXValidatePre() public {
        spherex_engine.configureRules(CF);
        vm.expectRevert("SphereX error: disallowed sender");
        vm.prank(random_address);
        spherex_engine.sphereXValidatePre(1, address(this), msg.data);
    }

    function test_onlyApprovedSenders_sphereXValidatePost() public {
        spherex_engine.configureRules(CF);
        vm.expectRevert("SphereX error: disallowed sender");
        vm.prank(random_address);
        bytes32[] memory emptyArray = new bytes32[](0);
        spherex_engine.sphereXValidatePost(1, 0, emptyArray, emptyArray);
    }

    function test_returnsIfNotActivated_sphereXValidateInternalPre() public {
        spherex_engine.deactivateAllRules();
        sendNumberToEngine(1);
        sendNumberToEngine(-1);

        assertFlowStorageSlotsInInitialState();
    }

    function test_returnsIfNotActivated_sphereXValidatePrePost() public {
        spherex_engine.deactivateAllRules();
        spherex_engine.sphereXValidatePre(1, address(this), msg.data);
        bytes32[] memory emptyArray = new bytes32[](0);
        spherex_engine.sphereXValidatePost(-1, 0, emptyArray, emptyArray);

        assertFlowStorageSlotsInInitialState();
    }

    function test_activateCallFlow_not_owner() public {
        spherex_engine.configureRules(CF);

        vm.expectRevert("SphereX error: operator required");
        vm.prank(random_address);
        spherex_engine.configureRules(CF);

        assertFlowStorageSlotsInInitialState();
    }

    function test_deactivateAllRules_not_owner() public {
        spherex_engine.deactivateAllRules();

        vm.expectRevert("SphereX error: operator required");
        vm.prank(random_address);
        spherex_engine.deactivateAllRules();

        assertFlowStorageSlotsInInitialState();
    }
}
