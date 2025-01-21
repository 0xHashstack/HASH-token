import fs from 'fs';
import {
    Account,
    Contract,
    RpcProvider,
} from "starknet";
import dotenv from "dotenv";
import path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, ".env.local") });

// Initialize provider and account
const provider = new RpcProvider({ nodeUrl: process.env.SEPOLIA_RPC });
const account = new Account(
    provider,
    process.env.ACCOUNT_ADDRESS as string,
    process.env.PRIVATE_KEY as string
);

// Token contract ABI
const tokenABI = [
    {
        "name": "transfer",
        "type": "function",
        "inputs": [
            {
                "name": "recipient",
                "type": "core::starknet::contract_address::ContractAddress"
            },
            {
                "name": "amount",
                "type": "core::integer::u256"
            }
        ],
        "outputs": [
            {
                "type": "core::bool"
            }
        ],
        "state_mutability": "external"
    }
];

async function transferTokens() {
    try {
        // Initialize contract
        const tokenContract = new Contract(
            tokenABI,
            process.env.TOKEN_ADDRESS as string,
            provider
        );
        tokenContract.connect(account);

        // Load addresses
        const rawData = fs.readFileSync('./address.json', 'utf8');
        const addresses = JSON.parse(rawData);
        console.log(`Loaded ${addresses.length} addresses`);

        // Set amount (25000 tokens)
        const amount = {
            low: "25000000000000000000000",
            high: "0"
        };

        // Process addresses
        for (let i = 0; i < addresses.length; i++) {
            const address = addresses[i];
            console.log(`\nProcessing transfer ${i + 1}/${addresses.length}`);
            console.log(`To address: ${address}`);

            try {
                // Execute transfer
                const tx = await tokenContract.transfer(
                    address,
                    amount
                );

                console.log(`Transaction hash: ${tx.transaction_hash}`);

                // Wait for transaction
                await provider.waitForTransaction(tx.transaction_hash);
                console.log(`Transfer completed`);

                // Add delay between transactions
                if (i < addresses.length - 1) {
                    console.log('Waiting 5 seconds before next transfer...');
                    await new Promise(resolve => setTimeout(resolve, 5000));
                }
            } catch (error) {
                console.error(`Error processing transfer to ${address}:`, error);
                fs.appendFileSync(
                    'failed_transfers.txt',
                    `Address ${i + 1}: ${address}\nError: ${error}\n\n`
                );

                // Wait longer if we hit an error
                console.log('Error occurred, waiting 30 seconds before continuing...');
                await new Promise(resolve => setTimeout(resolve, 30000));
            }
        }

        console.log('\nAll transfers processed');

    } catch (error) {
        console.error('Error in transfer process:', error);
        throw error;
    }
}

// Execute transfers
console.log('Starting token transfers...');
transferTokens().catch(console.error);