// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

import "./SMTMembershipVerifier.sol";
import "./WellFormedTicketVerifier.sol";
import "./Swapper.sol";

contract Pinch {

    // this is an SMT that tracks UTXO hashes.
    // it contains tickets for deposits, swaps, and deactivation tickets for both
    // it contains hash(ticket) (also called ticket key) => 0 for "present tickets"
    // when you want to deactivate a ticket, you insert hash(same ticket but where active = 0) => 0
    // when you deposit, swap, or withdraw, you modify this tree.
    // always check modification proofs, which should be presented before any update.
    uint256 utxo_hash_smt_root;

    // number of utxos in the smt root. apparently this is useful for some kind of regulatory compliance reason
    uint256 counter = 0;

    // this is the current batch number. incremented every time a swap batch is swapped.
    uint256 current_batch_num = 0;

    Swapper public swapper;

    /**
     * User facing functions **************
     */

    /**
     * @notice Deposit tokens into the SMT
     *
     * @param well_formed_proof A proof that verifies ticket_key is well-formed relative to the token, amount, and "deposit transaction"
     * @param smt_update_proof A proof that demonstrates the insertion of a KV pair ticket_key = True and that ticket_key is not previously in the proof
     * @param token The token to be deposited (IERC20 compatible)
     * @param amount The amount of tokens to be deposited
     * @param ticket_key The key associated with the deposit ticket
     * @param new_root The new SMT root after deposit
     */
    function deposit(
        WellFormedProof.Proof memory well_formed_proof,
        SMTUpdateProof.Proof memory smt_update_proof,
        IERC20 token,
        uint256 amount,
        uint256 ticket_key,
        uint256 new_root
    )
        public
    {
        counter += 1;

        // Check the proof of the well formed key
        // assert!(ticket_key = hash(token, amount, "deposit" ...some other fields...))
        // assert!(ticket.token == token && ticket.amount == amount && ticket.instr == "deposit")
        if (!WellFormedTicketVerifier.verifyProof(well_formed_proof, token, amount, ticket_key)) {
            revert("ticket was not well-formed");
        }

        // Check the smt update proof
        // assert!(ticket_key \not\in utxo_hash_smt_root)
        // assert!(ticket_key \in new_root (and update is done correctly))
        if (!SMTMembershipVerifier.update_proof(smt_update_proof, utxo_hash_smt_root, new_root, ticket_key)) {
            revert("SMT modification was not valid");
        }

        // Perform ERC 20 Approved Transfer
        if (!token.transferFrom(msg.sender, address(this), amount)) {
            revert("ERC20 transfer failed");
        }

        // Update the root
        utxo_hash_smt_root = new_root;
    }

    /**
     * TODO important: i think the whole "1 -> 1 + Option<2>" paradigm might be questionable here. let's discuss tomorrow.
     * TODO clean up and correct these parameters
     * @param old_key_comm - A commitment to the old ticket key. This is used in the proof of the old_ticket_key_canceling
     * @param old_ticket_key_proof - A proof that the old ticket is in one of the past SMT
     * @param update_proof - Checks that canceling ticket is **not** in the SMT and then appends it to the SMT
     * @param canceling_ticket_key - The old deposit key but now with active set to false and fresh randomness
     * @param new_ticket_key_1 - The first new ticket key which is split from the old ticket
     * @param new_ticket_key_2 - The second ticket key which is split from the new. If null just set to 0 (i.e. the old ticket is converted to just 1 new ticket)
     * @param new_ticket_proof - A proof showing that the 2 new tickets are well formed, i.e. the sum of the token amounts in the new tickets equal the old one and that the same token is used
     * and that the destination tokens and amounts match
     */
    function setup_swap(
        uint256 old_key_comm,
        uint256 canceling_ticket_key,
        uint256 new_ticket_key_1,
        address source_token,
        address destination_token,
        uint256 amount,
        uint256 new_utxo_root,
        Proof memory old_key_proof,
        Proof memory smt_update_proof_nulli,
        Proof memory old_key_proof,
    )
        public
    {
        assert(new_ticket_key_1 != 0);
        counter += 2;
        assert(amount > 0);
        assert(source_token != destination_token);

        // Check values and update the tree
        // TODO let's check that this is an acceptable list of invariants
        
        // first: check old ticket key and its cancellation
        
        // assert!(old_key_comm \in utxo_hash_smt_root)
        if (!SMTMembershipVerifier.inclusionProof(proof.old_ticket_key_proof, utxo_hash_smt_root, old_key_comm)) {
            revert("old ticket key was not in the SMT");
        }

        // assert!(canceling_ticket_key \notin utxo_hash_smt_root)
        // assert!(canceling_ticket_key \in new_utxo_root (and update is correct))
        if (!SMTMembershipVerifier.update_proof(smt_update_proof_nulli, utxo_hash_smt_root, new_root, canceling_ticket_key)) {
          revert("cancelling key SMT modification was not valid");
        }
        
        // assert!(canceling_ticket_key.active = 0, all other fields same as old_ticket_key)
        // assert!(we know preimage of nullifier hash of old_ticket_key)
        if !(WellFormedTicketVerifier.wellformedNullifierProof(proof, token, amount, old_key, cancelling_key)) {
          revert("cancellation ticket was not well-formed");
        }
        // validate new ticketx internally
        // assert!(new_ticket_key_1.active == 1)
        // assert!(new_ticket_key_1.timestamp == ???????)
        if(!WellFormedTicketVerifier.wellformedActiveSwapTicketProof()) {

        }
        // assert!(new_ticket_key_1.active == new_ticket_key_2.active == 1)
        // assert!(new_ticket_key_1.timestamp == new_ticket_key_2.timestamp == ???????)

        // validate new tickets versus other values
        // assert!(new_ticket_1.value == old_ticket.value)
        // assert!(new_ticket_1.value > 0)
        // assert!(new_ticket_1.source_token == old_ticket.token == source_token)
        // assert!(new_ticket_1.destination_token == destination_token)
        // assert!(new_ticket_1.amount == amount)
        // validate the state update with new tickets
        // assert!(new_ticket_key_1 \in new_utxo_root (and update is correct))
        // assert!(new_ticket_key_1 is well-formed)
        if (
            !SwapVerifier.proof(
                proof,
                utxo_hash_smt_root,
                old_key_comm,
                canceling_ticket_key,
                new_ticket_key_1,
                new_ticket_key_2,
                source_token,
                destination_token,
                amount,
                new_utxo_root
            )
        ) {
            revert("Swap proof was not valid");
        }

        utxo_hash_smt_root = new_utxo_root;

        swapper.addTransaction(source_token, destination_token, amount);
    }

    /** // TODO 
     * @param swap_ticket_key_comm  - A commitment to your old ticket key
     * @param swap_ticket_key_proof - A proof showing that your old ticket is in the tree
     * @param cancel_swap_ticket_key - New ticket to cancel old swap ticket
     * @param update_utxo_smt_proof - Proof showing update to utxo_smt done correctly
     * @param withdraw_amount_proof - Proof which checks that the withdraw amount is accurate
     * relative to the swap amount in the swap ticket key and the swap which is recorded in the
     * `swap_batch` SMT
     */
    function withdraw(
        uint256 swap_ticket_key,
        SMTMembershipVerifier.Proof memory swap_ticket_key_proof,
        uint256 nullify_swap_ticket_key,
        SMTMembershipVerifier.Proof memory nullification_proof,
        SMTMembershipVerifier.Proof memory update_utxo_smt_proof,
        withdraw_amount_proof,
        uint256 withdraw_amount,
        address withdraw_to,
        address token,
    )
        public
    {
        // TODO set counter correctly (for partial withdrawals)
        counter += 1;

        // TODO handle withdrawal of transfers AND swaps- right now you're only handling swaps.

        // looking at original swap ticket and invalidation
        //    assert!(swap_ticket_key_comm \in utxo_hash_smt_root)

        if (!SMTMembershipVerifier.inclusionProof(swap_ticket_key_proof, utxo_hash_smt_root, swap_ticket_key)) {
            revert("old swap ticket was not in the thing yo");
        }

        //    assert!(we know preimage of nullifier hash of swap_ticket_key)
        if (!wellformedNullifierProof(nullification_proof, token, withdraw_amount)) {
            revert("idk fml");
        }
        //    assert!(cancel_swap_ticket_key \notin utxo_hash_smt_root)
        //    assert!(cancel_swap_ticket_key \in new_utxo_root (and update is correct))
        if (!SMTMembershipVerifier.updateProof(swap_))
        //    assert!(cancel_swap_ticket_key.active = 0, all other fields same as swap_ticket_key)
        // swap batch logic
        //    assert!(swap_ticket_key.timestamp <= most recent batch timestamp)
        //    assert!(swap_ticket_key.destination_token == token)
        //    assert!(swap_ticket_key.timestamp is in the batch before the (privately) alleged swap batch)
        //    assert!(alleged swap batch is in the swap batch listings)
        //    assert!(withdrawal amount + new_deposit_ticket.amount == swap_ticket_key.amount * swap_price from batch smt)
        // TODO there are many more invariants here to add!

        // TODO do a real proof of all these things!!!
        // TODO check 
        Withdraw.proof(
            swap_ticket_key,
            swap_ticket_key_proof,
            cancel_swap_ticket_key,
            update_utxo_smt_proof,
            withdraw_amount_proof,
            withdraw_amount,
            withdraw_to,
            token,
            new_deposit_ticket
        );

        // withdraw your money
        // Perform ERC 20 Approved Transfer
        if (!token.transferFrom(address(this), withdraw_to, amount)) {
            revert("ERC20 transfer failed");
        }

        // set smt hash accordingly
        utxo_hash_smt_root = new_utxo_root;
    }


}
