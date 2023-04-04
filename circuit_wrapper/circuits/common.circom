pragma circom 2.1.0;
include "node_modules/circomlib/circuits/poseidon.circom";


template ItemHasher() {
  signal input active;
  signal input timestamp;
  signal input nullifier;
  signal input tok_addr[2]; // We need 2 signals. One for the upper 128 bits, one for the lower
  signal input amount;
  signal input instr;
  signal input data[3];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(11);
  signal null_hash <== Poseidon(1)([nullifier]);


  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  null_hash ==> poseidon.inputs[2];
  tok_addr[0] ==> poseidon.inputs[3];
  tok_addr[1] ==> poseidon.inputs[4];
  amount ==> poseidon.inputs[5];
  instr ==> poseidon.inputs[6];
  data[0] ==> poseidon.inputs[7];
  data[1] ==> poseidon.inputs[8];
  data[2] ==> poseidon.inputs[9];
  randomness ==> poseidon.inputs[10];

  out <== poseidon.out;
}

template SwapEvent() {
  signal input timestamp_start; // Inclusive
  signal input timestamp_end; // Inclusive
  signal input tok_in[2];
  signal input tok_out[2];
  signal input swap_price; // TODO: price per what???

  signal output out;

  out <== Poseidon(7)(timestamp_start, timestamp_end, tok_in[0], tok_in[1],
    tok_out[0], tok_out[1], swap_price)
}