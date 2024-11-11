use starknet::ContractAddress;
#[starknet::interface]
pub trait IBlackListedComponent<TContractState> {
    fn blackList_account(ref self:TContractState, account:ContractAddress);
    fn remove_blackListed_account(ref self: TContractState,account: ContractAddress);
    fn is_blackListed_account(self: @TContractState) -> bool;
}