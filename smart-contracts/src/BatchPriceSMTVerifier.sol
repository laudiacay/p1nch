// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

// this contains the swap batch info. it is an SMT that contains:
// (timestamp_of_prior_batch, timestamp_of_current_batch, token1, token2, token1_price_in_token2) => 0
// why does it contain timestamp_of_prior_batch? make sure that timestamp of swap ticket was actually inside the bounds
// why does it contain timestamp_of_current_batch? same reason.
// users can look up the price of a token in a given batch and present it to the contract
// the contract will verify the proof that the given swap UTXO *was* executed in that batch_num (per its timestamp)
// and that the given token was swapped in that batch_num at that swap price

// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
library BatchPriceSMTVerifier {
    // types
    // TODO SHAME! SHAME!. there should be separate types for each proof. SHAME!!
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(you are adding all the price data in the right format to the thing :3)
    // TODO the price data type here is super fucked up and you need to come back and fix it?
    function updateProof(
        Proof calldata proof,
        uint256 old_root,
        uint256 new_root,
        uint256 last_timestamp,
        uint256 current_timestamp,
        address token_a,
        address token_b,
        uint256 price
    )
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(the price inside this new ticket is listed in the SMT at this price window for these tokens)
    // assert!(the new ticket hash contains a price equal to the swap-ticket-commitment price times the swap token amount)
    // assert!(the swap ticket commitment contains a price and timestamp that are INSIDE the proposed provided swap window)
    function checkPriceSwap(
        Proof calldata proof,
        uint256 targetPriceRoot,
        uint256 priceDataCommitment,
        uint256 oldSwapCommitment,
        uint256 newP2SKHTicketHash
    )
        public
        returns (bool r)
    {
        return true;
    }
}