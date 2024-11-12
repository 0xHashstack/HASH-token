// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.19.0 (access/ownable/ownable.cairo)

/// # Ownable Component
///
/// The Ownable component provides a basic access control mechanism, where
/// there is an account (an fallback_admin) that can be granted exclusive access to
/// specific functions.
///
/// The initial fallback_admin can be set by using the `initializer` function in
/// construction time. This can later be changed with `transfer_fallback_adminship`.
///
/// The component also offers functionality for a two-step fallback_adminship
/// transfer where the new fallback_admin first has to accept their fallback_adminship to
/// finalize the transfer.
#[starknet::component]
pub mod FallbackAdminTwoStep {
    use core::num::traits::Zero;
    use cairo::interfaces::IfallbackAdmin2Step::IFallbackAdminTwoStep;
    // use cairo_starknet::interfaces::IsuperAdmin2Step;
    use cairo::interfaces::IfallbackAdmin2Step;

    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    #[storage]
    pub struct Storage {
        pub fallback_admin: ContractAddress,
        pub pending_admin: ContractAddress,
        pub handover_expires: u64
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        FallbackOwnershipTransferred: FallbackOwnershipTransferred,
        FallbackOwnershipTransferStarted: FallbackOwnershipTransferStarted
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct FallbackOwnershipTransferred {
        #[key]
        pub previous_fallback_admin: ContractAddress,
        #[key]
        pub new_fallback_admin: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct FallbackOwnershipTransferStarted {
        #[key]
        pub previous_fallback_admin: ContractAddress,
        #[key]
        pub new_fallback_admin: ContractAddress,
    }

    pub mod Errors {
        pub const NOT_OWNER: felt252 = 'Caller is not FB admin';
        pub const NOT_PENDING_OWNER: felt252 = 'Caller is not pending FB admin';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const ZERO_ADDRESS_OWNER: felt252 = 'New FB is the zero address';
        pub const HANDOVER_EXPIRED: felt252 = 'Super Admin Ownership expired';
    }

    /// Adds support for two step fallback_adminship transfer.
    #[embeddable_as(FallbackAdminTwoStepImpl)]
    impl FallbackAdminTwoStep<
        TContractState, +HasComponent<TContractState>
    > of IfallbackAdmin2Step::IFallbackAdminTwoStep<ComponentState<TContractState>> {
        /// Returns the address of the current fallback_admin.
        fn fallback_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.fallback_admin.read()
        }

        /// Returns the address of the pending fallback_admin.
        fn pending_fallback_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.pending_admin.read()
        }

        //Returns the handover expiry of the pending fallback_admin
        fn fallback_handover_expires_at(self: @ComponentState<TContractState>) -> u64 {
            self.handover_expires.read()
        }

        /// Finishes the two-step fallback_adminship transfer process by accepting the fallback_adminship.
        /// Can only be called by the pending fallback_admin.
        ///
        /// Requirements:
        ///
        /// - The caller is the pending fallback_admin.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn accept_fallback_adminship(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            let pending_fallback_admin = self.pending_admin.read();
            let fallback_adminship_expires_at: u64 = self.handover_expires.read();
            assert(caller == pending_fallback_admin, Errors::NOT_PENDING_OWNER);
            assert(
                get_block_timestamp() <= fallback_adminship_expires_at, Errors::HANDOVER_EXPIRED
            );
            self._transfer_fallback_adminship(pending_fallback_admin);
        }

        /// Starts the two-step fallback_adminship transfer process by setting the pending fallback_admin.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract fallback_admin.
        ///
        /// Emits an `OwnershipTransferStarted` event.
        fn transfer_fallback_adminship(
            ref self: ComponentState<TContractState>, new_fallback_admin: ContractAddress
        ) {
            self.assert_only_fallback_admin();
            self._propose_fallback_admin(new_fallback_admin);
        }

        /// Returns the time for which handover is valid for pending fallback_admin.
        fn fallback_admin_ownership_valid_for(self: @ComponentState<TContractState>) -> u64 {
            72 * 3600
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        /// Sets the contract's initial fallback_admin.
        ///
        /// This function should be called at construction time.
        fn initializer(ref self: ComponentState<TContractState>, fallback_admin: ContractAddress) {
            self._transfer_fallback_adminship(fallback_admin);
        }

        /// Panics if called by any account other than the fallback_admin. Use this
        /// to restrict access to certain functions to the fallback_admin.
        fn assert_only_fallback_admin(self: @ComponentState<TContractState>) {
            let fallback_admin = self.fallback_admin.read();
            let caller = get_caller_address();
            assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(caller == fallback_admin, Errors::NOT_OWNER);
        }

        /// Transfers fallback_adminship of the contract to a new address and resets
        /// the pending fallback_admin to the zero address.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn _transfer_fallback_adminship(
            ref self: ComponentState<TContractState>, new_fallback_admin: ContractAddress
        ) {
            self.pending_admin.write(Zero::zero());
            self.handover_expires.write(0);

            let previous_fallback_admin: ContractAddress = self.fallback_admin.read();
            self.fallback_admin.write(new_fallback_admin);
            self
                .emit(
                    FallbackOwnershipTransferred {
                        previous_fallback_admin: previous_fallback_admin,
                        new_fallback_admin: new_fallback_admin
                    }
                );
        }

        /// Sets a new pending fallback_admin.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferStarted` event.
        fn _propose_fallback_admin(
            ref self: ComponentState<TContractState>, new_fallback_admin: ContractAddress
        ) {
            let previous_fallback_admin = self.fallback_admin.read();
            self.pending_admin.write(new_fallback_admin);
            let fallback_adminship_expires_at = get_block_timestamp()
                + self.fallback_admin_ownership_valid_for();
            self.handover_expires.write(fallback_adminship_expires_at);
            self
                .emit(
                    FallbackOwnershipTransferStarted {
                        previous_fallback_admin: previous_fallback_admin,
                        new_fallback_admin: new_fallback_admin
                    }
                );
        }
    }
}
