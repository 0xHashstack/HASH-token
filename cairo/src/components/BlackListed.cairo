#[starknet::component]
pub mod BlackListedComponent {
    use starknet::{ContractAddress,get_caller_address};
    use core::panic_with_felt252;

    use cairo::interfaces::IblackListed::IBlackListedComponent;

    #[storage]
    struct Storage {
        blackListedAccount: LegacyMap::<ContractAddress,bool>,
        multiSig: ContractAddress
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewAccountBlackListed: NewAccountBlackListed,
        RemovedAccountBlackListed: RemovedAccountBlackListed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NewAccountBlackListed{
        #[key]
        blackListed_account:ContractAddress
    }

    #[derive(Drop,starknet::Event)]
    pub struct RemovedAccountBlackListed{
        #[key]
        removed_Account: ContractAddress
    }

    pub mod Error{
        pub const AccountBlackListed:felt252 ='Account is BlackListed';
        pub const RestrictedToMultiSig:felt252 ='Restricted To MultiSig Contract';
    }

    #[generate_trait]
    impl InternalFunctionBlackListed<TContractState, +HasComponent<TContractState>>
    of InternalFunctionBlackListedTraits<TContractState>{
        fn initializer(ref self: ComponentState<TContractState> , multiSig: ContractAddress){
            self.multiSig.write(multiSig);
        }

        fn _only_multiSig(self:@ComponentState<TContractState>){
            assert(get_caller_address() != self.multiSig.read(),Error::RestrictedToMultiSig);
        }

        fn _not_blackListed(self:@ComponentState<TContractState>,check:ContractAddress){
            let flag: bool = self.blackListedAccount.read(check);
            assert(flag,Error::AccountBlackListed);
        }

        fn blackList_account(ref self : ComponentState<TContractState>, account:ContractAddress){
            self._only_multiSig();
            self.blackListedAccount.write(account,true);
            self.emit(NewAccountBlackListed{
                blackListed_account:account
            });
        }

        fn remove_blackListed_account(ref self: ComponentState<TContractState>, account : ContractAddress){
            self._only_multiSig();
            self.blackListedAccount.write(account,false);
            self.emit(RemovedAccountBlackListed{
                removed_Account:account
            });
        }

        fn is_blackListed_account(self :@ComponentState<TContractState>, account:ContractAddress)-> bool {
            return self.blackListedAccount.read(account);
        }

    }
} 