// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

//import {Verifier as P2SKHVerifier} from "../../circuit_wrapper/build/p2skh_well_formed_verify.sol";

// a contract that verifies whether a ticket is well-formed
library WellFormedTicketVerifier {
    // types
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(ticket_hash = hash(active=true, token, amount, "deposit/swap" ...some other fields...))
    function wellformed_p2skh_proof(Proof calldata proof, address token, uint256 amount, uint256 ticket_hash)
        public
        returns (bool r)
    {
        // TODO: check format
        // P2SKHVerifier().verifyProof(
        //     proof.a,
        //     proof.b,
        //     proof.c,
        //     [
        //         amount,
        //         0, //TODO:TIMESAMP,
        //         0, //tok_addr_1,//TODO:
        //         0, //tok_addr_2,
        //         ticket_hash
        //     ]
        // );
        return true;
    }

    // assert!(ticket_hash = hash(active=false, token, amount, "deposit/swap" ...some other fields...))
    // assert!(all fields of cancelling_ticket_hash eq to fields of old_key)
    // assert!(know secret key that this is intended for)
    // TODO: remove?
    function well_formed_deactivation_hash_proof(
        Proof calldata proof,
        address token,
        uint256 amount,
        uint256 commitment_to_old_key,
        uint256 cancelling_key
    )
        public
        returns (bool r)
    {
        return true;
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
        uint256 timestamp,
        uint256 ticket_hash,
        uint256 old_ticket_hash_commitment
    )
        public
        returns (bool r)
    {}

    // prove the deactivator is well formed versus the old swap ticket
    function wellformedSwapDeactivatorProof(
        Proof calldata proof,
        uint256 old_swap_ticket_commit,
        uint256 new_spent_swap_deactivator_ticket
    )
        public
        returns (bool r)
    {
        return true;
    }
}
