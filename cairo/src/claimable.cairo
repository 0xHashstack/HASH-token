// use starknet::{ContractAddress, ClassHash};
// // use core::array::ArrayTrait;

// #[derive(Copy, Drop, Serde, starknet::Store)]
// pub struct Ticket {
//     cliff: u64,
//     vesting: u64,
//     amount: u256,
//     claimed: u256,
//     balance: u256,
//     created_at: u64,
//     last_claimed_at: u64,
//     tge_percentage: u64,
//     beneficiary: ContractAddress,
//     ticket_type: u8,
//     revoked: bool
// }

// #[starknet::interface]
// pub trait IClaimable<TContractState> {
//     fn upgrade_class_hash(ref self: TContractState, new_class_hash: ClassHash);

//     fn create(
//         ref self: TContractState,
//         beneficiary: ContractAddress,
//         cliff: u64,
//         vesting: u64,
//         amount: u256,
//         tge_percentage: u64,
//         ticket_type: u8
//     ) -> u64;

//     fn batch_create(
//         ref self: TContractState,
//         beneficiaries: Array<ContractAddress>,
//         cliff: u64,
//         vesting: u64,
//         amounts: Array<u256>,
//         tge_percentage: u64,
//         ticket_type: u8,
//     );

//     fn batch_create_same_amount(
//         ref self: TContractState,
//         beneficiaries: Array<ContractAddress>,
//         cliff: u64,
//         vesting: u64,
//         amount: u256,
//         tge_percentage: u64,
//         ticket_type: u8,
//     );

//     fn claim_ticket(ref self: TContractState, id: u64, recipient: ContractAddress) -> bool;
//     fn has_cliffed(self: @TContractState, id: u64) -> bool;
//     fn unlocked(self: @TContractState, id: u64) -> u256;
//     fn available(self: @TContractState, id: u64) -> u256;
//     fn view_ticket(self: @TContractState, id: u64) -> Ticket;
//     fn my_beneficiary_tickets(self: @TContractState, beneficiary: ContractAddress) -> Array<u64>;
//     fn transfer_hash_token(ref self: TContractState, to: ContractAddress, amount: u256);
//     fn revoke(ref self: TContractState, id: u64) -> bool;
// }

// #[starknet::contract]
// pub mod Claimable {
//     use super::{Ticket, IClaimable};
//     use core::traits::Into;
//     use starknet::{get_block_timestamp, get_caller_address, ContractAddress, ClassHash};

//     const SECONDS_PER_DAY: u64 = 86400;
//     const PERCENTAGE_DENOMINATOR: u64 = 100;

//     use cairo::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
//     use core::num::traits::Zero;

//     use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;
//     use openzeppelin::upgrades::upgradeable::UpgradeableComponent;
//     use openzeppelin::introspection::src5::SRC5Component;

//     component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
//     component!(
//         path: ReentrancyGuardComponent, storage: reentrancyguard, event: ReentracnyGuardEvent
//     );
//     component!(path: SRC5Component, storage: src5, event: SRC5Event);

//     impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
//     impl ReentrantInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

