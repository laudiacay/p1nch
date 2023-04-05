import express, { Request, Response } from "express";
import Redis from "ioredis";
//@ts-ignore
import * as cron from "node-cron";
import { ethers, Contract } from "ethers";
import erc20Abi from "./erc20Abi.json";

import { CircomSMT } from "./smt";
import { configs } from "./configs";
import { compile_snark } from "./snark_utils";

const app = express();
const port = process.env.PORT || 3000;
const redis = new Redis();

const provider = ethers.getDefaultProvider("goerli");

app.use(express.json());

// Initialize the SMT from Redis batches
let smt: CircomSMT;

CircomSMT.new_tree_from_redis(configs.N_LEVELS, redis).then((smt_) => {
  smt = smt_;
});

// initializeSMTFromRedisBatches(redis).then((smt_) => {
//   smt = smt_;
// });

// Users submit zk proofs to /sequencer
app.post("/sequencer", async (req: Request, res: Response) => {
  const data = req.body;

  // Perform initial format check and add data to Redis
  try {
    // check that all the right fields are present: ticketKey, erc20ID, amount, wellFormedProof
    if (
      !data.ticketKey ||
      !data.erc20ID ||
      !data.amount ||
      !data.wellFormedProof
    ) {
      res
        .status(500)
        .json({ message: "missing required fields... check the api spec" });
      return;
    }

    // check the wellformedproof is a valid proof
    // TODO

    // check that the ticketKey is not in the SMT currently
    // TODO: note that if the ticketKey goes into this batch twice, the second time, it'll fail.
    //       and we will not detect that failure here, because we're checking whether it's in the SMT :)
    //       what's the desired behavior?
    if ((await smt.find(data.ticketKey, false)) === null) {
      res.status(500).json({ message: "ticketKey already in SMT" });
    }

    // Append the posted JSON data as a string to the Redis list
    await redis.rpush("unprocessedData", JSON.stringify(data));

    // Send a response back to the client
    res.json({
      message: "Data received and added to Redis. it will be on chain soon :)",
      receivedData: data,
    });
  } catch (error) {
    console.error("Error:", error);
    res.status(500).json({ message: "Error adding data to Redis" });
  }
});

// Schedule cron job to run every 5 minutes
// TODO this literally drops everything if it fails
cron.schedule("*/5 * * * *", async () => {
  console.log("Running cron job");

  // Move unprocessed data to a new list and empty the original list
  await redis.rename("unprocessedData", "oldUnprocessedData");

  // get the new batch num and redis list name
  const batchNumber = await redis.zcard('batches');
  const new_list_name = `batch_${batchNumber}`;

  // Process each item in the old batch
  const items = await redis.lrange("oldUnprocessedData", 0, -1);
  for (const itemString of items) {
    const item = JSON.parse(itemString);

    // Process item: Add to SMT, validate, etc.
    // TODO do a quick well-formedness proof check
    if (!item.wellFormedProof) {
      // TODO :)?
      console.log("dropping item: no wellformed proof", item);
      continue;
    }

    // Add item to the Sparse Merkle Tree
    const insert_witness = await smt.insert(item.ticketKey);
    const { proof: smt_insert_proof, public_signals: smt_insert_pub } =
      await compile_snark(
        insert_witness,
        configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
        configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
      );

    // TODO: create SNARK proof via SNARKJS

    // check that alice authorized her funds.
    const erc20Contract = new Contract(item.erc20ID, erc20Abi, provider);
    const aliceAuthorized = await erc20Contract.allowance(
      item.alice,
      process.env.CONTRACT_ADDRESS
    );
    if (aliceAuthorized < item.amount) {
      console.log(
        "dropping item: alice didn't authorize sufficient funds",
        item
      );
      continue;
    }

    // build a transaction to call our thing on chain, push the proofs, update the SMT, do transfer.
    // TODO :)

    // put the ticketkey into the new batch in redis
    await redis.rpush(new_list_name, JSON.stringify(item.ticketKey));
  }

  // add the pushed ticket hashes as a batch to Redis
  await redis.rpush("batches", new_list_name);
});

// Hook for users to download a particular batch number of things that were put on chain.
app.get("/batch/:batchNumber", async (req: Request, res: Response) => {
  const batchNumber = parseInt(req.params.batchNumber, 10);

  try {
    // get the batch list name
    const batch_list_name = await redis.lindex("batches", batchNumber);

    if (!batch_list_name) {
      res.status(500).json({ message: "batch not found" });
      return;
    }

    // get the list of ticket keys in the batch
    const ticketKeys = await redis.lrange(batch_list_name, 0, -1);

    // send the list of ticket keys back to the user
    res.json({ message: "Batch data fetched", ticketKeys });
  } catch (error) {
    console.error("Error:", error);
    res.status(500).json({ message: "Error fetching batch data" });
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
