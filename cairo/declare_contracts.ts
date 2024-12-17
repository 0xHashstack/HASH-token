import { Account, json, RpcProvider } from "starknet";
import fs from "fs";
import dotenv from "dotenv";

const path = __dirname + "/../.env.local";

dotenv.config({ path: path });

const sepoliaRpc = process.env.SEPOLIA_RPC;

const provider = new RpcProvider({ nodeUrl: sepoliaRpc });

const owner_private_key: any = process.env.PRIVATE_KEY as string;
const owner_account_address = process.env.ACCOUNT_ADDRESS as string;
const owner = new Account(
  provider,
  owner_account_address,
  owner_private_key,
  "1"
);

export async function get_claims_class() {
  const Sierra = json.parse(
    fs
      .readFileSync("./target/dev/cairo_claimable.contract_class.json")
      .toString("ascii")
  );
  const Casm = json.parse(
    fs
      .readFileSync(
        "./target/dev/cairo_claimable.compiled_contract_class.json"
      )
      .toString("ascii")
  );

  const declareResponse = await owner.declareIfNot({
    contract: Sierra,
    casm: Casm,
  });

  fs.appendFile(
    path,
    `\nCLAIMS_CLASS_HASH = "${declareResponse.class_hash}"`,
    function (err) {
      if (err) throw err;
    }
  );

  return declareResponse.class_hash;
}


if (require.main === module) {
  get_claims_class();}