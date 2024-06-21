use starknet::{ContractAddress, ClassHash, contract_address::{contract_address_const}};
use starknet::{get_contract_address, get_block_timestamp};
use snforge_std::BlockId;
use snforge_std::{declare, ContractClassTrait, store, replace_bytecode};
use snforge_std::{
    start_prank, stop_prank, CheatTarget, CheatSpan, start_mock_call, stop_mock_call, prank
};

use cairo::interfaces::IHashToken::IHashToken;
use cairo::interfaces::IHashToken::{IHashTokenDispatcher, IHashTokenDispatcherTrait};
use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

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
    println!("deploy0");
    let contract = declare("HashToken").unwrap();
    println!("deploy1");
    let mut calldata = Default::default();
    println!("deploy2");
    Serde::serialize(@OWNER(), ref calldata);
    println!("deploy3");
    Serde::serialize(@MINTER(), ref calldata);
    println!("deploy4");
    Serde::serialize(@UPGRADER(), ref calldata);
    println!("deploy5");
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_id: BlockId::Number(634119))]
fn test_permissioned_mint() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};
    let default_admin = OWNER();
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 1000000);
}


#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_id: BlockId::Number(634119))]
fn test_permissioned_burn() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};
    let erc20Dispatcher = ERC20ABIDispatcher {contract_address};

    let default_admin = OWNER();
    let minter = MINTER();
    let upgrader = UPGRADER();

    start_prank(CheatTarget::One(contract_address), minter);
    hashTokenDispatcher.permissioned_mint(upgrader, 1000000);
    hashTokenDispatcher.permissioned_burn(upgrader, 1000000);
    stop_prank(CheatTarget::One(contract_address));

    let bal = erc20Dispatcher.balance_of(upgrader);
    assert_eq!(bal, 0);
}

#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_id: BlockId::Number(634119))]
fn test_increase_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};

    let upgrader = UPGRADER();

    hashTokenDispatcher.increase_allowance(upgrader, 1000000);
}

#[test]
#[fork(url: "https://starknet-mainnet.public.blastapi.io/rpc/v0_7", block_id: BlockId::Number(634119))]
fn test_decrease_allowance() {
    let contract_address = deploy_contract();
    let hashTokenDispatcher = IHashTokenDispatcher {contract_address};

    let upgrader = UPGRADER();

    hashTokenDispatcher.increase_allowance(upgrader, 1000000);
    hashTokenDispatcher.decrease_allowance(upgrader, 500000);
}