pragma circom 2.1.0;

include "circuits/swap_well_formed.circom";

component main {
	public [
		swap_amount,
		inp_tok_addr,
		out_tok_addr,
		p2skh_hash_inactive,
		new_p2skh_key,
		new_swap_key,
		p2skh_comm,
		new_p2skh_timestamp
	]
} = SwapWellFormed();