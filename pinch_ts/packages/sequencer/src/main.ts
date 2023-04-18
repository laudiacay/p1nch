import express, { NextFunction, Request, Response } from 'express';
//@ts-ignore
import * as cron from 'node-cron';
import * as swaggerUI from "swagger-ui-express";
import { ethers, Contract } from 'ethers';

import Redis from 'ioredis';
const redis = new Redis();

// Import TSOA
import { RegisterRoutes } from "../build/routes";
import swaggerJson from "../build/swagger.json";
import { ValidateError } from 'tsoa';

const app = express();
const port = process.env.PORT || 3000;

const provider = ethers.getDefaultProvider('goerli');

app.use(express.json());

// initializeSMTFromRedisBatches(redis).then((smt_) => {
//   smt = smt_;
// });

// Register TSAO routes
RegisterRoutes(app);

// Use error handler with TSOA
app.use(function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): Response | void {
  if (err instanceof ValidateError) {
    console.warn(`Caught Validation Error for ${req.path}:`, err.fields);
    return res.status(422).json({
      message: "Validation Failed",
      details: err?.fields,
    });
  }
  if (err instanceof Error) {
    return res.status(500).json({
      message: "Internal Server Error",
    });
  }
  next();
});

app.use(["/docs"], swaggerUI.serve, swaggerUI.setup(swaggerJson));


// Schedule cron job to run every 5 minutes
// TODO this literally drops everything if it fails
cron.schedule('*/5 * * * *', async () => {
  console.log('Running cron job');

  // Move unprocessed data to a new list and empty the original list
  await redis.rename('unprocessedData', 'oldUnprocessedData');

  // get the new batch num and redis list name
  const batchNumber = await redis.zcard('batches');
  const new_list_name = `batch_${batchNumber}`;

  // Process each item in the old batch
  const items = await redis.lrange('oldUnprocessedData', 0, -1);
  for (const itemString of items) {
    const item = JSON.parse(itemString);

    // Process item: Add to SMT, validate, etc.
    // TODO do a quick well-formedness proof check
    if (!item.wellFormedProof) {
      // TODO :)?
      console.log('dropping item: no wellformed proof', item);
      continue;
    }

    // Add item to the Sparse Merkle Tree
    // const insert_witness = await smt.insert(item.ticketKey);
    // const { proof: smt_insert_proof, public_signals: smt_insert_pub } =
    //   await compile_snark(
    //     insert_witness,
    //     configs.paths.SMT_PROCESSOR_DEPOSIT_WASM_PATH,
    //     configs.paths.SMT_PROCESSOR_DEPOSIT_ZKEY
    //   );

    // // TODO: create SNARK proof via SNARKJS

    // // check that alice authorized her funds.
    // const erc20Contract = new Contract(item.erc20ID, erc20Abi, provider);
    // const aliceAuthorized = await erc20Contract.allowance(
    //   item.alice,
    //   process.env.CONTRACT_ADDRESS
    // );
    // if (aliceAuthorized < item.amount) {
    //   console.log(
    //     "dropping item: alice didn't authorize sufficient funds",
    //     item
    //   );
    //   continue;
    // }

    // build a transaction to call our thing on chain, push the proofs, update the SMT, do transfer.
    // TODO :)

    // put the ticketkey into the new batch in redis
    // await redis.rpush(new_list_name, JSON.stringify(item.ticketKey));
  }

  // run the transactions

  // delete old unprocessed data
  await redis.del('oldUnprocessedData');

  // add the pushed ticket hashes as a batch to Redis
  await redis.rpush('batches', new_list_name);
});

// Hook for users to download a particular batch number of things that were put on chain.
app.get('/batch/:batchNumber', async (req: Request, res: Response) => {
  const batchNumber = parseInt(req.params.batchNumber, 10);

  try {
    // get the batch list name
    const batch_list_name = await redis.lindex('batches', batchNumber);

    if (!batch_list_name) {
      res.status(500).json({ message: 'batch not found' });
      return;
    }

    // get the list of ticket keys in the batch
    const ticketKeys = await redis.lrange(batch_list_name, 0, -1);

    // send the list of ticket keys back to the user
    res.json({ message: 'Batch data fetched', ticketKeys });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ message: 'Error fetching batch data' });
  }
});

const server = app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

server.on('error', console.error);
