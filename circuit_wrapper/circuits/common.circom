pragma circom 2.1.0;
include "node_modules/circomlib/circuits/bitify.circom";

var DEPOSIT_INSTR = 0;
var SWAP_INSTR = 1;

component ItemHasher() {
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
  component nullifier_hash = Poseidon(1);
  nullifier ==> nullifier_hash.inputs[0];


  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  nullifier_hash.out ==> poseidon.inputs[2];
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
