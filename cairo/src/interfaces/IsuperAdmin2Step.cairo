// SPDX-License-Identifier: MIT
use starknet::ContractAddress;


#[starknet::interface]
pub trait ISuperAdminTwoStep<TState> {
    fn super_admin(self: @TState) -> ContractAddress;
    fn pending_super_admin(self: @TState) -> ContractAddress;
    fn transfer_super_adminship(ref self: TState, new_super_admin: ContractAddress);
    fn super_admin_ownership_valid_for(self: @TState) -> u64;
    fn super_handover_expires_at(self: @TState) -> u64;
}
