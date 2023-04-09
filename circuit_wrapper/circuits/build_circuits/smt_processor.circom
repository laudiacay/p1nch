pragma circom 2.1.0;

include "circuits/smt_processor.circom";

component main {
	public [
		oldRoot,
  	oldKey,
		fnc,
		newKey
	]
} = SMTProcessorWrapper(254); //TODO: how many levels habib? 128 should be gucci