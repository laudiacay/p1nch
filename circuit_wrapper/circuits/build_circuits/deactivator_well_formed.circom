pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		deactive_hash,
		active_comm
	]
} = Deactivator();
