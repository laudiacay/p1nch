pragma circom 2.1.0;

include "circuits/common.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


component DepositWellFormed() {
		signal input nullifier;
    signal input randomness;

		signal public input nullifier_comm;
		signal public input amount;
    signal public input timestamp;
    signal public input tok_addr[2];
    signal public input item_hash;



    signal hash <== ItemHasher()(1, timestamp, nullifier, tok_addr[0], tok_addr[1]
      amount, DEPOSIT_INSTR, 0, 0, 0, randomness);
    hash === item_hash;
}