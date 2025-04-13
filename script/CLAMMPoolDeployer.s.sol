// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {CLAMMPool} from "../src/CLAMMPool.sol";

contract CLAMMPoolDeployer is Script {
    error CLAMMPoolDeployer__InvalidTokenAddressEntered();
    error CLAMMPoolDeployer__SameTokenAddressesEntered();
    error CLAMMPoolDeployer__InvalidFeeEntered();
    error CLAMMPoolDeployer__PoolAlreadyCreated();
    error CLAMMPoolDeployer__NotOwner();
    error CLAMMPoolDeployer__PoolNotCreated();

    address public owner;
    mapping(uint24 => int24) public feeToTickSpacing;
    mapping(address => mapping(address => mapping(uint24 => address))) public poolForPair;

    constructor() {
        // Initialize the feeToTickSpacing mapping with values
        feeToTickSpacing[500] = 10;
        feeToTickSpacing[3000] = 60;
        feeToTickSpacing[10000] = 200;
    }

    function run() public returns (CLAMMPool) {
        address tokenA = vm.envAddress("TOKEN_A");
        address tokenB = vm.envAddress("TOKEN_B");
        uint24 fee = uint24(vm.envUint("FEE"));
        uint160 initialSqrtPriceX96 = uint160(vm.envUint("INITIAL_SQRT_PRICE_X96"));

        if (tokenA == address(0) || tokenB == address(0)) {
            revert CLAMMPoolDeployer__InvalidTokenAddressEntered();
        }
        if (tokenA == tokenB) {
            revert CLAMMPoolDeployer__SameTokenAddressesEntered();
        }
        if (feeToTickSpacing[fee] == 0) {
            revert CLAMMPoolDeployer__InvalidFeeEntered();
        }
        if (owner != address(0) && msg.sender != owner) {
            revert CLAMMPoolDeployer__NotOwner();
        }
        return deployCLAMMPoolContract(tokenA, tokenB, fee, initialSqrtPriceX96);
    }

    function deployCLAMMPoolContract(address tokenA, address tokenB, uint24 fee, uint160 initialSqrtPriceX96)
        private
        returns (CLAMMPool)
    {
        address _tokenA = tokenA < tokenB ? tokenA : tokenB;
        address _tokenB = tokenA < tokenB ? tokenB : tokenA;

        if (poolForPair[_tokenA][_tokenB][fee] != address(0)) {
            revert CLAMMPoolDeployer__PoolAlreadyCreated();
        }

        vm.startBroadcast();

        // Deploy the CLAMMPool contract
        CLAMMPool clammPool = new CLAMMPool(_tokenA, _tokenB, fee, feeToTickSpacing[fee]);
        clammPool.initialize(initialSqrtPriceX96);
        if (owner == address(0)) owner = msg.sender;

        vm.stopBroadcast();

        if (address(clammPool) == address(0)) {
            revert CLAMMPoolDeployer__PoolNotCreated();
        }

        // Store the pool address in the mapping
        poolForPair[_tokenA][_tokenB][fee] = address(clammPool);
        poolForPair[_tokenB][_tokenA][fee] = address(clammPool); // Store the reverse pair as well

        // Print the address of the deployed contract
        console.log("CLAMMPool deployed at:", address(clammPool));
        console.log("Token A:", _tokenA);
        console.log("Token B:", _tokenB);
        console.log("Fee:", fee);
        console.log("Tick Spacing:", feeToTickSpacing[fee]);

        return clammPool;
    }

    function setAnotherOwner(address newOwner) public {
        if (msg.sender != owner) {
            revert CLAMMPoolDeployer__NotOwner();
        }
        owner = newOwner;
    }
}
