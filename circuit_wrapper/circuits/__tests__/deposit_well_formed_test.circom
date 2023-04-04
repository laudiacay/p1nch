pragma circom 2.1.0;

include "circuits/deposit_well_formed.circom";

component main {
	public [
		nullifier_comm,
		amount,
		timestamp,
		tok_addr,
		item_hash
	]
} = DepositWellFormed();