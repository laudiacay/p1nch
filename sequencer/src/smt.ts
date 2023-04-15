//@ts-ignore
import { newMemEmptyTrie, buildBabyjub } from 'circomlibjs';

// make a function that constructs the tree from redis batches
import Redis from 'ioredis';
type BigIntish = bigint | string | number;

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

  public get_root(): BigIntish {
    return this._smt.root;
  }

  private async insert_from_redis(redis: Redis) {
    // Fetch all the batches from Redis
    const batchSize = await redis.zcard('ticket_batches');
    const batchData = await redis.zrange('ticket_batches', 0, batchSize - 1);
    console.log('batchsize', batchSize);

    const proms_nested: Promise<void>[][] = batchData.map((ticket_batch_str) =>
      (JSON.parse(ticket_batch_str) as any[]).map(
        (ticket_hash: any) => this._smt.insert(ticket_hash, 0) as Promise<void> // We always set the value to 1
      )
    );
    // Wait for all promises to finish
    await Promise.all(proms_nested.flat());
  }

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
      newValue: this._smt.F.toObject(0),
    };
  }

  // See Circom's test: https://github.com/iden3/circomlib/blob/master/test/smtverifier.js, for details
  public async find(inp_key: BigIntish, inclusion = true) {
    const res: TreeFindRes = await this._smt.find(inp_key);
    const siblings = res.siblings;
    for (let i = 0; i < siblings.length; i++)
      siblings[i] = this._smt.F.toObject(siblings[i]);

    // Pad siblings path until we reach depth
    while (siblings.length < this.n_levels) siblings.push(0);
    res.key = inp_key;
    res.siblings = siblings;
    const tree_find = res;
    if (tree_find.found !== inclusion) return null;
    return {
      enabled: 1,
      fnc: inclusion ? 0 : 1,
      root: this._smt.F.toObject(this._smt.root),
      siblings: tree_find.siblings,
      oldKey: tree_find.isOld0
        ? 0
        : this._smt.F.toObject(tree_find.notFoundKey),
      oldValue: tree_find.isOld0
        ? 0
        : this._smt.F.toObject(tree_find.notFoundValue),
      isOld0: tree_find.isOld0 ? 1 : 0,
      key: this._smt.toObject(tree_find.key),
      value: 0,
    };
  }
}
