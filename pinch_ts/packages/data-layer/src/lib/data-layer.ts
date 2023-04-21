//@ts-ignore
import { newMemEmptyTrie, buildBabyjub } from 'circomlibjs';
import type { BigIntish } from '@pinch-ts/common';

// make a function that constructs the tree from redis batches
import Redis from 'ioredis';

interface TreeFindRes {
  found: boolean;
  key: BigIntish;
  siblings: BigIntish[];
  foundValue: BigIntish;
  isOld0: BigIntish;
  notFoundKey: BigIntish;
  notFoundValue: BigIntish;
}

interface TreeInsertRes extends TreeFindRes {
  oldRoot: BigIntish;
  oldKey: BigIntish;
}

interface TreeDeleteRes extends TreeFindRes {
  oldRoot: BigIntish;
  oldKey: BigIntish;
  delKey: BigIntish;
}

export type SMTInsertArgs = Awaited<ReturnType<CircomSMT['insert']>>;
export type SMTInclusionArgs = Awaited<ReturnType<CircomSMT['inclusion']>>;

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
    redis: Redis,
    tree_name: string,
  ): Promise<CircomSMT> {
    const babyjub = await buildBabyjub();
    const t = new CircomSMT(await newMemEmptyTrie(), n_levels, babyjub);
    t.insert_from_redis(redis, tree_name);
    return t;
  }

  public get_root(): BigIntish {
    return this._smt.root;
  }

  private async insert_from_redis(redis: Redis, tree_name: string) {
    // Fetch all the batches from Redis
    const batchSize = await redis.zcard('${tree_name}.ticket_batches');
    const batchData = await redis.zrange('${tree_name}.ticket_batches', 0, batchSize - 1);
    console.log('batchsize', batchSize);

    const proms_nested: Promise<void>[][] = batchData.map((ticket_batch_str) =>
      (JSON.parse(ticket_batch_str) as any[]).map(
        (ticket_hash: any) => this._smt.insert(ticket_hash, 0) as Promise<void> // We always set the value to 1
      )
    );
    // Wait for all promises to finish
    await Promise.all(proms_nested.flat());
  }

  // TODO ruh roh! you are not maintaining the redis at all
  public async insert(inp_key: BigIntish) {
    const tree_insert = await this._smt.insert(inp_key, 0);
    const siblings = tree_insert.siblings;
    for (let i = 0; i < siblings.length; i++)
      siblings[i] = this._smt.F.toObject(siblings[i]);

    // Pad siblings path until we reach depth
    while (siblings.length < this.n_levels) siblings.push(0);

    return {
      oldRoot: this._smt.F.toObject(tree_insert.oldRoot),
      siblings: siblings,
      newKey: this._smt.F.toObject(tree_insert.key),
    };
  }

  // See Circom's test: https://github.com/iden3/circomlib/blob/master/test/smtverifier.js, for details
  /**
   * Find the path to a key. If it is not in the tree, return null
   */
  public async inclusion(inp_key: BigIntish) {
    const res: TreeFindRes = await this._smt.find(inp_key);
    const siblings = res.siblings;
    for (let i = 0; i < siblings.length; i++)
      siblings[i] = this._smt.F.toObject(siblings[i]);

    // Pad siblings path until we reach depth
    while (siblings.length < this.n_levels) siblings.push(0);
    res.key = inp_key;
    res.siblings = siblings;
    const tree_find = res;
    if (!tree_find.found) return null;

    return {
      root: this._smt.F.toObject(this._smt.root),
      siblings: tree_find.siblings,
      key: BigInt(inp_key).valueOf(),
    };
  }
}
