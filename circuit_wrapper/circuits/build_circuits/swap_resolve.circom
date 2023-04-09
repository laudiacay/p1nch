pragma circom 2.1.0;

include "circuits/utxo.circom";

component main {
	public [
		swap_event_comm,
		out_p2skh_hash,
		p2skh_timestamp,
		swap_utxo_comm
	]
} = SwapResolveToP2SKH();

// TODO: move these from **test** circuits to the final product...