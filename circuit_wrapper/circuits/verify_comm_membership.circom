pragma circom 2.1.0;

include "circuits/common.circom";
include "circuit_wrapper/node_modules/circomlib/circuits/poseidon.circom";
include "circuit_wrapper/node_modules/circomlib/circuits/smt/smtverifier.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


template VerifyCommMembership(NLevels) {
		signal input nullifier;
		signal input deposit_key;
		signal input deposit_randomness;
		signal input siblings[NLevels];
		signal input oldKey;
    signal input oldValue;
    signal input isOld0;

	  /**** Public Signals ****/
    signal input deposit_comm;
		signal input root;
	  /**** End Signals ****/

    // TODO: is the bit amount a problem?
    1 === LessEqThan(252)(swap_amount, deposit_amount); // Check that the swap amont is less than deposit

    deposit_comm === Poseidon(2)([deposit_key, deposit_randomness]);
		SMTVerifier(NLevels)(1, root, siblings, oldKey, oldValue, isOld0, deposit_key, 0, 0);
}