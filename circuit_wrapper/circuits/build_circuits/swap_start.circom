pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		inp_tok_addr,
		out_tok_addr,
		new_swap_hash,
		p2skh_comm,
		new_hash_timestamp,
		p2skh_amount
	]
} = Swap();