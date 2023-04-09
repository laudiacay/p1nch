pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/comparators.circom";
include "node_modules/circomlib/circuits/poseidon.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)

// template 

template InactiveWellFormed() {
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

template P2SKHWellFormed() {
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

template SwapWellFormed() {
    var P2SKH_INSTR = 0;
    var SWAP_INSTR = 1;
		signal input sk;
    signal input p2skh_randomness;
    signal input p2skh_timestamp;
    signal input p2skh_amount;
    signal input p2skh_inactive_randomness;
    signal input p2skh_comm_randomness;
		// TODO: split up inactive and p2skh

	  /**** Public Signals ****/
		signal input swap_amount;
    signal input inp_tok_addr[2];
    signal input out_tok_addr[2];
    signal input p2skh_hash_inactive;
    signal input new_p2skh_key;
    signal input new_swap_key;
    signal input p2skh_comm;
    signal input new_p2skh_timestamp; // Then, we assume that the new swap timestamp is new_dep + 1
	  /**** End Signals ****/

    // TODO: is the bit amount a problem?
    signal comp_out <== LessEqThan(252)([swap_amount, p2skh_amount]); // Check that the swap amont is less than p2skh
    comp_out === 1;

    signal p2skh_key <== ItemHasherSK()(1, p2skh_timestamp, sk, inp_tok_addr, p2skh_amount, P2SKH_INSTR, [0, 0, 0], p2skh_randomness);
    signal _p2skh_comm <== Poseidon(2)([p2skh_key, p2skh_comm_randomness]);
    _p2skh_comm === p2skh_comm;

    signal _p2skh_hash_inactive <== ItemHasherSK()(0, p2skh_timestamp, sk, inp_tok_addr, p2skh_amount, P2SKH_INSTR, [0, 0, 0], p2skh_randomness);
    _p2skh_hash_inactive === p2skh_hash_inactive;

    signal _new_p2skh_key <== ItemHasherSK()(1, new_p2skh_timestamp, sk, inp_tok_addr, p2skh_amount - swap_amount, P2SKH_INSTR, [0, 0, 0], p2skh_randomness);
    _new_p2skh_key === new_p2skh_key;

    signal _new_swap_key <== ItemHasherSK()(1, new_p2skh_timestamp + 1, sk, inp_tok_addr, swap_amount, SWAP_INSTR, [out_tok_addr[0], out_tok_addr[1], 0], p2skh_randomness);
    _new_swap_key === new_swap_key;
}