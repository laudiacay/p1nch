// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
/**** Deploy dummy contracts for purposes of local testing ****/

import "@forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "../src/Pinch.sol";

contract DummyTokenA is ERC20("DummyTokenA", "DA") {
    constructor(address dep_addr, address mint_to) {
        _mint(mint_to, 1000000);
        _mint(dep_addr, 1000000);
    }
}

contract DummyTokenB is ERC20("DummyTokenB", "DB") {
    constructor(address dep_addr, address mint_to) {
        _mint(mint_to, 1000000);
        _mint(dep_addr, 1000000);
    }
}

contract DummyDeployScript is Script {
    function setUp() public {}

    function run() public {
        // string memory seedPhrase = vm.readFile(".secret_localnet");
        uint256 privateKey = vm.envUint("DEPLOY_SECRET_KEY");
        address mintToAddr = vm.envAddress("MINT_TO_ADDRESS");
        address uniswapFactAddr = vm.envAddress(
            "UNISWAP_FACTORY_ADDRESS"
        );
        vm.startBroadcast(privateKey);

        DummyTokenA tokA = new DummyTokenA(address(this), mintToAddr);

        DummyTokenB tokB = new DummyTokenB(address(this), mintToAddr);
        vm.stopBroadcast();

        vm.startBroadcast(privateKey);
        address _pool = IUniswapV3Factory(uniswapFactAddr).createPool(
            address(tokA),
            address(tokB),
            100
        );
        vm.stopBroadcast();
    }
}
