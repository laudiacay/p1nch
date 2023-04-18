pragma circom 2.1.0;

include "circuits/common.circom";

component main {
	public [
		batch_index,
		tok_in,
		tok_out,
		swap_total_in,
		swap_total_out
	]
} = SwapEventHasher();