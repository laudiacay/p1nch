// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/access/AccessControl.sol";

import "./SMTMembershipVerifier.sol";
import "./WellFormedTicketVerifier.sol";
import "./Swapper.sol";
import "./HistoricalRoots.sol";

contract Pinch is AccessControl {
    // TODO for circuit reasons, you need to safemath it with uint252

    // number of utxos in the smt root. apparently this is useful for some kind of regulatory compliance reason
    uint256 counter = 0;

    // this is the current batch number. incremented every time a swap batch is swapped.
    uint256 current_batch_num = 0;

    // this thing tracks swap prices
    Swapper swapper;

    // this is an SMT that tracks UTXO hashes.
    // it contains tickets for p2skh, swaps, and deactivation tickets for both
    // it contains hash(ticket) (also called ticket key) => 0 for "present tickets"
    // when you want to deactivate a ticket, you insert hash(same ticket but where active = 0) => 0
    // when you deposit, swap, or withdraw, you modify this tree.
    // always check modification proofs, which should be presented before any update.
    // it has this historicalroots type on it so we can validate that whatever latencied-up stale version of the smt root that the user proved against is a valid historical SMT root.
    HistoricalRoots utxo_root;

    bytes32 public constant SEQUENCER_ROLE = keccak256("SEQUENCER_ROLE");

    // TODO seriously think about permissioning better on this!
    constructor(address sequencer, address swap_bot) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SEQUENCER_ROLE, sequencer);
        swapper = new Swapper(address(this), swap_bot);
        utxo_root = new HistoricalRoots();
    }

    /**
     * User facing functions **************
     */

    /**
     * @notice Deposit tokens into the SMT
     *
     * @param well_formed_proof A proof that verifies ticket_key is well-formed relative to the token, amount, and "p2skh transaction"
     * @param smt_update_proof A proof that demonstrates the insertion of a KV pair ticket_key = True and that ticket_key is not previously in the proof
     * @param token The token to be deposited (IERC20 compatible)
     * @param amount The amount of tokens to be deposited
     * @param ticket_key The key associated with the deposit ticket
     * @param new_root The new SMT root after deposit
     */
    function deposit(
        WellFormedTicketVerifier.Proof calldata well_formed_proof,
        uint256 ticket_key,
        SMTMembershipVerifier.Proof calldata smt_update_proof,
        uint256 new_root,
        IERC20 token,
        uint256 amount
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 1;

        // Check the proof of the well formed key
        // assert!(ticket_key = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        if (
            !WellFormedTicketVerifier.wellformedDepositTicketProof(well_formed_proof, address(token), amount, ticket_key)
        ) {
            revert("ticket was not well-formed");
        }

        // Check the smt update proof
        // assert!(ticket_key \not\in utxo_hash_smt_root)
        // assert!(ticket_key \in new_root (and update is done correctly))
        if (!SMTMembershipVerifier.updateProof(smt_update_proof, utxo_root.getCurrent(), new_root, ticket_key)) {
            revert("SMT modification was not valid");
        }

        // Perform ERC 20 Approved Transfer
        if (!token.transferFrom(msg.sender, address(this), amount)) {
            revert("ERC20 transfer failed");
        }

        // Update the root
        utxo_root.setRoot(new_root);
    }

    /**
     * @notice Withdraws tokens from the contract based on the provided proofs.
     * @param well_formed_deactivator_proof A proof object that verifies the deactivator ticket is well-formed WRT the old ticket hash commitment and that we can produce a proof that we're allowed to spend it.
     * @param oldTokenCommitmentInclusionProof A proof object that verifies the inclusion of the old token commitment in the previous state.
     * @param smt_update_proof A proof object that verifies the Sparse Merkle Tree update to add the deactivator
     * @param token The ERC20 token contract address for the tokens being withdrawn.
     * @param prior_root The root of the Sparse Merkle Tree before the update- may be stale from user, not necessarily the most recent one. we'll check that it's a valid historical root
     * @param amount The amount of tokens being withdrawn.
     * @param old_ticket_hash_commitment The hash commitment of the old ticket.
     * @param new_deactivator_ticket_hash The hash of the new deactivator ticket.
     * @param new_root The root of the Sparse Merkle Tree after the update.
     * @param recipient The address that will receive the withdrawn tokens.
     */
    function withdraw(
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_proof,
        uint256 new_deactivator_ticket_hash,
        SMTMembershipVerifier.Proof calldata oldTokenCommitmentInclusionProof,
        uint256 old_ticket_hash_commitment,
        uint256 prior_root,
        SMTMembershipVerifier.Proof calldata smt_update_proof,
        uint256 new_root,
        IERC20 token,
        uint256 amount,
        address recipient
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 1;

        // Check the proof that the nullfier is well-formed and valid and new etc
        // check proof that the commitment
        // assert!(ticket_key = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.active = false && ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        // assert!(commitment(old_ticket_hash) is such that the fields in the new deactivator match it...
        // assert!(spending permissioning is okay/knowledge of recipient secret key)
        if (
            !WellFormedTicketVerifier.well_formed_deactivation_hash_proof(
                well_formed_deactivator_proof,
                address(token),
                amount,
                old_ticket_hash_commitment,
                new_deactivator_ticket_hash
            )
        ) {
            revert(
                "deactivator wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
            );
        }

        // assert!(committed old ticket is in the provided tree root)
        if (
            !SMTMembershipVerifier.commitmentInclusion(
                oldTokenCommitmentInclusionProof, prior_root, old_ticket_hash_commitment
            )
        ) {
            revert("the commitment to the old ticket wasn't in that tree root.");
        }

        // and check that that provided tree root is a recent historical commitment- valid :)
        if (!utxo_root.checkMembership(prior_root)) {
            revert("the tree root you proved stuff against isn't one we have on file");
        }

        // check our modification of the SMT (done by the sequencer) is valid
        if (
            !SMTMembershipVerifier.updateProof(
                smt_update_proof, utxo_root.getCurrent(), new_root, new_deactivator_ticket_hash
            )
        ) {
            revert("you didn't modify the SMT correctly to add your deactivator.");
        }

        // transfer
        if (!token.transferFrom(address(this), recipient, amount)) {
            revert("ERC20 transfer failed");
        }

        // and update the state root
        utxo_root.setRoot(new_root);
    }

    // TODO handle if the swap (or other operation) fails!
    function setup_swap (
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_proof,
        uint256 new_deactivator_ticket_hash,
        SMTMembershipVerifier.Proof calldata oldTokenCommitmentInclusionProof,
        uint256 prior_root_for_commitment_inclusion,
        uint256 old_ticket_hash_commitment,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof,
        uint256 root_after_adding_deactivator,
        WellFormedTicketVerifier.Proof calldata well_formed_new_swap_ticket_proof,
        uint256 new_swap_ticket_key,
        SMTMembershipVerifier.Proof calldata smt_update_new_swap_ticket_proof,
        uint256 root_after_adding_new_swap_ticket,
        IERC20 token,
        IERC20 destination_token,
        uint256 amount
    ) public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 2;
        assert(amount > 0);
        assert(token != destination_token);
        
        // Check the proof that the nullfier is well-formed and valid and new etc
        // check proof that the commitment
        // assert!(ticket_key = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.active = false && ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        // assert!(commitment(old_ticket_hash) is such that the fields in the new deactivator match it...
        // assert!(spending permissioning is okay/knowledge of recipient secret key)
        if (
            !WellFormedTicketVerifier.well_formed_deactivation_hash_proof(
                well_formed_deactivator_proof,
                address(token),
                amount,
                old_ticket_hash_commitment,
                new_deactivator_ticket_hash
            )
        ) {
            revert(
                "deactivator wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
            );
        }

        // assert!(committed old ticket is in the provided tree root)
        if (
            !SMTMembershipVerifier.commitmentInclusion(
                oldTokenCommitmentInclusionProof, prior_root_for_commitment_inclusion, old_ticket_hash_commitment
            )
        ) {
            revert("the commitment to the old ticket wasn't in that tree root.");
        }

        // and check that that provided tree root is a recent historical commitment- valid :)
        if (!utxo_root.checkMembership(prior_root_for_commitment_inclusion)) {
            revert("the tree root you proved stuff against isn't one we have on file");
        }

        // check our modification of the SMT (done by the sequencer) is valid (for the deactivator)
        if (
            !SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof, utxo_root.getCurrent(), root_after_adding_deactivator, new_deactivator_ticket_hash
            )
        ) {
            revert("you didn't modify the SMT correctly to add your deactivator.");
        }

        // check validity and well-formedness of the new swap ticket versus the old ticket's hash commitment and the provided arguments.
        // TODO does new_swap_ticket_key and old_ticket_hash_commitment need to be provided as arguments?
        if (
            !WellFormedTicketVerifier.wellFormedSwapTicketProof(
                well_formed_new_swap_ticket_proof,
                address(token),
                address(destination_token),
                amount,
                new_swap_ticket_key,
                old_ticket_hash_commitment
            )
        ) {
            revert("the new swap ticket wasn't well formed.");
        }

        // check our modification of the SMT (done by the sequencer) is valid (for the new swap ticket)
        if (
            !SMTMembershipVerifier.updateProof(
                smt_update_new_swap_ticket_proof, root_after_adding_deactivator, root_after_adding_new_swap_ticket, new_swap_ticket_key
            )
        ) {
            revert("you didn't modify the SMT correctly to add your new swap ticket.");
        }

        // update SMT root to add both tickets
        utxo_root.setRoot(root_after_adding_new_swap_ticket);

        // schedule the swap :)
        // TODO is this cast safe on amount?
        swapper.addTransaction(address(token), address(destination_token), uint128(amount));
    }

    //     /**
    //      * TODO clean up and correct these parameters
    //      * @param old_key_comm - A commitment to the old ticket key. This is used in the proof of the old_ticket_key_canceling
    //      * @param old_ticket_key_proof - A proof that the old ticket is in one of the past SMT
    //      * @param update_proof - Checks that canceling ticket is **not** in the SMT and then appends it to the SMT
    //      * @param canceling_ticket_key - The old deposit key but now with active set to false and fresh randomness
    //      * @param new_ticket_key_1 - The first new ticket key which is split from the old ticket
    //      * @param new_ticket_key_2 - The second ticket key which is split from the new. If null just set to 0 (i.e. the old ticket is converted to just 1 new ticket)
    //      * @param new_ticket_proof - A proof showing that the 2 new tickets are well formed, i.e. the sum of the token amounts in the new tickets equal the old one and that the same token is used
    //      * and that the destination tokens and amounts match
    //      */
    //     function setup_swap(
    //         uint256 old_key_comm, // note this is JUST A COMMITMENT to the ticket hash- you should not present the actual ticket hash
    //         uint256 canceling_ticket_key,
    //         uint256 new_ticket_key_1,
    //         address source_token,
    //         address destination_token,
    //         uint256 amount,
    //         uint256 new_utxo_root,
    //         uint256 provided_root,
    //         Proof memory smt_update_proof_deactivator,
    //         Proof memory old_key_proof
    //     )
    //         public
    //     {
    //         assert(new_ticket_key_1 != 0);
    //         counter += 2;
    //         assert(amount > 0);
    //         assert(source_token != destination_token);

    //         uint256 current_root = utxo_root.getCurrent();

    //         // Check values and update the tree
    //         // TODO let's check that this is an acceptable list of invariants

    //         // first: check old ticket key and its cancellation

    //         // assert!(old_key_comm \in some prior valid utxo_hash_smt_root)
    //         if (!SMTMembershipVerifier.inclusionProof(proof.old_ticket_key_proof, provided_root, old_key_comm)) {
    //             revert("old ticket key was not in the SMT");
    //         }

    //         utxo_root.checkMembership(provided_root);

    //         // assert!(canceling_ticket_key \notin utxo_hash_smt_root)
    //         // assert!(canceling_ticket_key \in new_utxo_root (and update is correct))
    //         if (
    //             !SMTMembershipVerifier.update_proof(
    //                 smt_update_proof_deactivator, current_root, new_root, canceling_ticket_key
    //             )
    //         ) {
    //             revert("cancelling key SMT modification was not valid");
    //         }

    //         // assert!(canceling_ticket_key.active = 0, all other fields same as old_ticket_key)
    //         // assert!(we know preimage of deactivator hash of old_ticket_key)
    //         if (
    //             !WellFormedTicketVerifier.well_formed_deactivation_hash_proof(
    //                 proof, token, amount, old_key_comm, cancelling_key
    //             )
    //         ) {
    //             revert("cancellation ticket was not well-formed");
    //         }

    //         // validate new ticketx internally
    //         // assert!(new_ticket_key_1.active == 1)
    //         // assert!(new_ticket_key_1.timestamp == ???????)
    //         if (!WellFormedTicketVerifier.wellformedActiveSwapTicketProof()) {}
    //         // assert!(new_ticket_key_1.active == new_ticket_key_2.active == 1)
    //         // assert!(new_ticket_key_1.timestamp == new_ticket_key_2.timestamp == ???????)

    //         // validate new tickets versus other values
    //         // assert!(new_ticket_1.value == old_ticket.value)
    //         // assert!(new_ticket_1.value > 0)
    //         // assert!(new_ticket_1.source_token == old_ticket.token == source_token)
    //         // assert!(new_ticket_1.destination_token == destination_token)
    //         // assert!(new_ticket_1.amount == amount)
    //         // validate the state update with new tickets
    //         // assert!(new_ticket_key_1 \in new_utxo_root (and update is correct))
    //         // assert!(new_ticket_key_1 is well-formed)
    //         if (
    //             !SwapVerifier.proof(
    //                 proof,
    //                 utxo_hash_smt_root,
    //                 old_key_comm,
    //                 canceling_ticket_key,
    //                 new_ticket_key_1,
    //                 new_ticket_key_2,
    //                 source_token,
    //                 destination_token,
    //                 amount,
    //                 new_utxo_root
    //             )
    //         ) {
    //             revert("Swap proof was not valid");
    //         }

    //         utxo_hash_smt_root = new_utxo_root;

    //         swapper.addTransaction(source_token, destination_token, amount);
    //     }
    // }
}
