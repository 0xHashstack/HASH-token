
#[starknet::component]
pub mod AccessRegistryComp {
    use starknet::{get_caller_address,get_block_timestamp};
    use starknet::ContractAddress;
    use cairo::interfaces::IaccessRegistry::IAccessRegistry;
    // use cairo::components::SuperAdmin2Step::SuperAdminTwoStepComp::SuperAdminTwoStepImpl;
    // use cairo::components::SuperAdmin2Step::SuperAdminTwoStepComp::InternalImpl;
    // use cairo::components::SuperAdmin2Step::SuperAdminTwoStepComp;
    use core::num::traits::Zero;
    // use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    // use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use openzeppelin_introspection::src5::SRC5Component::InternalImpl as SRC5InternalImpl;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use openzeppelin_introspection::src5::SRC5Component;

    #[storage]
    pub struct Storage {
        pub super_admin: ContractAddress,
        pub pending_admin: ContractAddress,
        pub signers: LegacyMap::<ContractAddress, bool>,
        pub handover_expires: u64,
        pub total_signer: u64,
    }

    #[event]
    #[derive(Drop,PartialEq, starknet::Event)]
    pub enum Event {
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        SignerRenounced: SignerRenounced,
        SuperOwnershipTransferred: SuperOwnershipTransferred,
        SuperOwnershipTransferStarted: SuperOwnershipTransferStarted
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SignerAdded {
        #[key]
        signer: ContractAddress
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SignerRemoved {
        #[key]
        signer: ContractAddress
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SignerRenounced {
        from: ContractAddress,
        to: ContractAddress
    }
    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SuperOwnershipTransferred {
        previous_super_admin: ContractAddress,
        new_super_admin: ContractAddress,
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SuperOwnershipTransferStarted {
        previous_super_admin: ContractAddress,
        new_super_admin: ContractAddress,
    }

    pub mod Error {
        pub const ZERO_ADDRESS: felt252 = 'Zero Address';
        pub const SuperAdminIsRestricted: felt252 = 'Super Admin Is Restricted';
        pub const Already_Signer: felt252 = 'Already a Signer';
        pub const SuperAdminCannotRemoved: felt252 = 'Super Admin Cannot Removed';
        pub const NonExistingSigner: felt252 = 'Non Existing Signer';
        pub const NOT_OWNER: felt252 = 'Caller is not super admin';
        pub const NOT_PENDING_OWNER: felt252 = 'Caller not pending super admin';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const HANDOVER_EXPIRED: felt252 = 'Super Admin Ownership expired';
    }


    #[embeddable_as(AccessRegistry)]
    impl AccessRegistyImpl<
        TContractState,+HasComponent<TContractState>,+Drop<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
    > of super::IAccessRegistry<ComponentState<TContractState>> {

        fn is_signer(self: @ComponentState<TContractState>, account: ContractAddress) -> bool {
            self.signers.read(account)
        }
        fn get_total_signer(self:@ComponentState<TContractState>)->u64{
            self.total_signer.read()
        }

        fn add_signer(ref self: ComponentState<TContractState>, new_signer: ContractAddress) {
            assert(!new_signer.is_zero(), Error::ZERO_ADDRESS);
            assert(!self.is_signer(new_signer), Error::Already_Signer);

            // let super_admin_comp = get_dep_component!(@self, SuperAdminTwoStepImpl);
            self.assert_only_super_admin();
            self.signers.write(new_signer, true);
            self.total_signer.write(self.total_signer.read() + 1);
            self.emit(SignerAdded { signer: new_signer });
        }

        fn remove_signer(
            ref self: ComponentState<TContractState>, existing_owner: ContractAddress
        ) {
            assert(!existing_owner.is_zero(), Error::ZERO_ADDRESS);
            assert(self.is_signer(existing_owner), Error::NonExistingSigner);

            let super_admin: ContractAddress = self.super_admin.read();
            assert(existing_owner != super_admin, Error::SuperAdminCannotRemoved);
            self.assert_only_super_admin();

            self.signers.write(existing_owner, false);
            self.total_signer.write(self.total_signer.read() - 1);

            self.emit(SignerRemoved { signer: existing_owner });
        }
        fn renounce_signership(ref self: ComponentState<TContractState>, signer: ContractAddress) {
            assert(!signer.is_zero(), Error::ZERO_ADDRESS); //check for zero address

            let caller: ContractAddress = get_caller_address();
            assert(self.is_signer(caller), Error::NonExistingSigner); //only be calleable by signer
            assert(
                !self.is_signer(signer), Error::Already_Signer
            ); //new signer cannot be existing signer

            let super_admin: ContractAddress = self.super_admin.read();
            assert(caller != super_admin, Error::SuperAdminCannotRemoved); //signer cannot be remove
            // check it needs to be existing owner
            self._renounce_signership(caller, signer);
        }

        fn accept_super_adminship(ref self: ComponentState<TContractState>){
            let caller: ContractAddress = get_caller_address();
            let super_admin:ContractAddress = self.super_admin.read();
            self._accept_super_adminship();
            self._renounce_signership(caller,super_admin);
        }

        fn get_super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.super_admin.read()
        }

        /// Returns the address of the pending super_admin.
        fn pending_super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.pending_admin.read()
        }

        //Returns the handover expiry of the pending super_admin
        fn super_handover_expires_at(self: @ComponentState<TContractState>) -> u64 {
            self.handover_expires.read()
        }


        /// Starts the two-step super_adminship transfer process by setting the pending super_admin.
        ///
        /// Requirements:
        ///
        /// - The caller is the contract super_admin.
        ///
        /// Emits an `OwnershipTransferStarted` event.
        fn transfer_super_adminship(
            ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
        ) {
            self.assert_only_super_admin();
            self._propose_super_admin(new_super_admin);
        }

        /// Returns the time for which handover is valid for pending super_admin.
        fn super_admin_ownership_valid_for(self: @ComponentState<TContractState>) -> u64 {
            72 * 3600
        }

    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,+Drop<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {

        /// Sets the contract's initial super_admin.
        ///
        /// This function should be called at construction time.
        fn initializer(ref self: ComponentState<TContractState>, super_admin: ContractAddress) {
            self.super_admin(super_admin);
            self.total_signer.write(1);
            self.signers.write(super_admin, true);
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IaccessRegistry::IACCESSCONTROL_ID);
        }
        
        fn _renounce_signership(
            ref self: ComponentState<TContractState>, _from: ContractAddress, _to: ContractAddress
        ) {
            self.signers.write(_from, false);
            self.signers.write(_to, true);

            self.emit(SignerRenounced { from: _from, to: _to });
        }
        /// Panics if called by any account other than the super_admin. Use this
        /// to restrict access to certain functions to the super_admin.
        fn assert_only_super_admin(self: @ComponentState<TContractState>) {
            let super_admin = self.super_admin.read();
            let caller = get_caller_address();
            assert(!caller.is_zero(), Error::ZERO_ADDRESS_CALLER);
            assert(caller == super_admin, Error::NOT_OWNER);
        }

        /// Finishes the two-step super_adminship transfer process by accepting the super_adminship.
        /// Can only be called by the pending super_admin.
        ///
        /// Requirements:
        ///
        /// - The caller is the pending super_admin.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn _accept_super_adminship(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            let pending_super_admin = self.pending_admin.read();
            let super_adminship_expires_at: u64 = self.handover_expires.read();
            assert(caller == pending_super_admin, Error::NOT_PENDING_OWNER);
            assert(get_block_timestamp() <= super_adminship_expires_at, Error::HANDOVER_EXPIRED);
            self._transfer_super_adminship(pending_super_admin);
        }

        /// Transfers super_adminship of the contract to a new address and resets
        /// the pending super_admin to the zero address.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferred` event.
        fn _transfer_super_adminship(
            ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
        ) {
            self.pending_admin.write(Zero::zero());
            self.handover_expires.write(0);

            let previous_super_admin: ContractAddress = self.super_admin.read();
            self.super_admin.write(new_super_admin);
            self
                .emit(
                    SuperOwnershipTransferred {
                        previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
                    }
                );
        }

        /// Sets a new pending super_admin.
        ///
        /// Internal function without access restriction.
        ///
        /// Emits an `OwnershipTransferStarted` event.
        fn _propose_super_admin(
            ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
        ) {
            let previous_super_admin = self.super_admin.read();
            self.pending_admin.write(new_super_admin);
            let super_adminship_expires_at = get_block_timestamp()
                + 72 * 3600;
            self.handover_expires.write(super_adminship_expires_at);
            self
                .emit(
                    SuperOwnershipTransferStarted {
                        previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
                    }
                );
            }
    }
}
