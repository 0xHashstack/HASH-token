import { Account, Contract, json, RpcProvider } from "starknet";
import fs from "fs";
import dotenv from "dotenv";

const path = __dirname + "/.env.local";

dotenv.config({ path: path });

const sepoliaRpc = process.env.SEPOLIA_RPC;

const provider = new RpcProvider({ nodeUrl: sepoliaRpc });

const owner_private_key: any = process.env.PRIVATE_KEY as string;
const owner_account_address = process.env.ACCOUNT_ADDRESS as string;
const deployer = new Account(
  provider,
  owner_account_address,
  owner_private_key,
  "1"
);

const relayer_address = process.env.RELAYER_ADDRESS as string;

const claims_contract_class = process.env.CLAIMS_CLASS_HASH as string;
const owner = process.env.OWNER_ADDRESS as string;
const token = process.env.TOKEN_ADDRESS as string;

async function deploy_claims_contract(): Promise<Contract> {
  const compiledContract = await json.parse(
    fs
      .readFileSync(`./target/dev/cairo_claimable.contract_class.json`)
      .toString("ascii")
  );

  const { transaction_hash, contract_address } = await deployer.deploy({
    classHash: claims_contract_class,
    constructorCalldata: {
      token: token,
      owner_: owner
    },
  });
  const [contractAddress] = contract_address;
  await provider.waitForTransaction(transaction_hash);

  const vault_factory_contract = new Contract(
    compiledContract.abi,
    contractAddress,
    deployer
  );

  console.log(
    "✅ Claims contract contract deployed at =",
    vault_factory_contract.address
  );
  fs.appendFile(
    path,
    `\CLAIMS_CONTRACT_ADDRESS = "${contractAddress}"`,
    function (err) {
      if (err) throw err;
    }
  );
  return vault_factory_contract;
}

if (require.main === module) {
  console.log("Deploying VaultFactory...");
  deploy_claims_contract();
}