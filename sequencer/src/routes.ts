import { Router, Request, Response } from 'express';
export const defaultRoute = Router();

import { CircomSMT } from './smt';
import { configs } from './configs';
import { compile_snark } from './snark_utils';

import Redis from 'ioredis';

const redis = new Redis();
import { ethers, Contract } from 'ethers';
import erc20Abi from './erc20Abi.json';
import p1nchAbi from '../../smart-contracts/out/Pinch.sol/Pinch.json';
const provider = ethers.getDefaultProvider('goerli');

// pinch address const
const p1nchAddress = '0xAAAAAAAABABBBBABABABABABBABABBABABAB';

// Initialize the SMT from Redis batches
let smt: CircomSMT;

CircomSMT.new_tree_from_redis(configs.N_LEVELS, redis).then((smt_) => {
  smt = smt_;
});

// types for the data we expect to receive
interface DepositData {
  message_type: 'deposit';
  well_formed_proof: string;
  ticket_hash: string;
  token: string;
  amount: string;
  alice: string;
}

interface WithdrawalData {}

// Users
defaultRoute.post('/sequencer/deposit', async (req: Request, res: Response) => {
  const data = req.body;

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
  if (
    !data.well_formed_proof ||
    !data.ticket_hash ||
    !data.token ||
    !data.amount ||
    !data.alice
  ) {
    res.status(500).json({
      message: 'missing required fields... check the api spec',
    });
    return;
  }

  // check that the ticketKey is not in the SMT currently
  if ((await smt.find(data.ticket_hash, false)) === null) {
    res.status(500).json({ message: 'ticketKey already in SMT' });
  }

  // check that alice authorized her funds.
  const erc20Contract = new Contract(data.token, erc20Abi, provider);
  const aliceAuthorized = await erc20Contract.allowance(
    data.alice,
    process.env.CONTRACT_ADDRESS
  );
  if (aliceAuthorized < data.amount) {
    console.log("dropping item: alice didn't authorize sufficient funds", data);
    res.status(500).json({ message: 'alice did not authorize sufficient funds' });
    return;
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
    data.alice
  );
  const receipt = await tx.wait();
  console.log('receipt', receipt);
  res.status(200).json({ message: 'success' });
});

defaultRoute.post(
  '/sequencer/withdraw',
  async (req: Request, res: Response) => {
    // contract args- those with a + before, we compute them.
    /*
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_proof,
        uint256 new_deactivator_ticket_hash,
        SMTMembershipVerifier.Proof calldata oldTokenCommitmentInclusionProof,
        uint256 old_ticket_hash_commitment,
        uint256 prior_root,
        +SMTMembershipVerifier.Proof calldata smt_update_proof,
        +uint256 new_root,
        IERC20 token,
        uint256 amount,
        address recipient
        */
    const data = req.body;
    // check for fields. need well_formed_deactivator_proof, new_deactivator_ticket_hash, old_ticket_hash_commitment, prior_root, token, amount, recipient
    if (
      !data.well_formed_deactivator_proof ||
      !data.new_deactivator_ticket_hash ||
      !data.old_ticket_hash_commitment ||
      !data.old_ticket_commitment_inclusion_proof ||
      !data.prior_root ||
      !data.token ||
      !data.amount ||
      !data.recipient
    ) {
      res.status(500).json({
        message: 'missing required fields... check the api spec',
      });
      return;
    }
    // check that the ticketKey is not in the SMT currently
    if ((await smt.find(data.new_deactivator_ticket_hash, false)) === null) {
      res.status(500).json({ message: 'ticketKey already in SMT' });
    }
    // TODO validate the snarks provided before you put them on chain. god forbid.
    const smt_update_witness = await smt.insert(
      data.new_deactivator_ticket_hash
    );
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
    res.status(200).json({ message: 'success' });
  }
);
defaultRoute.post('/sequencer/merge', async (req: Request, res: Response) => {
  const data = req.body;

  // contract args- those with a + before, we compute them.
  /*
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_1,
        WellFormedTicketVerifier.Proof calldata well_formed_deactivator_for_p2skh_2,
        +SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof_1,
        +SMTMembershipVerifier.Proof calldata smt_update_deactivator_proof_2,
        uint256 old_p2skh_ticket_commitment_1,
        uint256 old_p2skh_ticket_commitment_2,
        uint256 old_p2skh_deactivator_ticket_1,
        uint256 old_p2skh_deactivator_ticket_2,
        +uint256 smt_root_after_adding_deactivator_1,
        +uint256 smt_root_after_adding_deactivator_2,
        WellFormedTicketVerifier.Proof calldata well_formed_new_p2skh_ticket_proof,
        +SMTMembershipVerifier.Proof calldata smt_update_new_p2skh_ticket_proof,
        uint256 new_p2skh_ticket,
        +uint256 smt_root_after_adding_new_p2skh_ticket
        */
  if (
    !data.well_formed_deactivator_for_p2skh_1 ||
    !data.well_formed_deactivator_for_p2skh_2 ||
    !data.old_p2skh_ticket_commitment_1 ||
    !data.old_p2skh_ticket_commitment_2 ||
    !data.old_p2skh_deactivator_ticket_1 ||
    !data.old_p2skh_deactivator_ticket_2 ||
    !data.well_formed_new_p2skh_ticket_proof ||
    !data.new_p2skh_ticket
  ) {
    res.status(500).json({
      message: 'missing required fields... check the api spec',
    });
  }
  // check that the various tickets are not in the SMT currently
  if ((await smt.find(data.old_p2skh_deactivator_ticket_1, false)) === null) {
    res.status(500).json({ message: 'ticketKey already in SMT' });
  }
  if ((await smt.find(data.old_p2skh_deactivator_ticket_2, false)) === null) {
    res.status(500).json({ message: 'ticketKey already in SMT' });
  }
  if ((await smt.find(data.new_p2skh_ticket, false)) === null) {
    res.status(500).json({ message: 'ticketKey already in SMT' });
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
  res.status(200).json({ message: 'success' });
});

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
  // call contract
  const p1nchcontract = new ethers.Contract(
    configs.p1nch_contract_address,
    configs.p1nch_contract_abi,
    wallet
  );
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

//     case 'swap': {
//       break;
//     }
//     case 'closeSwap': {
//       break;
//     }
//     default: {
//       res.status(500).json({ message: 'invalid message type' });
//     }
//   }
// } catch (error) {
//   console.error('Error:', error);
// }

//   // Append the posted JSON data as a string to the Redis list
//   await redis.rpush("unprocessedData", JSON.stringify(data));

//   // Send a response back to the client
//   res.json({
//     message: "Data received and added to Redis. it will be on chain soon :)",
//     receivedData: data,
//   });
// } catch (error) {
//   console.error("Error:", error);
//   res.status(500).json({ message: "Error adding data to Redis" });
// }
// });
