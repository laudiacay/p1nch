pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		old_comm_1,
		old_comm_2,
		new_hash
	]
} = P2SKHMerge();