//     #[storage]
//     pub struct Storage {
//         #[substorage(v0)]
//         upgradeable: UpgradeableComponent::Storage,
//         #[substorage(v0)]
//         reentrancyguard: ReentrancyGuardComponent::Storage,
//         #[substorage(v0)]
//         src5: SRC5Component::Storage,
//         current_id: u64,
//         hash_token: ContractAddress,
//         owner: ContractAddress,
//         tickets: LegacyMap<u64, Ticket>,
//         beneficiary_tickets: LegacyMap<(ContractAddress, u64), u64>,
//         beneficiary_ticket_count: LegacyMap<
//             ContractAddress, u64
//         >
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub enum Event {
//         TicketCreated: TicketCreated,
//         Claimed: Claimed,
//         Revoked: Revoked,
//         #[flat]
//         UpgradeableEvent: UpgradeableComponent::Event,
//         #[flat]
//         ReentracnyGuardEvent: ReentrancyGuardComponent::Event,
//         #[flat]
//         SRC5Event: SRC5Component::Event,
//     }

//     #[derive(Drop, Serde, starknet::Event)]
//     pub struct TicketCreated {
//         #[key]
//         id: u64,
//         amount: u256,
//         tge_percentage: u64,
//         ticket_type: u8
//     }

//     #[derive(Drop, Serde, starknet::Event)]
//     pub struct Claimed {
//         #[key]
//         id: u64,
//         amount: u256,
//         claimer: ContractAddress,
//     }
//     #[derive(Drop, Serde, starknet::Event)]
//     pub struct Revoked {
//         #[key]
//         id: u64
//     }

//     pub mod Errors {
//         pub const UNAUTHORIZED: felt252 = 'Unauthorized';
//         pub const INVALID_BENEFICIARY: felt252 = 'Invalid beneficiary';
//         pub const INVALID_AMOUNT: felt252 = 'Invalid amount';
//         pub const INVALID_VESTING_PERIOD: felt252 = 'Invalid vesting period';
//         pub const INVALID_TGE_PERCENTAGE: felt252 = 'Invalid TGE percentage';
//         pub const TICKET_REVOKED: felt252 = 'Ticket revoked';
//         pub const NOTHING_TO_CLAIM: felt252 = 'Nothing to claim';
//         pub const ZERO_ADDRESS: felt252 = 'Zero address';
//     }

//     #[abi(embed_v0)]
//     pub impl Claimable of super::IClaimable<ContractState> {
//         fn upgrade_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
//             assert(get_caller_address() == self.owner.read(), 'Error');
//             self.upgradeable.upgrade(new_class_hash);
//         }

//         fn create(
//             ref self: ContractState,
//             beneficiary: ContractAddress,
//             cliff: u64,
//             vesting: u64,
//             amount: u256,
//             tge_percentage: u64,
//             ticket_type: u8
//         ) -> u64 {
//             // Access control
//             let caller = get_caller_address();
//             assert(caller == self.owner.read(), Errors::UNAUTHORIZED);

//             // Validations
//             assert(!beneficiary.is_zero(), Errors::INVALID_BENEFICIARY);
//             assert(amount != 0, Errors::INVALID_AMOUNT);
//             assert(vesting >= cliff, Errors::INVALID_VESTING_PERIOD);
//             assert(tge_percentage <= PERCENTAGE_DENOMINATOR, Errors::INVALID_TGE_PERCENTAGE);

//             // Create ticket
//             let ticket_id: u64 = self.current_id.read() + 1;
//             self.current_id.write(ticket_id);

//             let ticket = Ticket {
//                 cliff,
//                 vesting,
//                 amount,
//                 claimed: 0,
//                 balance: amount,
//                 created_at: get_block_timestamp(),
//                 last_claimed_at: 0,
//                 tge_percentage,
//                 beneficiary,
//                 ticket_type,
//                 revoked: false
//             };

//             // Use write method for LegacyMap
//             self.tickets.write(ticket_id, ticket);

//             // Update beneficiary tickets
//             let current_count = self.beneficiary_ticket_count.read(beneficiary);
//             self.beneficiary_tickets.write((beneficiary, current_count), ticket_id);
//             self.beneficiary_ticket_count.write(beneficiary, current_count + 1);

//             // Emit event
//             self
//                 .emit(
//                     Event::TicketCreated(
//                         TicketCreated { id: ticket_id, amount, tge_percentage, ticket_type }
//                     )
//                 );

//             ticket_id
//         }

//         fn batch_create(
//             ref self: ContractState,
//             beneficiaries: Array<ContractAddress>,
//             cliff: u64,
//             vesting: u64,
//             amounts: Array<u256>,
//             tge_percentage: u64,
//             ticket_type: u8,
//         ) {
//             // Access control
//             let caller = get_caller_address();
//             assert(caller == self.owner.read(), Errors::UNAUTHORIZED);

//             // Validate input arrays
//             assert(beneficiaries.len() == amounts.len(), 'Mismatched array lengths');
//             assert(beneficiaries.len() > 0, 'Empty beneficiary list');
//             assert(vesting >= cliff, Errors::INVALID_VESTING_PERIOD);
//             assert(tge_percentage <= PERCENTAGE_DENOMINATOR, Errors::INVALID_TGE_PERCENTAGE);

//             // Iterate and create tickets for each beneficiary
//             let mut i = 0;
//             loop {
//                 if i >= beneficiaries.len() {
//                     break;
//                 }

//                 let beneficiary = *beneficiaries.at(i);
//                 let amount = *amounts.at(i);

//                 // Reuse create logic with fixed irrevocable as false
//                 self.create(beneficiary, cliff, vesting, amount, tge_percentage, ticket_type);

//                 i += 1;
//             }
//         }

//         fn batch_create_same_amount(
//             ref self: ContractState,
//             beneficiaries: Array<ContractAddress>,
//             cliff: u64,
//             vesting: u64,
//             amount: u256,
//             tge_percentage: u64,
//             ticket_type: u8,
//         ) {
//             // Access control
//             let caller = get_caller_address();
//             assert(caller == self.owner.read(), Errors::UNAUTHORIZED);

//             // Validate input
//             assert(beneficiaries.len() > 0, 'Empty beneficiary list');
//             assert(amount != 0, Errors::INVALID_AMOUNT);
//             assert(vesting >= cliff, Errors::INVALID_VESTING_PERIOD);
//             assert(tge_percentage <= PERCENTAGE_DENOMINATOR, Errors::INVALID_TGE_PERCENTAGE);

//             // Iterate and create tickets for each beneficiary with same amount
//             let mut i = 0;
//             loop {
//                 if i >= beneficiaries.len() {
//                     break;
//                 }

//                 let beneficiary = *beneficiaries.at(i);

//                 // Reuse create logic with fixed irrevocable as false
//                 self.create(beneficiary, cliff, vesting, amount, tge_percentage, ticket_type);

//                 i += 1;
//             }
//         }

//         fn has_cliffed(self: @ContractState, id: u64) -> bool {
//             let ticket = self.tickets.read(id);
//             if ticket.cliff == 0 {
//                 return true;
//             }
//             let current_time = get_block_timestamp();
//             current_time >= ticket.created_at + (ticket.cliff * SECONDS_PER_DAY)
//         }

//         fn unlocked(self: @ContractState, id: u64) -> u256 {
//             let ticket = self.tickets.read(id);

//             // Calculate TGE amount
//             let tge_percentage_u256: u256 = ticket.tge_percentage.into();
//             let denominator_u256: u256 = PERCENTAGE_DENOMINATOR.into();
//             let tge_amount = (ticket.amount * tge_percentage_u256) / denominator_u256;

//             if !self.has_cliffed(id) {
//                 return tge_amount;
//             }

//             let remaining_amount = ticket.amount - tge_amount;
//             let cliff_time = ticket.created_at + (ticket.cliff * SECONDS_PER_DAY);
//             let vesting_duration = ticket.vesting * SECONDS_PER_DAY;
//             let current_time = get_block_timestamp();

//             let time_since_cliff = current_time - cliff_time;

//             if time_since_cliff >= vesting_duration {
//                 return ticket.amount;
//             }

//             let time_since_cliff_u256: u256 = time_since_cliff.into();
//             let vesting_duration_u256: u256 = vesting_duration.into();
//             let vested_amount = (remaining_amount * time_since_cliff_u256) /
//             vesting_duration_u256;

//             tge_amount + vested_amount
//         }

//         fn available(self: @ContractState, id: u64) -> u256 {
//             let ticket = self.tickets.read(id);

//             if (ticket.balance == 0) {
//                 return 0;
//             }

//             let unlocked_amount = self.unlocked(id);
//             if unlocked_amount > ticket.claimed {
//                 unlocked_amount - ticket.claimed
//             } else {
//                 0
//             }
//         }

//         fn claim_ticket(ref self: ContractState, id: u64, recipient: ContractAddress) -> bool {
//             self.reentrancyguard.start();
//             let mut ticket = self.tickets.read(id);
//             assert(!recipient.is_zero(), Errors::INVALID_BENEFICIARY);
//             assert(!ticket.revoked,'Errors');
//             assert(ticket.beneficiary == get_caller_address(), Errors::UNAUTHORIZED);
//             assert(ticket.balance != 0, Errors::NOTHING_TO_CLAIM);

//             let claimable_amount = self.available(id);
//             assert(claimable_amount != 0, Errors::NOTHING_TO_CLAIM);

//             // Process claim
//             ticket.claimed += claimable_amount;
//             ticket.balance -= claimable_amount;
//             ticket.last_claimed_at = get_block_timestamp().into();
//             self.tickets.write(id, ticket);

//             // Emit event
//             self.emit(Event::Claimed(Claimed { id, amount: claimable_amount, claimer: recipient
//             }));

//             // Transfer hash_tokens
//             let flag: bool = IERC20Dispatcher { contract_address: self.hash_token.read() }
//                 .transfer(recipient, claimable_amount);

//             self.reentrancyguard.end();

//             flag
//         }
//         fn view_ticket(self: @ContractState, id: u64) -> Ticket {
//             self.tickets.read(id)
//         }

//         fn my_beneficiary_tickets(
//             self: @ContractState, beneficiary: ContractAddress,
//         ) -> Array<u64> {
//             let mut result = ArrayTrait::new();
//             let count = self.beneficiary_ticket_count.read(beneficiary);

//             let mut i: u64 = 0;
//             loop {
//                 if i >= count {
//                     break;
//                 }
//                 let ticket_id = self.beneficiary_tickets.read((beneficiary, i));
//                 result.append(ticket_id);
//                 i += 1;
//             };

//             result
//         }

//         fn transfer_hash_token(ref self: ContractState, to: ContractAddress, amount: u256) {
//             self.reentrancyguard.start();
//             assert(get_caller_address() == self.owner.read(), Errors::UNAUTHORIZED);
//             IERC20Dispatcher { contract_address: self.hash_token.read() }.transfer(to, amount);
//             self.reentrancyguard.end();
//         }

//         // Note: For the `revoke` function, add the Revoked event instead of TicketRevoked
//         fn revoke(ref self: ContractState, id: u64) -> bool {
//             let mut ticket = self.tickets.read(id);
//             assert(get_caller_address() == self.owner.read(), 'Error');
//             assert(!ticket.revoked, 'Already revoked');
//             assert(ticket.balance != 0, 'No balance to revoke');

//             ticket.revoked = true;
//             ticket.balance = 0;

//             // Write back the modified ticket
//             self.tickets.write(id, ticket);

//             // Emit Revoked event
//             self.emit(Event::Revoked(Revoked { id }));

//             true
//         }
//     }
// }


