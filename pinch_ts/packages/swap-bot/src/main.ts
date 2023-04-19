import * as path from 'path';

import cron from 'node-cron';

import { CircomSMT } from '@pinch-ts/data-layer';
import { configs } from '@pinch-ts/common';
import { compile_snark, gen_ticket_hash } from '@pinch-ts/proof-utils';

import Redis from 'ioredis';

const redis = new Redis();

// Import your smart contract, web3, and zk proof libraries here
// ...

import { ethers, Contract } from 'ethers';
import swapperAbi from '../../../../smart-contracts/out/Swapper.sol/Swapper.json';
import express = require('express');

const provider = ethers.getDefaultProvider('goerli');
const swapperAddress = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const swapperContract = new Contract(swapperAddress, swapperAbi.abi, provider);

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
type Account = {
    address: string;
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
    const packedData = ethers.utils.solidityPack(['address', 'address'], [token_src, token_dest]);
  
    // Compute the keccak256 hash of the packed data
    const hash = ethers.utils.keccak256(packedData);
  
    // Convert the hash to a BigNumber
    const hashAsBigNumber = ethers.BigNumber.from(hash);
  
    return hashAsBigNumber;
  }

// TODO this is pretty bad and needs to handle these long-running calls a bit better
const runCronJob = async () => {

  // Call the smart contract function and wait for it to execute
  const swapBatchTxn = await swapperContract.doSwap();
  await swapBatchTxn.wait();

  // Get data from the contract state
  const swapData: SwapData = await swapperContract.getSwapDataForEntry();

  // get the smt root from contract state
  const smtRoot = await swapperContract.smtRoot();

  let updateProofs = [];
  let wellFormedProofs = [];
  let newRoots = [];
  let swapEventHashes = [];

  // Create a proof that updates the contract state in SMT
  for (let i = 0; i < swapData.swap_tokens.length; i++) {
    const pair = swapData.swap_tokens[i];
    const pair_hash = pairHash(pair);
    const { token_src_amount_in, token_dest_amount_out } = swapData.swap_amounts[pair_hash];
    const ticket = {
        'batch_index': swapData.batchNumber,
        'tok_in': pair.token_src,
        'tok_out': pair.token_dest,
        'swap_total_in': token_src_amount_in,
        'swap_total_out': token_dest_amount_out,
    }
    // compute the poseidon of the ticket
    const ticketHash = await gen_ticket_hash(ticket);
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
      configs.circuits.???,
    ); 
    // add to the smt
    const smt_update_witness = await smt.insert(ticketHash);
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
