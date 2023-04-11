// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Verifier as P2SKHWellFormedVerify} from "@circuits/p2skh_well_formed_verify.sol";

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
    function wellFormedP2SKHproof(Proof calldata proof, address token, uint256 amount, uint256 ticket_hash)
        public
        returns (bool r)
    {
        P2SKHWellFormedVerify verif = new P2SKHWellFormedVerify();
        return verif.verifyProof(
            proof.a,
            proof.b,
            proof.c,
            [
                amount,
                uint160(token),
                ticket_hash
            ]);
    }

    // assert!(ticket_hash = hash(active=false, token, amount, "deposit/swap" ...some other fields...))
    // assert!(all fields of cancelling_ticket_hash eq to fields of old_key)
    // assert!(know secret key that this is intended for)
    // TODO: remove?
    function wellFormedP2SKHDeactivatorProof(
        Proof calldata proof,
        // address token,
        // uint256 amount,
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
        uint256 batchNumber,
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

    // checks p2skh deactivation proof. same as the SNARK above,
    // but also will accept on an input of hash("dummy" || some BS randomness for hiding), if the ticket is a commitment(hash("dummy" || some BS randomness for hiding)))
    function wellFormedP2SKHDeactivatorOrCorrectDummyProof(
        Proof calldata proof,
        uint256 old_swap_ticket_commit,
        uint256 new_spent_swap_deactivator_ticket
    )
        public
        returns (bool r)
    {
        return true;
    }

    // // assert!(ticket_hash for both new_p2skh tickets = hash(active=true, token, amount, "p2skh" ...some other fields...))
    // // assert!(ALL FOUR HAVE THE SAME TOKEN OR ARE DUMMIES!!)
    // // assert!(dummy format = hash("dummy" || some BS randomness for hiding))
    // // assert!(sum of the amounts of the new_p2skh tickets = sum of the amounts of the old ticket commitments. ensure dummies are counted as ZERO OTHERWISE YOU ARE IN TROUBLE)
    // function wellFormedP2SKHMergeSplitAdditionInvariantOrDummyProof(
    //     Proof calldata proof,
    //     uint256 old_p2skh_ticket_commitment_1,
    //     uint256 old_p2skh_ticket_commitment_or_dummy_2,
    //     uint256 new_p2skh_ticket_1,
    //     uint256 new_p2skh_ticket_or_dummy_2
    // )
    //     public
    //     returns (bool r)
    // {
    //     return true;
    // }

    // assert!(ticket_hash for both new_p2skh tickets = hash(active=true, token, amount, "p2skh" ...some other fields...))
    // assert!(ALL THREE HAVE THE SAME TOKEN!!)
    // assert!(sum of the amounts of the new_p2skh tickets = amt of old ticket commitment)
    function wellFormedP2SKHSplitAdditionInvariant(
        Proof calldata proof,
        uint256 old_p2skh_ticket_commitment,
        uint256 new_p2skh_ticket_1,
        uint256 new_p2skh_ticket_2
    )
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(ticket_hash for new_p2skh ticket = hash(active=true, token, amount, "p2skh" ...some other fields...))
    // assert!(ALL THREE HAVE THE SAME TOKEN!!)
    // assert!(sum of the amounts of the new_p2skh ticket = sum of the amounts of the old ticket commitments.)
    function wellFormedP2SKHMergeAdditionInvariant(
        Proof calldata proof,
        uint256 old_p2skh_ticket_commitment_1,
        uint256 old_p2skh_ticket_commitment_2,
        uint256 new_p2skh_ticket
    )
        public
        returns (bool r)
    {
        return true;
    }
}
