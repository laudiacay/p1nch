// TODO: make a rea test
// https://github.com/iden3/snarkjs
//@ts-ignore
import * as snarkjs from "snarkjs";

const main = async () => {
  var start = new Date().getTime();

  const NLevels = 254;
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    {
      oldRoot: 0,
      siblings: new Array(NLevels).fill(0),
      oldKey: 0,
      newKey: 0,
    },
    "../smart-contracts/circuit_build/smt_processor_js/smt_processor.wasm",
    "../smart-contracts/circuit_build/smt_processor.zkey"
  );
  var end = new Date().getTime();
  console.log(`TOTAL TIME ${end - start}`);
  console.log(publicSignals);
  console.log(proof);
};
main()