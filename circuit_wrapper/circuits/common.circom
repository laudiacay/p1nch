var DEPOSIT_INSTR = 0;
var SWAP_INSTR = 1;

component ItemHasher() {
  signal input active;
  signal input timestamp;
  signal input nullifier;
  signal input tok_addr;
  signal input amount;
  signal input instr;
  signal input data[2];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(9);
  component nullifier_hash = Poseidon(1);
  nullifier ==> nullifier_hash.inputs[0];


  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  nullifier_hash.out ==> poseidon.inputs[2];
  tok_addr ==> poseidon.inputs[3];
  amount ==> poseidon.inputs[4];
  instr ==> poseidon.inputs[5];
  data[1] ==> poseidon.inputs[6];
  data[2] ==> poseidon.inputs[7];
  randomness ==> poseidon.inputs[8];

  out <== poseidon.out;
}

