// SPDX-License-Identifier: MIT
use starknet::ContractAddress;


#[starknet::interface]
pub trait IFallbackAdminTwoStep<TState> {
    fn fallback_admin(self: @TState) -> ContractAddress;
    fn pending_fallback_admin(self: @TState) -> ContractAddress;
    fn accept_fallback_adminship(ref self: TState);
    fn transfer_fallback_adminship(ref self: TState, new_fallback_admin: ContractAddress);
    fn fallback_admin_ownership_valid_for(self:@TState)->u64;
    fn fallback_handover_expires_at(self: @TState)->u64;
}