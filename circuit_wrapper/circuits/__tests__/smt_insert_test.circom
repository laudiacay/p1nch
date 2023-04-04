pragma circom 2.1.0;

include "circuits/new_smt_insert.circom";

component main {
	public [
		item_hash,
		old_root,
		new_root,
		key
	]
} = NewSmtInsert(254); //TODO: how many levels habib? 128 should be gucci