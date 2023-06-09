// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity >=0.6.2;

import "../../src/ISphereXEngine.sol";
import "forge-std/console.sol";

contract mockEngine is ISphereXEngine {
    uint256[2] public stor;

    function sphereXValidatePre(int256 num, address sender, bytes calldata data)
        external
        override
        returns (bytes32[] memory)
    {
        bytes32[] memory slot = new bytes32[](1);
        slot[0] = bytes32(0);
        return slot;
    }

    function sphereXValidatePost(int256 num, uint256 gas, bytes32[] calldata valuesBefore, bytes32[] calldata valuesAfter)
        external
        override
    {
        stor[0] = uint256(valuesBefore[0]);
        stor[1] = uint256(valuesAfter[0]);
    }

    function sphereXValidateInternalPre(int256 num) external override {}
    function sphereXValidateInternalPost(int256 num, uint256 gas) external override {}
}
