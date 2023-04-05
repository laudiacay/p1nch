// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import '../lib/SMTMembershipVerifier.sol';
import '../lib/WellFormedTicketVerifier.sol';

contract Pinch {
    // always sorted.
    struct Pair {
        address token1;
        address token2;
    }

    // this is an SMT that tracks UTXO hashes.
    // it contains tickets for deposits, swaps, and deactivation tickets for both
    // it contains hash(ticket) (also called ticket key) => 0 for "present tickets"
    // when you want to deactivate a ticket, you insert hash(same ticket but where active = 0) => 0
    // when you deposit, swap, or withdraw, you modify this tree. 
    // always check modification proofs, which should be presented before any update.
    uint256 utxo_hash_smt_root;

    // this contains the swap batch info. it is an SMT that contains (batch_num, token1, token2, token1_price_in_token2) => 0
    // users can look up the price of a token in a given batch and present it to the contract
    // the contract will verify the proof that the given swap UTXO *was* executed in that batch_num (per its timestamp)
    // and that the given token was swapped in that batch_num at that swap price
    uint256 batch_swap_root;

    // this is a list that registers when batches are swapped- any swap UTXO timestamp in between these is in the latter batch
    uint256[] batch_swap_timestamps;

    // number of utxos in the smt root. apparently this is useful for some kind of regulatory compliance reason
    uint counter = 0;

    // this is the current batch number. it is incremented every time a swap batch is swapped.
    uint current_batch_num = 0;

    // a mapping that says how much of each vault should be net swapped into another token in this batch. 
    // negative means you're getting more of first token
    // positive means you're getting more of second token
    // TODO safemath me pls mom
    mapping(Pair => int256) public swap_amounts;
    
    // list of pairs in the current batch
    Pair[] public swap_tokens;
    
    /****************** User facing functions ***************/
    
    /**
    * @brief - Allow for depositing tokens into the SMT
    *
    * @param well_formed_proof - A proof that checks that ticket_key is well formed relative to the token, amount, and "deposit transaction"
    * @param smt_update_proof - A proof which shows that we are inserting a KV pair ticket_key = True and that ticket_key is not previously in the proof
    * @param new_root - New smt root
    */
	function deposit(WellFormedProof.Proof memory well_formed_proof, smt_update_proof, IERC20 token, uint256 amount, uint256 ticket_key, uint256 new_root)
		public {
        counter += 1;
        
        // Check the proof of the well formed key
        // assert!(ticket_key = hash(token, amount, "deposit" ...some other fields...))
        // assert!(ticket.token == token && ticket.amount == amount && ticket.instr == "deposit")
        if (!WellFormedTicketVerifier.verifyProof(well_formed_proof, token, amount, ticket_key))  {
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
    uint256 new_ticket_key_2, 
    address source_token,
    address destination_token, 
    uint256 amount,
    uint256 new_utxo_root,
    Proof memory proof
    ) public {

      assert(new_ticket_key_1 != 0);
    if (new_ticket_key_2 == 0)
	    counter += 2;
    else counter += 3;
   assert(amount > 0);
   assert(source_token != destination_token);

    // Check values and update the tree TODO check these
    // [active, timestamp, nullifier_hash, tok_addr, amount, instr, data_1, data_2, randomness]
    // check old ticket key and its cancellation
    // assert!(old_key_comm \in utxo_hash_smt_root)
    // assert!(we know preimage of nullifier hash of old_ticket_key)
    // assert!(canceling_ticket_key \notin utxo_hash_smt_root)
    // assert!(canceling_ticket_key \in new_utxo_root (and update is correct))
    // assert!(canceling_ticket_key.active = 0, all other fields same as old_ticket_key)
    // validate new tickets internally
    // assert!(new_ticket_key_1.active == new_ticket_key_2.active == 1)
    // assert!(new_ticket_key_1.timestamp == new_ticket_key_2.timestamp == ???????)
    // validate new tickets versus other values
    // assert!(new_ticket_2.value + new_ticket_1.value == old_ticket.value)
    // assert!(new_ticket_1.value > 0 && new_ticket_2.value > 0)
    // assert!(new_ticket_2.source_token == new_ticket_1.source_token == old_ticket.token == source_token)
    // assert!(new_ticket_2.destination_token == new_ticket_1.destination_token == destination_token)
    // assert!(new_ticket_1.amount == amount)
    // validate the state update with new tickets
    // assert!(new_ticket_key_1 \in new_utxo_root (and update is correct))
    // assert!(new_ticket_key_2 (if it exists) \in new_utxo_root (and update is correct))
    // assert!(new_ticket_key_1 and new_ticket_key_2 are well-formed)
    // TODO!!! PROOF LOL
    if (!SwapVerifier.proof(proof, utxo_hash_smt_root, old_key_comm, 
        canceling_ticket_key, new_ticket_key_1, new_ticket_key_2, source_token, 
        destination_token, amount, new_utxo_root)) {
      revert("Swap proof was not valid");
    }

    utxo_hash_smt_root = new_utxo_root;

    token_a = max(source_token, destination_token);
    token_b = min(source_token, destination_token);

    if (token_a == source_token) {
      swap_amounts[token_a][token_b] += amount;
    } else {
      swap_amounts[token_a][token_b] -= amount;
    }
  }
  
  /**
   * @param swap_ticket_key_comm  - A commitment to your old ticket key
   * @param swap_ticket_key_proof - A proof showing that your old ticket is in the tree
   * @param cancel_swap_ticket_key - New ticket to cancel old swap ticket
   * @param update_utxo_smt_proof - Proof showing update to utxo_smt done correctly
   * @param withdraw_amount_proof - Proof which checks that the withdraw amount is accurate
     relative to the swap amount in the swap ticket key and the swap which is recorded in the
   * `swap_batch` SMT
   */
  function withdraw(uint256 swap_ticket_key, swap_ticket_key_proof,
    uint256 cancel_swap_ticket_key, update_utxo_smt_proof,
    withdraw_amount_proof,
		uint256 withdraw_amount, address withdraw_to, address token,
    uint256 new_deposit_ticket) public {
    // TODO set counter correctly (for partial withdrawals)
    counter += 1;

    // TODO handle withdrawal of transfers AND swaps- right now you're only handling swaps.

    // looking at original swap ticket and invalidation
    //    assert!(swap_ticket_key_comm \in utxo_hash_smt_root)
    //    assert!(we know preimage of nullifier hash of swap_ticket_key)
    //    assert!(cancel_swap_ticket_key \notin utxo_hash_smt_root)
    //    assert!(cancel_swap_ticket_key \in new_utxo_root (and update is correct))
    //    assert!(cancel_swap_ticket_key.active = 0, all other fields same as swap_ticket_key)
    // swap batch logic
    //    assert!(swap_ticket_key.timestamp <= most recent batch timestamp)
    //    assert!(swap_ticket_key.destination_token == token)
    //    assert!(swap_ticket_key.timestamp is in the batch before the (privately) alleged swap batch)
    //    assert!(alleged swap batch is in the swap batch listings)
    //    assert!(withdrawal amount + new_deposit_ticket.amount == swap_ticket_key.amount * swap_price from batch smt)
    // TODO there are many more invariants here to add!

    // TODO do a real proof of all these things!!!
    Withdraw.proof(swap_ticket_key, swap_ticket_key_proof,
      cancel_swap_ticket_key, update_utxo_smt_proof,
      withdraw_amount_proof,
      withdraw_amount, withdraw_to, token,
      new_deposit_ticket);

    // withdraw your money
    		// Perform ERC 20 Approved Transfer
        if (!token.transferFrom(address(this), withdraw_to, amount)) {
          revert("ERC20 transfer failed");
        }

    // set smt hash accordingly
    utxo_hash_smt_root = new_utxo_root;

  }

  /****************** End user facing functions ***************/
  function do_swap(swap_smt_update_proof, new_swap_smt_root) {
    // Use the `swap_batch` info to perform a 1Inch swap. Then clear the swap batch information
    // (assume external storage solution for now)
    // and then update the SMT root.
    // need to do some payout logic...? to make sure a validator/mevoor calls this.
    // TODO much to think about here...
  }
}