// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.5.0;

interface ISphereXProtected {
    function changeSphereXEngine(address newSphereXEngine) external;
    function changeSphereXManager(address newSphereXManager) external;
}