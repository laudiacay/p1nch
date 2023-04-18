import erc20Abi from '../erc20Abi.json';
import p1nchAbi from '../../../../smart-contracts/out/Pinch.sol/Pinch.json';
import { TsoaResponse } from 'tsoa';
import {
  DepositData,
  MergeData,
  SplitData,
  WithdrawalData,
} from '../controller/contract_controller';
import { Contract, ethers } from 'ethers';
import { CircomSMT } from '@pinch-ts/data-layer';
import Redis from 'ioredis';
import { configs } from '@pinch-ts/common';
import { compile_snark } from '@pinch-ts/proof-utils';

// Initialize the SMT from Redis batches
let smt: CircomSMT;
const provider = ethers.getDefaultProvider('goerli');
// pinch address const
const p1nchAddress = '0xAAAAAAAABABBBBABABABABABBABABBABABAB';

// TODO: not convinced about this...
const redis = new Redis();
CircomSMT.new_tree_from_redis(configs.N_LEVELS, redis).then((smt_) => {
  smt = smt_;
});

export const sequencerDeposit = async (
  illFormedResponse: TsoaResponse<500, { message: string }>,
  success: TsoaResponse<200, { message: string }>,
  data: DepositData
) => {
  // Perform initial format check and add data to Redis
  // contract args- those with a + before, we compute them.
  /*
        WellFormedTicketVerifier.Proof calldata well_formed_proof,
        uint256 ticket_hash,
        +SMTMembershipVerifier.Proof calldata smt_update_proof,
        +uint256 new_root,
        IERC20 token,
        uint256 amount,
        address alice
        */

  // check for fields. need well_formed_proof, ticket_hash, token, amount, alice

  // check that the ticketKey is not in the SMT currently
  if ((await smt.inclusion(data.ticket_hash)) !== null) {
    return illFormedResponse(500, { message: 'ticketKey already in SMT' });
  }

  // check that alice authorized her funds.
  const erc20Contract = new Contract(data.token, erc20Abi, provider);
  const sender_authorized = await erc20Contract.allowance(
    data.token_sender,
    process.env.CONTRACT_ADDRESS
  );
  if (sender_authorized < data.amount) {
    console.log("dropping item: alice didn't authorize sufficient funds", data);
    return illFormedResponse(500, {
      message: 'address sender did not authorize sufficient funds',
    });
  }

  // TODO validate the snarks provided before you put them on chain. god forbid.
  const smt_update_witness = await smt.insert(data.ticket_hash);
  const smt_new_root = smt.get_root();
  const { proof: smt_update_proof, public_signals: smt_update_pub } =
    await compile_snark(
      smt_update_witness,
      configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
      configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
    );
  const p1nchcontract = new Contract(p1nchAddress, p1nchAbi.abi, provider);
  const tx = await p1nchcontract.deposit(
    data.well_formed_proof,
    data.ticket_hash,
    [smt_update_proof, smt_update_pub],
    smt_new_root,
    data.token,
    data.amount,
    data.token_sender
  );
  const receipt = await tx.wait();
  console.log('receipt', receipt);
  return success(200, { message: 'success' });
};

export const sequencerWithdraw = async (
  illFormedResponse: TsoaResponse<500, { message: string }>,
  success: TsoaResponse<200, { message: string }>,
  data: WithdrawalData
) => {
  // check that the ticketKey is not in the SMT currently
  if ((await smt.inclusion(data.new_deactivator_ticket_hash)) !== null) {
    return illFormedResponse(500, { message: 'ticketKey already in SMT' });
  }
  // TODO validate the snarks provided before you put them on chain. god forbid.
  const smt_update_witness = await smt.insert(data.new_deactivator_ticket_hash);
  const smt_new_root = smt.get_root();
  const { proof: smt_update_proof, public_signals: smt_update_pub } =
    await compile_snark(
      smt_update_witness,
      configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
      configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
    );
  const p1nchcontract = new Contract(p1nchAddress, p1nchAbi.abi, provider);
  const tx = await p1nchcontract.withdraw(
    data.well_formed_deactivator_proof,
    data.new_deactivator_ticket_hash,
    data.old_ticket_commitment_inclusion_proof,
    data.old_ticket_hash_commitment,
    data.prior_root,
    [smt_update_proof, smt_update_pub],
    smt_new_root,
    data.token,
    data.amount,
    data.recipient
  );
  const receipt = await tx.wait();
  console.log('receipt', receipt);

  return success(200, { message: 'success' });
};

