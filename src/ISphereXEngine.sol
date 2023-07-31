// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {IERC165} from "openzeppelin-contracts/utils/introspection/IERC165.sol";
/**
 * @title Interface for SphereXEngine - definitions of core functionality
 * @author SphereX Technologies ltd
 * @notice This interface is imported by SphereXProtected, so that SphereXProtected can call functions from SphereXEngine
 * @dev Full docs of these functions can be found in SphereXEngine
 */

interface ISphereXEngine is IERC165 {
    function sphereXValidatePre(int256 num, address sender, bytes calldata data) external returns (bytes32[] memory);
    function sphereXValidatePost(
        int256 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external;
    function sphereXValidateInternalPre(int256 num) external;
    function sphereXValidateInternalPost(int256 num, uint256 gas) external;
}
