import { poseidon } from "circomlib";
//@ts-ignore
import { newMemEmptyTrie, buildBabyjub } from "circomlibjs";

// make a function that constructs the tree from redis batches
import Redis from "ioredis";
type BigIntish = BigInt | string | number;

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
  delKey: BigIntish
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
        (ticket_hash: any) => this._smt.insert(ticket_hash, 0) as Promise<void> // We always set the value to 1
      )
    );
    // Wait for all promises to finish
    await Promise.all(proms_nested.flat());
  }

  public async insert(inp_key: BigIntish): Promise<void> {
    await this._smt.insert(inp_key, 0);
  }
  public async delete(inp_key: BigIntish): Promise<void> {
    await this._smt.delete(inp_key, 0);
  }
  public async update(inp_key: BigIntish): Promise<void> {
    await this._smt.update(inp_key, 0);
  }
  // See Circom's test: https://github.com/iden3/circomlib/blob/master/test/smtverifier.js, for details
  public async find(inp_key: BigIntish): Promise<TreeFindRes> {
    const res: TreeFindRes = await this._smt.find(inp_key);
    let siblings = res.siblings;
    for (let i = 0; i < siblings.length; i++)
      siblings[i] = this._smt.F.toObject(siblings[i]);

    // Pad siblings path until we reach depth
    while (siblings.length < this.n_levels) siblings.push(0);
    res.key = inp_key;
    res.siblings = siblings;
    return res;
  }

  /**
   *
   * @param inclusion - true for an inclusion proof, false otherwise
   */
  public format_input_arguments_verify(
    tree_find: TreeFindRes,
    inclusion = true
  ) {
    if (tree_find.found !== inclusion)
      throw `The tree find must match inclusion`;
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

  public format_input_arguments_insert(tree_insert: TreeInsertRes) {
    return {
      fnc: [1, 0],
      oldRoot: this._smt.F.toObject(tree_insert.oldRoot),
      siblings: tree_insert.siblings,
      oldKey: tree_insert.isOld0 ? 0 : this._smt.F.toObject(tree_insert.oldKey),
      oldValue: tree_insert.isOld0 ? 0 : this._smt.F.toObject(0),
      isOld0: tree_insert.isOld0 ? 1 : 0,
      newKey: this._smt.F.toObject(tree_insert.key),
      newValue: this._smt.F.toObject(0),
    };
  }

  public format_input_arguments_delete(
    tree_delete: TreeDeleteRes,
  ) {
    return {
        fnc: [1,1],
        oldRoot: this._smt.F.toObject(tree_delete.oldRoot),
        siblings: tree_delete.siblings,
        oldKey: tree_delete.isOld0 ? 0 : this._smt.F.toObject(tree_delete.oldKey),
        oldValue: tree_delete.isOld0 ? 0 : this._smt.F.toObject(0),
        isOld0: tree_delete.isOld0 ? 1 : 0,
        newKey: this._smt.F.toObject(tree_delete.delKey),
        newValue: this._smt.F.toObject(0)
    }
  }
  
  // IDK if we need this as we never use it...
  static format_input_arguments_update(
    tree_find: TreeFindRes,
    inclusion: number
  ) {
    throw "TODO:";
  }
}
