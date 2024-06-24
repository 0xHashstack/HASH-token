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
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 1000000);
}


#[test]
fn test_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

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
fn test_increase_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

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
fn test_decrease_allowance() {
    
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

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
fn test_name() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

    let name = erc20Dispatcher.name();
    assert_eq!(name, "Hash Token");
}

#[test]
fn test_symbol() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

    let symbol = erc20Dispatcher.symbol();
    assert_eq!(symbol, "HASH");
}

#[test]
fn test_decimals() {
    let contract_address = deploy_contract();
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

    let decimals = erc20Dispatcher.decimals();
    assert_eq!(decimals, 18);
}

#[test]
fn test_transfer() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
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
fn test_transfer_from() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
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
fn test_total_supply() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
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
    let hashTokenDispatcher = IHashTokenCamelDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissionedMint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 1000000);
}

#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_id: BlockId::Number(634119))]
fn upgrade() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
    let minter = MINTER();
    let upgrader = UPGRADER();
    let alice = contract_address_const::<013579>();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));



}