import deploy_addresses from '@pinch-ts/assets/src/deploy_addresses.json';
import deploy_tok_addresses from '@pinch-ts/assets/src/deploy_token_addresses.json';
export type BigIntish = bigint | string | number;

type ENV = 'localnet' | 'mainnet' | 'testnet';

const get_config_addresses = (env: ENV) => {
  switch (env) {
    case 'localnet':
      return {
        UNISWAP_ROUTER_ADDR: '0xe592427a0aece92de3edee1f18e0157c05861564', // Mainnet router address
        PINCH_CONTRACT_ADDR: deploy_addresses.localnet.Pinch,
        TOKEN_A: deploy_tok_addresses.localnet.DummyTokenA,
        TOKEN_B: deploy_tok_addresses.localnet.DummyTokenB,
      };
    case 'mainnet':
      return;
    case 'testnet':
      return;
    default:
      throw new Error('Unknown network');
  }
};

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
  addresses: get_config_addresses('localnet'),
};
