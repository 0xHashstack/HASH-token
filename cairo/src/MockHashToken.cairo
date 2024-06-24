// SPDX-License-Identifier: MIT

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

#[starknet::contract]
mod MockHashToken {
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::{UpgradeableComponent, interface::IUpgradeable};
    use super::{MINTER_ROLE, UPGRADER_ROLE};
    use cairo::interfaces::IHashToken::{IHashToken, IHashTokenCamel};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        default_admin: ContractAddress,
        minter: ContractAddress,
        upgrader: ContractAddress,
    ) {
        self.erc20.initializer("HashToken", "HASH");
        self.accesscontrol.initializer();

        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.accesscontrol._grant_role(MINTER_ROLE, minter);
        self.accesscontrol._grant_role(UPGRADER_ROLE, upgrader);
    }

    #[abi(embed_v0)]
    impl HashTokenImpl of IHashToken<ContractState> {
        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            self._increase_allowance(spender, added_value)
        }
        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            self._decrease_allowance(spender, subtracted_value)
        }
        fn permissioned_mint(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            self.erc20._mint(account, amount);
        }
        fn permissioned_burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            self.erc20._burn(account, amount);
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
        fn increaseAllowance(
            ref self: ContractState, spender: ContractAddress, addedValue: u256
        ) -> bool {
            HashTokenImpl::increase_allowance(ref self, spender, addedValue)
        }
        fn decreaseAllowance(
            ref self: ContractState, spender: ContractAddress, subtractedValue: u256
        ) -> bool {
            HashTokenImpl::decrease_allowance(ref self, spender, subtractedValue)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(UPGRADER_ROLE);
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Internal method for the external [increase_allowance](increase_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                .erc20
                ._approve(
                    caller,
                    spender,
                    self.erc20.ERC20_allowances.read((caller, spender)) + added_value
                );
            true
        }

        /// Internal method for the external [decrease_allowance](decrease_allowance).
        /// Emits an [Approval](Approval) event indicating the updated allowance.
        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                .erc20
                ._approve(
                    caller,
                    spender,
                    self.erc20.ERC20_allowances.read((caller, spender)) - subtracted_value
                );
            true
        }


        fn _dummy_function(self: @ContractState) -> u256 {
            let mut x = 0;
            x += 1;
            x
        }
    }
}
