//@ts-ignore
import snarkjs from 'snarkjs';
import { readFileSync } from 'fs';
import { configs } from './configs';

export const compile_snark = async (
  witness: any,
  wasm_path: string,
  zkey_path: string
) => {
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    witness,
    wasm_path,
    zkey_path
  );

  console.log('Proof: ');
  console.log(JSON.stringify(proof, null, 1));

  const vKey = readFileSync('verification_key.json').toJSON();

  const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

  if (res === true) {
    console.log('Verification OK');
  } else {
    console.log('Invalid proof');
  }
  return { proof, public_signals: publicSignals };
};
