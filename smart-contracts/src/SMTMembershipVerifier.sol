// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import {Verifier as SMTProcessorVerifier} from "../../circuit_wrapper/build/smt_processor_verify.sol";
import {Verifier as CommMembVerify} from "../../circuit_wrapper/build/comm_memb_verify.sol";

// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
library SMTMembershipVerifier {    

    // types
    // TODO SHAME! SHAME!. there should be separate types for each proof. SHAME!!
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(ticket_key \in root)
    // function inclusionProof(Proof calldata proof, uint256 root, uint256 ticket_hash) public returns (bool r) {
    //     return true;
    // }

    // // assert!(ticket_key \not \in root)
    // function exclusionProof(Proof calldata proof, uint256 root, uint256 ticket_hash) public returns (bool r) {
    //     return true;
    // }

    // assert!(root_after = root_before \union (ticket_hash, 0))
    // assert!(ticket_hash \not \in root_before)
    function updateProof(
        Proof calldata proof,
        uint256 root_before,
        uint256 root_after,
        uint256 ticket_hash
    ) public returns (bool r) {
        // TODO: should this be a 
        SMTProcessorVerifier smt_proc_verifier = SMTProcessorVerifier();
        // A dummy value for the proof as there is no "old key" in an insert
        uint old_key_dummy = 0;
        // Specify that the proof should check that we are doing an **insert**
        // I.e. the key did not exist before in the tree
        uint fn_0 = 1;
        uint fn_1 = 0;
        uint[6] memory inputValues = [root_before, old_key_dummy, fn_0, fn_1,  ticket_hash, root_after];
        
        return smt_proc_verifier.verifyProof(
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
        CombMembVerify comm_memb_verify  = CombMembVerify();
        uint[2] memory inputValues = [ticket_hash_commitment, root];
        return comm_memb_verify.verifyProof(proof.a, proof.b, proof.c, inputValues);
    }
}
