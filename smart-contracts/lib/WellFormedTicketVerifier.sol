// a contract that verifies whether a ticket is well-formed
contract WellFormedTicketVerifier {
    // types
    struct Proof {
        uint[2] a;
        uint[2][2] b;
        uint[2] c;
    }

    // public functions
    // assert!(ticket_key = hash(token, amount, "deposit" ...some other fields...))
    function wellformedDepositProof(Proof memory proof, address token, uint256 amount, uint256 ticket_key) public returns (bool r) {
        return true;
    }
    // assert!(ticket_key = hash(token, amount, "withdraw" ...some other fields...))
    // assert!(ticket_key \in root)
    // assert!(new_withdraw \not\in root)
    // assert!(new_withdraw = root \union (new_spend, 0)
    // assert!(amount <= old_note_balance * swap_price 
    //         where swap_price == swap_batch[])
    //         where swap_batch[] is the swap batch that the initial deposit got swapped in
    function wellformedWithdrawProof(Proof memory proof, address token, uint256 amount, uint256 ticket_key) public returns (bool r) {
        return true;
    }
}
        