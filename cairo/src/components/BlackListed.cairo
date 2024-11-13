use starknet::{ContractAddress, get_caller_address};
use core::traits::Into;
use core::option::OptionTrait;

#[starknet::component]
mod BlackListedComp {
    use core::num::traits::zero::Zero;
    use cairo::interfaces::IblackListed::IBlackListedComponent;
    use starknet::{ContractAddress, get_caller_address};
    use core::traits::Into;

    #[storage]
    struct Storage {
        blacklisted_account: LegacyMap::<ContractAddress, bool>,
        multi_sig: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        NewAccountBlackListed: NewAccountBlackListed,
        RemovedAccountBlackListed: RemovedAccountBlackListed,
    }

    #[derive(Drop, starknet::Event)]
    struct NewAccountBlackListed {
        #[key]
        blacklisted_account: ContractAddress
    }

    #[derive(Drop, starknet::Event)]
    struct RemovedAccountBlackListed {
        #[key]
        removed_account: ContractAddress
    }

    mod errors {
        pub const ACCOUNT_BLACKLISTED: felt252 = 'Account is BlackListed';
        pub const RESTRICTED_TO_MULTISIG: felt252 = 'Restricted To MultiSig Contract';
        pub const ZERO_ADDRESS: felt252 = 'Calldata consist Zero Address';
    }

    #[embeddable_as(BlackListed)]
    impl BlackListedImpl<
        TContractState, +HasComponent<TContractState>
    > of IBlackListedComponent<ComponentState<TContractState>> {
        fn is_blacklisted_account(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> bool {
            self.blacklisted_account.read(account)
        }
        fn blacklist_account(ref self: ComponentState<TContractState>, account: ContractAddress) {
            self._only_multi_sig();
            self.blacklisted_account.write(account, true);
            self.emit(NewAccountBlackListed { blacklisted_account: account });
        }

        fn remove_blacklisted_account(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            self._only_multi_sig();
            self.blacklisted_account.write(account, false);
            self.emit(RemovedAccountBlackListed { removed_account: account });
        }
    }

    #[generate_trait]
    impl InternalFunctions<
        TContractState, +HasComponent<TContractState>
    > of InternalFunctionsTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, multi_sig: ContractAddress) {
            assert(multi_sig.is_zero(), errors::ZERO_ADDRESS);
            self.multi_sig.write(multi_sig);
        }

        fn _only_multi_sig(self: @ComponentState<TContractState>) {
            assert(get_caller_address() == self.multi_sig.read(), errors::RESTRICTED_TO_MULTISIG);
        }

        fn _not_blacklisted(self: @ComponentState<TContractState>, check: ContractAddress) {
            let flag: bool = self.blacklisted_account.read(check);
            assert(!flag, errors::ACCOUNT_BLACKLISTED);
        }
    }
}
