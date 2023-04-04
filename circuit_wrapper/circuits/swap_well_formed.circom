pragma circom 2.1.0;

include "circuits/common.circom";
include "circuit_wrapper/node_modules/circomlib/circuits/comparators.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


template DepositWellFormed() {
    var DEPOSIT_INSTR = 0;
    var SWAP_INSTR = 1;
		signal input nullifier;
    signal input deposit_randomness;
    signal input deposit_timestamp;
    signal input deposit_amount;
    signal input deposit_inactive_randomness;
    signal input deposit_comm_randomness;

	  /**** Public Signals ****/
		signal input nullifier_comm;
		signal input swap_amount;
    signal input inp_tok_addr[2];
    signal input out_tok_addr[2];
    signal input deposit_hash_inactive;
    signal input new_deposit_key;
    signal input new_swap_key;
    signal input deposit_comm;

    signal input new_deposit_timestamp; // Then, we assume that the new swap timestamp is new_dep + 1
	  /**** End Signals ****/

    // TODO: is the bit amount a problem?
    1 === LessEqThan(252)(swap_amount, deposit_amount); // Check that the swap amont is less than deposit

    signal deposit_key <== ItemHasher()(1, deposit_timestamp, nullifier, inp_tok_addr, deposit_amount, DEPOSIT_INSTR, [0, 0, 0], deposit_randomness);
    deposit_comm === Poseidon(2)([deposit_key, deposit_comm_randomness]);

    deposit_hash_inactive === ItemHasher()(0, deposit_timestamp, nullifier, inp_tok_addr, deposit_amount, DEPOSIT_INSTR, [0, 0, 0], deposit_randomness);

    new_deposit_key === ItemHasher()(1, deposit_timestamp, nullifier, inp_tok_addr, deposit_amount - swap_amount, DEPOSIT_INSTR, [0, 0, 0], deposit_randomness);

    new_swap_key === ItemHasher()(1, deposit_timestamp, nullifier, inp_tok_addr, swap_amount, SWAP_INSTR, [out_tok_addr[0], out_tok_addr[1], 0], deposit_randomness);
}