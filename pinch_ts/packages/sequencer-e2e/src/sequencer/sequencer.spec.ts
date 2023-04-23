import axios from 'axios';
import {
  compile_snark,
  // genP2SKHWellFormed,
  gen_circom_randomness,
  gen_ticket_hash,
  hash_sk,
} from '@pinch-ts/proof-utils';
import { ethers, Contract, BigNumberish } from 'ethers';
import { Api as SequencerApi } from '@pinch-ts/client-lib';
import { configs } from '@pinch-ts/common';
import tokAddress from '@pinch-ts/assets/src/deploy_token_addresses.json';
import contractAddr from '@pinch-ts/assets/src/deploy_addresses.json';
import { erc20Abi } from '@pinch-ts/assets';
// import deployAddresses from '@pinch-ts/assets/src/deploy_addresses.json';

const sk: bigint = 69000420n;
let erc20ContractA: Contract;
let erc20ContractB: Contract;
const eth_sk =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const eth_addr = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';

const tok_addr_a = tokAddress.localnet.DummyTokenA;

let wallet: ethers.Wallet;

const load_ethers = async () => {
  const provider = new ethers.JsonRpcProvider('http://localhost:8545');
  wallet = new ethers.Wallet(eth_sk, provider);
  erc20ContractA = new Contract(
    tokAddress.localnet.DummyTokenA,
    erc20Abi,
    wallet
  );

  erc20ContractB = new Contract(
    tokAddress.localnet.DummyTokenB,
    erc20Abi,
    wallet
  );
};

describe('Post and P2SKH Basic Actions', () => {
  beforeAll(async () => {
    await load_ethers();
  });

  it('Should deposit funds', async () => {
    const seqApi: SequencerApi<unknown> = new SequencerApi<unknown>({
      baseUrl: 'http://localhost:3000',
    });
    const balanceStart: BigNumberish = await erc20ContractA.balanceOf(eth_addr);
    const p2skh_rand = gen_circom_randomness();
    const amount_init_dep = 1_000;

    const pk = await hash_sk(sk);

    const item_hash = await gen_ticket_hash(
      true,
      pk,
      tok_addr_a,
      amount_init_dep,
      0,
      [0, 0],
      p2skh_rand
    );
    const { proof, public_signals } = await compile_snark(
      {
        sk,
        randomness: p2skh_rand,
        amount: amount_init_dep,
        tok_addr: tok_addr_a,
        item_hash,
      },
      configs.circuits.WELL_FORMED_P2SKH
    );
    // Approve the TX
    const tx = await erc20ContractA.approve(
      contractAddr.localnet.Pinch,
      amount_init_dep
    );
    await tx.wait();
    const resp = await seqApi.sequencer.deposit({
      well_formed_proof: proof,
      ticket_hash: public_signals[2],
      token: tok_addr_a,
      amount: public_signals[0],
      token_sender: eth_addr,
    });
    expect(resp.status).toBe(200);
    const balanceEnd: BigNumberish = await erc20ContractA.balanceOf(eth_addr);
    expect(BigInt(balanceEnd).valueOf() - BigInt(balanceStart).valueOf()).toBe(
      BigInt(amount_init_dep)
    );

    // Check your ERC20 balance

    // 1. Approve funds for deposit

    // const { ticket_hash, proof: well_formed_proof } = await genP2SKHWellFormed({
    //   sk,
    //   randomness: deposit_randomness,
    //   amount: dep_amount,
    //   tok_addr,
    // });

    // // 2. Call sequencer/deposit endpoint
    // const res = await axios.post(`/sequencer/deposit`, {
    //   well_formed_proof,
    //   ticket_hash,
    //   tok_addr,
    //   dep_amount,
    //   alice,
    // });

    // expect(res.status).toBe(200);
    // expect(res.data).toEqual({ message: 'Hello API' });

    // 3. Check that your ticket is in the tree and that the tree matches the chain's root

    // 4. Split your deposit into two tickets

    // 4a. Check tickets membership

    // 5. Merge your deposit
    // 5a. Check ticket membership
  }, 30_000);
});
