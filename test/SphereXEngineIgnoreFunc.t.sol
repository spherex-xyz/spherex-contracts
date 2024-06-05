// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineIgnoreFunc is Test, CFUtils {
    address random_address = 0x6A08098568eE90b71dD757F070D79364197f944B;
    uint256[] ignoredFunctions;

    function setUp() public {
        spherex_engine = new SphereXEngine();
        allowed_senders.push(address(this));
        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.configureRules(bytes8(CF));
    }

    function sendExternalNumberToEngine(int256 num) private {
        bytes32[] memory emptyArray = new bytes32[](0);
        bytes memory emptyArray2 = new bytes(0);
        if (num > 0) {
            spherex_engine.sphereXValidatePre(num, random_address, emptyArray2);
        } else {
            spherex_engine.sphereXValidatePost(num, 0, emptyArray, emptyArray);
        }
    }

    //  ============ Test for the management functions  ============

    function test_not_approved_pattern_should_revert() public {
        allowed_cf_storage = [int256(1), -1];

        sendExternalNumberToEngine(allowed_cf_storage[0]);
        vm.expectRevert("SphereX error: disallowed tx pattern");
        sendExternalNumberToEngine(allowed_cf_storage[1]);
    }

    function test_ignore_function_in_not_approved_pattern_should_not_revert() public {
        allowed_cf_storage = [int256(1), -1];
        ignoredFunctions = [uint256(1)];

        spherex_engine.ignoreFunctionsFromFlow(ignoredFunctions);

        sendExternalNumberToEngine(allowed_cf_storage[0]);
        sendExternalNumberToEngine(allowed_cf_storage[1]);
    }

    function test_ignore_cf_and_revert_not_ignored_cf() public {
        allowed_cf_storage = [int256(1), -1];
        ignoredFunctions = [uint256(1)];

        spherex_engine.ignoreFunctionsFromFlow(ignoredFunctions);

        sendExternalNumberToEngine(allowed_cf_storage[0]);
        sendExternalNumberToEngine(allowed_cf_storage[1]);

        allowed_cf_storage = [int256(2), -2];

        sendExternalNumberToEngine(allowed_cf_storage[0]);
        vm.expectRevert("SphereX error: disallowed tx pattern");
        sendExternalNumberToEngine(allowed_cf_storage[1]);
    }
}
