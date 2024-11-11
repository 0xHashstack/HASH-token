use starknet::ContractAddress;
#[starknet::interface]
pub trait IAccessRegistryComponent<TContractState> {
    fn add_signer(ref self:TContractState, new_signer:ContractAddress);
    fn remove_signer(ref self: TContractState,existing_owner: ContractAddress);
    fn renounce_signership(ref self: TContractState,signer: ContractAddress);
    fn is_signer(self :@TContractState,account:ContractAddress)->bool;
    fn accept_super_adminship(ref self:TContractState);
}