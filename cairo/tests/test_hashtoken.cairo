use starknet::{ContractAddress, ClassHash, contract_address::{contract_address_const}};
use snforge_std::{declare, ContractClassTrait, store, replace_bytecode};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, CheatSpan, start_mock_call, stop_mock_call, prank
};

use cairo::interfaces::IHashToken::{IHashToken, IHashTokenCamel};
use cairo::interfaces::IHashToken::{IHashTokenCamelDispatcher, IHashTokenCamelDispatcherTrait};
use cairo::interfaces::IHashToken::{IHashTokenDispatcher, IHashTokenDispatcherTrait};
use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
use openzeppelin::upgrades::interface::IUpgradeable;
use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};

fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn MINTER() -> ContractAddress {
    'minter'.try_into().unwrap()
}

fn UPGRADER() -> ContractAddress {
    'upgrader'.try_into().unwrap()
}

fn deploy_contract() -> ContractAddress {
    let contract = declare("HashToken").unwrap();
    let mut calldata = Default::default();
    Serde::serialize(@OWNER(), ref calldata);
    Serde::serialize(@MINTER(), ref calldata);
    Serde::serialize(@UPGRADER(), ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}


#[test]
fn test_permissioned_mint() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 1000000);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_fail_role_permissioned_mint() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let upgrader = UPGRADER();
    let pranker = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), pranker);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
#[should_panic(expected: ('ERC20: mint to 0',))]
fn test_fail_zero_address_permissioned_mint() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let minter = MINTER();
    let zero_address = contract_address_const::<0>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(zero_address, 1000000);
    stop_prank(CheatTarget::One(contract_address));
}

// #[test]
// #[should_panic(expected: ('ERC20: mint to 0', ))]
// fn test_fail_zero_amount_permissioned_mint() {
//     let contract_address = deploy_contract();
//     let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
//     let minter = MINTER();
//     let upgrader = UPGRADER();

//     start_prank(CheatTarget::One(contract_address), minter);
//     hashTokenDispatcher.permissioned_mint(upgrader, 0);
//     stop_prank(CheatTarget::One(contract_address));
// }

#[test]
fn test_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    hashTokenDispatcher.permissioned_burn(upgrader, 500000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 500000);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_fail_role_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let upgrader = UPGRADER();
    let minter = MINTER();
    let pranker = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), pranker);
    hashTokenDispatcher.permissioned_burn(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
#[should_panic(expected: ('ERC20: burn from 0',))]
fn test_fail_zero_address_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let minter = MINTER();
    let zero_address = contract_address_const::<0>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_burn(zero_address, 1000000);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test_fail_zero_balance_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_burn(upgrader, 2000000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
fn test_increase_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let upgrader = UPGRADER();
    let minter = MINTER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.increase_allowance(upgrader, 1000000);
    hashTokenDispatcher.increase_allowance(upgrader, 500000);
    stop_prank(CheatTarget::One(contract_address));

    let allowance = erc20Dispatcher.allowance(minter, upgrader);

    assert_eq!(allowance, 1500000);
}

#[test]
#[should_panic(expected: ('ERC20: approve to 0)',))]
fn test_fail_zero_address_increase_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let minter = MINTER();
    let zero_address = contract_address_const::<0>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.increase_allowance(zero_address, 1000000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
fn test_decrease_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let upgrader = UPGRADER();
    let minter = MINTER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.increase_allowance(upgrader, 1000000);
    hashTokenDispatcher.decrease_allowance(upgrader, 500000);
    stop_prank(CheatTarget::One(contract_address));

    let allowance = erc20Dispatcher.allowance(minter, upgrader);

    assert_eq!(allowance, 500000);
}


#[test]
#[should_panic(expected: ('u256_sub Overflow',))]
fn test_fail_negative_allowance_decrease_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.decrease_allowance(upgrader, 500000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
fn test_name() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let name = erc20Dispatcher.name();
    assert_eq!(name, "Hash Token");
}

#[test]
fn test_symbol() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let symbol = erc20Dispatcher.symbol();
    assert_eq!(symbol, "HASH");
}

#[test]
fn test_decimals() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };

    let decimals = erc20Dispatcher.decimals();
    assert_eq!(decimals, 18);
}

#[test]
fn test_transfer() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.transfer(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));

    let alice_bal = erc20Dispatcher.balance_of(alice);

    assert_eq!(alice_bal, 400000);
}


#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test_fail_balance_less_than_transfer() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.transfer(alice, 2000000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
#[should_panic(expected: ('ERC20: transfer to 0',))]
fn test_fail_zero_address_transfer() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<0>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.transfer(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));
}


// #[test]
// #[should_panic(expected: ('ERC20: transfer to 0', ))]
// fn test_fail_same_address_transfer() {
//     let contract_address = deploy_contract();
//     let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
//     let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
//     let minter = MINTER();
//     let upgrader = UPGRADER();

//     start_prank(CheatTarget::One(contract_address), minter);
//     hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
//     stop_prank(CheatTarget::One(contract_address));

//     start_prank(CheatTarget::One(contract_address), upgrader);
//     erc20Dispatcher.transfer(upgrader, 400000);
//     stop_prank(CheatTarget::One(contract_address));

// }

#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test_fail_zero_balance_transfer() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.transfer(alice, 2000000);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_transfer_from() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.approve(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), alice);
    erc20Dispatcher.transfer_from(upgrader, alice, 300000);
    stop_prank(CheatTarget::One(contract_address));

    let alice_bal = erc20Dispatcher.balance_of(alice);

    assert_eq!(alice_bal, 300000);
}


#[test]
#[should_panic(expected: ('ERC20: approve to 0',))]
fn test_fail_zero_address_transfer_from() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<0>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.approve(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), alice);
    erc20Dispatcher.transfer_from(upgrader, alice, 300000);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('ERC20: insufficient allowance',))]
fn test_fail_transfer_more_than_approved_transfer_from() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.approve(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), alice);
    erc20Dispatcher.transfer_from(upgrader, alice, 600000);
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('ERC20: insufficient balance',))]
fn test_fail_balance_less_than_approved() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 200000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), upgrader);
    erc20Dispatcher.approve(alice, 400000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), alice);
    erc20Dispatcher.transfer_from(upgrader, alice, 300000);
    stop_prank(CheatTarget::One(contract_address));
}


#[test]
fn test_total_supply() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();
    let bob = contract_address_const::<02468>();
    let charlie = contract_address_const::<090909>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(alice, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(bob, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    start_prank(CheatTarget::One(contract_address), bob);
    erc20Dispatcher.transfer(charlie, 500000);
    stop_prank(CheatTarget::One(contract_address));

    let total_supply = erc20Dispatcher.total_supply();

    assert_eq!(total_supply, 3000000);
}

#[test]
fn test_permissionedMint() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenCamelDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissionedMint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 1000000);
}

#[test]
fn test_upgrade() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher { contract_address };
    let erc20Dispatcher = ERC20ABIDispatcher { contract_address };
    let upgradeDispatcher = IUpgradeableDispatcher { contract_address };
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal_before = erc20Dispatcher.balance_of(upgrader);

    let contract_new = declare("MockHashToken").unwrap();
    let class_hash = contract_new.class_hash;

    start_prank(CheatTarget::One(contract_address), upgrader);
    upgradeDispatcher.upgrade(class_hash);
    stop_prank(CheatTarget::One(contract_address));

    let bal_after = erc20Dispatcher.balance_of(upgrader);

    assert_eq!(bal_before, bal_after);
}

