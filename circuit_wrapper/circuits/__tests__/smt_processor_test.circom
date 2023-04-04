pragma circom 2.1.0;

include "circuits/smt_processor.circom";

component main {
	public [
		oldRoot,
  	newRoot,
  	oldKey,
		fnc,
		newKey
	]
} = NewSmtInsert(10); //TODO: how many levels habib? 128 should be gucci