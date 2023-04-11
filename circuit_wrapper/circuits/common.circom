pragma circom 2.1.0;
include "node_modules/circomlib/circuits/poseidon.circom";
include "node_modules/circomlib/circuits/bitify.circom";

// p2skh
template ItemHasherPK() {
  signal input active;
  signal input pk;
  signal input tok_addr; // We need 2 signals. One for the upper 128 bits, one for the lower
  signal input amount;
  signal input instr;
  signal input data[2];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(8);


  active ==> poseidon.inputs[0];
  pk ==> poseidon.inputs[1];
  tok_addr ==> poseidon.inputs[2];
  amount ==> poseidon.inputs[3];
  instr ==> poseidon.inputs[4];
  data[0] ==> poseidon.inputs[5];
  data[1] ==> poseidon.inputs[6];
  randomness ==> poseidon.inputs[7];

  out <== poseidon.out;
}



template ItemHasherSK() {
  signal input active;
  signal input sk;
  signal input tok_addr;
  signal input amount;
  signal input instr;
  signal input data[2];
  signal input randomness;

  signal output out;

  component poseidon = Poseidon(8);
  signal pk <== Poseidon(1)([sk]);

  active ==> poseidon.inputs[0];
  pk ==> poseidon.inputs[1];
  tok_addr ==> poseidon.inputs[2];
  amount ==> poseidon.inputs[3];
  instr ==> poseidon.inputs[4];
  data[0] ==> poseidon.inputs[5];
  data[1] ==> poseidon.inputs[6];
  randomness ==> poseidon.inputs[7];

  out <== poseidon.out;
}

template SwapEventHasher() {
  signal input batch_index;
  signal input tok_in;
  signal input tok_out;
  signal input price_in; // TODO: price per what???
  signal input price_out; // TODO: price per what???

  signal output out;

  out <== Poseidon(5)([batch_index, tok_in,
    tok_out, price_in, price_out]);
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
 * Check that the bits fit into 125 bits
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