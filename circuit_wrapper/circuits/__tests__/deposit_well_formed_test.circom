pragma circom 2.1.0;

include "circuits/p2skh_well_formed.circom";

component main {
	public [
		sk_comm,
		amount,
		timestamp,
		tok_addr,
		item_hash
	]
} = P2SKHWellFormed();