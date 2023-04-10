// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

// a contract that verifies whether a ticket is well-formed
library WellFormedTicketVerifier {
    // types
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(ticket_key = hash(active=true, token, amount, "deposit/swap" ...some other fields...))
    function wellformedDepositTicketProof(Proof calldata proof, address token, uint256 amount, uint256 ticket_key)
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(ticket_key = hash(active=false, token, amount, "deposit/swap" ...some other fields...))
    // assert!(all fields of cancelling_ticket_key eq to fields of old_key)
    // assert!(know secret key that this is intended for)
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

    // assert!(ticket_key = hash(active=true, token, amount, "initSwap" ...some other fields...))
    // assert!(ticket.source = source, ticket.amount = amount, ticket.dest=dest)
    // assert!(old_ticket_hash_commitment = hash(old_ticket_key) = hash(hash(old_ticket)))
    // assert!(old_ticket.token = source, old_ticket.amount = amount)
    function wellFormedSwapTicketProof(Proof calldata proof, address source, address dest, uint256 amount, uint256 ticket_key, uint256 old_ticket_hash_commitment)
        public
        returns (bool r)
    {
        return true;
    }

    // // assert!(ticket_key = hash(token, amount, "withdraw" ...some other fields...))
    // // assert!(new_root = old_root \union (, 0)
    // // assert!(amount <= old_note_balance * swap_price
    // //         where swap_price == swap_batch[])
    // //         where swap_batch[] is the swap batch that the initial deposit got swapped in
    // function wellformedburnSwapProof(Proof calldata proof, address token, uint256 amount, uint256 ticket_key)
    //     public
    //     returns (bool r)
    // {
    //     return true;
    // }
}
