// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Verifier as SMTProcessorVerifier} from "@circuits/smt_processor_verify.sol";
import {Verifier as CommMembVerify} from "@circuits/comm_memb_verify.sol";

// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
library SMTMembershipVerifier {
    // types
    // TODO SHAME! SHAME!. there should be separate types for each proof. SHAME!!
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // assert!(root_after = root_before \union (ticket_hash, 0))
    // assert!(ticket_hash \not \in root_before)
    function updateProof(
        Proof calldata proof,
        uint256 root_before,
        uint256 root_after,
        uint256 ticket_hash
    ) public returns (bool r) {
        // TODO: should this be a
        SMTProcessorVerifier smt_proc_verifier = new SMTProcessorVerifier();
        // A dummy value for the proof as there is no "old key" in an insert
        uint256 old_key_dummy = 0;
        uint256[4] memory inputValues = [
            root_before,
            old_key_dummy,
            ticket_hash,
            root_after
        ];

        return
            smt_proc_verifier.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                inputValues
            );
    }

    // assert!(the commitment to this ticket is in the given root :))
    function commitmentInclusion(
        Proof calldata proof,
        uint256 root,
        uint256 ticket_hash_commitment
    ) public returns (bool r) {
        CommMembVerify comm_memb_verify = new CommMembVerify();
        uint256[2] memory inputValues = [ticket_hash_commitment, root];
        return
            comm_memb_verify.verifyProof(
                proof.a,
                proof.b,
                proof.c,
                inputValues
            );
    }
}
