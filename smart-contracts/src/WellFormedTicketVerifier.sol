// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Verifier as P2SKHWellFormedVerify} from "@circuits/p2skh_well_formed_verify.sol";
import {Verifier as DeactivatorWellFormedVerify} from "@circuits/deactivator_well_formed_verify.sol";
import {Verifier as MergeWellFormedVerify} from "@circuits/p2skh_merge_verify.sol";
import {Verifier as SplitWellFormedVerify} from "@circuits/p2skh_split_verify.sol";

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
    function wellFormedP2SKHproof(
        Proof calldata proof,
        address token,
        uint256 amount,
        uint256 ticket_hash
    ) public returns (bool r) {
        P2SKHWellFormedVerify verif = new P2SKHWellFormedVerify();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [amount, uint160(token), ticket_hash]
            );
    }

    // assert!(ticket_hash = hash(active=false, token, amount, "deposit/swap" ...some other fields...))
    // assert!(all fields of cancelling_ticket_hash eq to fields of old_key)
    // assert!(know secret key that this is intended for)
    function wellFormedDeactivatorProof(
        Proof calldata proof,
        // address token,
        // uint256 amount,
        uint256 commitment_to_old_key,
        uint256 cancelling_hash
    ) public returns (bool r) {
        DeactivatorWellFormedVerify verif = new DeactivatorWellFormedVerify();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [cancelling_hash, commitment_to_old_key]
            );
    }

    // // checks p2skh deactivation proof. same as the SNARK above,
    // // but also will accept on an input of hash("dummy" || some BS randomness for hiding), if the ticket is a commitment(hash("dummy" || some BS randomness for hiding)))
    // function wellFormedP2SKHDeactivatorOrCorrectDummyProof(
    //     Proof calldata proof,
    //     uint256 old_swap_ticket_commit,
    //     uint256 new_spent_swap_deactivator_ticket
    // )
    //     public
    //     returns (
    //         // Isn't this the same thing... will ask
    //         bool r
    //     )
    // {
    //     // Oh wait... do we need **another** circuit for this??
    //     // (SMT + Comm check)
    //     // Or is it like you do 2 seperate circ. checks... I think thats it
    //     return true;
    // }

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
    ) public returns (bool r) {
        SplitWellFormedVerify verif = new SplitWellFormedVerify();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [
                    old_p2skh_ticket_commitment,
                    new_p2skh_ticket_1,
                    new_p2skh_ticket_2
                ]
            );
    }

    // assert!(ticket_hash for new_p2skh ticket = hash(active=true, token, amount, "p2skh" ...some other fields...))
    // assert!(ALL THREE HAVE THE SAME TOKEN!!)
    // assert!(sum of the amounts of the new_p2skh ticket = sum of the amounts of the old ticket commitments.)
    function wellFormedP2SKHMergeAdditionInvariant(
        Proof calldata proof,
        uint256 old_p2skh_ticket_commitment_1,
        uint256 old_p2skh_ticket_commitment_2,
        uint256 new_p2skh_ticket
    ) public returns (bool r) {
        MergeWellFormedVerify verif = new MergeWellFormedVerify();
        return
            verif.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                [
                    old_p2skh_ticket_commitment_1,
                    old_p2skh_ticket_commitment_2,
                    new_p2skh_ticket
                ]
            );
    }
}
