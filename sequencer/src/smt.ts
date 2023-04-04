import { poseidon } from "circomlib";
//@ts-ignore
import { newMemEmptyTrie, buildBabyjub } from "circomlibjs";

// make a function that constructs the tree from redis batches
import Redis from "ioredis";
type BigIntish = BigInt | string | number;

interface TreeFindRes {
  found: boolean;
  siblings: BigIntish[];
  foundValue: BigIntish;
  isOld0: BigIntish;
  notFoundKey: BigIntish;
  notFoundValue: BigIntish;
}

// Adding leaves up to depth is in https://github.com/iden3/circomlib/blob/master/test/smtverifier.js
export class CircomSMT {
  private n_levels: number;
  private _smt: any;
  private _babyjub: any;
  private Fr: any;

  /**
   * Create a new smt from scratch
   */
  private constructor(_smt: any, n_levels: number, _babyjub: any) {
    this.n_levels = n_levels;
    this._smt = _smt;
    this._babyjub = _babyjub;
    this.Fr = _babyjub.F;
  }

  static async new_tree(n_levels: number): Promise<CircomSMT> {
    const babyjub = await buildBabyjub();
    return new CircomSMT(await newMemEmptyTrie(), n_levels, babyjub);
  }

  static async new_tree_from_redis(
    n_levels: number,
    redis: Redis
  ): Promise<CircomSMT> {
    const babyjub = await buildBabyjub();
    const t = new CircomSMT(await newMemEmptyTrie(), n_levels, babyjub);
    t.insert_from_redis(redis);
    return t;
  }

  private async insert_from_redis(redis: Redis) {
    // Fetch all the batches from Redis
    const batchSize = await redis.zcard("ticket_batches");
    const batchData = await redis.zrange("ticket_batches", 0, batchSize - 1);
    console.log("batchsize", batchSize);

    const proms_nested: Promise<void>[][] = batchData.map((ticket_batch_str) =>
      (JSON.parse(ticket_batch_str) as any[]).map(
        (ticket_hash: any) => this._smt.insert(ticket_hash, 1) as Promise<void> // We always set the value to 1
      )
    );
    // Wait for all promises to finish
    await Promise.all(proms_nested.flat());
  }

  public async insert(inp_key: BigIntish, inp_val: BigIntish): Promise<void> {
    await this._smt.insert(inp_key, inp_val);
  }
  public async delete(inp_key: BigIntish, inp_val: BigIntish): Promise<void> {
    await this._smt.delete(inp_key, inp_val);
  }
  public async update(inp_key: BigIntish, inp_val: BigIntish): Promise<void> {
    await this._smt.update(inp_key, inp_val);
  }
  public async find(inp_key: BigIntish): Promise<TreeFindRes> {
    const res: TreeFindRes = await this._smt.find(inp_key);
    let siblings = res.siblings;
    for (let i = 0; i < siblings.length; i++)
      siblings[i] = this._smt.F.toObject(siblings[i]);
    while (siblings.length < this.n_levels) siblings.push(0);
    res.siblings = siblings;
    return res;
  }
}
