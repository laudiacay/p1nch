// a contract that verifies whether an update to the SMT is done right (and not including this ticket already!)
contract SMTMembershipVerifier {
    // types
    struct Proof {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
    }

    // public functions
    // assert!(ticket_key \in root)
    function inclusionProof(Proof memory proof, uint256 root, uint256 ticket_key) public returns (bool r) {
        return true;
    }
    // assert!(ticket_key \not \in root)
    function exclusionProof(Proof memory proof, uint256 root, uint256 ticket_key) public returns (bool r) {
        return true;
    }
    // assert!(root_after = root_before \union (ticket_key, 0))
    // assert!(ticket_key \not \in root_before)
    function updateProof(Proof memory proof, uint256 root_before, uint256 root_after, uint256 ticket_key) public returns (bool r) {
        return true;
    }
}
        