import axios from 'axios';
import {
  genP2SKHWellFormed,
  gen_circom_randomness,
} from '@pinch-ts/proof-utils';
import ethers, { Contract } from 'ethers';
import { configs } from '@pinch-ts/common';

const sk: bigint = 69000420n;
const tok_addr = '0x000';

import p1nchAbi from '../../../../../smart-contracts/out/Pinch.sol/Pinch.json';
const provider = ethers.getDefaultProvider('goerli');
const p1nchcontract = new Contract(
  configs.addresses.PINCH_CONTRACT_ADDR,
  p1nchAbi.abi,
  provider
);

describe('Post and P2SKH Basic Actions', () => {
  it('Should deposit funds', async () => {
    const deposit_randomness = gen_circom_randomness();
    const dep_amount = 1000;
    // 1. Approve funds for deposit
    const { ticket_hash, proof: well_formed_proof } = await genP2SKHWellFormed({
      sk,
      randomness: deposit_randomness,
      amount: dep_amount,
      tok_addr,
    });

    // 2. Call sequencer/deposit endpoint
    const res = await axios.post(`/sequencer/deposit`, {
      well_formed_proof,
      ticket_hash,
      tok_addr,
      dep_amount,
      alice,
    });

    expect(res.status).toBe(200);
    expect(res.data).toEqual({ message: 'Hello API' });

    // 3. Check that your ticket is in the tree and that the tree matches the chain's root

    // 4. Split your deposit into two tickets

    // 4a. Check tickets membership

    // 5. Merge your deposit
    // 5a. Check ticket membership
  });
});
