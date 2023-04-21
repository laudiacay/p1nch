import { Contract, ethers } from 'ethers';
import {
  Body,
  Controller,
  Get,
  Path,
  Post,
  Query,
  Res,
  Route,
  SuccessResponse,
  TsoaResponse,
} from 'tsoa';
import {
  sequencerDeposit,
  sequencerMerge,
  sequencerSplit,
  sequencerWithdraw,
} from '../services/contract_services';

type BigIntTsoaSerial = string;
// TODO:

export interface GrothPoof {
  pi_a: BigIntTsoaSerial[];
  pi_b: BigIntTsoaSerial[][];
  pi_c: BigIntTsoaSerial[];
  protocol: 'groth16';
  curve: 'bn128';
}
type Proof = GrothPoof;

// types for the data we expect to receive
export interface DepositData {
  well_formed_proof: Proof;
  ticket_hash: BigIntTsoaSerial;
  token: string;
  amount: BigIntTsoaSerial;
  token_sender: string;
}

export interface WithdrawalData {
  well_formed_deactivator_proof: Proof;
  new_deactivator_ticket_hash: BigIntTsoaSerial;
  old_ticket_hash_commitment: BigIntTsoaSerial;
  old_ticket_commitment_inclusion_proof: Proof;
  prior_root: BigIntTsoaSerial;
  token: string;
  amount: BigIntTsoaSerial;
  recipient: string;
}

export interface MergeData {
  well_formed_deactivator_for_p2skh_1: Proof;
  well_formed_deactivator_for_p2skh_2: Proof;
  old_p2skh_ticket_commitment_1: BigIntTsoaSerial;
  old_p2skh_ticket_commitment_2: BigIntTsoaSerial;
  old_p2skh_deactivator_ticket_1: BigIntTsoaSerial;
  old_p2skh_deactivator_ticket_2: BigIntTsoaSerial;
  well_formed_new_p2skh_ticket_proof: BigIntTsoaSerial;
  new_p2skh_ticket: BigIntTsoaSerial;
}

export interface SplitData {
  well_formed_deactivator_for_p2skh: Proof;
  old_p2skh_ticket_commitment: BigIntTsoaSerial;
  old_p2skh_deactivator_ticket: BigIntTsoaSerial;
  well_formed_new_p2skh_tickets_proof: Proof;
  new_p2skh_ticket_1: BigIntTsoaSerial;
  new_p2skh_ticket_2: BigIntTsoaSerial;
}

@Route('sequencer')
export class ContractController extends Controller {
  @SuccessResponse('200', 'Deposited Successfully')
  @Post('deposit')
  public async deposit(
    @Body() data: DepositData,
    @Res() illFormedResponse: TsoaResponse<500, { message: string }>,
    @Res() success: TsoaResponse<200, { message: string }>
  ): Promise<string> {
    return await sequencerDeposit(illFormedResponse, success, data);
  }

  @Post('withdraw')
  public async withdraw(
    @Body() data: WithdrawalData,
    @Res() illFormedResponse: TsoaResponse<500, { message: string }>,
    @Res() success: TsoaResponse<200, { message: string }>
  ): Promise<string> {
    return await sequencerWithdraw(illFormedResponse, success, data);
  }

  @Post('merge')
  public async merge(
    @Body() data: MergeData,
    @Res() illFormedResponse: TsoaResponse<500, { message: string }>,
    @Res() success: TsoaResponse<200, { message: string }>
  ): Promise<string> {
    return sequencerMerge(illFormedResponse, success, data);
  }

  @Post('split')
  public async split(
    @Body() data: SplitData,
    @Res() illFormedResponse: TsoaResponse<500, { message: string }>,
    @Res() success: TsoaResponse<200, { message: string }>
  ): Promise<string> {
    return sequencerSplit(illFormedResponse, success, data);
  }
}
