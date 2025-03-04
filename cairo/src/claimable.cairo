use starknet::{ContractAddress, ClassHash};

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Ticket {
    cliff: u64,
    vesting: u64,
    amount: u256,
    claimed: u256,
    balance: u256,
    created_at: u64,
    last_claimed_at: u64,
    tge_percentage: u64,
    beneficiary: ContractAddress,
    ticket_type: u8,
    revoked: bool
}

#[starknet::interface]
pub trait IClaimable<TContractState> {
    fn upgrade_class_hash(ref self: TContractState, new_class_hash: ClassHash);

    fn batch_create(
        ref self: TContractState,
        beneficiaries: Array<ContractAddress>,
        cliff: u64,
        vesting: u64,
        amounts: Array<u256>,
        tge_percentage: u64,
        ticket_type: u8,
    );

    fn batch_create_same_amount(
        ref self: TContractState,
        beneficiaries: Array<ContractAddress>,
        cliff: u64,
        vesting: u64,
        amount: u256,
        tge_percentage: u64,
        ticket_type: u8,
    );
    fn claim_ticket(ref self: TContractState, id: u64, recipient: ContractAddress) -> bool;
    fn has_cliffed(self: @TContractState, id: u64) -> bool;
    fn unlocked(self: @TContractState, id: u64) -> u256;
    fn available(self: @TContractState, id: u64) -> u256;
    fn view_ticket(self: @TContractState, id: u64) -> Ticket;
    fn my_beneficiary_tickets(self: @TContractState, beneficiary: ContractAddress) -> Array<u64>;
    fn transfer_hash_token(ref self: TContractState, to: ContractAddress, amount: u256);
    fn revoke(ref self: TContractState, id: u64) -> bool;
    fn token(self: @TContractState) -> ContractAddress;
    fn claimable_owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn transfer_tickets(ref self: TContractState, beneficiaries:Array<ContractAddress>, ticket_type: u8);
    fn claim_tokens(ref self: TContractState, receipient: ContractAddress);
}

#[starknet::contract]
pub mod Claimable {
    use super::{Ticket, IClaimable};
    use core::traits::Into;
    use starknet::{
        get_block_timestamp, get_caller_address, ContractAddress, ClassHash, contract_address_const
    };
    use cairo::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use core::num::traits::Zero;
    use openzeppelin::{
        security::reentrancyguard::ReentrancyGuardComponent,
        upgrades::upgradeable::UpgradeableComponent, introspection::src5::SRC5Component
    };
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    const SECONDS_PER_DAY: u64 = 86400;
    const PERCENTAGE_DENOMINATOR: u64 = 100;

