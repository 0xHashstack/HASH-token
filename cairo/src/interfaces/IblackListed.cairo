use starknet::ContractAddress;
#[starknet::interface]
pub trait IBlackListedComponent<TContractState> {
    fn is_blacklisted_account(self: @TContractState, account: ContractAddress) -> bool;
    fn blacklist_account(ref self: TContractState, account: ContractAddress);
    fn remove_blacklisted_account(ref self: TContractState, account: ContractAddress);
}
