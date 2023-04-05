pragma circom 2.1.0;

include "circuits/swap_well_formed.circom";

component main {
	public [
		swap_amount,
		inp_tok_addr,
		out_tok_addr,
		deposit_hash_inactive,
		new_deposit_key,
		new_swap_key,
		deposit_comm,
		new_deposit_timestamp
	]
} = SwapWellFormed();