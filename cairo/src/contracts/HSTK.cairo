// SPDX-License-Identifier: MIT
use starknet::ContractAddress;

#[starknet::interface]
pub trait IHashToken<TContractState>{

    fn permissioned_mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissioned_burn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn total_supply(self: @TContractState) -> u256;

    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;

    fn allowance(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress
    ) -> u256;

    fn transfer(
        ref self: TContractState, recipient: ContractAddress, amount: u256
    ) -> bool;

    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) -> bool;

    fn approve(
        ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // IERC20Metadata
    fn name(self:@TContractState) -> ByteArray;
    fn symbol(self:@TContractState) -> ByteArray;
    fn decimals(self:@TContractState) -> u8;


}
#[starknet::interface]
pub trait IHashTokenCamel<TContractState>{

    fn permissionedMint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissionedBurn(ref self: TContractState, account: ContractAddress, amount: u256);
    fn totalSupply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) -> bool;

}

#[starknet::contract]
mod HSTK {
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    // use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use super::IHashToken;
    use super::IHashTokenCamel;
    // use cairo::components::AccessRegistry::AccessRegistryComp::{InternalImpl,AccessRegistry};
    // use cairo::interfaces::IHashToken::{IHashToken, IHashTokenCamel};
    use cairo::components::BlackListed::BlackListedComp;
    component!(path: BlackListedComp, storage: blacklisted, event: BlackListedEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);


    // #[abi(embed_v0)]
    // impl AccessControlImpl = access_comp::AccessControlImpl<ContractState>;
    // impl AccessControlInternalImpl = access_comp::InternalImpl<ContractState>;


    impl ERC20MixinImpl = ERC20Component::ERC20Mixin<ContractState>;
   
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl BlackListedInternalImpl = BlackListedComp::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl BlackListedImpl = BlackListedComp::BlackListed<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        blacklisted: BlackListedComp::Storage,
        bridge: ContractAddress,
        l1_token:ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        BlackListedEvent: BlackListedComp::Event,

    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        default_admin: ContractAddress,
        bridge: ContractAddress,
        l1_token: ContractAddress,
        multi_sig:ContractAddress
    ) {
        self.erc20.initializer("HSTK", "HSTK");
        self.blacklisted.initializer(multi_sig);
        self.l1_token.write(l1_token);
        self.bridge.write(bridge);
    }

    #[abi(embed_v0)]
    impl HashTokenImpl of IHashToken<ContractState> {
        fn permissioned_mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.assert_only_bridge();
            self.erc20._mint(account, amount);
        }
        fn permissioned_burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.assert_only_bridge();
            self.erc20._burn(get_caller_address(), amount);
        }
        fn total_supply(self:@ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256{
            self.erc20.balance_of(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(
            ref self: ContractState, recipient: ContractAddress, amount: u256
        ) -> bool {

            self.blacklisted._not_blacklisted(recipient);
            self.blacklisted._not_blacklisted(get_caller_address());
            // should be active
            self.erc20.transfer(recipient, amount)
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {

            self.blacklisted._not_blacklisted(recipient);
            self.blacklisted._not_blacklisted(recipient);
            self.erc20.transfer_from(sender, recipient, amount)
        }

        fn approve(
            ref self: ContractState, spender: ContractAddress, amount: u256
        ) -> bool {
            self.blacklisted._not_blacklisted(spender);
            self.blacklisted._not_blacklisted(get_caller_address());
            self.erc20.approve(spender, amount)
        }

        // IERC20Metadata
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

    }

    #[abi(embed_v0)]
    impl HashTokenCamelImpl of IHashTokenCamel<ContractState> {
        fn permissionedMint(ref self: ContractState, account: ContractAddress, amount: u256){
            HashTokenImpl::permissioned_mint(ref self, account, amount)
        }
        fn permissionedBurn(ref self: ContractState, account: ContractAddress, amount: u256) {
            HashTokenImpl::permissioned_burn(ref self, account, amount)
        }

         // IERC20CamelOnly
         fn totalSupply(self: @ContractState) -> u256 {
            HashTokenImpl::total_supply(self)
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            HashTokenImpl::balance_of(self, account)
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            HashTokenImpl::transfer_from(ref self, sender, recipient, amount)
        }
    }


    #[generate_trait]
    impl HSTKInternalImpl of InternalTrait {
        fn assert_only_bridge(self: @ContractState){

            let caller = get_caller_address();
            let bridge = self.bridge.read();
            assert(caller == bridge,'Only Bridge');

        }
    }
}