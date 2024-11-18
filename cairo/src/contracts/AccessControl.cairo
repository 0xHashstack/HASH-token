#[starknet::component]
pub mod AccessControlComponent{
    use starknet::{ContractAddress,get_block_timestamp,get_caller_address};
    use cairo::interfaces::IaccessRegistry::IAccessRegistry;
    use core::num::traits::Zero;

    #[storage]
    pub struct Storage{
        pub Super_admin: ContractAddress,
        pub Pending_admin: ContractAddress,
        pub Signers: LegacyMap::<ContractAddress,bool>,
        pub Handover_expires: u64,
        pub Total_signer: u64,
    }

    #[event]
    #[derive(Drop,PartialEq, starknet::Event)]
    pub enum Event{
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        SuperOwnershipTransferred: SuperOwnershipTransferred,
        SuperOwnershipTransferStarted: SuperOwnershipTransferStarted
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SignerAdded {
        pub signer: ContractAddress
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SignerRemoved {
        pub signer: ContractAddress
    }
    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SuperOwnershipTransferred {
        pub previous_super_admin: ContractAddress,
        pub new_super_admin: ContractAddress,
    }

    #[derive(Drop,PartialEq, starknet::Event)]
    pub struct SuperOwnershipTransferStarted {
        pub previous_super_admin: ContractAddress,
        pub new_super_admin: ContractAddress,
    }

    pub mod Errors {
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

    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>
    > of IAccessRegistry<ComponentState<TContractState>>{

        fn is_signer(self: @ComponentState<TContractState>, account: ContractAddress)-> bool{
            self.Signers.read(account)
        }
        fn get_total_signer(self:@ComponentState<TContractState>)->u64{
            self.Total_signer.read()
        }
        fn add_signer(ref self: ComponentState<TContractState>, new_signer: ContractAddress) {
            assert(!new_signer.is_zero(), Errors::ZERO_ADDRESS);
            assert(!self.Signers.read(new_signer), Errors::Already_Signer);

            // let super_admin_comp = get_dep_component!(@self, SuperAdminTwoStepImpl);
            self.assert_only_super_admin();
            self.Signers.write(new_signer, true);
            self.Total_signer.write(self.Total_signer.read() + 1);
            self.emit(SignerAdded { signer: new_signer });
        }

        fn remove_signer(
            ref self: ComponentState<TContractState>, existing_owner: ContractAddress
        ) {
            assert(!existing_owner.is_zero(), Errors::ZERO_ADDRESS);
            assert(self.Signers.read(existing_owner), Errors::NonExistingSigner);

            let super_admin: ContractAddress = self.Super_admin.read();
            assert(existing_owner != super_admin, Errors::SuperAdminCannotRemoved);
            self.assert_only_super_admin();

            self.Signers.write(existing_owner, false);
            self.Total_signer.write(self.Total_signer.read() - 1);

            self.emit(SignerRemoved { signer: existing_owner });
        }
        fn renounce_signership(ref self: ComponentState<TContractState>, signer: ContractAddress) {
            assert(!signer.is_zero(), Errors::ZERO_ADDRESS); //check for zero address

            let caller: ContractAddress = get_caller_address();
            assert(self.Signers.read(caller), Errors::NonExistingSigner); //only be calleable by signer
            assert(
                !self.Signers.read(signer), Errors::Already_Signer
            ); //new signer cannot be existing signer

            let super_admin: ContractAddress = self.Super_admin.read();
            assert(caller != super_admin, Errors::SuperAdminCannotRemoved); //signer cannot be remove
            // check it needs to be existing owner
            self._renounce_signership(caller, signer);
        }

        fn accept_super_adminship(ref self: ComponentState<TContractState>){
            let caller: ContractAddress = get_caller_address();
            let super_admin:ContractAddress = self.Super_admin.read();
            self._accept_super_adminship();
            self._renounce_signership(caller,super_admin);
        }
        fn get_super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Super_admin.read()
        }

        /// Returns the address of the pending super_admin.
        fn pending_super_admin(self: @ComponentState<TContractState>) -> ContractAddress {
            self.Pending_admin.read()
        }

        //Returns the handover expiry of the pending super_admin
        fn super_handover_expires_at(self: @ComponentState<TContractState>) -> u64 {
            self.Handover_expires.read()
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
            TContractState,
            +HasComponent<TContractState>,
            +Drop<TContractState>
        > of InternalTrait<TContractState> {

            fn initializer(ref self: ComponentState<TContractState>, super_admin: ContractAddress) {
                self.Super_admin.write(super_admin);
                self.Total_signer.write(1);
                self.Signers.write(super_admin, true);
            }

            fn _renounce_signership(
                ref self: ComponentState<TContractState>, _from: ContractAddress, _to: ContractAddress
            ) {
                self.Signers.write(_from, false);
                self.Signers.write(_to, true);
    
                // self.emit(SignerRenounced { from: _from, to: _to });
            }
            fn assert_only_super_admin(self: @ComponentState<TContractState>) {
                let super_admin = self.Super_admin.read();
                let caller = get_caller_address();
                assert(!caller.is_zero(), Errors::ZERO_ADDRESS_CALLER);
                assert(caller == super_admin, Errors::NOT_OWNER);
            }

            fn _accept_super_adminship(ref self: ComponentState<TContractState>) {
                let caller = get_caller_address();
                let pending_super_admin = self.Pending_admin.read();
                let super_adminship_expires_at: u64 = self.Handover_expires.read();
                assert(caller == pending_super_admin, Errors::NOT_PENDING_OWNER);
                assert(get_block_timestamp() <= super_adminship_expires_at, Errors::HANDOVER_EXPIRED);
                // self._transfer_super_adminship(pending_super_admin);
            }

            fn _transfer_super_adminship(
                ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
            ) {
                self.Pending_admin.write(Zero::zero());
                self.Handover_expires.write(0);
    
                let previous_super_admin: ContractAddress = self.Super_admin.read();
                self.Super_admin.write(new_super_admin);
                self
                    .emit(
                        SuperOwnershipTransferred {
                            previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
                        }
                    );
            }
            fn _propose_super_admin(
                ref self: ComponentState<TContractState>, new_super_admin: ContractAddress
            ) {
                let previous_super_admin = self.Super_admin.read();
                self.Pending_admin.write(new_super_admin);
                let super_adminship_expires_at = get_block_timestamp()
                    + 72 * 3600;
                self.Handover_expires.write(super_adminship_expires_at);
                self
                    .emit(
                        SuperOwnershipTransferStarted {
                            previous_super_admin: previous_super_admin, new_super_admin: new_super_admin
                        }
                    );
                }

        }



    




}