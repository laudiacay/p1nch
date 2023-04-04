pragma circom 2.1.0;

include "circuits/common.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


template DepositWellFormed() {
    var DEPOSIT_INSTR = 0;
    var SWAP_INSTR = 1;
		signal input nullifier;
    signal input randomness;

	  /**** Public Signals ****/
		signal input nullifier_comm;
		signal input amount;
    signal input timestamp;
    signal input tok_addr[2];
    signal input item_hash;
	  /**** End Signals ****/



    signal hash <== ItemHasher()(1, timestamp, nullifier, tok_addr,
      amount, DEPOSIT_INSTR, [0, 0, 0], randomness);
    hash === item_hash;
}