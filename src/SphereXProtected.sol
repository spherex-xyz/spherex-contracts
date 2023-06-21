// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.17;

import {SphereXProtectedBase} from "./SphereXProtectedBase.sol";

/**
 * @title SphereX base Customer contract template
 * @dev notice this is an abstract
 */
abstract contract SphereXProtected is SphereXProtectedBase(msg.sender, address(0), address(0)) {
    /**
     * @dev used when the client uses a proxy - should be called by the inhereter initialization
     */
    function __SphereXProtected_init() internal virtual {
        super.__SphereXProtected_init(msg.sender, address(0), address(0));
    }
}
