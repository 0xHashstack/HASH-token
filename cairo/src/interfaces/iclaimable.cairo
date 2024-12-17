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
    fn create(
        ref self: TContractState,
        beneficiary: ContractAddress,
        cliff: u64,
        vesting: u64,
        amount: u256,
        tge_percentage: u64,
        ticket_type: u8
    ) -> u64;
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
    fn transfer_ownership(ref self: TContractState,new_owner:ContractAddress);
}
