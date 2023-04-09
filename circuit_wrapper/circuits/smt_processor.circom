pragma circom 2.1.0;

include "node_modules/circomlib/circuits/smt/smtverifier.circom";
include "node_modules/circomlib/circuits/smt/smtprocessor.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "circuits/common.circom";

/**
 * This component checks that we are inserting a **new** leaf into the tree
 * This is done by checking a non membership proof as well as a well formed update proof
 */
template SMTProcessorWrapper(NLevels) {
	signal input oldRoot;
  signal output newRoot;
  signal input siblings[NLevels];
  signal input oldKey;
  // signal input oldValue;
  signal input isOld0;
  signal input newKey;
  // signal input newValue;
  signal input fnc[2];

	newRoot <== SMTProcessor(NLevels)(
		oldRoot, siblings, oldKey, 0, isOld0, newKey, 0, fnc
	);
}

/**
 * Verify membership of a commited to leaf in the tree
 */
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