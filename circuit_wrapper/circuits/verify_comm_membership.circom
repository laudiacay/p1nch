pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/smt/smtverifier.circom";

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

    signal _deposit_comm <== Poseidon(2)([deposit_key, deposit_randomness]);
		deposit_comm === _deposit_comm;
		SMTVerifier(NLevels)(1, root, siblings, oldKey, oldValue, isOld0, deposit_key, 0, 0);
}