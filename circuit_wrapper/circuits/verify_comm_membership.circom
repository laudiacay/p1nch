pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/smt/smtverifier.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)

template VerifyCommMembership(NLevels) {
		signal input key;
		signal input randomness;
		signal input siblings[NLevels];
		signal input oldKey;
    signal input oldValue;
    signal input isOld0;

	  /**** Public Signals ****/
    signal input comm;
		signal input root;
	  /**** End Signals ****/

    signal _comm <== Poseidon(2)([key, randomness]);
		comm === _comm;
		SMTVerifier(NLevels)(1, root, siblings, oldKey, oldValue, isOld0, key, 0, 0);
}