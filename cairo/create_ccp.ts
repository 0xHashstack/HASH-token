import fs from 'fs';
import {
    Account,
    Contract,
    constants,
    CallData,
    RpcProvider,
    json,num
} from "starknet";
import dotenv from "dotenv";

const path = __dirname + "/.env.local";

dotenv.config({ path: path });

const sepoliaRpc = process.env.SEPOLIA_RPC as string;

const provider = new RpcProvider({ nodeUrl: sepoliaRpc });


const owner_private_key: any = process.env.PRIVATE_KEY as string;
const owner_account_address = process.env.ACCOUNT_ADDRESS as string;
const owner = new Account(
  provider,
  owner_account_address,
  owner_private_key
);

// Define the contract ABI - replace with your actual function ABI
const contractABI = [
        {
          "name": "Claimable",
          "type": "impl",
          "interface_name": "cairo::claimable::IClaimable"
        },
        {
          "name": "core::integer::u256",
          "type": "struct",
          "members": [
            {
              "name": "low",
              "type": "core::integer::u128"
            },
            {
              "name": "high",
              "type": "core::integer::u128"
            }
          ]
        },
        {
          "name": "core::bool",
          "type": "enum",
          "variants": [
            {
              "name": "False",
              "type": "()"
            },
            {
              "name": "True",
              "type": "()"
            }
          ]
        },
        {
          "name": "cairo::claimable::Ticket",
          "type": "struct",
          "members": [
            {
              "name": "cliff",
              "type": "core::integer::u64"
            },
            {
              "name": "vesting",
              "type": "core::integer::u64"
            },
            {
              "name": "amount",
              "type": "core::integer::u256"
            },
            {
              "name": "claimed",
              "type": "core::integer::u256"
            },
            {
              "name": "balance",
              "type": "core::integer::u256"
            },
            {
              "name": "created_at",
              "type": "core::integer::u64"
            },
            {
              "name": "last_claimed_at",
              "type": "core::integer::u64"
            },
            {
              "name": "tge_percentage",
              "type": "core::integer::u64"
            },
            {
              "name": "beneficiary",
              "type": "core::starknet::contract_address::ContractAddress"
            },
            {
              "name": "ticket_type",
              "type": "core::integer::u8"
            },
            {
              "name": "revoked",
              "type": "core::bool"
            }
          ]
        },
        {
          "name": "cairo::claimable::IClaimable",
          "type": "interface",
          "items": [
            {
              "name": "upgrade_class_hash",
              "type": "function",
              "inputs": [
                {
                  "name": "new_class_hash",
                  "type": "core::starknet::class_hash::ClassHash"
                }
              ],
              "outputs": [],
              "state_mutability": "external"
            },
            {
              "name": "batch_create",
              "type": "function",
              "inputs": [
                {
                  "name": "beneficiaries",
                  "type": "core::array::Array::<core::starknet::contract_address::ContractAddress>"
                },
                {
                  "name": "cliff",
                  "type": "core::integer::u64"
                },
                {
                  "name": "vesting",
                  "type": "core::integer::u64"
                },
                {
                  "name": "amounts",
                  "type": "core::array::Array::<core::integer::u256>"
                },
                {
                  "name": "tge_percentage",
                  "type": "core::integer::u64"
                },
                {
                  "name": "ticket_type",
                  "type": "core::integer::u8"
                }
              ],
              "outputs": [],
              "state_mutability": "external"
            },
            {
              "name": "batch_create_same_amount",
              "type": "function",
              "inputs": [
                {
                  "name": "beneficiaries",
                  "type": "core::array::Array::<core::starknet::contract_address::ContractAddress>"
                },
                {
                  "name": "cliff",
                  "type": "core::integer::u64"
                },
                {
                  "name": "vesting",
                  "type": "core::integer::u64"
                },
                {
                  "name": "amount",
                  "type": "core::integer::u256"
                },
                {
                  "name": "tge_percentage",
                  "type": "core::integer::u64"
                },
                {
                  "name": "ticket_type",
                  "type": "core::integer::u8"
                }
              ],
              "outputs": [],
              "state_mutability": "external"
            },
            {
              "name": "claim_ticket",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                },
                {
                  "name": "recipient",
                  "type": "core::starknet::contract_address::ContractAddress"
                }
              ],
              "outputs": [
                {
                  "type": "core::bool"
                }
              ],
              "state_mutability": "external"
            },
            {
              "name": "has_cliffed",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                }
              ],
              "outputs": [
                {
                  "type": "core::bool"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "unlocked",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                }
              ],
              "outputs": [
                {
                  "type": "core::integer::u256"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "available",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                }
              ],
              "outputs": [
                {
                  "type": "core::integer::u256"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "view_ticket",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                }
              ],
              "outputs": [
                {
                  "type": "cairo::claimable::Ticket"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "my_beneficiary_tickets",
              "type": "function",
              "inputs": [
                {
                  "name": "beneficiary",
                  "type": "core::starknet::contract_address::ContractAddress"
                }
              ],
              "outputs": [
                {
                  "type": "core::array::Array::<core::integer::u64>"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "transfer_hash_token",
              "type": "function",
              "inputs": [
                {
                  "name": "to",
                  "type": "core::starknet::contract_address::ContractAddress"
                },
                {
                  "name": "amount",
                  "type": "core::integer::u256"
                }
              ],
              "outputs": [],
              "state_mutability": "external"
            },
            {
              "name": "revoke",
              "type": "function",
              "inputs": [
                {
                  "name": "id",
                  "type": "core::integer::u64"
                }
              ],
              "outputs": [
                {
                  "type": "core::bool"
                }
              ],
              "state_mutability": "external"
            },
            {
              "name": "token",
              "type": "function",
              "inputs": [],
              "outputs": [
                {
                  "type": "core::starknet::contract_address::ContractAddress"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "claimable_owner",
              "type": "function",
              "inputs": [],
              "outputs": [
                {
                  "type": "core::starknet::contract_address::ContractAddress"
                }
              ],
              "state_mutability": "view"
            },
            {
              "name": "transfer_ownership",
              "type": "function",
              "inputs": [
                {
                  "name": "new_owner",
                  "type": "core::starknet::contract_address::ContractAddress"
                }
              ],
              "outputs": [],
              "state_mutability": "external"
            }
          ]
        },
        {
          "name": "constructor",
          "type": "constructor",
          "inputs": [
            {
              "name": "token",
              "type": "core::starknet::contract_address::ContractAddress"
            },
            {
              "name": "owner_",
              "type": "core::starknet::contract_address::ContractAddress"
            }
          ]
        },
        {
          "kind": "struct",
          "name": "cairo::claimable::Claimable::TicketCreated",
          "type": "event",
          "members": [
            {
              "kind": "key",
              "name": "id",
              "type": "core::integer::u64"
            },
            {
              "kind": "data",
              "name": "amount",
              "type": "core::integer::u256"
            },
            {
              "kind": "data",
              "name": "tge_percentage",
              "type": "core::integer::u64"
            },
            {
              "kind": "data",
              "name": "ticket_type",
              "type": "core::integer::u8"
            }
          ]
        },
        {
          "kind": "struct",
          "name": "cairo::claimable::Claimable::Claimed",
          "type": "event",
          "members": [
            {
              "kind": "key",
              "name": "id",
              "type": "core::integer::u64"
            },
            {
              "kind": "data",
              "name": "amount",
              "type": "core::integer::u256"
            },
            {
              "kind": "data",
              "name": "claimer",
              "type": "core::starknet::contract_address::ContractAddress"
            }
          ]
        },
        {
          "kind": "struct",
          "name": "cairo::claimable::Claimable::Revoked",
          "type": "event",
          "members": [
            {
              "kind": "key",
              "name": "id",
              "type": "core::integer::u64"
            }
          ]
        },
        {
          "kind": "struct",
          "name": "openzeppelin_upgrades::upgradeable::UpgradeableComponent::Upgraded",
          "type": "event",
          "members": [
            {
              "kind": "data",
              "name": "class_hash",
              "type": "core::starknet::class_hash::ClassHash"
            }
          ]
        },
        {
          "kind": "enum",
          "name": "openzeppelin_upgrades::upgradeable::UpgradeableComponent::Event",
          "type": "event",
          "variants": [
            {
              "kind": "nested",
              "name": "Upgraded",
              "type": "openzeppelin_upgrades::upgradeable::UpgradeableComponent::Upgraded"
            }
          ]
        },
        {
          "kind": "enum",
          "name": "openzeppelin_security::reentrancyguard::ReentrancyGuardComponent::Event",
          "type": "event",
          "variants": []
        },
        {
          "kind": "enum",
          "name": "openzeppelin_introspection::src5::SRC5Component::Event",
          "type": "event",
          "variants": []
        },
        {
          "kind": "enum",
          "name": "cairo::claimable::Claimable::Event",
          "type": "event",
          "variants": [
            {
              "kind": "nested",
              "name": "TicketCreated",
              "type": "cairo::claimable::Claimable::TicketCreated"
            },
            {
              "kind": "nested",
              "name": "Claimed",
              "type": "cairo::claimable::Claimable::Claimed"
            },
            {
              "kind": "nested",
              "name": "Revoked",
              "type": "cairo::claimable::Claimable::Revoked"
            },
            {
              "kind": "flat",
              "name": "UpgradeableEvent",
              "type": "openzeppelin_upgrades::upgradeable::UpgradeableComponent::Event"
            },
            {
              "kind": "flat",
              "name": "ReentracnyGuardEvent",
              "type": "openzeppelin_security::reentrancyguard::ReentrancyGuardComponent::Event"
            },
            {
              "kind": "flat",
              "name": "SRC5Event",
              "type": "openzeppelin_introspection::src5::SRC5Component::Event"
            }
          ]
        }
];

// const claims_contract =process.env.CLAIMS_CONTRACT_ADDRESS as string;
const token_address = '0x02e8f2e80fab8239b234c125ee1a68d522718e1d698c214ac85d1f48407349c9'


// // Interface for the input JSON structure
interface AirdropEntry {
    Address: string;
}

// // Interface for the return type
interface ProcessedData {
    addresses: string[];
}

function processData(): ProcessedData | null {
    try {
        // Read the JSON file
        const rawData: Buffer = fs.readFileSync('../Provisions/CCP_output.json');
        const data: AirdropEntry[] = JSON.parse(rawData.toString());

        // Create arrays for addresses and allocations
        const addresses: string[] = data.map(item => item.Address);
        
        // Multiply allocations by 10^18 and handle as BigInt to prevent precision loss
        const allocations: string[] = data.map(item => {
            // Convert to string to handle decimal places properly
            
            // Split into integer and decimal parts
            const [integerPart, decimalPart = ''] = allocationStr.split('.');
            
            // Pad or truncate decimal part to 18 places
            const paddedDecimal: string = decimalPart.padEnd(18, '0').slice(0, 18);
            
            // Combine parts and convert to BigInt
            const fullNumber: bigint = BigInt(integerPart + paddedDecimal);
            
            return fullNumber.toString(); // Convert back to string for easier handling
        });

        // Log the results
        // console.log('Addresses:', addresses);
        // console.log('Allocations (multiplied by 10^18):', allocations);

        // Return the arrays for further processing
        return {
            addresses
        };

    } catch (error) {
        console.error('Error processing file:', error);
        return null;
    }
}

async function createBatchAirdropTransaction() {
    try {
        // Get processed data
        const data = processData();
        if (!data) {
            throw new Error("Failed to process data");
        }

           const { addresses } = data;

            const contractInstance = new Contract(contractABI, token_address, provider);
            contractInstance.connect(owner);

          const amount = 25000 * 10**18;

            // Prepare and execute transaction
            try {
                const tx = await contractInstance.transfer(
                    addresses,
                    amount
                );

                console.log(` transaction hash:`, tx.transaction_hash);

                // Wait for transaction confirmation
                await provider.waitForTransaction(tx.transaction_hash);


            } catch (error) {
                console.error(`Error processing batch`, error);
                // Continue with next batch instead of stopping completely

            }
        }
    catch (error) {
        console.error("Error in batch processing:", error);
        throw error;
    }
}

// Execute the function
createBatchAirdropTransaction().catch(console.error);

export { createBatchAirdropTransaction };