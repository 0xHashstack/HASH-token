use starknet::ContractAddress;

#[starknet::interface]
pub trait IHashToken<TContractState> {
    fn increase_allowance(
        ref self: TContractState, spender: ContractAddress, added_value: u256
    ) -> bool;
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool;
    fn permissioned_mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissioned_burn(ref self: TContractState, account: ContractAddress, amount: u256);
}

#[starknet::interface]
pub trait IHashTokenCamel<TContractState> {
    fn permissionedMint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissionedBurn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn increaseAllowance(
        ref self: TContractState, spender: ContractAddress, addedValue: u256
    ) -> bool;
    fn decreaseAllowance(
        ref self: TContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool;
}
