// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineTest is Test, CFUtils {
    address random_address = 0x6A08098568eE90b71dD757F070D79364197f944B;

    modifier activateRule(bytes8 rule) {
        // This will make forge call the function with 1 and 2 as inputs!
        uint16 assumeVariable = uint8(uint16(uint64(rule)));
        vm.assume(assumeVariable > 0 && assumeVariable < 3);
        spherex_engine.activateRules(bytes8(rule));

        _;
    }

    function setUp() public {
        spherex_engine = new SphereXEngine();
        allowed_senders.push(address(this));
        spherex_engine.addAllowedSender(allowed_senders);
    }

    function sendNumberToEngine(int16 num) private {
        if (num > 0) {
            spherex_engine.sphereXValidateInternalPre(num);
        } else {
            spherex_engine.sphereXValidateInternalPost(num, 0);
        }
    }

    //  ============ Test for the management functions  ============

    function test_transferOwnership() public {
        spherex_engine.transferOwnership(random_address);
        vm.prank(random_address);
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);
    }

    function test_addAllowedSender() public activateRule(CF) {
        allowed_senders = [random_address];
        spherex_engine.addAllowedSender(allowed_senders);
        vm.prank(random_address);
        sendNumberToEngine(1);
    }

    function test_removeAllowedSender(bytes8 rule) public activateRule(rule) {
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);

        vm.expectRevert("!SX:SENDERS");
        sendNumberToEngine(1);

        assertFlowStorageSlotsInInitialState();
    }

    function test_addAllowedPatterns_two_patterns() public activateRule(CF) {
        int16[2] memory allowed_cf = [int16(1), -1];
        uint256 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint256(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash)));
        }

        int16[2] memory allowed_cf_2 = [int16(2), -2];
        uint256 allowed_cf_hash_2 = 1;
        for (uint256 i = 0; i < allowed_cf_2.length; i++) {
            allowed_cf_hash_2 = uint256(keccak256(abi.encode(int256(allowed_cf_2[i]), allowed_cf_hash_2)));
        }

        allowed_patterns = [allowed_cf_hash, allowed_cf_hash_2];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        for (uint256 i = 0; i < allowed_cf.length; i++) {
            sendNumberToEngine(allowed_cf[i]);
        }

        assertFlowStorageSlotsInInitialState();

        for (uint256 i = 0; i < allowed_cf_2.length; i++) {
            sendNumberToEngine(allowed_cf_2[i]);
        }

        assertFlowStorageSlotsInInitialState();
    }

    function test_removeAllowedPatterns(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), -1];
        uint256 allowed_cf_hash = addAllowedPattern();

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.removeAllowedPatterns(allowed_patterns);

        sendNumberToEngine(1);
        vm.expectRevert("!SX:DETECTED");
        sendNumberToEngine(-1);
    }

    // remove two cf and check that the first one was removed
    function test_removeAllowedPatterns_check_first_pattern_removed() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        uint256 allowed_cf_hash = addAllowedPattern();
        allowed_cf_storage = [int16(2), -2];
        addAllowedPattern();
        allowed_cf_storage = [int16(3), -3];
        uint256 allowed_cf_hash_3 = addAllowedPattern();

        allowed_patterns = [allowed_cf_hash, allowed_cf_hash_3];
        spherex_engine.removeAllowedPatterns(allowed_patterns);

        sendNumberToEngine(2);
        sendNumberToEngine(-2);

        sendNumberToEngine(1);
        vm.expectRevert("!SX:DETECTED");
        sendNumberToEngine(-1);
    }

    // remove two cf and check that the second one was removed
    function test_removeAllowedPatterns_check_second_pattern_removed() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        uint256 allowed_cf_hash = addAllowedPattern();
        allowed_cf_storage = [int16(2), -2];
        addAllowedPattern();
        allowed_cf_storage = [int16(3), -3];
        uint256 allowed_cf_hash_3 = addAllowedPattern();

        allowed_patterns = [allowed_cf_hash, allowed_cf_hash_3];
        spherex_engine.removeAllowedPatterns(allowed_patterns);

        sendNumberToEngine(2);
        sendNumberToEngine(-2);

        sendNumberToEngine(3);
        vm.expectRevert("!SX:DETECTED");
        sendNumberToEngine(-3);
    }

    // ============ Modifiers  ============

    function test_onlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        // change caller to random address
        vm.prank(random_address);
        allowed_senders = [address(this)];
        spherex_engine.removeAllowedSender(allowed_senders);
    }

    function test_onlyApprovedSenders_sphereXValidateInternalPre() public {
        spherex_engine.activateRules(CF);
        vm.expectRevert("!SX:SENDERS");
        vm.prank(random_address);
        sendNumberToEngine(1);
    }

    function test_onlyApprovedSenders_sphereXValidatePre() public {
        spherex_engine.activateRules(CF);
        vm.expectRevert("!SX:SENDERS");
        vm.prank(random_address);
        spherex_engine.sphereXValidatePre(1, address(this), msg.data);
    }

    function test_onlyApprovedSenders_sphereXValidatePost() public {
        spherex_engine.activateRules(CF);
        vm.expectRevert("!SX:SENDERS");
        vm.prank(random_address);
        bytes32[] memory emptyArray = new bytes32[](0);
        spherex_engine.sphereXValidatePost(1, 0, emptyArray, emptyArray);
    }

    function test_returnsIfNotActivated_sphereXValidateInternalPre() public {
        spherex_engine.deactivateRules();
        sendNumberToEngine(1);
        sendNumberToEngine(-1);

        assertFlowStorageSlotsInInitialState();
    }

    function test_returnsIfNotActivated_sphereXValidatePrePost() public {
        spherex_engine.deactivateRules();
        spherex_engine.sphereXValidatePre(1, address(this), msg.data);
        bytes32[] memory emptyArray = new bytes32[](0);
        spherex_engine.sphereXValidatePost(-1, 0, emptyArray, emptyArray);

        assertFlowStorageSlotsInInitialState();
    }

    function test_activateRule1_not_owner() public {
        spherex_engine.activateRules(CF);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(random_address);
        spherex_engine.activateRules(CF);

        assertFlowStorageSlotsInInitialState();
    }

    function test_activateRule2_not_owner() public {
        spherex_engine.activateRules(CF);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(random_address);
        spherex_engine.activateRules(PREFIX_TX_FLOW);

        assertFlowStorageSlotsInInitialState();
    }

    function test_deactivateRules_not_owner() public {
        spherex_engine.deactivateRules();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(random_address);
        spherex_engine.deactivateRules();

        assertFlowStorageSlotsInInitialState();
    }

    //  ============ Call flow  ============

    function test_sphereXValidateInternalPre_allowed_cf() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        assertFlowStorageSlotsInInitialState();
    }

    function test_sphereXValidateInternalPre_not_allowed_cf() public activateRule(CF) {
        sendNumberToEngine(1);

        vm.expectRevert(bytes("!SX:DETECTED"));
        sendNumberToEngine(-1);
    }

    function test_sphereXValidatePrePost_allowed_cf() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            if (allowed_cf_storage[i] > 0) {
                bytes memory empty;
                spherex_engine.sphereXValidatePre(allowed_cf_storage[i], address(0), empty);
            }
            if (allowed_cf_storage[i] < 0) {
                bytes32[] memory empty;
                spherex_engine.sphereXValidatePost(allowed_cf_storage[i], 0, empty, empty);
            }
        }

        assertFlowStorageSlotsInInitialState();
    }

    function test_sphereXValidatePrePost_not_allowed_cf() public activateRule(CF) {
        bytes memory empty;
        spherex_engine.sphereXValidatePre(1, address(0), empty);

        vm.expectRevert(bytes("!SX:DETECTED"));

        bytes32[] memory empty2;
        spherex_engine.sphereXValidatePost(-1, 0, empty2, empty2);
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check success with [1,2,3,4,5,-5,-4,-3,-2,-1]
    function test_CallFlow_sanity() public activateRule(CF) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[10] memory allowed_long_cf = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        for (uint256 i = 0; i < allowed_long_cf.length; i++) {
            sendNumberToEngine(allowed_long_cf[i]);
        }

        assertFlowStorageSlotsInInitialState();
    }

    // allowed call flow is [1,-1]
    // we check success with [1,-1], [1,-1]
    function test_CallFlow_same_flow_twice_in_a_row() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        assertFlowStorageSlotsInInitialState();
    }

    function test_currentPattern_and_callDepth_values_in_storage() public activateRule(CF) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        sendNumberToEngine(1);
        assertEq(
            vm.load(address(spherex_engine), currentPatternStorageSlot), keccak256(abi.encode(int256(1), uint256(1)))
        );
        assertEq(vm.load(address(spherex_engine), cfDepthStorageSlot), bytes32(uint256(2)));

        sendNumberToEngine(-1);
        assertFlowStorageSlotsInInitialState();
    }

    //  ============ Prefix tx flow  ============

    // Check that the current pattern isnt cleared at depth == 1 like in CF
    function test_PrefixTFlow_current_pattern_not_clean_at_depth_1() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        assertEq(vm.load(address(spherex_engine), currentPatternStorageSlot) != bytes32(uint256(1)), true);
        assertEq(vm.load(address(spherex_engine), cfDepthStorageSlot), bytes32(uint256(1)));
    }

    // Sanity check, unlike cf the current pattern isnt being cleaned at depth==1 hence this
    // test should work and the entire [1,-1,2,-2] should be approved
    function test_PrefixTFlow_sanity() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        allowed_cf_storage = [int16(1), -1, 2, -2];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }
    }

    // Check that after the block number is incremented we check the current flow from the beginning
    // In cf this test would have failed since the pattern would have been cleaned
    function test_PrefixTFlow_same_origin_same_block_number() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            if (i == allowed_cf_storage.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(allowed_cf_storage[i]);
        }
    }

    // Check that after the block number is incremented we check the current flow from the begning
    function test_PrefixTFlow_same_origin_different_block_number() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        vm.roll(2);

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }
    }

    // Check that after the a different tx.origin we check the current flow from the begning
    function test_PrefixTFlow_different_origin_same_block_number() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        vm.startPrank(address(this), random_address);

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }
        vm.stopPrank();
    }

    function test_activateRule1_after_Rule2() public activateRule(PREFIX_TX_FLOW) {
        spherex_engine.activateRules(CF);
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        // If we were still in rule2 (prefix tx flow) this would have been reverted
        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }
    }

    function test_activateRule2_after_Rule1() public activateRule(CF) {
        spherex_engine.activateRules(PREFIX_TX_FLOW);

        // If we would have stayed in rule1 the test would have failed (see somment above the original test)
        test_PrefixTFlow_same_origin_same_block_number();
    }

    // Check currentBlock and currentAddress state variable change
    function test_PrefixTFlow_different_origin_different_block_number() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        vm.roll(2);
        vm.startPrank(address(this), random_address);

        // since the effect on the storage will be applied only at the next transaction we need to acll at least
        // once to the engine again
        sendNumberToEngine(allowed_cf_storage[0]);

        vm.stopPrank();

        // the slot layout is 0x[32 empty bits][160 bits for origin address][64 bits for block number]
        assertEq((vm.load(address(spherex_engine), currentBlockStorageSlot)), keccak256(abi.encode(2, random_address)));
    }

    // Check that after we recognize a new transaction we dont allow the suffix of an approved flow
    // to pass. [1,-1], [1,-1,2,-2] approved, [2,-2] reverted!
    function test_PrefixTFlow_check_suffix() public activateRule(PREFIX_TX_FLOW) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();

        allowed_cf_storage = [int16(1), -1, 2, -2];
        addAllowedPattern();

        allowed_cf_storage = [int16(1), -1];
        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            sendNumberToEngine(allowed_cf_storage[i]);
        }

        vm.roll(2);

        allowed_cf_storage = [int16(2), -2];
        for (uint256 i = 0; i < allowed_cf_storage.length; i++) {
            if (i == allowed_cf_storage.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(allowed_cf_storage[i]);
        }
    }

    //  ============ Prefix tx/cf flow  ============

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [4,3,5,-5,-3,-4]
    function test_CallFlow_partial_elements_different_length(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[6] memory not_allowed_cf = [int16(4), 3, 5, -5, -3, -4];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [1,2,3,1,2,3,-3,-2,-1,-3,-2,-1]
    function test_CallFlow_partial_elements_same_length(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[12] memory not_allowed_cf = [int16(1), 2, 3, 1, 2, 3, -3, -2, -1, -3, -2, -1];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [1,2,4,5,-5,-4,-2,-1]
    function test_CallFlow_partial_elements_same_order_different_length(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[8] memory not_allowed_cf = [int16(1), 2, 4, 5, -5, -4, -2, -1];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [5,4,3,2,1,-1,-2,-3,-4,-5]
    function test_CallFlow_same_elements_backwards_order_same_length(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[10] memory not_allowed_cf = [int16(5), 4, 3, 2, 1, -1, -2, -3, -4, -5];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [2,1,5,3,4,-4,-3,-5,-1,-2]
    function test_CallFlow_same_elements_different_order_same_length(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[10] memory not_allowed_cf = [int16(2), 1, 5, 3, 4, -4, -3, -5, -1, -2];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check failure with [1,2,4,3,5,-5,-3,-4,-2,-1]
    function test_CallFlow_same_elements_different_order_same_length_same_prefix_and_suffix(bytes8 rule)
        public
        activateRule(rule)
    {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[10] memory not_allowed_cf = [int16(1), 2, 4, 3, 5, -5, -3, -4, -2, -1];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,2,3,4,5,-5,-4,-3,-2,-1]
    // we check success with [1,-1,2,-2,3,-3,4,-4,5,-5]
    function test_CallFlow_same_elements_different_nesting(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[10] memory not_allowed_cf = [int16(1), -1, 2, -2, 3, -3, 4, -4, 5, -5];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == 1) {
                // we expect the -1 step will revert
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    // allowed call flow is [1,-1][2,-2]
    // we check success with [1,2,-2,-1]
    function test_CallFlow_same_elements_different_nesting_2(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();
        allowed_cf_storage = [int16(2), -2];
        addAllowedPattern();

        int16[4] memory not_allowed_cf = [int16(1), int16(2), -2, -1];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == not_allowed_cf.length - 1) {
                vm.expectRevert("!SX:DETECTED");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }

    function test_CFNumIsZero(bytes8 rule) public activateRule(rule) {
        vm.expectRevert(bytes("!SX: ERROR"));
        sendNumberToEngine(0);
    }

    function test_CFNumIsZero_in_the_middle_of_a_flow(bytes8 rule) public activateRule(rule) {
        allowed_cf_storage = [int16(1), 2, 3, 4, 5, -5, -4, -3, -2, -1];
        addAllowedPattern();

        int16[4] memory not_allowed_cf = [int16(1), 2, 3, 0];
        for (uint256 i = 0; i < not_allowed_cf.length; i++) {
            if (i == 3) {
                // we expect the 0 step will revert
                vm.expectRevert("!SX: ERROR");
            }
            sendNumberToEngine(not_allowed_cf[i]);
        }
    }
}
