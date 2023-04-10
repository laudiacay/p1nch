// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

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

    // assert!(root_after = root_before \union (ticket_key, 0))
    // assert!(ticket_key \not \in root_before)
    function updateProof(Proof calldata proof, uint256 root_before, uint256 root_after, uint256 ticket_hash)
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(the commitment to this ticket is in the given root :))
    function commitmentInclusion(Proof calldata proof, uint256 root, uint256 ticket_key_commitment)
        public
        returns (bool r)
    {
        return true;
    }
}
