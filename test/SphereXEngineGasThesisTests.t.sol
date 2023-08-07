// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "./Utils/CFUtils.sol";
import "../src/SphereXEngine.sol";

contract SphereXEngineTest is Test, CFUtils {
    address random_address = 0x6A08098568eE90b71dD757F070D79364197f944B;
    SphereXEngine.GasRangePatterns[] gasRanges;
    SphereXEngine.GasExactPatterns[] gasExacts;
    uint32[] gasNumbersExacts;

    function setUp() public {
        spherex_engine = new SphereXEngine();
        allowed_senders.push(address(this));
        spherex_engine.addAllowedSender(allowed_senders);
        spherex_engine.configureRules(GAS);
    }

    function sendDataToEngine(int256 num, uint256 gas) private {
        if (num > 0) {
            spherex_engine.sphereXValidateInternalPre(num);
        } else {
            bytes32[] memory emptyArray = new bytes32[](0);
            spherex_engine.sphereXValidateInternalPost(num, gas, emptyArray, emptyArray);
        }
    }

    //  ============ Test for the management functions  ============

    function test_addAllowedPatterns_noGasData_revert_expected() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        
        sendDataToEngine(allowed_cf[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf[1], 400);
    }
    
    function test_changeGasRangePatterns() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);
        gasRanges.push(SphereXEngine.GasRangePatterns(allowed_cf_hash, 399, 401));
        
        spherex_engine.changeGasRangePatterns(gasRanges);
        
        sendDataToEngine(allowed_cf[0], 400);
        sendDataToEngine(allowed_cf[1], 400);

        gasRanges.pop();
    }

    function test_addGasExactPatterns() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);

        gasNumbersExacts = [uint32(400)];
        gasExacts.push(SphereXEngine.GasExactPatterns(allowed_cf_hash, gasNumbersExacts));

        spherex_engine.addGasExactPatterns(gasExacts);
        
        sendDataToEngine(allowed_cf[0], 400);
        sendDataToEngine(allowed_cf[1], 400);
    }

    function test_excludeFromGasChecks() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.excludePatternsFromGas(allowed_patterns);
      
        sendDataToEngine(allowed_cf[0], 400);
        sendDataToEngine(allowed_cf[1], 400);
    }

    function test_includeFromGasChecks() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.incluePatternsInGas(allowed_patterns);
      
        sendDataToEngine(allowed_cf[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf[1], 400);
    }

    function test_setGasStrikeOutsLimit() public {
        int256[2] memory allowed_cf = [int256(1), -1];
        uint200 allowed_cf_hash = 1;
        for (uint256 i = 0; i < allowed_cf.length; i++) {
            allowed_cf_hash = uint200(bytes25(keccak256(abi.encode(int256(allowed_cf[i]), allowed_cf_hash))));
        }

        allowed_patterns = [allowed_cf_hash];
        spherex_engine.addAllowedPatterns(allowed_patterns);
        spherex_engine.incluePatternsInGas(allowed_patterns);
      
        sendDataToEngine(allowed_cf[0], 400);
        vm.expectRevert("SphereX error: disallowed tx gas pattern");
        sendDataToEngine(allowed_cf[1], 400);

        spherex_engine.setGasStrikeOutsLimit(1);
        sendDataToEngine(allowed_cf[1], 400);
    }

}
