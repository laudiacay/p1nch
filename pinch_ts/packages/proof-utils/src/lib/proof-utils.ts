//@ts-ignore
import * as snarkjs from 'snarkjs';
import * as crypto from 'crypto';
import { readFileSync } from 'fs';
//@ts-ignore
import { buildPoseidon } from 'circomlibjs';
import {
  CircomSMT,
  SMTInclusionArgs,
  SMTInsertArgs,
} from '@pinch-ts/data-layer';
import { BigIntish } from '@pinch-ts/common';
import { BitwiseOperator } from 'typescript';
import { dirname, join } from 'path';

const CIRCOM_PRIME: bigint =
  21888242871839275222246405745257275088548364400416034343698204186575808495617n;

const build_path_base = '../../../../smart-contracts/circuit_build';

const get_wasm_path = (circuit_name: string) => {
  return `smart-contracts/circuit_build/${circuit_name}_js/${circuit_name}.wasm`;
  return join(
    __dirname,
    `${build_path_base}/${circuit_name}_js/${circuit_name}.wasm`
  );
};

const get_verification_key_path = (circuit_name: string) =>
  `smart-contracts/circuit_build/${circuit_name}_verification_key.json`;
// join(__dirname, `${build_path_base}/${circuit_name}_verification_key.json`);

const get_zkey_path = (circuit_name: string) =>
  `smart-contracts/circuit_build/${circuit_name}.zkey`;
// join(__dirname, `${build_path_base}/${circuit_name}.zkey`);

let poseidon_inner: any;
let poseidon: any;
const get_poseidon = async () => {
  if (!poseidon || !poseidon_inner) {
    poseidon_inner = await buildPoseidon();
    poseidon = (inp: any) => poseidon_inner.F.toString(poseidon_inner(inp));
  }
  return poseidon;
};

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

export const hash_sk = async (sk: BigIntish) => {
  return (await get_poseidon())([sk]);
};

export const gen_ticket_hash = async (
  active: boolean,
  pk: BigIntish,
  tok_addr: BigIntish,
  amount: BigIntish,
  instr: BigIntish,
  data: [BigIntish, BigIntish],
  randomness: BigIntish
) => {
  return (await get_poseidon())([
    active ? 1 : 0,
    pk,
    tok_addr,
    amount,
    instr,
    data[0],
    data[1],
    randomness,
  ]);
};

export const gen_price_hash = async (
  batch_index: BigIntish,
  tok_in: BigIntish,
  tok_out: BigIntish,
  swap_total_in: BigIntish,
  swap_total_out: BigIntish,
) => {
  return (await get_poseidon())([
    batch_index,
    tok_in,
    tok_out,
    swap_total_in,
    swap_total_out,
  ]);
};

export const gen_commitment = async (
  ticket: BigIntish,
  randomness: BigIntish
) => {
  return (await get_poseidon())([ticket, randomness]);
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

export const compile_snark = async (witness: any, circuit_name: string) => {
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    witness,
    get_wasm_path(circuit_name),
    get_zkey_path(circuit_name)
  );

  const vKey = JSON.parse(
    readFileSync(get_verification_key_path(circuit_name)).toString()
  );

  const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);
  const call_data = await snarkjs.groth16.exportSolidityCallData(
    proof,
    publicSignals
  );
  const call_data_parsed = JSON.parse(`[${call_data}]`);

  if (res === true) {
    console.log('Verification OK');
  } else {
    throw 'Invalid proof';
  }
  proof.pi_a = call_data_parsed[0];
  proof.pi_b = call_data_parsed[1];
  proof.pi_c = call_data_parsed[2];
  return { proof, public_signals: publicSignals };
};
