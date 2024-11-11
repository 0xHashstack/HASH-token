#[starknet::contract]
pub mod MultiSigL2{

    use starknet::{ContractAddress,get_caller_address};
    use cairo_starknet::components::AccessRegistry::AccessRegistryComp;


    component!(path:AccessRegistryComp , storage:access_registry , event:AccessRegistryEvents);

     // Constants
    const SIGNER_WINDOW: u64 = 86400; // 24 hours in seconds
    const FALLBACK_ADMIN_WINDOW: u64 = 259200; // 72 hours in seconds
    const APPROVAL_THRESHOLD: u64 = 60; // 60% of signers must approve
 
     // Function selectors as constants
    const MINT_SELECTOR: felt252 = selector!("add_supported_bridge(ContractAddress)");
    const BURN_SELECTOR: felt252 = selector!("remove_supported_bridge(ContractAddress)");
    const PAUSE_STATE_SELECTOR: felt252 = selector!("update_pause_state(u8)");
    const BLACKLIST_ACCOUNT_SELECTOR: felt252 = selector!("blacklist_account(ContractAddress)");
    const REMOVE_BLACKLIST_ACCOUNT_SELECTOR: felt252 = selector!("remove_blacklisted(ContractAddress)");
    const RECOVER_TOKENS_SELECTOR: felt252 = selector!("recover_tokens(ContractAddress)");

    #[derive(Copy, Drop, Serde, starknet::Store)]
    enum TransactionState {
        Pending,
        Active,
        Queued,
        Expired,
        Executed,
    }

    #[derive(Drop, Serde, starknet::Store)]
    struct Transaction {
        proposer: ContractAddress,
        selector: felt252,
        params: Array<felt252>,
        proposed_at: u64,
        first_sign_at: u64,
        approvals: u64,
        state: TransactionState,
        is_fallback_admin: bool,
    }

    #[storage]
    struct Storage {
        token_contract: ContractAddress,
        transactions: LegacyMap<u256, Transaction>,
        has_approved: LegacyMap<(u256, ContractAddress), bool>,
        transaction_exists: LegacyMap<u256, bool>,
        fallback_admin_functions: LegacyMap<felt252, bool>,
        signer_functions: LegacyMap<felt252, bool>,
        #[substorage(v0)]
        access_registry:AccessRegistryComp::Storage

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransactionProposed: TransactionProposed,
        TransactionApproved: TransactionApproved,
        TransactionRevoked: TransactionRevoked,
        TransactionExecuted: TransactionExecuted,
        TransactionExpired: TransactionExpired,
        TransactionStateChanged: TransactionStateChanged,
        #[flat]
        AccessRegistryEvents::AccessRegistryComp::Events
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionProposed {
        tx_id: felt252,
        proposer: ContractAddress,
        proposed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionApproved {
        tx_id: felt252,
        signer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionRevoked {
        tx_id: felt252,
        revoker: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionExecuted {
        tx_id: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionExpired {
        tx_id: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionStateChanged {
        tx_id: felt252,
        new_state: TransactionState,
    }

    #[constructor]
    fn constructor(ref self: ContractState,token_l2:ContractAddress, super_admin:ContractAddress, fallback_admin:ContractAddress){
        self.access_registry.initializer(super_admin,fallback_admin);
        self.token_contract.write(token_l2);
    }




 




}