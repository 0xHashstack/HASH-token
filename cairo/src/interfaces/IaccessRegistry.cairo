use starknet::ContractAddress;
#[starknet::interface]
pub trait IAccessRegistryComponent<TContractState> {
    fn add_signer(ref self: TContractState, new_signer: ContractAddress);
    fn remove_signer(ref self: TContractState, existing_owner: ContractAddress);
    fn renounce_signership(ref self: TContractState, signer: ContractAddress);
    fn is_signer(self: @TContractState, account: ContractAddress) -> bool;
    fn accept_super_adminship(ref self: TContractState);
    fn total_signer(self:@TContractState)->u64;
    fn super_admin(self: @TContractState) -> ContractAddress;
    fn pending_super_admin(self: @TContractState) -> ContractAddress;
    fn transfer_super_adminship(ref self: TContractState, new_super_admin: ContractAddress);
    fn super_admin_ownership_valid_for(self: @TContractState) -> u64;
    fn super_handover_expires_at(self: @TContractState) -> u64;
}