    // Components
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancyguard, event: ReentracnyGuardEvent
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl ReentrantInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        reentrancyguard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        current_id: u64,
        hash_token: ContractAddress,
        owner: ContractAddress,
        tickets: Map<u64, Ticket>,
        beneficiary_tickets: Map<(ContractAddress, u64), u64>,
        beneficiary_ticket_count: Map<ContractAddress, u64>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TicketCreated: TicketCreated,
        Claimed: Claimed,
        Revoked: Revoked,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ReentracnyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct TicketCreated {
        #[key]
        id: u64,
        amount: u256,
        tge_percentage: u64,
        ticket_type: u8
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Claimed {
        #[key]
        id: u64,
        amount: u256,
        claimer: ContractAddress,
    }

    #[derive(Drop, Serde, starknet::Event)]
    pub struct Revoked {
        #[key]
        id: u64
    }

    mod Errors {
        pub const UNAUTHORIZED: felt252 = 'Unauthorized';
        pub const INVALID_CALLDATA: felt252 = 'Invalid inputs';
        pub const INVALID_BENEFICIARY: felt252 = 'Invalid beneficiary';
        pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
        pub const INVALID_VESTING_PERIOD: felt252 = 'Invalid vesting period';
        pub const INVALID_TGE_PERCENTAGE: felt252 = 'Invalid TGE percentage';
        pub const TICKET_REVOKED: felt252 = 'Ticket is revoked';
        pub const NOTHING_TO_CLAIM: felt252 = 'Nothing to claim';
        pub const ZERO_ADDRESS: felt252 = 'Zero address';
        pub const INVALID_TYPE: felt252 = 'Invalid ticket type';
        pub const ZERO_BALANCE: felt252 = 'Zero Balance in Claims';
    }

    #[constructor]
    fn constructor(ref self: ContractState, token: ContractAddress, owner_: ContractAddress) {
        assert(!token.is_zero() && !owner_.is_zero(), Errors::ZERO_ADDRESS);
        self.owner.write(owner_);
        self.hash_token.write(token);
    }

    #[abi(embed_v0)]
    pub impl Claimable of super::IClaimable<ContractState> {
        fn upgrade_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
            self._assert_owner();
            self.upgradeable.upgrade(new_class_hash);
        }

        fn batch_create(
            ref self: ContractState,
            beneficiaries: Array<ContractAddress>,
            cliff: u64,
            vesting: u64,
            amounts: Array<u256>,
            tge_percentage: u64,
            ticket_type: u8,
        ) {
            // self._assert_owner();
            self._validate_params(cliff, vesting, tge_percentage, ticket_type);
            assert(beneficiaries.len() == amounts.len(), Errors::INVALID_CALLDATA);
            assert(beneficiaries.len() > 0, Errors::INVALID_CALLDATA);

            let mut i = 0;
            loop {
                if i >= beneficiaries.len() {
                    break;
                }
                let beneficiary = *beneficiaries.at(i);
                let amount = *amounts.at(i);
                self._validate_basic_params(beneficiary, amount);
                self
                    ._create_single_ticket(
                        beneficiary, cliff, vesting, amount, tge_percentage, ticket_type
                    );
                i += 1;
            }
        }

        fn batch_create_same_amount(
            ref self: ContractState,
            beneficiaries: Array<ContractAddress>,
            cliff: u64,
            vesting: u64,
            amount: u256,
            tge_percentage: u64,
            ticket_type: u8,
        ) {
            self._validate_params(cliff, vesting, tge_percentage, ticket_type);
            assert(beneficiaries.len() > 0, Errors::INVALID_CALLDATA);

            let mut i = 0;
            loop {
                if i >= beneficiaries.len() {
                    break;
                }
                let beneficiary = *beneficiaries.at(i);
                self._validate_basic_params(beneficiary, amount);
                self
                    ._create_single_ticket(
                        beneficiary, cliff, vesting, amount, tge_percentage, ticket_type
                    );
                i += 1;
            }
        }

        fn has_cliffed(self: @ContractState, id: u64) -> bool {
            let ticket = self.tickets.read(id);
            if ticket.cliff == 0 {
                return true;
            }
            get_block_timestamp() >= ticket.created_at + (ticket.cliff * SECONDS_PER_DAY)
        }

        fn unlocked(self: @ContractState, id: u64) -> u256 {
            let ticket = self.tickets.read(id);
            let tge_amount = (ticket.amount * ticket.tge_percentage.into())
                / PERCENTAGE_DENOMINATOR.into();

            if !self.has_cliffed(id) {
                return tge_amount;
            }

            let remaining_amount = ticket.amount - tge_amount;
            let cliff_time = ticket.created_at + (ticket.cliff * SECONDS_PER_DAY);
            let vesting_duration = ticket.vesting * SECONDS_PER_DAY;
            let current_time = get_block_timestamp();
            let time_since_cliff = current_time - cliff_time;

            if time_since_cliff >= vesting_duration {
                return ticket.amount;
            }

            tge_amount + ((remaining_amount * time_since_cliff.into()) / vesting_duration.into())
        }

        fn available(self: @ContractState, id: u64) -> u256 {
            let ticket = self.tickets.read(id);
            if ticket.balance == 0 {
                return 0;
            }

            let unlocked_amount = self.unlocked(id);
            if unlocked_amount > ticket.claimed {
                unlocked_amount - ticket.claimed
            } else {
                0
            }
        }

        fn claim_ticket(ref self: ContractState, id: u64, recipient: ContractAddress) -> bool {
            self.reentrancyguard.start();

            let ticket = self.tickets.read(id);
            let claimable_amount = self.available(id);
            assert(!ticket.revoked, Errors::TICKET_REVOKED);
            assert(ticket.beneficiary == get_caller_address(), Errors::UNAUTHORIZED);
            self._validate_basic_params(recipient, ticket.balance);
            assert(claimable_amount != 0, Errors::NOTHING_TO_CLAIM);
            let transfer_result: bool = self._process_claim(id, claimable_amount, recipient);

            self.reentrancyguard.end();
            transfer_result
        }


        fn transfer_tickets(ref self: ContractState,beneficiaries:Array<ContractAddress>,ticket_type:u8){
            self._assert_owner();
            let count = beneficiaries.len();
            let mut i=0;
            loop{
                if i == count {
                    break;
                }
                self._transfer_tickets(*beneficiaries.at(i),ticket_type);
                i += 1;
            };   

        }

        fn claim_tokens(ref self: ContractState, receipient: ContractAddress) {
           
            self.reentrancyguard.start();
            let caller: ContractAddress = get_caller_address();
            let result: Array<u64> = self.my_beneficiary_tickets(caller);
            let length = result.len();
            assert(length > 0, Errors::NOTHING_TO_CLAIM);
            let mut claimable_amounts:Array<u256> = ArrayTrait::new();

            let mut flag:bool = false;
            let mut i:u32 = 0;

            loop {
                if i == length.try_into().unwrap() {
                    break;
                }
                let ticket_id: u64 = self.beneficiary_tickets.read((caller, i.into()));
                let available:u256 = self.available(ticket_id);
                    claimable_amounts.append(available);
                    if(available !=0 ){
                        flag = true;
                }
                i += 1;
            };

            assert(flag,Errors::NOTHING_TO_CLAIM);

            i = 0;
            loop {
                if i == length.try_into().unwrap() {
                    break;
                }
                let claimable_amount: u256 = *claimable_amounts.at(i);
                if (claimable_amount != 0) {
                    let ticket_id: u64 = self.beneficiary_tickets.read((caller, i.into()));
                    self._process_claim(ticket_id, claimable_amount, receipient);
                }
                i += 1;
            };

            self.reentrancyguard.end();
        }

        fn view_ticket(self: @ContractState, id: u64) -> Ticket {
            self.tickets.read(id)
        }

        fn my_beneficiary_tickets(
            self: @ContractState, beneficiary: ContractAddress
        ) -> Array<u64> {
            let mut result = ArrayTrait::new();
            let count = self.beneficiary_ticket_count.read(beneficiary);

            let mut i: u64 = 0;
            loop {
                if i >= count {
                    break;
                }
                result.append(self.beneficiary_tickets.read((beneficiary, i)));
                i += 1;
            };
            result
        }

        fn transfer_hash_token(ref self: ContractState, to: ContractAddress, amount: u256) {
            self.reentrancyguard.start();
            self._assert_owner();
            self._validate_basic_params(to, amount);
            IERC20Dispatcher { contract_address: self.hash_token.read() }.transfer(to, amount);
            self.reentrancyguard.end();
        }

        fn revoke(ref self: ContractState, id: u64) -> bool {
            self._assert_owner();
            let mut ticket = self.tickets.read(id);
            assert(!ticket.revoked, Errors::TICKET_REVOKED);
            assert(ticket.balance != 0, Errors::ZERO_BALANCE);

            ticket.revoked = true;
            ticket.balance = 0;
            self.tickets.write(id, ticket);
            self.emit(Event::Revoked(Revoked { id }));

            true
        }

        fn token(self: @ContractState) -> ContractAddress {
            self.hash_token.read()
        }

        fn claimable_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            assert(!new_owner.is_zero(), Errors::ZERO_ADDRESS);
            self._assert_owner();
            self.owner.write(new_owner);
        }
    }


    #[generate_trait]
    impl InternalFunctionsImpl of InternalFunctions {
        fn _validate_basic_params(
            self: @ContractState, beneficiary: ContractAddress, amount: u256,
        ) {
            assert(!beneficiary.is_zero(), Errors::INVALID_BENEFICIARY);
            assert(amount != 0, Errors::INVALID_AMOUNT);
        }

        fn _validate_params(
            self: @ContractState, cliff: u64, vesting: u64, tge_percentage: u64, ticket_type: u8
        ) {
            self._assert_owner();
            assert(ticket_type < 5, Errors::INVALID_TYPE);
            assert(tge_percentage <= PERCENTAGE_DENOMINATOR, Errors::INVALID_TGE_PERCENTAGE);
        }

        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
        }

        fn _create_single_ticket(
            ref self: ContractState,
            beneficiary: ContractAddress,
            cliff: u64,
            vesting: u64,
            amount: u256,
            tge_percentage: u64,
            ticket_type: u8
        ) -> u64 {
            let ticket_id: u64 = self.current_id.read() + 1;
            self.current_id.write(ticket_id);

            let ticket = Ticket {
                cliff,
                vesting,
                amount,
                claimed: 0,
                balance: amount,
                created_at: get_block_timestamp(),
                last_claimed_at: 0,
                tge_percentage,
                beneficiary,
                ticket_type,
                revoked: false
            };

            self.tickets.write(ticket_id, ticket);

            let current_count = self.beneficiary_ticket_count.read(beneficiary);
            self.beneficiary_tickets.write((beneficiary, current_count), ticket_id);
            self.beneficiary_ticket_count.write(beneficiary, current_count + 1);

            self
                .emit(
                    Event::TicketCreated(
                        TicketCreated { id: ticket_id, amount, tge_percentage, ticket_type }
                    )
                );

            ticket_id
        }

        fn _process_claim(
            ref self: ContractState, id: u64, claimable_amount: u256, recipient: ContractAddress
        ) -> bool {
            let mut ticket: Ticket = self.tickets.read(id);
            let hash_token: ContractAddress = self.hash_token.read();
            ticket.claimed += claimable_amount;
            ticket.balance -= claimable_amount;
            ticket.last_claimed_at = get_block_timestamp();
            self.tickets.write(id, ticket);

            self.emit(Event::Claimed(Claimed { id, amount: claimable_amount, claimer: recipient }));

            let transfer_result: bool = IERC20Dispatcher { contract_address: hash_token }
                .transfer(recipient, claimable_amount);

            transfer_result
        }


        fn _transfer_tickets(
            ref self: ContractState, beneficiary: ContractAddress, ticket_type: u8
        ) {
            let count: u64 = self.beneficiary_ticket_count.read(beneficiary);
            let mut i: u64 = 0;
            let mut new_count: u64 = 0;
            let mut first_type3_found = false;
            let mut consolidated_ticket_id = 0;
            let mut new_balance = 0;
            let mut new_amount = 0;
            let mut claimed_amount = 0;

            // First pass: Identify all type 3 tickets and sum their balances
            loop {
                if i >= count {
                    break;
                }
                let ticket_id = self.beneficiary_tickets.read((beneficiary, i));
                let mut ticket_info: Ticket = self.tickets.read(ticket_id);

                if ticket_info.ticket_type == ticket_type {
                    if !first_type3_found {
                        first_type3_found = true;
                        consolidated_ticket_id = ticket_id;
                    }
                    new_balance += ticket_info.balance;
                    claimed_amount += ticket_info.claimed;
                    new_amount += ticket_info.amount;

                    if ticket_id != consolidated_ticket_id {
                        ticket_info.beneficiary = contract_address_const::<0>();
                        ticket_info.balance = 0;
                        ticket_info.claimed = 0;
                        ticket_info.amount = 0;
                        self.tickets.write(ticket_id, ticket_info);
                    }
                } else {
                    self.beneficiary_tickets.write((beneficiary, new_count), ticket_id);
                    new_count += 1;
                }
                i += 1;
            };

            if first_type3_found {
                let mut consolidated_ticket = self.tickets.read(consolidated_ticket_id);
                consolidated_ticket.balance = new_balance;
                consolidated_ticket.claimed = claimed_amount;
                consolidated_ticket.amount = new_amount;
                self.tickets.write(consolidated_ticket_id, consolidated_ticket);

                self.beneficiary_tickets.write((beneficiary, new_count), consolidated_ticket_id);
                new_count += 1;
            }
            self.beneficiary_ticket_count.write(beneficiary, new_count);
        }
    }
}
