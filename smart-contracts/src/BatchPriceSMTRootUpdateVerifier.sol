// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
contract BatchPriceSMTRootUpdateVerifier {
    // types
    // TODO SHAME! SHAME!. there should be separate types for each proof. SHAME!!
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(you are adding all the 
    // TODO the price data type here is super fucked up and you need to come back and fix it?
    function updateProof(Proof memory proof, uint256 old_root, uint256 new_root, uint256 price_data) public returns (bool r) {
        return true;
    }

}
