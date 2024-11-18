// // SPDX-License-Identifier: MIT
// // OpenZeppelin Contracts for Cairo v0.19.0 (access/ownable/ownable.cairo)

// /// # Ownable Component
// ///
// /// The Ownable component provides a basic access control mechanism, where
// /// there is an account (an super_admin) that can be granted exclusive access to
// /// specific functions.
// ///
// /// The initial super_admin can be set by using the `initializer` function in
// /// construction time. This can later be changed with `transfer_super_adminship`.
// ///
// /// The component also offers functionality for a two-step super_adminship
// /// transfer where the new super_admin first has to accept their super_adminship to
// /// finalize the transfer.
// #[starknet::component]
// pub mod SuperAdminTwoStepComp {
//     use core::num::traits::Zero;
//     use cairo::interfaces::IsuperAdmin2Step::ISuperAdminTwoStep;
//     // use cairo_starknet::interfaces::IsuperAdmin2Step;
//     use cairo::interfaces::IsuperAdmin2Step;

//     use starknet::ContractAddress;
//     use starknet::{get_caller_address, get_block_timestamp};

//     #[storage]
//     pub struct Storage {
//         pub super_admin: ContractAddress,
//         pub pending_admin: ContractAddress,
//         pub handover_expires: u64
//     }

//     #[event]
//     #[derive(Drop, PartialEq, starknet::Event)]
//     pub enum Event {
//         SuperOwnershipTransferred: SuperOwnershipTransferred,
//         SuperOwnershipTransferStarted: SuperOwnershipTransferStarted
//     }

//     #[derive(Drop, PartialEq, starknet::Event)]
//     pub struct SuperOwnershipTransferred {
//         #[key]
//         pub previous_super_admin: ContractAddress,
//         #[key]
//         pub new_super_admin: ContractAddress,
//     }

//     #[derive(Drop, PartialEq, starknet::Event)]
//     pub struct SuperOwnershipTransferStarted {
//         #[key]
//         pub previous_super_admin: ContractAddress,
//         #[key]
//         pub new_super_admin: ContractAddress,
//     }

//     pub mod Errors {
//         pub const NOT_OWNER: felt252 = 'Caller is not super admin';
//         pub const NOT_PENDING_OWNER: felt252 = 'Caller not pending super admin';
//         pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
//         pub const ZERO_ADDRESS_OWNER: felt252 = 'Calldata consist zero address';
//         pub const HANDOVER_EXPIRED: felt252 = 'Super Admin Ownership expired';
//     }

//     /// Adds support for two step super_adminship transfer.
//     #[embeddable_as(SuperAdminTwoStepImpl)]
//     pub impl SuperAdminTwoStep<
//         TContractState, +HasComponent<TContractState>, +Drop<TContractState>
//     > of IsuperAdmin2Step::ISuperAdminTwoStep<ComponentState<TContractState>> {
//         /// Returns the address of the current super_admin.
//         fn super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
//             self.super_admin.read()
//         }

//         /// Returns the address of the pending super_admin.
//         fn pending_super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
//             self.pending_admin.read()
//         }

//         //Returns the handover expiry of the pending super_admin
//         fn super_handover_expires_at(self: @ComponentState<TContractState>) -> u64 {
//             self.handover_expires.read()
//         }


//         /// Starts the two-step super_adminship transfer process by setting the pending super_admin.
//         ///
//         /// Requirements:
//         ///
//         /// - The caller is the contract super_admin.
//         ///
//         /// Emits an `OwnershipTransferStarted` event.
//         fn transfer_super_adminship(
//             ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
//         ) {
//             self.assert_only_super_admin();
//             self._propose_super_admin(new_super_admin);
//         }

//         /// Returns the time for which handover is valid for pending super_admin.
//         fn super_admin_ownership_valid_for(self: @ComponentState<TContractState>) -> u64 {
//             72 * 3600
//         }
//     }

//     #[generate_trait]
//     pub impl InternalImpl<
//         TContractState, +HasComponent<TContractState>
//     > of InternalTrait<TContractState> {
//         /// Sets the contract's initial super_admin.
//         ///
//         /// This function should be called at construction time.
//         fn initializer(ref self: ComponentState<TContractState>, super_admin: ContractAddress) {
//             self._transfer_super_adminship(super_admin);
//         }

//         /// Panics if called by any account other than the super_admin. Use this
//         /// to restrict access to certain functions to the super_admin.
//         fn assert_only_super_admin(self: @ComponentState<TContractState>) {
//             let super_admin = self.super_admin.read();
//             let caller = get_caller_address();
//             assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
//             assert(caller == super_admin, Errors::NOT_OWNER);
//         }

//         /// Finishes the two-step super_adminship transfer process by accepting the super_adminship.
//         /// Can only be called by the pending super_admin.
//         ///
//         /// Requirements:
//         ///
//         /// - The caller is the pending super_admin.
//         ///
//         /// Emits an `OwnershipTransferred` event.
//         fn _accept_super_adminship(ref self: ComponentState<TContractState>) {
//             let caller = get_caller_address();
//             let pending_super_admin = self.pending_admin.read();
//             let super_adminship_expires_at: u64 = self.handover_expires.read();
//             assert(caller == pending_super_admin, Errors::NOT_PENDING_OWNER);
//             assert(get_block_timestamp() <= super_adminship_expires_at, Errors::HANDOVER_EXPIRED);
//             self._transfer_super_adminship(pending_super_admin);
//         }

//         /// Transfers super_adminship of the contract to a new address and resets
//         /// the pending super_admin to the zero address.
//         ///
//         /// Internal function without access restriction.
//         ///
//         /// Emits an `OwnershipTransferred` event.
//         fn _transfer_super_adminship(
//             ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
//         ) {
//             self.pending_admin.write(Zero::zero());
//             self.handover_expires.write(0);

//             let previous_super_admin: ContractAddress = self.super_admin.read();
//             self.super_admin.write(new_super_admin);
//             self
//                 .emit(
//                     SuperOwnershipTransferred {
//                         previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
//                     }
//                 );
//         }

//         /// Sets a new pending super_admin.
//         ///
//         /// Internal function without access restriction.
//         ///
//         /// Emits an `OwnershipTransferStarted` event.
//         fn _propose_super_admin(
//             ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
//         ) {
//             let previous_super_admin = self.super_admin.read();
//             self.pending_admin.write(new_super_admin);
//             let super_adminship_expires_at = get_block_timestamp()
//                 + 72 * 3600;
//             self.handover_expires.write(super_adminship_expires_at);
//             self
//                 .emit(
//                     SuperOwnershipTransferStarted {
//                         previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
//                     }
//                 );
//         }
//     }
// }
