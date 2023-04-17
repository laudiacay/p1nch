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
  signal input siblings[NLevels];
  signal input newKey;

  signal output newRoot;

	newRoot <== SMTProcessor(NLevels)(
		oldRoot, siblings, 0, 0, 1 /* isOld0 being 1 means we do not have an old key */, newKey, 0, [1, 0] // We only support insertions
	);
}

/**
 * Verify membership of a commited to leaf in the tree
 */
template VerifyCommMembership(NLevels) {
		signal input key;
		signal input randomness;
		signal input siblings[NLevels];

	  /**** Public Signals ****/
    signal input comm;
		signal input root;
	  /**** End Signals ****/

    signal _comm <== Poseidon(2)([key, randomness]);
		comm === _comm;
		SMTVerifier(NLevels)(1, root, siblings, 0, 0, 1, key, 0, 0);
}