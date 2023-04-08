// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

// a contract that verifies whether a ticket is well-formed
contract WellFormedTicketVerifier {
    // types
    struct Proof {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
    }

    // public functions
    // assert!(ticket_key = hash(active=true, token, amount, "deposit/swap" ...some other fields...))
    function wellformedActiveTicketProof(Proof memory proof, address token, uint256 amount, uint256 ticket_key)
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(ticket_key = hash(active=false, token, amount, "deposit/swap" ...some other fields...))
    // assert!(know preimage of hash(nullifier) in ticket)
    // assert!(all fields of cancelling_ticket_key eq to fields of old_key)
    function wellformedNullifierProof(Proof memory proof, address token, uint256 amount, uint256 old_key, uint256 cancelling_key)
        public
        returns (bool r)
    {
        return true;
    }

    // assert!(ticket_key = hash(token, amount, "withdraw" ...some other fields...))
    // assert!(ticket_key \in root)
    // assert!(new_withdraw_commit \not\in root)
    // assert!(new_root = old_root \union (, 0)
    // assert!(amount <= old_note_balance * swap_price
    //         where swap_price == swap_batch[])
    //         where swap_batch[] is the swap batch that the initial deposit got swapped in
    function wellformedWithdrawProof(Proof memory proof, address token, uint256 amount, uint256 ticket_key)
        public
        returns (bool r)
    {
        return true;
    }
}
