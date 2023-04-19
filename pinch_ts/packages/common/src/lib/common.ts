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
  circuits: {
    SMT_PROCESSOR: 'smt_processor',
    SMT_VERIFIER: 'comm_memb',
    WELL_FORMED_P2SKH: 'p2skh_well_formed',
  },
  addresses: get_config_addresses('localnet'),
};
