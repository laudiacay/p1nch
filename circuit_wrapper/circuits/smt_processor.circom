pragma circom 2.1.0;

include "node_modules/circomlib/circuits/smt/smtverifier.circom";
include "node_modules/circomlib/circuits/smt/smtprocessor.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "circuits/common.circom";

// Use SMT Processor
// component main = SMTVerifier(10);
// TODO: n levels?
// SMTVerifier(10)


/**
 * This component checks that we are inserting a **new** leaf into the tree
 * This is done by checking a non membership proof as well as a well formed update proof
 */
template SMTProcessorWrapper(NLevels) {
	signal input oldRoot;
  signal output newRoot;
  signal input siblings[nLevels];
  signal input oldKey;
  // signal input oldValue;
  signal input isOld0;
  signal input newKey;
  // signal input newValue;
  signal input fnc[2];

	newRoot <== SMTProcessor(NLevels)(
		oldRoot, newRoot, siblings, oldKey, 0, isOld0, newKey, 0, fnc
	);
}