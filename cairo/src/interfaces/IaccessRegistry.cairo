use starknet::ContractAddress;

pub const IACCESSCONTROL_ID: felt252 =
    0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

#[starknet::interface]
pub trait IAccessRegistry<TContractState> {
    fn is_signer(self: @TContractState, account: ContractAddress) -> bool;
    fn get_total_signer(self:@TContractState)->u64;
    fn add_signer(ref self: TContractState, new_signer: ContractAddress);
    fn remove_signer(ref self: TContractState, existing_owner: ContractAddress);
    fn renounce_signership(ref self: TContractState, signer: ContractAddress);
    fn accept_super_adminship(ref self: TContractState);
    fn get_super_admin(self: @TContractState) -> ContractAddress;
    fn pending_super_admin(self: @TContractState) -> ContractAddress;
    fn transfer_super_adminship(ref self: TContractState, new_super_admin: ContractAddress);
    fn super_admin_ownership_valid_for(self: @TContractState) -> u64;
    fn super_handover_expires_at(self: @TContractState) -> u64;
}
