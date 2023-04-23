// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "forge-std/console.sol";

import "./SMTMembershipVerifier.sol";
import "./WellFormedTicketVerifier.sol";
import "./swap/Swapper.sol";
import "./swap/SwapProofVerifier.sol";
import "./HistoricalRoots.sol";

contract Pinch is AccessControl {
    // TODO for circuit reasons, you need to safemath it with uint252

    // TODO clean up argument ordering!
    
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
    constructor(address owner, address sequencer, address swap_bot, address swap_router) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(SEQUENCER_ROLE, sequencer);
        swapper = new Swapper(address(this), swap_bot, swap_router);
        utxo_root = new HistoricalRoots();
    }

    /**
     * User facing functions **************
     */

    /**
     * @notice Deposit tokens into the SMT
     *
     * @param well_formed_proof A proof that verifies ticket_hash is well-formed relative to the token, amount, and "p2skh transaction"
     * @param smt_update_proof A proof that demonstrates the insertion of a KV pair ticket_hash = True and that ticket_hash is not previously in the proof
     * @param token The token to be deposited (IERC20 compatible)
     * @param amount The amount of tokens to be deposited
     * @param ticket_hash The key associated with the deposit ticket
     * @param new_root The new SMT root after deposit
     */
    function deposit(
        WellFormedTicketVerifier.Proof calldata well_formed_proof,
        uint256 ticket_hash,
        SMTMembershipVerifier.Proof calldata smt_update_proof,
        uint256 new_root,
        address token,
        uint256 amount,
        address alice
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 1;

        // Check the proof of the well formed key
        // assert!(ticket_hash = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        require(
            WellFormedTicketVerifier.wellFormedP2SKHproof(well_formed_proof, token, amount, ticket_hash),
            "Well-formed proof failed"
        );

        // Check the smt update proof
        // assert!(ticket_hash \not\in utxo_hash_smt_root)
        // assert!(ticket_hash \in new_root (and update is done correctly))
        require(
            SMTMembershipVerifier.updateProof(smt_update_proof, utxo_root.getCurrent(), new_root, ticket_hash),
            "SMT update proof failed"
        );

		console.log(amount, IERC20(token).allowance(alice, address(this)), address(this));

        // Perform ERC 20 Approved Transfer
        require(IERC20(token).transferFrom(alice, address(this), amount), "ERC20 transfer failed");

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
        // assert!(ticket_hash = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.active = false && ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        // assert!(commitment(old_ticket_hash) is such that the fields in the new deactivator match it...
        // assert!(spending permissioning is okay/knowledge of recipient secret key)
        require(
            WellFormedTicketVerifier.wellFormedDeactivatorProof(
                well_formed_deactivator_proof,
                // address(token),
                // amount,
                old_ticket_hash_commitment,
                new_deactivator_ticket_hash
            ),
            "deactivator wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
        );

        // assert!(committed old ticket is in the provided tree root)
        require(
            SMTMembershipVerifier.commitmentInclusion(
                oldTokenCommitmentInclusionProof, prior_root, old_ticket_hash_commitment
            ),
            "the commitment to the old ticket wasn't in that tree root."
        );

        // and check that that provided tree root is a recent historical commitment- valid :)
        require(
            utxo_root.checkMembership(prior_root), "the tree root you proved stuff against isn't one we have on file"
        );

        // check our modification of the SMT (done by the sequencer) is valid
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_proof, utxo_root.getCurrent(), new_root, new_deactivator_ticket_hash
            ),
            "the SMT modification was not valid"
        );

        // transfer
        require(token.transferFrom(address(this), recipient, amount), "ERC20 transfer failed");

        // and update the state root
        utxo_root.setRoot(new_root);
    }

    // TODO handle if the swap (or other operation) fails!
    function setup_swap(
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_proof,
        uint256 new_deactivator_ticket_hash,
        SMTMembershipVerifier.Proof calldata oldTokenCommitmentInclusionProof,
        uint256 prior_root_for_commitment_inclusion,
        uint256 old_ticket_hash_commitment,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof,
        uint256 root_after_adding_deactivator,
        SwapProofVerifier.Proof calldata well_formed_new_swap_ticket_proof,
        uint256 new_swap_ticket_hash,
        SMTMembershipVerifier.Proof calldata smt_update_new_swap_ticket_proof,
        uint256 root_after_adding_new_swap_ticket,
        IERC20 token,
        IERC20 destination_token,
        uint256 amount
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 2;
        require(amount > 0);
        require(token != destination_token);

        // get the swap batch number
        uint256 swap_batch_number = swapper.getBatchNumber();

        // Check the proof that the nullfier is well-formed and valid and new etc
        // check proof that the commitment
        // assert!(ticket_hash = hash(token, amount, "p2skh" ...some other fields...))
        // assert!(ticket.active = false && ticket.token == token && ticket.amount == amount && ticket.instr == "p2skh")
        // assert!(commitment(old_ticket_hash) is such that the fields in the new deactivator match it...
        // assert!(spending permissioning is okay/knowledge of recipient secret key)
        require(
            WellFormedTicketVerifier.wellFormedDeactivatorProof(
                well_formed_deactivator_proof,
                old_ticket_hash_commitment,
                new_deactivator_ticket_hash
            ),
            "deactivator wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
        );

        // assert!(committed old ticket is in the provided tree root)
        require(
            SMTMembershipVerifier.commitmentInclusion(
                oldTokenCommitmentInclusionProof, prior_root_for_commitment_inclusion, old_ticket_hash_commitment
            ),
            "the commitment to the old ticket wasn't in that tree root."
        );

        // and check that that provided tree root is a recent historical commitment- valid :)
        require(
            utxo_root.checkMembership(prior_root_for_commitment_inclusion),
            "the tree root you proved stuff against isn't one we have on file"
        );

        // check our modification of the SMT (done by the sequencer) is valid (for the deactivator)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof,
                utxo_root.getCurrent(),
                root_after_adding_deactivator,
                new_deactivator_ticket_hash
            ),
            "you didn't modify the SMT correctly to add your deactivator."
        );

        // check validity and well-formedness of the new swap ticket versus the old ticket's hash commitment and the provided arguments.
        // TODO does new_swap_ticket_hash and old_ticket_hash_commitment need to be provided as arguments?
        require(
            SwapProofVerifier.wellFormedSwapTicketProof(
                well_formed_new_swap_ticket_proof,
                address(token),
                address(destination_token),
                amount,
                swap_batch_number,
                new_swap_ticket_hash,
                old_ticket_hash_commitment
            ),
            "the new swap ticket wasn't well formed."
        );

        // check our modification of the SMT (done by the sequencer) is valid (for the new swap ticket)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_new_swap_ticket_proof,
                root_after_adding_deactivator,
                root_after_adding_new_swap_ticket,
                new_swap_ticket_hash
            ),
            "you didn't modify the SMT correctly to add your new swap ticket."
        );

        // update SMT root to add both tickets
        utxo_root.setRoot(root_after_adding_new_swap_ticket);

        // schedule the swap :)
        // TODO is this cast safe on amount?
        swapper.addTransaction(address(token), address(destination_token), uint128(amount));
    }

    function burnSwapToP2SKH(
        WellFormedTicketVerifier.Proof calldata well_formed_spent_swap_deactivator_proof,
        uint256 new_spent_swap_deactivator_ticket,
        uint256 old_swap_hash_commitment,
        SMTMembershipVerifier.Proof calldata oldSwapCommitmentInclusionProof,
        uint256 prior_root_for_commitment_inclusion,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof,
        uint256 root_after_adding_deactivator,
        SwapProofVerifier.Proof calldata price_smt_proof_and_wellformed_new_p2skh_ticket_proof,
        uint256 new_p2skh_ticket_hash,
        uint256 prior_price_root_for_deactivator_amount,
        uint256 swap_event_commitment,
        SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_proof,
        uint256 root_after_adding_new_p2skh_ticket
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 2;

        // need to prove:
        // 1. the deactivator is well formed versus the old swap ticket
        // 2. the old swap ticket is in the provided tree root, which is a recent historical commitment
        // 3. updating to add the deactivator is done correctly
        // 4. the swap ticket was swapped (and thus has a price in the price smt). and, the new p2skh ticket is well formed (and matches the deactivator and price SMT in amount, currency, and swap amount)
        // 5. updating to add the new p2skh ticket is done correctly

        // 1. the deactivator is well formed versus the old swap ticket
        require(
            WellFormedTicketVerifier.wellFormedDeactivatorProof(
                well_formed_spent_swap_deactivator_proof, old_swap_hash_commitment, new_spent_swap_deactivator_ticket
            ),
            "deactivator wasn't well formed either in itself, or against your commitment to its swap ticket, or against your call arguments, or your babyjub key."
        );

        // 2. the old swap ticket is in the provided tree root, which is a recent historical commitment
        require(
            SMTMembershipVerifier.commitmentInclusion(
                oldSwapCommitmentInclusionProof, prior_root_for_commitment_inclusion, old_swap_hash_commitment
            ),
            "the commitment to the old ticket wasn't in that tree root."
        );

        require(
            utxo_root.checkMembership(prior_root_for_commitment_inclusion),
            "the SMT root you proved stuff against isn't one we have on file"
        );

        // 3. updating to add the deactivator is done correctly
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof,
                utxo_root.getCurrent(),
                root_after_adding_deactivator,
                new_spent_swap_deactivator_ticket
            ),
            "you didn't modify the SMT correctly to add your deactivator."
        );

        // 4. the swap ticket was swapped (and thus has a price in the price smt). and, the new p2skh ticket is well formed (and matches the deactivator and price SMT in amount, currency, and swap amount)
        // make sure they presented a valid historical price smt root
        require(
            swapper.checkHistoricalRoot(prior_price_root_for_deactivator_amount),
            "the price SMT root you proved stuff against isn't one we have on file"
        );

        // check well-formedness of the new p2skh ticket.
        // make sure the price is correct and performs a correct conversion at the listed price in the SMT for the given batch
        require(
            SwapProofVerifier.checkPriceSwap(
                price_smt_proof_and_wellformed_new_p2skh_ticket_proof,
                swap_event_commitment,
                old_swap_hash_commitment,
                new_p2skh_ticket_hash
            )
        );

        // 5. updating to add the new p2skh ticket is done correctly
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_new_p2skh_ticket_proof,
                root_after_adding_deactivator,
                root_after_adding_new_p2skh_ticket,
                new_p2skh_ticket_hash
            ),
            "you didn't modify the SMT correctly to add your new p2skh ticket."
        );

        // update SMT root to add both tickets
        utxo_root.setRoot(root_after_adding_new_p2skh_ticket);
    }

    // function splitMergeP2SKH(
    //     WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_1,
    //     WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_2,
    //     SMTMembershipVerifier.Proof calldata smt_update_deactivator_1_proof,
    //     SMTMembershipVerifier.Proof calldata smt_update_deactivator_2_proof,
    //     uint256 old_p2skh_ticket_commitment_1,
    //     uint256 old_p2skh_ticket_commitment_or_dummy_2,
    //     uint256 old_p2skh_deactivator_ticket_1,
    //     uint256 smt_root_after_adding_deactivator_1,
    //     uint256 old_p2skh_deactivator_ticket_or_dummy_2,
    //     uint256 smt_root_after_adding_deactivator_2,
    //     WellFormedTicketVerifier.Proof calldata well_formed_new_p2skh_tickets_proof,
    //     SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_1_proof,
    //     SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_2_proof,
    //     uint256 new_p2skh_ticket_1,
    //     uint256 smt_root_after_adding_new_p2skh_ticket_1,
    //     uint256 new_p2skh_ticket_or_dummy_2,
    //     uint256 smt_root_after_adding_new_p2skh_ticket_2
    // )
    //     public
    //     onlyRole(SEQUENCER_ROLE)
    // {
    //     counter += 4;
    //     // ok so
    //     // we need to prove:
    //     // 1. the deactivator hashes are well formed vs the old p2skh ticket commitments OR they're "dummy || some BS randomness"
    //     // 2. they are updated correctly in the SMT :)
    //     // 3. the new p2skh tickets are well formed vs the old p2skh ticket commitments: this means: addition invariant (with zero add if it's a dummy input) ;) OR they're "dummy || some BS randomness"
    //     // 4. they are also updated correctly in the SMT :)

    //     // 1. the deactivator hashes are well formed vs the old p2skh ticket commitments OR they're "dummy || some BS randomness"

    //     // 1a. deactivator 1
    //     require(
    //         WellFormedTicketVerifier.wellFormedP2SKHDeactivatorOrCorrectDummyProof(
    //             well_formed_deactivator_for_p2skh_1, old_p2skh_ticket_commitment_1, old_p2skh_deactivator_ticket_1
    //         ),
    //         "deactivator 1 wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
    //     );

    //     // 1b. deactivator 2
    //     require(
    //         WellFormedTicketVerifier.wellFormedP2SKHDeactivatorOrCorrectDummyProof(
    //             well_formed_deactivator_for_p2skh_2,
    //             old_p2skh_ticket_commitment_or_dummy_2,
    //             old_p2skh_deactivator_ticket_or_dummy_2
    //         ),
    //         "deactivator 2 wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
    //     );

    //     // 2. they are updated correctly in the SMT :)
    //     // 2a. deactivator 1
    //     require(
    //         SMTMembershipVerifier.updateProof(
    //             smt_update_deactivator_1_proof,
    //             utxo_root.getCurrent(),
    //             smt_root_after_adding_deactivator_1,
    //             old_p2skh_deactivator_ticket_1
    //         ),
    //         "you didn't modify the SMT correctly to add your deactivator 1."
    //     );

    //     // 2b. deactivator 2
    //     require(
    //         SMTMembershipVerifier.updateProof(
    //             smt_update_deactivator_2_proof,
    //             smt_root_after_adding_deactivator_1,
    //             smt_root_after_adding_deactivator_2,
    //             old_p2skh_deactivator_ticket_or_dummy_2
    //         ),
    //         "you didn't modify the SMT correctly to add your deactivator 2."
    //     );

    //     // 3. the new p2skh tickets are well formed vs the old p2skh ticket commitments: this means:
    //     // check addition invariant o_O
    //     // they're also allowed to be "dummy || some BS randomness" with zero contribution to the add invariant
    //     require(
    //         WellFormedTicketVerifier.wellFormedP2SKHMergeSplitAdditionInvariantOrDummyProof(
    //             well_formed_new_p2skh_tickets_proof,
    //             old_p2skh_ticket_commitment_1,
    //             old_p2skh_ticket_commitment_or_dummy_2,
    //             new_p2skh_ticket_1,
    //             new_p2skh_ticket_or_dummy_2
    //         ),
    //         "either the new p2skh tickets weren't well formed, or their tokens were not all the same as the old commitments, or they weren't correct dummies, or... spooky... the addition invariant failed... were you trying to steal funds?"
    //     );

    //     // 4. they are also updated correctly in the SMT :)
    //     // 4a. new p2skh ticket 1
    //     require(
    //         SMTMembershipVerifier.updateProof(
    //             smt_update_new_p2skh_ticket_1_proof,
    //             smt_root_after_adding_deactivator_2,
    //             smt_root_after_adding_new_p2skh_ticket_1,
    //             new_p2skh_ticket_1
    //         ),
    //         "you didn't modify the SMT correctly to add your new p2skh ticket 1."
    //     );

    //     // 4b. new p2skh ticket 2
    //     require(
    //         SMTMembershipVerifier.updateProof(
    //             smt_update_new_p2skh_ticket_2_proof,
    //             smt_root_after_adding_new_p2skh_ticket_1,
    //             smt_root_after_adding_new_p2skh_ticket_2,
    //             new_p2skh_ticket_or_dummy_2
    //         ),
    //         "you didn't modify the SMT correctly to add your new p2skh ticket 2."
    //     );
    //     utxo_root.setRoot(smt_root_after_adding_new_p2skh_ticket_2);
    // }

    function splitP2SKH(
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof,
        uint256 old_p2skh_ticket_commitment,
        uint256 old_p2skh_deactivator_ticket,
        uint256 smt_root_after_adding_deactivator,
        WellFormedTicketVerifier.Proof calldata well_formed_new_p2skh_tickets_proof,
        SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_1_proof,
        SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_2_proof,
        uint256 new_p2skh_ticket_1,
        uint256 smt_root_after_adding_new_p2skh_ticket_1,
        uint256 new_p2skh_ticket_2,
        uint256 smt_root_after_adding_new_p2skh_ticket_2
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 3;
        // ok so
        // we need to prove:
        // 1. the deactivator hash is well formed vs the old p2skh ticket commitment
        // 2. they are updated correctly in the SMT :)
        // 3. the new p2skh tickets are well formed vs the old p2skh ticket commitments: this means: addition invariant
        // 4. they are also updated correctly in the SMT :)

        // 1. the deactivator hash is well formed vs the old p2skh ticket commitment

        // 1. deactivator
        require(
            WellFormedTicketVerifier.wellFormedP2SKHDeactivatorOrCorrectDummyProof(
                well_formed_deactivator_for_p2skh, old_p2skh_ticket_commitment, old_p2skh_deactivator_ticket
            ),
            "deactivator 1 wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
        );

        // 2. deactivator updated correctly in the SMT :)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof,
                utxo_root.getCurrent(),
                smt_root_after_adding_deactivator,
                old_p2skh_deactivator_ticket
            ),
            "you didn't modify the SMT correctly to add your deactivator."
        );

        // 3. the new p2skh tickets are well formed vs the old p2skh ticket commitments: this means:
        // check addition invariant o_O
        require(
            WellFormedTicketVerifier.wellFormedP2SKHSplitAdditionInvariant(
                well_formed_new_p2skh_tickets_proof, old_p2skh_ticket_commitment, new_p2skh_ticket_1, new_p2skh_ticket_2
            ),
            "either the new p2skh tickets weren't well formed, or their tokens were not all the same as the old commitments, or... spooky... the addition invariant failed... were you trying to steal funds?"
        );

        // 4. they are also updated correctly in the SMT :)
        // 4a. new p2skh ticket 1
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_new_p2skh_ticket_1_proof,
                smt_root_after_adding_deactivator,
                smt_root_after_adding_new_p2skh_ticket_1,
                new_p2skh_ticket_1
            ),
            "you didn't modify the SMT correctly to add your new p2skh ticket 1."
        );

        // 4b. new p2skh ticket 2
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_new_p2skh_ticket_2_proof,
                smt_root_after_adding_new_p2skh_ticket_1,
                smt_root_after_adding_new_p2skh_ticket_2,
                new_p2skh_ticket_2
            ),
            "you didn't modify the SMT correctly to add your new p2skh ticket 2."
        );
        utxo_root.setRoot(smt_root_after_adding_new_p2skh_ticket_2);
    }

    function mergeP2SKH(
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_1,
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_2,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof_1,
        SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof_2,
        uint256 old_p2skh_ticket_commitment_1,
        uint256 old_p2skh_ticket_commitment_2,
        uint256 old_p2skh_deactivator_ticket_1,
        uint256 old_p2skh_deactivator_ticket_2,
        uint256 smt_root_after_adding_deactivator_1,
        uint256 smt_root_after_adding_deactivator_2,
        WellFormedTicketVerifier.Proof calldata well_formed_new_p2skh_ticket_proof,
        SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_proof,
        uint256 new_p2skh_ticket,
        uint256 smt_root_after_adding_new_p2skh_ticket
    )
        public
        onlyRole(SEQUENCER_ROLE)
    {
        counter += 3;
        // ok so
        // we need to prove:
        // 1. the deactivator hash are well formed vs the old p2skh ticket commitments
        // 2. they are updated correctly in the SMT :)
        // 3. the new p2skh ticket is well formed vs the old p2skh ticket commitments: this means: addition invariant
        // 4. they are also updated correctly in the SMT :)

        // 1. the deactivator hash is well formed vs the old p2skh ticket commitment

        // 1a. deactivator1
        require(
            WellFormedTicketVerifier.wellFormedP2SKHDeactivatorOrCorrectDummyProof(
                well_formed_deactivator_for_p2skh_1, old_p2skh_ticket_commitment_1, old_p2skh_deactivator_ticket_1
            ),
            "deactivator 1 wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
        );

        // 1b. deactivator2
        require(
            WellFormedTicketVerifier.wellFormedP2SKHDeactivatorOrCorrectDummyProof(
                well_formed_deactivator_for_p2skh_2, old_p2skh_ticket_commitment_2, old_p2skh_deactivator_ticket_2
            ),
            "deactivator 2 wasn't well formed either in itself, or against your commitment to its p2skh ticket, or against your call arguments, or your babyjub key."
        );

        // 2a. deactivator 1 updated correctly in the SMT :)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof_1,
                utxo_root.getCurrent(),
                smt_root_after_adding_deactivator_1,
                old_p2skh_deactivator_ticket_1
            ),
            "you didn't modify the SMT correctly to add your deactivator 1."
        );

        // 2b. deactivator 2 updated correctly in the SMT :)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_deactivator_proof_2,
                smt_root_after_adding_deactivator_1,
                smt_root_after_adding_deactivator_2,
                old_p2skh_deactivator_ticket_2
            ),
            "you didn't modify the SMT correctly to add your deactivator 2."
        );

        // 3. the new p2skh ticket is well formed vs the old p2skh ticket commitments: this means:
        // check addition invariant o_O
        require(
            WellFormedTicketVerifier.wellFormedP2SKHMergeAdditionInvariant(
                well_formed_new_p2skh_ticket_proof,
                old_p2skh_ticket_commitment_1,
                old_p2skh_ticket_commitment_2,
                new_p2skh_ticket
            ),
            "either the new p2skh tickets isn't well formed, or their tokens were not all the same as the old commitment, or... spooky... the addition invariant failed... were you trying to steal funds?"
        );

        // 4. they are also updated correctly in the SMT :)
        require(
            SMTMembershipVerifier.updateProof(
                smt_update_new_p2skh_ticket_proof,
                smt_root_after_adding_deactivator_2,
                smt_root_after_adding_new_p2skh_ticket,
                new_p2skh_ticket
            ),
            "you didn't modify the SMT correctly to add your new p2skh ticket."
        );
        utxo_root.setRoot(smt_root_after_adding_new_p2skh_ticket);
    }
}
