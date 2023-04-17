// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@forge-std/src/Script.sol";
import "../src/Pinch.sol";

contract P1nchDeployScript is Script {
    function setUp() public {}

    function run() public {
        // string memory seedPhrase = vm.readFile(".secret_localnet");
        uint256 privateKey = vm.envUint("DEPLOY_SECRET_KEY");
        vm.startBroadcast(privateKey);
        address botAddress = vm.envAddress("BOT_ADDRESS");
        address sequencerAddress = vm.envAddress("SEQUENCER_ADDRESS");
        address gnosisOrOwnerAddress = vm.envAddress("GNOSIS_OR_OWNER_ADDRESS");
        address uniswapSwapRouterAddress = vm.envAddress("UNISWAP_ROUTER_ADDRESS");

        Pinch pinch = new Pinch(gnosisOrOwnerAddress, sequencerAddress, botAddress, uniswapSwapRouterAddress);

        vm.stopBroadcast();
    }
}