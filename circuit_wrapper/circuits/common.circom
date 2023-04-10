pragma circom 2.1.0;
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/bitify.circom";

// p2skh
template ItemHasherPK() {
  signal input active;
  signal input timestamp;
  signal input pk;
  signal input tok_addr; // We need 2 signals. One for the upper 128 bits, one for the lower
  signal input amount;
  signal input instr;
  signal input data[2];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(9);


  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  pk ==> poseidon.inputs[2];
  tok_addr ==> poseidon.inputs[3];
  amount ==> poseidon.inputs[4];
  instr ==> poseidon.inputs[5];
  data[0] ==> poseidon.inputs[6];
  data[1] ==> poseidon.inputs[7];
  randomness ==> poseidon.inputs[8];

  out <== poseidon.out;
}



template ItemHasherSK() {
  signal input active;
  signal input timestamp;
  signal input sk;
  signal input tok_addr;
  signal input amount;
  signal input instr;
  signal input data[2];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(9);
  signal pk <== Poseidon(1)([sk]);

  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  pk ==> poseidon.inputs[2];
  tok_addr ==> poseidon.inputs[3];
  amount ==> poseidon.inputs[4];
  instr ==> poseidon.inputs[5];
  data[0] ==> poseidon.inputs[6];
  data[1] ==> poseidon.inputs[7];
  randomness ==> poseidon.inputs[8];

  out <== poseidon.out;
}

template SwapEventHasher() {
  signal input timestamp_range[2]; 
  signal input tok_in;
  signal input tok_out;
  signal input price_in; // TODO: price per what???
  signal input price_out; // TODO: price per what???

  signal output out;

  out <== Poseidon(6)([timestamp_range[0], timestamp_range[1], tok_in,
    tok_out, price_in, price_out]);
}

template CheckSwapInclusion() {
  signal input event_range[2];
  signal input timestamp_check;
  signal out_1 <== LessThan(252)([timestamp_check, event_range[1]]);
  out_1 === 1;
  signal out_2 <== LessEqThan(252)([event_range[0], timestamp_check]);
  out_2 === 1;
}

/**
 * Check that the bits fit into 252 bits
 */
template Check252Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits.in <== in;
  num2bits.out[253] === 0;
  num2bits.out[252] === 0;
}

/**
 * Check that the bits fit into 252 bits
 */
template Check125Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits.in <== in;
  for (var i = 125; i < 254; i++) {
    num2bits.out[i] === 0;
  }
}

template Check250Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits.in <== in;
  for (var i = 250; i < 254; i++) {
    num2bits.out[i] === 0;
  }
}

/**
 * @brief - Divide inp[0] / inp[1] = out
 *
 */
template TokDivision() {
  signal input inp[2];
  signal output out;

  out <-- inp[0] \ inp[1];
  Check250Bits()(inp[0]);
  signal remainder <-- inp[0] % inp[1];

	// Check that 0 <= remainder < inp[1]
  signal remainder_check_gte <== GreaterEqThan(252)([remainder, 0]);
  remainder_check_gte === 1;
  signal remainder_check_lt <== LessThan(252)([remainder, inp[1]]);
  remainder_check_lt === 1;

	// Check that 0 <= quotient <= inp[0]
  signal quot_check_gte <== GreaterEqThan(252)([out, 0]);
  signal quot_check_lt <== LessEqThan(252)([out, inp[0]]);
  quot_check_gte === 1;
  quot_check_lt === 1;

  // Check that out * inp[1] + remainder = inp[0]
  out * inp[1] + remainder === inp[0];

}