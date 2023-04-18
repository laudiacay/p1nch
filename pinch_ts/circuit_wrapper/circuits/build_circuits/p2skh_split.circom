pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		old_comm,
		new_hash_1,
		new_hash_2
	]
} = P2SKHSplit();