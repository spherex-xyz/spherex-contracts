// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

/**
 * @title Interface for SphereXEngine - defenitions of core functionality
 * @author SphereX Technolegies ltd
 * @notice This interface is imported by SphereXProtected, so that SphereXProtected can call functions from SphereXEngine
 * @dev Full docs of these functions can be found in SphereXEngine
 */
interface ISphereXEngine {
    function sphereXValidatePre(int16 num, address sender, bytes calldata data) external returns (bytes32[] memory);
    function sphereXValidatePost(
        int16 num,
        uint256 gas,
        bytes32[] calldata valuesBefore,
        bytes32[] calldata valuesAfter
    ) external;
    function sphereXValidateInternalPre(int16 num) external;
    function sphereXValidateInternalPost(int16 num, uint256 gas) external;
}
