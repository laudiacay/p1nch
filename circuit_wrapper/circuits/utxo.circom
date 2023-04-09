pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template Inactive() {
	signal input active_randomness;
	signal input active_timestamp;
	signal input active_amount;
	signal input active_comm_randomness;
	signal input sk;
	signal input active_instr;
	signal input active_data[3];
	signal input active_tok_inp_addr[2];

	/*** Public Signal ***/
	signal input inactive_hash;
	signal input active_comm;
	/*** End Public Signals **/

  signal active_hash <== ItemHasherSK()(1, active_timestamp,
		sk, active_tok_inp_addr,
		amount, active_instr, active_data,
		active_randomness);
  signal _active_comm <== Poseidon(2)([active_hash, p2skh_comm_randomness]);
	active_comm === _active_comm;

	signal _inactive_hash <== ItemHasherSK()(0, active_timestamp,
		sk, active_tok_inp_addr,
		amount, active_instr, active_data,
		active_randomness);
	_inactive_hash === inactive_hash;
}

template P2SKHDeposit() {
    var P2SKH_INSTR = 0;
		signal input sk;
    signal input randomness;

	  /**** Public Signals ****/
		signal input sk_comm;
		signal input amount;
    signal input timestamp;
    signal input tok_addr[2];
    signal input item_hash;
	  /**** End Signals ****/

    signal hash <== ItemHasherSK()(1, timestamp, sk, tok_addr,
      amount, P2SKH_INSTR, [0, 0, 0], randomness);
    hash === item_hash;
}

/**
 * Check the transformation of a P2SKH to a swap UTXO
 */
template Swap() {
    var P2SKH_INSTR = 0;
    var SWAP_INSTR = 1;
		signal input sk;
    signal input p2skh_randomness;
    signal input p2skh_timestamp;
    signal input p2skh_amount;
    signal input p2skh_comm_randomness;
		signal input swap_randomness;
		signal input received_pk;

	  /**** Public Signals ****/
    signal input inp_tok_addr[2];
    signal input out_tok_addr[2];
    signal input new_swap_hash;
    signal input p2skh_comm;
    signal input new_hash_timestamp; // Then, we assume that the new swap timestamp is new_dep + 1
	  /**** End Signals ****/

    signal p2skh_hash <== ItemHasherSK()(1, p2skh_timestamp, sk, inp_tok_addr, p2skh_amount, P2SKH_INSTR, [0, 0, 0], p2skh_randomness);
    signal _p2skh_comm <== Poseidon(2)([p2skh_hash, p2skh_comm_randomness]);
    _p2skh_comm === p2skh_comm;

    signal _new_swap_hash <== ItemHasherPK()(1, new_hash_timestamp, received_pk, inp_tok_addr, p2skh_amount, SWAP_INSTR, [out_tok_addr[0], out_tok_addr[1], 0], swap_randomness);
    new_swap_hash === new_swap_hash;
}

// /**
//  * @brief - A circuit to split or merge p2skh
//  */
// template P2SKHSplitMerge() {
// 	signal input sk;
// 	signal input split_or_merge; // 0 for split, 1 for merge
// 	(split_or_merge - 1) * split_or_merge === 0; // check `split_or_merge` is binary
// 	signal input old_1_comm_randomness;
// 	signal input old_2_comm_randomness;

// 	/*** Public Signals ***/
// 	signal input old_1_comm;
// 	signal input old_2_comm; // If we are splitting and not merging, this is a dummy commitment
// 	signal input new_1_leaf;
// 	signal input new_2_leaf; 
// 	/*** End Public Signals ***/

// 	ItemHasherPK()
// }

template P2SKHSplit() {
	var P2SKH_INSTR = 0;
	signal input sk;
	signal input old_randomness;
	signal input new_randomness_1;
	signal input new_randomness_2;
	signal input new_pk_1;
	signal input new_pk_2;
	signal input old_comm_randomness;
	signal input old_amount;
	signal input old_timestamp;
	signal input tok_addr[2];
	signal input new_amount_1; // New amount 2 is determined by new amount 1

	/**** Public Inputes ***/
	signal input old_comm;
	signal input new_timestamp_1; // New timestamp 2 is `new_timestamp_1 + 1`
	signal input new_hash_1;
	signal input new_hash_2;
	/**** End Public Inputes ***/

  signal old_hash <== ItemHasherSK()(1, old_timestamp, sk, tok_addr,
		old_amount, P2SKH_INSTR, [0, 0, 0], old_randomness);
	signal _old_comm <== Poseidon(2)([old_hash, old_comm_randomness]);
	old_comm === _old_comm;

	Check252Bits()(old_amount); // Ensure that old_amount is positive and fits into leq check
	Check252Bits()(new_amount_1); // Ensure that new_amount_1 is positive and fits into leq check

	signal amount_check <== LessEqThan(252)(new_amount_1, old_amount);
	amount_check === 1;

  signal _new_hash_1 <== ItemHasherPK()(1, new_timestamp_1, new_pk_1, tok_addr,
		new_amount_1, P2SKH_INSTR, [0, 0, 0], new_randomness_1);
	_new_hash_1 === new_hash_1;

  signal _new_hash_2 <== ItemHasherPK()(1, new_timestamp_1 + 1, new_pk_2, tok_addr,
		old_amount - new_amount_1, P2SKH_INSTR, [0, 0, 0], new_randomness_2);
	_new_hash_2 === new_hash_2;
}

template P2SKHMerge() {
	var P2SKH_INSTR = 0;
	signal input sk_1;
	signal input sk_2;
	signal input old_randomness_1;
	signal input old_randomness_2;
	signal input old_comm_randomness_1;
	signal input old_comm_randomness_2;
	signal input old_amount_1;
	signal input old_amount_2;
	signal input old_timestamp_1;
	signal input old_timestamp_2;
	signal input tok_addr[2];

	signal input new_randomness;
	signal input new_pk;

	/**** Public Inputes ***/
	signal input old_comm_1;
	signal input old_comm_2;
	signal input new_timestamp;
	signal input new_hash;
	/**** End Public Inputes ***/

  signal old_hash_1 <== ItemHasherSK()(1, old_timestamp_1, sk, tok_addr,
		old_amount_1, P2SKH_INSTR, [0, 0, 0], old_randomness_1);
	signal _old_comm_1 <== Poseidon(2)([old_hash_1, old_comm_randomness_1]);
	old_comm_1 === _old_comm_1;

  signal old_hash_2 <== ItemHasherSK()(1, old_timestamp_2, sk, tok_addr,
		old_amount_2, P2SKH_INSTR, [0, 0, 0], old_randomness_2);
	signal _old_comm_2 <== Poseidon(2)([old_hash_2, old_comm_randomness_2]);
	old_comm_2 === _old_comm_2;

  signal _new_hash <== ItemHasherPK()(1, new_timestamp, new_pk, tok_addr,
		old_amount_1 + old_amount_2, P2SKH_INSTR, [0, 0, 0], new_randomness_2);
	new_hash === _new_hash;
}