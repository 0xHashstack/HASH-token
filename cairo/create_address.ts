import { RpcProvider, hash, num } from 'starknet';
import dotenv from "dotenv";
import fs from "fs";
import path from "path";

dotenv.config({ path: __dirname + "/.env.local" });

const sepoliaRpc = process.env.SEPOLIA_RPC as string;
const provider = new RpcProvider({ nodeUrl: sepoliaRpc });

// Define the contract addresses and their respective `fromBlock` values
const contracts = [
  { name: "rSTRK", fromBlock: 574615, address: '0x7514ee6fa12f300ce293c60d60ecce0704314defdb137301dae78a7e5abbdd7' },
  { name: "rDAI", fromBlock: 268070, address: '0x19c981ec23aa9cbac1cc1eb7f92cf09ea2816db9cbd932e251c86a2e8fb725f' },
  { name: "rUSDC", fromBlock: 268067, address: '0x3bcecd40212e9b91d92bbe25bb3643ad93f0d230d93237c675f46fac5187e8c' },
  { name: "rUSDT", fromBlock: 268064, address: '0x5fa6cc6185eab4b0264a4134e2d4e74be11205351c7c91196cb27d5d97f8d21' },
  { name: "rETH", fromBlock: 268062, address: '0x436d8d078de345c11493bd91512eae60cd2713e05bcaa0bb9f0cba90358c6e' },
  { name: "rBTC", fromBlock: 268060, address: '0x1320a9910e78afc18be65e4080b51ecc0ee5c0a8b6cc7ef4e685e02b50e57ef' }
];

const outputFilePath = path.join(__dirname, "events_data.json");

async function fetchEventsForContract(contractName: string, fromBlock: number, address: string, existingData: Set<string>) {
  try {
    const keyFilter = [
      [num.toHex(hash.starknetKeccak('EventPanic')), '0x9149d2123147c5f43d258257fef0b7b969db78269369ebcf5ebb9eef8592f2']
    ];

    const toBlock = 1037689; // Define a fixed end block
    const chunkSize = 100;
    let continuationToken: string | null = null;

    do {
      const eventsResponse = await provider.getEvents({
        address,
        from_block: { block_number: fromBlock },
        to_block: { block_number: toBlock },
        keys: keyFilter,
        chunk_size: chunkSize,
        continuation_token: continuationToken || undefined, // Ensure it is either string or undefined
      });

      continuationToken = eventsResponse.continuation_token ?? null; // Explicitly handle null or undefined

      for (const event of eventsResponse.events) {
        const data = event.data;

        if (BigInt(data[0]) === BigInt('0x1b862c518939339b950d0d21a3d4cc8ead102d6270850ac8544636e558fab68')) {
          // Check if data[1] is already in the set, add if not
          if (!existingData.has(data[1])) {
            console.log(`[${contractName}] Appending new value: ${data[1]}`);
            existingData.add(data[1]);
          } else {
            console.log(`[${contractName}] Duplicate value skipped: ${data[1]}`);
          }
        }
      }
      console.log(`[${contractName}] Processed chunk. Continuation token: ${continuationToken}`);
    } while (continuationToken); // Continue while there are more events
  } catch (error) {
    console.error(`[${contractName}] Error fetching events:`, error);
  }
}

async function fetchAllContractsEvents() {
  // Ensure the JSON file exists or initialize it with an empty array
  if (!fs.existsSync(outputFilePath)) {
    fs.writeFileSync(outputFilePath, JSON.stringify([]));
  }

  // Load existing data from the JSON file into a Set for deduplication
  const existingData: string[] = JSON.parse(fs.readFileSync(outputFilePath, "utf-8"));
  const uniqueData = new Set<string>(existingData);

  // Process each contract
  for (const contract of contracts) {
    console.log(`Fetching events for ${contract.name}...`);
    await fetchEventsForContract(contract.name, contract.fromBlock, contract.address, uniqueData);
  }

  // Write updated data back to the JSON file
  fs.writeFileSync(outputFilePath, JSON.stringify([...uniqueData], null, 2));
  console.log("All events data written to:", outputFilePath);
}

fetchAllContractsEvents();
