import * as path from 'path';

import cron from 'node-cron';

import { CircomSMT } from '@pinch-ts/data-layer';
import { configs } from '@pinch-ts/common';
import { compile_snark, gen_price_hash } from '@pinch-ts/proof-utils';

import Redis from 'ioredis';

const redis = new Redis();

// Import your smart contract, web3, and zk proof libraries here
// ...

import { ethers, Contract, BigNumberish } from 'ethers';

import swapperAbi from '../../../smart-contracts/out/Swapper.sol/Swapper.json';
import pinchAbi from '../../../smart-contracts/out/Pinch.sol/Pinch.json';

import express = require('express');

const provider = new ethers.JsonRpcProvider(configs.endpoint.PROVIDER_ENDPOINT);
const wallet = new ethers.Wallet(configs.private_keys.BOT_SK, provider);

// pinch address const
const p1nchAddress = configs.addresses.PINCH_CONTRACT_ADDR;

// get the wallet of the swapper from the pinch contract
const pinchContract = new Contract(p1nchAddress, pinchAbi.abi, provider);

// Initialize the SMT from Redis batches
let smt: CircomSMT;

CircomSMT.new_tree_from_redis(configs.N_LEVELS, redis, "p1nchsmtree").then((smt_) => {
  smt = smt_;
});

// make a pair type
type Pair = {
    token_src: string;
    token_dest: string;
};
type PairTokenAmount = {
    token_src_amount_in: number;
    token_dest_amount_out: number;
};

type SwapData = {
    // from solidity
    batchNumber: number;
    swap_tokens: Pair[];
    swap_amounts: {[key: number]: PairTokenAmount};
}

function pairHash(pair: Pair) {
    const { token_src, token_dest } = pair;
  
    // Concatenate token_src and token_dest addresses
    const packedData = ethers.solidityPacked(['address', 'address'], [token_src, token_dest]);
  
    // Compute the keccak256 hash of the packed data
    const hash = ethers.keccak256(packedData);
  
    // Convert the hash to a BigNumber
    const hashAsBigNumber : BigNumberish = hash;
  
    return hashAsBigNumber;
  }

// TODO this is pretty bad and needs to handle these long-running calls a bit better
const runCronJob = async () => {

  const swapperAddressTxn = await pinchContract.swapper();
  const swapperAddress = await swapperAddressTxn.wait();
  const swapperContract = new Contract(swapperAddress, swapperAbi.abi, provider);
  swapperContract.connect(wallet);

  // Call the smart contract function and wait for it to execute
  const swapBatchTxn = await swapperContract.doSwap();
  await swapBatchTxn.wait();

  // Get data from the contract state
  const swapData: SwapData = await swapperContract.getSwapDataForEntry();

  // get the smt root from contract state
  //const smtRoot = await swapperContract.smtRoot();

  const updateProofs = [];
  const wellFormedProofs = [];
  const newRoots = [];
  const swapEventHashes = [];

  // Create a proof that updates the contract state in SMT
  for (let i = 0; i < swapData.swap_tokens.length; i++) {
    const pair = swapData.swap_tokens[i];
    const pair_hash = pairHash(pair);
    const { token_src_amount_in, token_dest_amount_out } = swapData.swap_amounts[pair_hash];
    // compute the poseidon of the ticket
    const ticketHash = await gen_price_hash(swapData.batchNumber,
        pair.token_src,
        pair.token_dest,
        token_src_amount_in,
        token_dest_amount_out
        );
    // prove well-formedness- witness is the ticket plus the hash of the ticket together in a struct
    const swapWellFormedWitness = {
        'batch_index': swapData.batchNumber,
        'tok_in': pair.token_src,
        'tok_out': pair.token_dest,
        'swap_total_in': token_src_amount_in,
        'swap_total_out': token_dest_amount_out,
        'out': ticketHash,
    }
    const { proof: swapdata_wellformed_proof, public_signals: swapdata_wellformed_pub } =
    await compile_snark(
      swapWellFormedWitness,
      configs.circuits.WELL_FORMED_SWAP_EVENT,
    ); 
    // add to the smt
    const smt_update_witness = await smt.insert(ticketHash);
    // TODO see how we got smtRoot from chain earlier...? bot and sequencer have different roots.....!!!
    const smt_new_root = smt.get_root();
    const { proof: smt_update_proof, public_signals: smt_update_pub } =
    await compile_snark(
      smt_update_witness,
      configs.circuits.SMT_PROCESSOR,
    );

    updateProofs.push({smt_update_proof, smt_update_pub});
    newRoots.push(smt_new_root);
    swapEventHashes.push(ticketHash);
    wellFormedProofs.push({swapdata_wellformed_proof, swapdata_wellformed_pub});
  }

  // Submit the zk proof to the blockchain
  const updateRootTxn = await swapperContract.updateRoot(
    updateProofs,
    wellFormedProofs,
    newRoots,
    swapEventHashes,
  );
  await updateRootTxn.wait();
};

// Schedule the cron job to run every 5 minutes
cron.schedule('*/5 * * * *', async () => {
  try {
    await runCronJob();
    console.log('Cron job executed successfully');
  } catch (error) {
    console.error('Error executing cron job:', error);
  }
});

// why is it running a webserver! great question.
const app = express();
const port = process.env.PORT || 3333;
const server = app.listen(port, () => {
  console.log(`Listening at http://localhost:${port}/api`);
});
server.on('error', console.error);
