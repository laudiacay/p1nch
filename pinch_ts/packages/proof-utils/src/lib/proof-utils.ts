//@ts-ignore
import snarkjs from 'snarkjs';
import {
  CircomSMT,
  SMTInclusionArgs,
  SMTInsertArgs,
} from '@pinch-ts/data-layer';
import { BigIntish } from '@pinch-ts/common';

const CIRCOM_PRIME: bigint =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n;

const get_wasm_path = (circuit_name: string) =>
  `../../../assets/src/${circuit_name}_js/${circuit_name}.wasm`;

const get_zkey_path = (circuit_name: string) =>
  `../../../assets/src/${circuit_name}.zkey`;

// TODO: fill in **after testing**
// Hmmmm.... now its a question of where to keep zkeys etc...
// TODO: add assets folder
export const proveCommitmentSMTInclusion = async (
  inclusion_args: SMTInclusionArgs,
  commitment: BigIntish,
  comm_randomness: BigIntish
) => {
  // TODO: return something else?
  const circ_name = 'comm_memb';
  const { proof, _publicSignals } = await snarkjs.groth16.fullProve(
    {
      ...inclusion_args,
      comm: commitment,
      randomness: comm_randomness,
    },
    get_wasm_path(circ_name),
    get_zkey_path(circ_name)
  );
  return proof;
};

export const gen_ticket_hash = async () => {
  // Poseidon that boi
};

export const gen_commitment = async (
  ticket: BigIntish,
  randomness: BigIntish
) => {
  // Poseidon that boi
};

/**
 * @brief Sample 256 bit randomness until we find a sample which is smaller than the Circom Prime
 * Because the prime ~254 bits, we should expect 4 samples until we find a valid one
 */
export const gen_circom_randomness = () => {
  while (true) {
    const bytes = crypto.getRandomValues(new Uint8Array(32));
    // convert byte array to hexademical representation
    const bytesHex = bytes.reduce(
      (o, v) => o + ('00' + v.toString(16)).slice(-2),
      ''
    );

    const big_int = BigInt('0x' + bytesHex);
    if (big_int < CIRCOM_PRIME) {
      return big_int;
    }
  }
};
