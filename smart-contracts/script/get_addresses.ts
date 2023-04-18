import { writeFileSync } from "fs";
import deploy_data from "../broadcast/Deploy.sol/1/run-latest.json";
import deploy_toks_data from "../broadcast/DeployDummies.sol/1/run-latest.json";
import { join } from "path";

const network = process.argv[2];
const main = (network: string) => {
  switch (network) {
    case "mainnet":
      throw new Error("Not implemented");
    case "localnet":
      //  TODO: This **overwrites** the existing addresses file.
			// we need to have it not overwrite the existing file
      const addrs_entries = deploy_data.transactions
        .filter((tx: any) => tx.transactionType === "CREATE")
        .map((tx: any) => [tx.contractName, tx.contractAddress]);
      const addrs_toks_data = deploy_toks_data.transactions
        .filter((tx: any) => tx.transactionType === "CREATE")
        .map((tx: any) => [tx.contractName, tx.contractAddress]);
      const deploy_addresses = { localnet: Object.fromEntries(addrs_entries) };
      const tok_addresses = { localnet: Object.fromEntries(addrs_toks_data) };
      writeFileSync(
        join(__dirname, "../../pinch_ts/packages/assets/src/deploy_addresses.json"),
        JSON.stringify(deploy_addresses)
      );
      writeFileSync(
        join(
          __dirname,
          "../../pinch_ts/packages/assets/src/deploy_token_addresses.json"
        ),
        JSON.stringify(tok_addresses)
      );
      console.log("Done coppying over addresses");
      return;
    default:
      throw new Error("Unknown network");
  }
};

main(network);
