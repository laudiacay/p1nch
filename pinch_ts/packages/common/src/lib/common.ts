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
    // so it looks like you have this swap_event_format_verifier in circom
    // and then 
   WELL_FORMED_SWAP_EVENT: 'swap_event_format_verifier',
  },
  addresses: get_config_addresses('localnet'),
  private_keys: {
    SEQUENCER_SK:
      '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a',
    BOT_SK:
      '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a',
    // TODO: use .env file!
  },
  endpoint: {
    PROVIDER_ENDPOINT: 'http://localhost:8545',
  },
};
