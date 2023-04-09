pragma circom 2.1.0;
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/bitify.circom";

// p2skh
template ItemHasherPK() {
  signal input active;
  signal input timestamp;
  signal input pk;
  signal input tok_addr[2]; // We need 2 signals. One for the upper 128 bits, one for the lower
  signal input amount;
  signal input instr;
  signal input data[3];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(11);


  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  pk ==> poseidon.inputs[2];
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



template ItemHasherSK() {
  signal input active;
  signal input timestamp;
  signal input sk;
  signal input tok_addr[2]; // We need 2 signals. One for the upper 128 bits, one for the lower
  signal input amount;
  signal input instr;
  signal input data[3];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(11);
  signal pk <== Poseidon(1)([sk]);

  active ==> poseidon.inputs[0];
  timestamp ==> poseidon.inputs[1];
  pk ==> poseidon.inputs[2];
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

template SwapEventHasher() {
  signal input timestamp_range[2]; 
  signal input tok_in[2];
  signal input tok_out[2];
  signal input swap_price; // TODO: price per what???

  signal output out;

  out <== Poseidon(7)(timestamp_range[0], timestamp_range[1], tok_in[0], tok_in[1],
    tok_out[0], tok_out[1], swap_price)
}

template CheckSwapInclusion() {
  signal input event_range[2];
  signal input timestamp_check;
  signal out_1 <== LessThan(252)(timestamp_check, event_range[1]);
  out_1 === 1;
  signal out_2 <== LessThanEq(252)(event_range[0], timestamp_check)
  out_2 === 1;
}

/**
 * Check that the bits fit into 252 bits
 */
template Check252Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits <== in;
  num2bits.out[253] == 0;
  num2bits.out[252] == 0;
}

/**
 * Check that the bits fit into 252 bits
 */
template Check125Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits <== in;
  for (var i = 125; i < 254; i++) {
    num2bits.out[i] === 0;
  }
}

template Check250Bits() {
  signal input in;
  component num2bits = Num2Bits_strict();
  num2bits <== in;
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
  Check250Bits(inp[0]);
  signal remainder <-- inp[0] % inp[1];

	// Check that 0 <= remainder < inp[1]
  signal remainder_check_gte <== GreaterEqThan(252)(remainder, 0);
  remainder_check_gte === 1;
  signal remainder_check_lt <== LessThan(252)(remainder, inp[1]);
  remainder_check_lt === 1;

	// Check that 0 <= quotient <= inp[0]
  signal quot_check_gte <== GreaterEqThan(252)(out, 0);
  signal quot_check_lt <== LessThanEq(252)(out, inp[0]);

  // Check that out * inp[1] + remainder = inp[0]
  out * inp[1] + remainder === inp[0];

}