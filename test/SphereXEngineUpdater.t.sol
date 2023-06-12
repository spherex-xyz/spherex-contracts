// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2;

import "forge-std/Test.sol";
import "../src/SphereXEngineUpdater.sol";
import "../src/SphereXProtected.sol";


contract MockContract is SphereXProtected {

    constructor(address newSphereXEngine) public SphereXProtected(newSphereXEngine) {}
    function initialize(address newSphereX) public {
        __SphereXProtected_init(newSphereX);
    }
}

contract SphereXEngineUpdaterTest is Test {
    SphereXEngineUpdater updater;
    MockContract[] public protectedContracts;
    address[] public protectedAddresses;
    address constant initialEngineAddress = 0xeF9c2F2C9B767496Ba849A269d18C5E4C0717b62;
    bytes32 private constant SPHEREX_MANAGER_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.spherex")) - 1);
    bytes32 private constant SPHEREX_ENGINE_STORAGE_SLOT = bytes32(uint256(keccak256("eip1967.spherex.spherex_engine")) - 1);

    function setUp() public virtual {
        updater = new SphereXEngineUpdater();
        for (uint i = 0; i < 5; i++) {
            protectedContracts.push(new MockContract(address(this)));
            protectedContracts[i].changeSphereXEngine(initialEngineAddress);
            protectedAddresses.push(address(protectedContracts[i]));
        }
    }

    function checkProtectedsEngine(address addr) internal {
        for (uint i = 0; i < protectedContracts.length; i++) {
            address current_engine = address(uint160(uint256(vm.load(address(protectedContracts[i]), SPHEREX_ENGINE_STORAGE_SLOT))));
            assertEq(current_engine, addr);
        }
    }

    function checkProtectedsManager(address addr) internal {
        for (uint i = 0; i < protectedContracts.length; i++) {
            address current_engine = address(uint160(uint256(vm.load(address(protectedContracts[i]), SPHEREX_MANAGER_STORAGE_SLOT))));
            assertEq(current_engine, addr);
        }
    }

    function updateOwnershipToUpdater() internal {
        for (uint i = 0; i < protectedContracts.length; i++) {
            protectedContracts[i].changeSphereXManager(address(updater));
        }
    }

    function testUpdateFailureWithoutOwnershipTransfer() external {
        checkProtectedsEngine(initialEngineAddress);
        vm.expectRevert("!SX:SPHEREX");
        updater.update(protectedAddresses, address(this));
    }

    function testUpdate() external {
        checkProtectedsEngine(initialEngineAddress);
        updateOwnershipToUpdater();

        address newEngine = 0xeF9C2F2C9B767496bA849A269D18C5e4C0717b63;
        updater.update(protectedAddresses, newEngine);

        checkProtectedsEngine(newEngine);
        checkProtectedsManager(address(this));
    }
}