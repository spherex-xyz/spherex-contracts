// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {ISphereXEngine} from "../ISphereXEngine.sol";

/**
 * @title Interface for a spherex beacon to be used by spherex's beacon proxy.
 */
interface ISphereXBeacon {
    function protectedImplementation(bytes4 func_sig) external view returns (address, address, bool);
}
