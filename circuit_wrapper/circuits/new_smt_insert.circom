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
component NewSmtInsert(NLevels) {
  signal public input item_hash;
	signal public input old_root;
	signal public input new_root;
	signal input siblings[NLevels];
	// TODO: ?
	signal input is_old_0;
	signal public input key;

	// Check the update
	signal new_root_out <== SMTProcessor(NLevels)(old_root, siblings, key, 1, is_old_0, key, 1, 1, 0);
	new_root === new_root_out;

}