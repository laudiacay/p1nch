// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
/**** Deploy dummy contracts for purposes of local testing ****/

import "@forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-periphery/contracts/SwapRouter.sol";
import "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
// import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../src/Pinch.sol";

contract DummyUniswapFactory is UniswapV3Factory {}

contract DummyUniswapRouter is SwapRouter {
    constructor(address factory) SwapRouter(factory, address(0)) {}
}

contract DummyTokenA is ERC20("DummyTokenA", "DA") {
    constructor(address mint_to) {
        _mint(mint_to, 1000000);
    }
}

contract DummyTokenB is ERC20("DummyTokenB", "DB") {
    constructor(address mint_to) {
        _mint(mint_to, 1000000);
    }
}

contract DummyDeployScript is Script {
    function setUp() public {}

    function run() public {
        // string memory seedPhrase = vm.readFile(".secret_localnet");
        uint256 privateKey = vm.envUint("DEPLOY_SECRET_KEY");
        address mintToAddr = vm.envAddress("MINT_TO_ADDRESS");
        vm.startBroadcast(privateKey);

        DummyTokenA tokA = new DummyTokenA(mintToAddr);

        DummyTokenB tokB = new DummyTokenB(mintToAddr);

        UniswapV3Factory uniFact = new UniswapV3Factory();

        address _pool = uniFact.createPool(tokA.address, tokB.address, 0);
        DummyUniswapRouter uniRouter = new DummyUniswapRouter(uniFact.address);

        vm.stopBroadcast();
    }
}
