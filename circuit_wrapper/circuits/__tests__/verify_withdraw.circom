pragma circom 2.1.0;

include "circuits/common.circom";
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/smt/smtverifier.circom";

template VerifyWithdraw(NLevels) {
		signal input sk;
		signal input key;
		signal input randomness;
		signal input swap_event_key;
		signal input swap_event_randomness;
		signal input tok_in[2];
		signal input amount_tok_in;
		// TODO: precision etc.
		signal input price;
		signal input swap_event_timestamp;
		signal input swap_ticket_timestamp;


	  /**** Public Signals ****/
    signal input swap_event_comm;
		signal input root;
		signal input tok_out[2];
		signal input amount_out;
		// Hmmmmmm.... we have to make sure of this habib...
		signal input addr_out[2];
		signal input addr_out_sig;
	  /**** End Signals ****/

		// TODO: what am I doing here
    signal _addr_out_sig <== Poseidon(3)([sk, addr_out[0], addr_out[1]]);
		_addr_out_sig === addr_out_sig;

    signal _swap_event_comm <== Poseidon(2)([swap_event_key, swap_event_randomness]);
		swap_event_comm === _swap_event_comm;

		ItemHasher()(1, )
}