// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "./Utils/MockEngine.sol";
import "./Utils/CostumerContract.sol";
import "../src/SphereXEngine.sol";
import "../src/SphereXProtected.sol";

contract SphereXProtectedTest is Test, CFUtils {
    CostumerContract public costumer_contract;

    modifier activateRule2() {
        spherex_engine.configureRules(PREFIX_TX_FLOW);
        allowed_cf_storage = [int16(1), -1, 11, 12, -12, -11];
        addAllowedPattern();
        allowed_cf_storage = [int16(1), -1];
        addAllowedPattern();
        allowed_cf_storage = [int16(1), -1, 11, 12, -12];
        addAllowedPattern();
        _;
    }

    function setUp() public virtual {
        spherex_engine = new SphereXEngine();
        costumer_contract = new CostumerContract();

        int16[2] memory allowed_cf = [int16(1), -1];
        uint216 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint216(bytes27(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }
        allowed_patterns.push(allowed_cf_hash);
        allowed_senders.push(address(costumer_contract));

        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.configureRules(bytes8(uint64(1)));

        costumer_contract.changeSphereXEngine(address(spherex_engine));
    }

    //  ============ Managment functions  ============

    function test_changeSphereXEngine_disable_engine() external {
        // this test covers enable->disable (by default the engine is enabled in the set up)
        costumer_contract.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_disable_enable() external {
        costumer_contract.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        costumer_contract.changeSphereXEngine(address(spherex_engine));
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_disable_disable() external {
        costumer_contract.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        costumer_contract.changeSphereXEngine(address(0));
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXEngine_enable_enable() external {
        // the setup function is enabling the engine by default so we only need to
        // enable once
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        costumer_contract.changeSphereXEngine(address(spherex_engine));
        costumer_contract.try_allowed_flow();
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function test_changeSphereXAdmin() external {
        address otherAddress = address(1);

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

    //  ============ Call flow thesis tests  ============

    function testAllowed() external {
        costumer_contract.try_allowed_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testTwoAllowedCall() external {
        costumer_contract.try_allowed_flow();
        costumer_contract.try_allowed_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testBlocked() external {
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_blocked_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testPartialRevertAllowedFlow() external {
        allowed_cf_storage = [int16(3), 4, -4, -3];
        addAllowedPattern();
        costumer_contract.call_inner();

        assertFlowStorageSlotsInInitialState();
    }

    function testPartialRevertNotAllowedFlow() external {
        // create an allowed cf [3,4,5,-5,-4,-3]
        allowed_cf_storage = [int16(3), 4, 5, -5, -4, -3];
        addAllowedPattern();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.call_inner();

        assertFlowStorageSlotsInInitialState();
    }
    /**
     * @dev this test will fail if we add a storage logic!
     *      for now it checks that nothing is being sent
     *      to the engine at the post call except for the num parameter.
     */

    function testPublicFunction() external {
        allowed_cf_storage = [int16(6), -6];
        addAllowedPattern();

        bytes memory publicFunctionMsgData = abi.encodeWithSelector(costumer_contract.publicFunction.selector);
        bytes memory engineCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidatePre.selector, 6, address(1), publicFunctionMsgData);
        bytes memory engineCallnoMsgData = abi.encodeWithSelector(spherex_engine.sphereXValidatePost.selector);
        vm.expectCall(address(spherex_engine), engineCallMsgData);
        vm.expectCall(address(spherex_engine), engineCallnoMsgData);
        vm.prank(address(1));
        costumer_contract.publicFunction();

        assertFlowStorageSlotsInInitialState();
    }

    function testExternalFunction() external {
        bytes memory externalFunctionMsgData = abi.encodeWithSelector(costumer_contract.try_allowed_flow.selector);
        bytes memory engineCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidatePre.selector, 1, address(1), externalFunctionMsgData);
        vm.expectCall(address(spherex_engine), engineCallMsgData);
        vm.prank(address(1));
        costumer_contract.try_allowed_flow();

        assertFlowStorageSlotsInInitialState();
    }

    function testExternalCallsInternalFunction() external {
        allowed_cf_storage = [int16(3), 4, -4, -3];
        addAllowedPattern();

        bytes memory externalFunctionMsgData = abi.encodeWithSelector(costumer_contract.call_inner.selector);
        bytes memory engineExternalCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidatePre.selector, 3, address(1), externalFunctionMsgData);
        bytes memory engineInternalCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidateInternalPre.selector, 4);

        vm.expectCall(address(spherex_engine), engineExternalCallMsgData);
        vm.expectCall(address(spherex_engine), engineInternalCallMsgData);
        vm.prank(address(1));
        costumer_contract.call_inner();

        assertFlowStorageSlotsInInitialState();
    }

    function testPublicCallsPublic() external {
        allowed_cf_storage = [int16(7), 6, -6, -7];
        addAllowedPattern();

        bytes memory publicCallsPublicMsgData = abi.encodeWithSelector(costumer_contract.publicCallsPublic.selector);
        bytes memory publicCallsPublicEngineCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidatePre.selector, 7, address(1), publicCallsPublicMsgData);

        bytes memory publicFunctionEngineCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidateInternalPre.selector, 6);

        vm.expectCall(address(spherex_engine), publicCallsPublicEngineCallMsgData);
        vm.expectCall(address(spherex_engine), publicFunctionEngineCallMsgData);
        vm.prank(address(1));
        costumer_contract.publicCallsPublic();

        assertFlowStorageSlotsInInitialState();
    }

    /**
     * @dev this is andesirable behaviour where internally called
     *      public function, in the context of the same function
     *      being called externally, will trigger sending msg.data
     *      twice to the engine.
     */
    function testPublicCallsSamePublic() external {
        allowed_cf_storage = [int16(8), 8, -8, -8];
        addAllowedPattern();

        allowed_cf_storage = [int16(8), 8, -8];
        addAllowedPattern();

        bytes memory publicCallsSamePublicMsgData =
            abi.encodeWithSelector(costumer_contract.publicCallsSamePublic.selector, true);
        bytes memory engineCallMsgData = abi.encodeWithSelector(
            spherex_engine.sphereXValidatePre.selector, 8, address(1), publicCallsSamePublicMsgData
        );

        vm.expectCall(address(spherex_engine), engineCallMsgData);
        vm.expectCall(address(spherex_engine), engineCallMsgData);
        vm.prank(address(1));
        costumer_contract.publicCallsSamePublic(true);

        assertFlowStorageSlotsInInitialState();
    }

    function testArbitraryCall() external {
        allowed_cf_storage = [int16(10), -10];
        addAllowedPattern();

        bytes memory engineCallMsgData =
            abi.encodeWithSelector(spherex_engine.sphereXValidateInternalPre.selector, int16(10));

        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.arbitraryCall(address(spherex_engine), engineCallMsgData);

        assertFlowStorageSlotsInInitialState();
    }

    function testExternalCallsExternalTwice() external {
        allowed_cf_storage = [int16(11), 12, -12, -11];
        addAllowedPattern();

        allowed_cf_storage = [int16(11), 12, -12];
        addAllowedPattern();

        costumer_contract.externalCallsExternal();
        costumer_contract.externalCallsExternal();

        assertFlowStorageSlotsInInitialState();
    }

    //  ============ Storage thesis helper function test  ============

    function test_readSlot() external {
        MockEngine mock_spherex_engine = new MockEngine();
        uint256 before = costumer_contract.slot0();
        costumer_contract.changeSphereXEngine(address(mock_spherex_engine));
        costumer_contract.changex();
        assertEq(mock_spherex_engine.stor(0), before);
        assertEq(mock_spherex_engine.stor(1), costumer_contract.slot0());

        assertFlowStorageSlotsInInitialState();
    }

    //  ============ Prefix tx flow  ============
    // We initialize the engine (in the activateRule2 modifier) such that
    // the allowed patterns are calling allowed, and calling allowed,externalCallsExternal
    // calling only externalCallsExternal is prohibited

    function test_PrefixTxFlow_sanity() public activateRule2 {
        costumer_contract.try_allowed_flow();
        costumer_contract.externalCallsExternal();
    }

    function test_PrefixTxFlow_sanity_revert() public activateRule2 {
        costumer_contract.try_allowed_flow();
        vm.roll(2);
        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.externalCallsExternal();
    }

    function test_PrefixTxFlow_known_issue_good_scenario() public activateRule2 {
        costumer_contract.try_allowed_flow();
        costumer_contract.externalCallsExternal();

        vm.startPrank(address(this), 0x6A08098568eE90b71dD757F070D79364197f944B);
        costumer_contract.try_allowed_flow();
        costumer_contract.externalCallsExternal();
        vm.stopPrank();

        costumer_contract.try_allowed_flow();
        costumer_contract.externalCallsExternal();
    }

    function test_PrefixTxFlow_known_issue_bad_scenario() public activateRule2 {
        costumer_contract.try_allowed_flow();
        costumer_contract.externalCallsExternal();

        vm.expectRevert("SphereX error: disallowed tx pattern");
        costumer_contract.try_allowed_flow();
    }
}
