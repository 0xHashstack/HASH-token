// SPDX-License-Identifier: MIT
#[starknet::interface]
pub trait IMockERC20<TContractState> {
    fn mint(account: ContractAddress, to: u256);
}
#[starknet::contract]
mod MockERC20 {
    use starknet::{ClassHash, ContractAddress, get_caller_address};

    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use super::IHashToken;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Hash Token", "HASH");
    }

    #[abi(embed_v0)]
    impl HashTokenImpl of IHashToken<ContractState> {
        fn mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20._mint(account, amount);
        }
    }
}
