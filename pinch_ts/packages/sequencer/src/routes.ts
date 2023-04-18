import { Router, Request, Response } from 'express';
export const defaultRoute = Router();

import { CircomSMT } from '@pinch-ts/data-layer';
import { configs } from '@pinch-ts/common';
import { compile_snark } from '@pinch-ts/proof-utils';

import Redis from 'ioredis';

const redis = new Redis();
import { ethers, Contract } from 'ethers';
import erc20Abi from './erc20Abi.json';
// TODO: fix me
import p1nchAbi from '../../../../smart-contracts/out/Pinch.sol/Pinch.json';
const provider = ethers.getDefaultProvider('goerli');
// pinch address const
const p1nchAddress = '0xAAAAAAAABABBBBABABABABABBABABBABABAB';

// Initialize the SMT from Redis batches
let smt: CircomSMT;

CircomSMT.new_tree_from_redis(configs.N_LEVELS, redis).then((smt_) => {
  smt = smt_;
});
interface WithdrawalData {}



defaultRoute.post('/sequencer/split', async (req, res) => {
  const data = req.body;
  // contract args: those with a + are computed here
  /* 
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh,
        +SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof,
        uint256 old_p2skh_ticket_commitment,
        uint256 old_p2skh_deactivator_ticket,
        +uint256 smt_root_after_adding_deactivator,
        WellFormedTicketVerifier.Proof calldata well_formed_new_p2skh_tickets_proof,
        +SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_1_proof,
        +SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_2_proof,
        uint256 new_p2skh_ticket_1,
        +uint256 smt_root_after_adding_new_p2skh_ticket_1,
        uint256 new_p2skh_ticket_2,
        +uint256 smt_root_after_adding_new_p2skh_ticket_2
        */
  // validate the data
  if (
    !data.well_formed_deactivator_for_p2skh ||
    !data.old_p2skh_ticket_commitment ||
    !data.old_p2skh_deactivator_ticket ||
    !data.well_formed_new_p2skh_tickets_proof ||
    !data.new_p2skh_ticket_1 ||
    !data.new_p2skh_ticket_2
  ) {
    res.status(500).json({ message: 'invalid data' });
  }
  // TODO validate provided proofs!
  // update smt with deactivator
  const smt_root_after_adding_deactivator = await smt.insert(
    data.old_p2skh_deactivator_ticket
  );
  // prove update
  const {
    proof: smt_update_deactivator_proof,
    public_signals: smt_update_deactivator_pub,
  } = await compile_snark(
    smt_root_after_adding_deactivator,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );
  // update smt with new p2skh tickets
  const smt_root_after_adding_new_p2skh_ticket_1 = await smt.insert(
    data.new_p2skh_ticket_1
  );
  // prove update
  const {
    proof: smt_update_new_p2skh_ticket_1_proof,
    public_signals: smt_update_new_p2skh_ticket_1_pub,
  } = await compile_snark(
    smt_root_after_adding_new_p2skh_ticket_1,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );
  const smt_root_after_adding_new_p2skh_ticket_2 = await smt.insert(
    data.new_p2skh_ticket_2
  );
  // prove update
  const {
    proof: smt_update_new_p2skh_ticket_2_proof,
    public_signals: smt_update_new_p2skh_ticket_2_pub,
  } = await compile_snark(
    smt_root_after_adding_new_p2skh_ticket_2,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );

  const p1nchcontract = new Contract(p1nchAddress, p1nchAbi.abi, provider);
  const tx = await p1nchcontract.split(
    data.well_formed_deactivator_for_p2skh,
    [smt_update_deactivator_proof, smt_update_deactivator_pub],
    data.old_p2skh_ticket_commitment,
    data.old_p2skh_deactivator_ticket,
    smt_root_after_adding_deactivator,
    data.well_formed_new_p2skh_tickets_proof,
    [smt_update_new_p2skh_ticket_1_proof, smt_update_new_p2skh_ticket_1_pub],
    data.new_p2skh_ticket_1,
    smt_root_after_adding_new_p2skh_ticket_1,
    [smt_update_new_p2skh_ticket_2_proof, smt_update_new_p2skh_ticket_2_pub],
    data.new_p2skh_ticket_2,
    smt_root_after_adding_new_p2skh_ticket_2
  );
  const receipt = await tx.wait();
  console.log('receipt', receipt);
  res.status(200).json({ message: 'success' });
});
