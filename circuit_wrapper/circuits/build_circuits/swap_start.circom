pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		inp_tok_addr,
		out_tok_addr,
		new_swap_hash,
		p2skh_comm,
		swap_batch_index,
		p2skh_amount
	]
} = Swap();