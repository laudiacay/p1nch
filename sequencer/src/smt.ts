import { SMT } from "@cedoor/smt"
import { poseidon } from "circomlib"
import { ChildNodes } from "@cedoor/smt/dist/types/smt"

// make a function that constructs the tree from redis batches
import Redis from 'ioredis';

export async function initializeSMTFromRedisBatches(redis: Redis): Promise<SMT> {
    const hash2 = (childNodes: ChildNodes) => poseidon(childNodes)
    const smt = new SMT(hash2, true)

    // Fetch all the batches from Redis
    const batchSize = await redis.zcard('ticket_batches');
    const batchData = await redis.zrange('ticket_batches', 0, batchSize - 1);
    console.log("batchsize", batchSize);

  for (const ticket_batch_str of batchData) {
    const ticket_batch = JSON.parse(ticket_batch_str);
    for (const ticket_hash in ticket_batch) {
        // Add item to the Sparse Merkle Tree
        smt.add(ticket_hash, BigInt(1));
    }
  }

  return smt;
}

export { SMT } from "@cedoor/smt"

