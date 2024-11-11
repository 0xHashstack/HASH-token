#[starknet::component]
pub mod AccessRegistryComp{
    use starknet::{ContractAddress,get_caller_address};
    use cairo::interfaces::IaccessRegistry::IAccessRegistryComponent;
    use cairo::components::utils::FallbackAdmin2Step::FallbackAdminTwoStep;
    use cairo::components::utils::SuperAdmin2Step::SuperAdminTwoStep;


    #[storage]
    struct Storage{
        total_signers:u256,
        signers:LegacyMap::<ContractAddress,bool>,
    }

    #[event]
    #[derive(Drop, starknet::event)]
    enum Event{
        SignerAdded: SignerAdded,
        SignerRemoved: SignerRemoved,
        SignerRenounced: SignerRenounced
    } 

    #[derive(Drop, starknet::Event)]
    pub struct SignerAdded{
        #[key]
        new_signer:ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct SignerRemoved{
        #[key]
        removed_signer: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    pub struct SignerRenounced{
        #[key]
        from:ContractAddress,
        #[key]
        to:ContractAddress
    }

    pub mod Error{
        pub const ZERO_ADDRESS:felt252 = 'Zero Address';
        pub const SuperAdminIsRestricted:felt252='Super Admin Is Restricted';
        pub const Already_Signer:felt252='Already a Signer';
        pub const SuperAdminCannotRemoved:felt252='Super Admin Cannot Removed';
        pub const NonExistingSigner:felt252='Non Existing Signer';
      
    }



    #[embeddable_as(AccessRegistry)]
    impl AccessRegistyImpl<
    TContractState, 
    +HasComponent<TContractState>,
    impl SuperAdminTwoStep:SuperAdminTwoStep::HasComponent<TContractState>,
    impl FallbackAdminTwoStep:FallbackAdminTwoStep::HasComponent<TContractState>
    > of  IAccessRegistryComponent<ComponentState<TContractState>>{

        fn is_signer(self:@ComponentState<TContractState>,account:ContractAddress)->bool{
            self.signers.read(account)
        }

        fn add_signer(ref self: ComponentState<TContractState>, new_signer:ContractAddress){

            assert(!new_signer.is_zero(), Error::ZERO_ADDRESS);
            asser(!self.is_signer(new_signer),Error::Already_Signer);

            let super_admin_comp = get_dep_component!(@self,SuperAdminTwoStep);
            super_admin_comp.assert_only_super_admin();
            self.signers.write(new_signer,true);
            self.total_signers.write(self.total_signers.read()+1);
            self.emit(
                SignerAdded{
                    new_signer:existing_owner
            });

        }

        fn remove_signer(ref self: ComponentState<TContractState>,existing_owner:ContractAddress){
            
            assert(!existing_owner.is_zero(), Error::ZERO_ADDRESS);            
            asser(self.is_signer(existing_owner),Error::Not_A_Signer);

            let super_admin_comp = get_dep_component!(@self,SuperAdminTwoStep);

            let super_admin:ContractAddress = super_admin_comp.super_admin();
            assert(existing_owner!=super_admin,Error::SuperAdminCannotRemoved);
            super_admin_comp.assert_only_super_admin();


            self.signers.write(existing_owner,false);
            self.total_signers.write(self.total_signers.read()-1);

            self.emit(
                SignerRemoved{
                    remove_signer:existing_owner
            });
        }
        fn renounce_signership(ref self: ComponentState<TContractState>,signer:ContractAddress){

            assert(!signer.is_zero(), Error::ZERO_ADDRESS);   //check for zero address
             
            let caller:ContractAddress = get_caller_address();
            assert(self.is_signer(caller),Error::Not_A_Signer);      //only be calleable by signer
            assert(!self.is_signer(signer),Error::Already_Signer);   //new signer cannot be existing signer

            let super_admin_comp = get_dep_component!(@self,SuperAdminTwoStep);
            let super_admin:ContractAddress = super_admin_comp.super_admin();
            assert(existing_owner!=super_admin,Error::SuperAdminCannotRemoved); //signer cannot be remove
            // check it needs to be existing owner
            _renounce_signership(caller,signer);
        }
        fn accept_super_adminship(ref self:ComponentState<TContractState>){
           
           let caller:ContractAddress = get_caller_address(); 
           let super_admin_comp = get_dep_component!(ref self, SuperAdminTwoStep);
           let super_admin:ContractAddress = super_admin_comp.super_admin();
            super_admin_comp._accept_super_adminship();
           self._renounce_signership(caller,super_admin);
        }

        #[generate_trait]
        pub impl InternalImpl<
            TContractState, +HasComponent<TContractState>
        > of InternalTrait<TContractState> 

            fn initializer(ref self: ComponentState<TContractState>,super_admin:ContractAddress, fallback_admin:ContractAddress){
                let super_admin_comp = get_dep_component!(ref self,SuperAdminTwoStep);
                let fallback_admin_comp = get_dep_component!(ref self,FallbackAdminTwoStep);
                super_admin_comp.initializer(super_admin);
                fallback_admin_comp.initializer(fallback_admin);
                self.total_signers.write(1);
                self.signers.write(super_admin,true);
            }

            fn _renounce_signership(ref self:ComponentState<TContractState>,from:ContractAddress, to:ContractAddress){

            self.signers.write(from,false);
            self.signers.write(to,true);

            self.emit(
                SignerRenounced{
                    from:from,
                    to:to
                })

            }
        }













}