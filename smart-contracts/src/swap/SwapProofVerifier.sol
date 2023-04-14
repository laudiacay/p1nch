// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Verifier as SwapResolveVerif} from "@circuits/swap_resolve_verify.sol";
import {Verifier as SwapWellFormedVerify} from "@circuits/swap_start_verify.sol";

// this contains the swap batch info. it is an SMT that contains:
// (timestamp_of_prior_batch, timestamp_of_current_batch, token1, token2, token_src_amount_in) => 0
// why does it contain timestamp_of_prior_batch? make sure that timestamp of swap ticket was actually inside the bounds
// why does it contain timestamp_of_current_batch? same reason.
// users can look up the price of a token in a given batch and present it to the contract
// the contract will verify the proof that the given swap UTXO *was* executed in that batch_num (per its timestamp)
// and that the given token was swapped in that batch_num at that swap price

// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
library SwapProofVerifier {
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
        uint256 swap_batch_number,
        address token_a,
        address token_b,
        uint256 amount_in,
        uint256 amount_out
    ) public returns (bool r) {
        // TODO: should this be public
        return true;
    }

    // assert!(new p2skh ticket is well-formed)
    // assert!(the price inside this new ticket is listed in the SMT at this price window for these tokens)
    // assert!(the new ticket hash contains a price equal to the swap-ticket-commitment price times the swap token amount)
    // assert!(the swap ticket commitment contains a price and timestamp that are INSIDE the proposed provided swap window)
    // Hmmm... I see I think we want to rename this to WellFormedSwapResolveProof?
    function checkPriceSwap(
        Proof calldata proof,
        uint256 swap_event_comm,
        uint256 swap_utxo_hash_comm,
        uint256 p2skh_hash
    )
        public
        returns (
            bool r
        )
    {
        SwapResolveVerif verif = new SwapResolveVerif();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [swap_event_comm, p2skh_hash, swap_utxo_hash_comm]
            );
    }

    // assert!(ticket_hash = hash(active=true, token, amount, "initSwap" ...some other fields...))
    // assert!(ticket.source = source, ticket.timestamp=timestamp, ticket.amount = amount, ticket.dest=dest)
    // assert!(old_ticket_hash_commitment = hash(old_ticket_hash) = hash(hash(old_ticket)))
    // assert!(old_ticket.token = source, old_ticket.amount = amount)
    function wellFormedSwapTicketProof(
        Proof calldata proof,
        address source,
        address dest,
        uint256 amount,
        uint256 batchNumber,
        uint256 ticket_hash,
        uint256 old_ticket_hash_commitment
    ) public returns (bool r) {
        SwapWellFormedVerify verif = new SwapWellFormedVerify();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [
                    uint160(source),
                    uint160(dest),
                    ticket_hash,
                    old_ticket_hash_commitment,
                    batchNumber,
                    amount
                ]
            );
    }
}
