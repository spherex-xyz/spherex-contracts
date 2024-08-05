// SPDX-License-Identifier: UNLICENSED
// (c) SphereX 2023 Terms&Conditions

pragma solidity ^0.8.0;

import {SphereXConfiguration} from "../SphereXConfiguration.sol";
import {SpherexProtetedMinimalProxy} from "./ProtectedMinimalProxy.sol";

// TODO: add event for deploying

/**
 * @title A factory contract that deploys the SpherexProtetedMinimalProxy contracts.
 */
contract MinimalProtectedProxyFactory is SphereXConfiguration {

    address private immutable IMPLEMENTATION;
    address private immutable ALLOWED_DEPLOYER;
    bytes4[] private /*immutable*/ PROTECTED_SIGS; // this is in effect immutable.

    constructor(address allowedDeployer, address implementation, bytes4[] memory protectedSigs ) SphereXConfiguration(msg.sender, address(0), address(0)) {
        ALLOWED_DEPLOYER = allowedDeployer;
        IMPLEMENTATION = implementation;
        PROTECTED_SIGS = protectedSigs;
    }

    event DeployedMinimalPRotectedProxy(address proxy_address, address implementation);


    modifier onlyAllowedDeployer() {
        require(msg.sender == ALLOWED_DEPLOYER, "Only Allowed Deployer");
        _;
    }

    

    /**
     * Deploys a new protected minimal proxy. Sets the inital protected values (admin, operator and engie) to equal those of the factory.
     *  If the current engine is not the null address, also updates the engine about a valid new sender
     * @dev notice the deploy function itself is NOT PROTECTED
     */
    function deploy() virtual public onlyAllowedDeployer returnsIfNotActivated returns (address proxyAddress) {
        address engineAddress = sphereXEngine();
        SpherexProtetedMinimalProxy minimalProxy = new SpherexProtetedMinimalProxy(
            sphereXAdmin(), 
            sphereXOperator(), 
            engineAddress, 
            IMPLEMENTATION
        );
        proxyAddress = address(minimalProxy);

        _addAllowedSenderOnChain(address(proxyAddress));
        minimalProxy.addProtectedFuncSigs(PROTECTED_SIGS);

        emit DeployedMinimalPRotectedProxy(proxyAddress, IMPLEMENTATION);
        
    }

}

