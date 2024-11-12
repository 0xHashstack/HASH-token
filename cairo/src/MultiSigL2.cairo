#[starknet::contract]
pub mod MultiSigL2{

    use starknet::{ContractAddress,get_caller_address};
    use cairo::components::AccessRegistry::AccessRegistryComp;
    use cairo::component::SuperAdmin2Step::SuperAdminTwoStep;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::UpgradeableComponent;


    component!(path:AccessRegistryComp , storage:access_registry , event:AccessRegistryEvents);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImp<ContractState>;
    impl AccessControlInternalImpl = AccessRegistryComp::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
    AccessRegistryComp::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SuperAdminTwoStepImpl =
        SuperAdminTwoStep::SuperAdminTwoStepImpl<ContractState>;



     // Constants
    const SIGNER_WINDOW: u64 = 86400; // 24 hours in seconds
    const APPROVAL_THRESHOLD: u64 = 60; // 60% of signers must approve
 
     // Function selectors as constants
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
        params : felt252,
        proposed_at: u64,
        first_sign_at: u64,
        approvals: u64,
        state: TransactionState
    }

    #[storage]
    struct Storage {

        token_contract: ContractAddress,
        transactions: LegacyMap<u256, Transaction>,
        has_approved: LegacyMap<(u256, ContractAddress), bool>,
        transaction_exists: LegacyMap<u256, bool>,
        signer_functions: LegacyMap<felt252, bool>,
        #[substorage(v0)]
        access_registry:AccessRegistryComp::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage

    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TransactionProposed: TransactionProposed,
        TransactionApproved: TransactionApproved,
        SignatoryRevoked: SignatoryRevoked,
        TransactionExecuted: TransactionExecuted,
        TransactionExpired: TransactionExpired,
        TransactionStateChanged: TransactionStateChanged,
        #[flat]
        AccessRegistryEvents:AccessRegistryComp::Events,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionProposed {
        tx_id: felt252,
        proposer:ContractAddress,
        proposed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TransactionApproved {
        tx_id: felt252,
        signer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SignatoryRevoked {
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

    pub mod Error{
        pub const ZERO_ADDRESS:felt252 = 'CAlldata consist Zero Address';
    }

    #[constructor]
    fn constructor(ref self: ContractState,token_l2:ContractAddress, super_admin:ContractAddress){
        assert(!token_l2.is_zero() && !super_admin.is_zero(),Error::ZERO_ADDRESS);
        self.access_registry.initializer(super_admin);
        self.token_contract.write(token_l2);
    }


    // Upgradable
    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accessControl.assert_only_super_admin();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    // impl MultiSigL2Impl<
    // TContractState,
    // +Has