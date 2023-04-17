export type BigIntish = bigint | string | number;

// TODO: testnet configs vs mainnet configs
export const configs = {
  N_LEVELS: 254,
  paths: {
    VALID_DEPOSIT_WASM_PATH: 'TODO:',
    VALID_DEPOSIT_ZKEY: 'TODO:',

    SMT_PROCESSOR_DEPOSIT_WASM_PATH: 'TODO:',
    SMT_PROCESSOR_DEPOSIT_ZKEY: 'TODO:',

    SMT_VERIFIER_DEPOSIT_WASM_PATH: 'TODO:',
    SMT_VERIFIER_DEPOSIT_ZKEY: 'TODO:',
  },
  addresses: {
    ONE_INCH_ROUTER_ADDR: "TODO:",
    PINCH_CONTRACT_ADDR: "TODO:",
  }
};