export const sequencerMerge = async (
  illFormedResponse: TsoaResponse<500, { message: string }>,
  success: TsoaResponse<200, { message: string }>,
  data: MergeData
) => {
  const check_inclusion_rets = await Promise.all([
    smt.inclusion(data.old_p2skh_deactivator_ticket_1),
    smt.inclusion(data.old_p2skh_deactivator_ticket_2),
    smt.inclusion(data.new_p2skh_ticket),
  ]);

  // Ensure that none of the tickets are already in the SMT by checking that every return is null
  if (check_inclusion_rets.every(null) === false) {
    return illFormedResponse(500, { message: 'ticketKey already in SMT' });
  }

  // TODO validate the snarks provided before you put them on chain. god forbid.

  // update the SMT
  const smt_root_after_adding_deactivator_1 = await smt.insert(
    data.old_p2skh_deactivator_ticket_1
  );
  // prove first update
  const {
    proof: smt_update_deactivator_proof_1,
    public_signals: smt_update_deactivator_pub_1,
  } = await compile_snark(
    smt_root_after_adding_deactivator_1,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );
  // update with second deactivator
  const smt_root_after_adding_deactivator_2 = await smt.insert(
    data.old_p2skh_deactivator_ticket_2
  );
  // prove second update
  const {
    proof: smt_update_deactivator_proof_2,
    public_signals: smt_update_deactivator_pub_2,
  } = await compile_snark(
    smt_root_after_adding_deactivator_2,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );
  // update with new p2skh ticket
  const smt_root_after_adding_new_p2skh_ticket = await smt.insert(
    data.new_p2skh_ticket
  );
  // prove third update
  const {
    proof: smt_update_new_p2skh_ticket_proof,
    public_signals: smt_update_new_p2skh_ticket_pub,
  } = await compile_snark(
    smt_root_after_adding_new_p2skh_ticket,
    configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
  );
  // build transaction
  const p1nchcontract = new Contract(p1nchAddress, p1nchAbi.abi, provider);
  const tx = await p1nchcontract.merge(
    data.well_formed_deactivator_for_p2skh_1,
    data.well_formed_deactivator_for_p2skh_2,
    [smt_update_deactivator_proof_1, smt_update_deactivator_pub_1],
    [smt_update_deactivator_proof_2, smt_update_deactivator_pub_2],
    data.old_p2skh_ticket_commitment_1,
    data.old_p2skh_ticket_commitment_2,
    data.old_p2skh_deactivator_ticket_1,
    data.old_p2skh_deactivator_ticket_2,
    smt_root_after_adding_deactivator_1,
    smt_root_after_adding_deactivator_2,
    data.well_formed_new_p2skh_ticket_proof,
    [smt_update_new_p2skh_ticket_proof, smt_update_new_p2skh_ticket_pub],
    data.new_p2skh_ticket,
    smt_root_after_adding_new_p2skh_ticket
  );
  const receipt = await tx.wait();
  console.log('receipt', receipt);
  return success(200, { message: 'success' });
};

export const sequencerSplit = async (
  illFormedResponse: TsoaResponse<500, { message: string }>,
  success: TsoaResponse<200, { message: string }>,
  data: SplitData
) => {
	 /****************************** TODO ******************************/
  // TODO validate provided proofs!
	// @laudiacay

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

  return success(200, { message: 'success' });
};
