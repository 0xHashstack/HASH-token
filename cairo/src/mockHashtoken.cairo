// SPDX-License-Identifier: MIT
#[starknet::contract]
pub mod HashToken {
    use starknet::{ContractAddress};
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use cairo::interfaces::ierc20::{IHashToken, IHashTokenCamel};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);


    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Hash Token", "HASH");
    }

    #[abi(embed_v0)]
    impl HashTokenImpl of IHashToken<ContractState> {
        fn permissioned_mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20.mint(account, amount);
        }
        fn permissioned_burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20.burn(account, amount);
        }
    }

    #[abi(embed_v0)]
    impl HashTokenCamelImpl of IHashTokenCamel<ContractState> {
        fn permissionedMint(ref self: ContractState, account: ContractAddress, amount: u256) {
            HashTokenImpl::permissioned_mint(ref self, account, amount)
        }
        fn permissionedBurn(ref self: ContractState, account: ContractAddress, amount: u256) {
            HashTokenImpl::permissioned_burn(ref self, account, amount)
        }
    }
}
