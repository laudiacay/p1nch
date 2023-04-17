//@ts-ignore
import snarkjs from 'snarkjs';
import {
  CircomSMT,
  SMTInclusionArgs,
  SMTInsertArgs,
} from '@pinch-ts/data-layer';
import { BigIntish } from '@pinch-ts/common';

// TODO: inputs
export const proveSMTInsert = async (insert_args: SMTInsertArgs) => {
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    insert_args,
    'build/poseidon_hasher_js/poseidon_hasher.wasm', // TODO
    'circuit_0000.zkey' // TODO
  );
  console.log(publicSignals);
  console.log(proof);
};

// TODO: fill in **after testing**
// Hmmmm.... now its a question of where to keep zkeys etc...
// TODO: add assets folder
export const proveSMTInclusion = async (inclusion_args: SMTInclusionArgs) => {};

type P2SKHWellFormedArgs = {
  sk: BigIntish,
  randomness: BigIntish,
  amount: BigIntish,
  tok_addr: BigIntish,
}

export const genP2SKHWellFormed = async (args: P2SKHWellFormedArgs) => {
  const hash = 'blah'
  const proof = 'blah'
  return {
    item_hash: hash,
    proof,
  }
};
export const genDeactivatorWellFormed = async () => {};
export const genP2SKHSplit = async () => {};
export const genP2SKHMerge = async () => {};
export const genSwapEventWellFormed = async () => {};
export const genSwapBurnedToP2SKH = async () => {};
export const genSwapStart = async () => {};
