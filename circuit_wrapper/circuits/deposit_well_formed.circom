pragma circom 2.0.0;

include "node_modules/circomlib/circuits/smt/smtverifier.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "circuits/common.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


component DepositWellFormed(NLevels) {
		signal input nullifier;
    signal input randomness;

		signal public input nullifier_comm;
		signal public input amount;
    signal public input timestamp;
    signal public input tok_addr;
    signal public input item_hash;

    signal hash <== ItemHasher()(1, timestamp, nullifier, tok_addr,
      amount, DEPOSIT_INSTR, 0, 0, randomness);
    hash === item_hash;
}