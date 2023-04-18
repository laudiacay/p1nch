pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		amount,
		tok_addr,
		item_hash
	]
} = P2SKHWellFormed();
