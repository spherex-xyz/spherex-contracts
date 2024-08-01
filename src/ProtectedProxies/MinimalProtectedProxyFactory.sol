// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXProtected} from "../SphereXProtected.sol";
import {SpherexProtetedMinimalProxy} from "./ProtectedMinimalProxy.sol";

// TODO: add event for deploying

/**
 * @title A factory contract that deploys the SpherexProtetedMinimalProxy contracts.
 */
contract MinimalProtectedProxyFactory is SphereXProtected {

    /**
     * Deploys a new protected minimal proxy. Sets the inital protected values (admin, operator and engie) to equal those of the factory.
     *  If the current engine is not the null address, also updates the engine about a valid new sender
     * @dev notice the deploy function itself is NOT PROTECTED
     */
    function deploy(address implementation) virtual public returns (address) {
        address engineAddress = sphereXEngine();
        SpherexProtetedMinimalProxy minimalProxy = new SpherexProtetedMinimalProxy(
            sphereXAdmin(), 
            sphereXOperator(), 
            engineAddress, 
            implementation
        );
        address proxyAddress = address(minimalProxy);

        if (engineAddress != address(0)) {
            _addAllowedSenderOnChain(address(proxyAddress));
        }
        // TODO: log event
        return proxyAddress;
    }

}

