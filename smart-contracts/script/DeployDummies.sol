// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
/**** Deploy dummy contracts for purposes of local testing ****/

import "@forge-std/src/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../src/Pinch.sol";

contract DummyUniswap {
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

contract P1nchDeployScript is Script {
    function setUp() public {}

    function run() public {
        // string memory seedPhrase = vm.readFile(".secret_localnet");
        uint256 privateKey = vm.envUint("DEPLOY_SECRET_KEY");
        vm.startBroadcast(privateKey);
        address botAddress = vm.envAddress("BOT_ADDRESS");
        address sequencerAddress = vm.envAddress("SEQUENCER_ADDRESS");
        address gnosisOrOwnerAddress = vm.envAddress("GNOSIS_OR_OWNER_ADDRESS");
        address uniswapSwapRouterAddress = vm.envAddress("UNISWAP_SWAP_ROUTER_ADDRESS");

        Pinch pinch = new Pinch(gnosisOrOwnerAddress, sequencerAddress, botAddress, uniswapSwapRouterAddress);

        vm.stopBroadcast();
    }
}