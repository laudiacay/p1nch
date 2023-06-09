pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

template Deactivator() {
	signal input active_randomness;
	signal input active_amount;
	signal input active_comm_randomness;
	signal input sk;
	signal input active_instr;
	signal input active_data[2];
	signal input active_tok_inp_addr;

	/*** Public Signal ***/
	signal input deactive_hash;
	signal input active_comm;
	/*** End Public Signals **/

  signal active_hash <== ItemHasherSK()(1,
		sk, active_tok_inp_addr,
		active_amount, active_instr, active_data,
		active_randomness);
  signal _active_comm <== Poseidon(2)([active_hash, active_comm_randomness]);
	active_comm === _active_comm;

	signal _deactive_hash <== ItemHasherSK()(0,
		sk, active_tok_inp_addr,
		active_amount, active_instr, active_data,
		active_randomness);
	_deactive_hash === deactive_hash;
}

template P2SKHWellFormed() {
    var P2SKH_INSTR = 0;
		signal input sk;
    signal input randomness;

	  /**** Public Signals ****/
		signal input amount;
    signal input tok_addr;
    signal input item_hash;
	  /**** End Signals ****/

    signal hash <== ItemHasherSK()(1, sk, tok_addr,
      amount, P2SKH_INSTR, [0, 0], randomness);
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
    signal input p2skh_comm_randomness;
		signal input swap_randomness;
		signal input received_pk;

	  /**** Public Signals ****/
    signal input inp_tok_addr;
    signal input out_tok_addr;
    signal input new_swap_hash;
    signal input p2skh_comm;
    signal input swap_batch_index;
    signal input p2skh_amount;
	  /**** End Signals ****/

    signal p2skh_hash <== ItemHasherSK()(1, sk, inp_tok_addr, p2skh_amount, P2SKH_INSTR, [0, 0], p2skh_randomness);
    signal _p2skh_comm <== Poseidon(2)([p2skh_hash, p2skh_comm_randomness]);
    _p2skh_comm === p2skh_comm;

    signal _new_swap_hash <== ItemHasherPK()(1, received_pk, inp_tok_addr, p2skh_amount, SWAP_INSTR, [out_tok_addr, swap_batch_index], swap_randomness);
    new_swap_hash === new_swap_hash;

		// Check that the swap amount fits into 120 bits so that we can later do arithmetic on it later
		Check125Bits()(p2skh_amount);
}

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
	signal input tok_addr;
	signal input new_amount_1; // New amount 2 is determined by new amount 1

	/**** Public Inputes ***/
	signal input old_comm;
	signal input new_hash_1;
	signal input new_hash_2;
	/**** End Public Inputes ***/

  signal old_hash <== ItemHasherSK()(1, sk, tok_addr,
		old_amount, P2SKH_INSTR, [0, 0], old_randomness);
	signal _old_comm <== Poseidon(2)([old_hash, old_comm_randomness]);
	old_comm === _old_comm;

	Check252Bits()(old_amount); // Ensure that old_amount is positive and fits into leq check
	Check252Bits()(new_amount_1); // Ensure that new_amount_1 is positive and fits into leq check

	signal amount_check <== LessEqThan(252)([new_amount_1, old_amount]);
	amount_check === 1;

  signal _new_hash_1 <== ItemHasherPK()(1, new_pk_1, tok_addr,
		new_amount_1, P2SKH_INSTR, [0, 0], new_randomness_1);
	_new_hash_1 === new_hash_1;

  signal _new_hash_2 <== ItemHasherPK()(1, new_pk_2, tok_addr,
		old_amount - new_amount_1, P2SKH_INSTR, [0, 0], new_randomness_2);
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
	signal input tok_addr;

	signal input new_randomness;
	signal input new_pk;

	/**** Public Inputes ***/
	signal input old_comm_1;
	signal input old_comm_2;
	signal input new_hash;
	/**** End Public Inputes ***/

  signal old_hash_1 <== ItemHasherSK()(1, sk_1, tok_addr,
		old_amount_1, P2SKH_INSTR, [0, 0], old_randomness_1);
	signal _old_comm_1 <== Poseidon(2)([old_hash_1, old_comm_randomness_1]);
	old_comm_1 === _old_comm_1;

  signal old_hash_2 <== ItemHasherSK()(1, sk_2, tok_addr,
		old_amount_2, P2SKH_INSTR, [0, 0], old_randomness_2);
	signal _old_comm_2 <== Poseidon(2)([old_hash_2, old_comm_randomness_2]);
	old_comm_2 === _old_comm_2;

  signal _new_hash <== ItemHasherPK()(1, new_pk, tok_addr,
		old_amount_1 + old_amount_2, P2SKH_INSTR, [0, 0], new_randomness);
	new_hash === _new_hash;
}

/**
 * @brief - Resolve the swap after it occured
 */
template SwapResolveToP2SKH() {
  var P2SKH_INSTR = 0;
  var SWAP_INSTR = 1;

	signal input sk;
	signal input swap_randomness;
	signal input inp_tok_amount;
	signal input inp_tok;
	signal input out_tok;
	
	// TODO: precision?
	signal input swap_total_in;
	signal input swap_total_out;

	signal input swap_event_batch_index;

	signal input p2skh_randomness;
	signal input pk_out;

	signal input swap_utxo_comm_randomness;
	signal input swap_event_comm_randomness;

	/*** Public Signals ***/
	signal input swap_event_comm;
	signal input out_p2skh_hash;
	signal input swap_utxo_comm;
	/*** End Public Signals ***/

	// Check that the prices fit into 125 bit	
	Check125Bits()(swap_total_in);
	Check125Bits()(swap_total_out);

//  TODO: add more precision???
	signal mult_temp <== inp_tok_amount * swap_total_out;
	signal amount_out <== TokDivision()([mult_temp, swap_total_in]);

  // Check the swap event commitment
	signal _swap_utxo_hash <== ItemHasherSK()(1, sk, inp_tok, inp_tok_amount, SWAP_INSTR, [out_tok, swap_event_batch_index], swap_randomness);
	signal _swap_utxo_comm <== Poseidon(2)([_swap_utxo_hash, swap_utxo_comm_randomness]);
	_swap_utxo_comm === swap_utxo_comm;

  // Check the output hash
	signal _out_p2skh_hash <== ItemHasherPK()(1, pk_out, out_tok, amount_out, P2SKH_INSTR, [0, 0], p2skh_randomness);
	_out_p2skh_hash === out_p2skh_hash;

	signal swap_event_hash <== SwapEventHasher()(swap_event_batch_index, inp_tok, out_tok, swap_total_in, swap_total_out);
	signal _swap_event_comm <== Poseidon(2)([swap_event_hash, swap_event_comm_randomness]);
	_swap_event_comm === swap_event_comm;
}