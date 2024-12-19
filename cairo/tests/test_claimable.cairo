use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use starknet::contract_address::contract_address_const;
use starknet::{ContractAddress, get_block_timestamp};
use core::traits::Into;

// Correct dispatcher imports
use cairo::interfaces::iclaimable::{IClaimableDispatcher, IClaimableDispatcherTrait};
use cairo::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};

const DAY: u64 = 86400;
const MONTH: u64 = DAY * 30;

fn deploy_mock_token() -> ContractAddress {
    let erc20_class = declare("HashToken").unwrap().contract_class();
    let mut calldata: Array<felt252> = ArrayTrait::new();
    let (token_address, _) = erc20_class.deploy(@calldata).unwrap();
    println!("Im here mock token");
    token_address
}

// Helper function to deploy the contract
fn setup() -> (ContractAddress, ContractAddress) {
    let claimable_class = declare("Claimable").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<1>();

    // println!("Im here token-2");

    let token_address: ContractAddress = deploy_mock_token();

    let mut calldata = ArrayTrait::new();
    calldata.append(token_address.into());
    calldata.append(admin.into());

    // println!("Im here token-3");
    let (claimable_address, _) = claimable_class.deploy(@calldata).unwrap();
    // println!("Im here token");

    let amount: u256 = 20000000000000000;

    IERC20Dispatcher { contract_address: token_address }
        .permissioned_mint(claimable_address, amount);

    (claimable_address, token_address)
}

#[test]
fn test_Initialization() {
    // println!("Im here token---");
    let (claimable_address, token_address) = setup();

    let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };

    let hash_token: ContractAddress = claimable_dispatcher.token();
    let owner: ContractAddress = contract_address_const::<1>();
    let claimable_owner: ContractAddress = claimable_dispatcher.claimable_owner();

    let amount = IERC20Dispatcher { contract_address: token_address }.balance_of(claimable_address);

    assert(token_address == hash_token, 'Token Not Set');
    assert(claimable_owner == owner, 'Owner Not Set');
    assert(amount == 20000000000000000, 'Balance Not matched');
}

#[test]
fn test_create_and_claim() {
    println!("Im here token---");

    let (claimable_address, token_address) = setup();

    let owner: ContractAddress = contract_address_const::<1>();
    let beneficiary: ContractAddress = contract_address_const::<3>();
    let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };

    // // Start as owner to create vesting
    // // start_prank(CheatTarget::One(claimable), owner);
    start_cheat_caller_address(claimable_address, owner);

    println!("Im here token---2");

    let amount: u256 = 10000000;
    let cliff: u64 = 30;
    let vesting: u64 = 180;
    let tge: u64 = 10;
    let ticket_type: u8 = 1;

    let ticket_id: u64 = claimable_dispatcher
        .create(
            beneficiary,
            cliff, // 30 days cliff
            vesting, // 180 days vesting
            amount,
            tge, // 10% TGE
            ticket_type // ticket type
        );

    assert(ticket_id == 1, 'TIcket Id doesnot matched');

    // // Stop being owner
    stop_cheat_caller_address(claimable_address);
    let current_time = get_block_timestamp();

    // Advance time past cliff
    start_cheat_block_timestamp(claimable_address, current_time + cliff * 86400);

    let available = claimable_dispatcher.available(ticket_id);
    println!("tokens available:{:?}", available);
    assert(available == 1000000, 'Should have tokens available');

    let recipient = beneficiary;
    start_cheat_caller_address(claimable_address, beneficiary);
    let claim_success: bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
    assert(claim_success, 'Claim should succeed');

    stop_cheat_block_timestamp(claimable_address);

    // Verify recipient received tokens
    let balance: u256 = IERC20Dispatcher { contract_address: token_address }.balance_of(recipient);
    assert(balance == available, 'Wrong amount received');
}

#[test]
fn test_vesting_linear_realease() {
    // println!("Im here token---");

    let (claimable_address, token_address) = setup();

    let owner: ContractAddress = contract_address_const::<1>();
    let beneficiary: ContractAddress = contract_address_const::<3>();
    let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };

    // // Start as owner to create vesting
    // // start_prank(CheatTarget::One(claimable), owner);
    start_cheat_caller_address(claimable_address, owner);

    // println!("Im here token---2");

    let amount: u256 = 10_000_000;
    let cliff: u64 = 30;
    let vesting: u64 = 180;
    let tge: u64 = 10;
    let ticket_type: u8 = 1;

    let ticket_id: u64 = claimable_dispatcher
        .create(
            beneficiary,
            cliff, // 30 days cliff
            vesting, // 180 days vesting
            amount,
            tge, // 10% TGE
            ticket_type // ticket type
        );

    assert(ticket_id == 1, 'TIcket Id doesnot matched');

    // // Stop being owner
    stop_cheat_caller_address(claimable_address);

    let mut current_time = get_block_timestamp() + (cliff - 1) * 86400;

    start_cheat_block_timestamp(claimable_address, current_time);

    let recipient = beneficiary;
    start_cheat_caller_address(claimable_address, beneficiary);
    let claim_success: bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
    assert(claim_success, 'Claim should succeed');

    stop_cheat_block_timestamp(claimable_address);
    // // Stop being owner
    stop_cheat_caller_address(claimable_address);

    // let current_time = get_block_timestamp() + 86400;
    // let current_time = get_block_timestamp() + (cliff-1)* 86400;
    // let current_time = get_block_timestamp() + (cliff)* 86400;
    // let current_time = get_block_timestamp() + (cliff+1)* 86400;
    // let current_time = get_block_timestamp() + (cliff+(vesting/2))* 86400;
    current_time = get_block_timestamp() + (cliff + vesting - 1) * 86400;
    // let current_time = get_block_timestamp() + (cliff+vesting/2 +23)* 86400;

    // Advance time past cliff
    start_cheat_block_timestamp(claimable_address, current_time);

    let available = claimable_dispatcher.available(ticket_id);
    println!("tokens available:{:?}", available);
    // assert(available == 1000000, 'Should have tokens available');
    // assert(available == 1050000, 'Should have tokens available'); // ------> clif + 1
    // assert(available == 1000_000 + 4500_000, 'Should have tokens available'); // ------> clif +
    // vesting/2
    assert(
        available == (50_000 * 179), 'Should have tokens available'
    ); // ------> clif + vesting - 1
    // assert(available == 10000000, 'Should have tokens available');

    //     let recipient = beneficiary;
    //     start_cheat_caller_address(claimable_address,beneficiary);
    //     let claim_success:bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
    //     assert(claim_success, 'Claim should succeed');
    //     stop_cheat_caller_address(claimable_address);

    stop_cheat_block_timestamp(claimable_address);
    //     // Verify recipient received tokens
//     let balance:u256 = IERC20Dispatcher { contract_address: token_address
//     }.balance_of(recipient);
//     assert(balance == available, 'Wrong amount received');
}

#[test]
// #[should_panic(expected: ('Unauthorized',))]
// #[should_panic(expected: ('Invalid beneficiary',))]
// #[should_panic(expected: ('Invalid amount',))]
// #[should_panic(expected: ('Invalid vesting period',))]
// #[should_panic(expected: ('Invalid TGE percentage',))]
#[should_panic(expected: ('Invalid ticket type',))]
fn test_create_ticket_validation() {
    let (claimable_address, _) = setup();
    let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };
    let owner = contract_address_const::<1>();
    let beneficiary = contract_address_const::<2>();

    // // Test unauthorized creation
    // start_cheat_caller_address(claimable_address, beneficiary);
    //     claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 10, 1);
    // stop_cheat_caller_address(claimable_address);

    // Test invalid parameters
    start_cheat_caller_address(claimable_address, owner);

    // Test zero beneficiary

    // claimable_dispatcher.create(contract_address_const::<0>(), 30, 180, 1000000.into(), 10, 1);

    // // Test zero amount

    // claimable_dispatcher.create(beneficiary, 30, 180, 0.into(), 10, 1);

    // // Test invalid vesting period

    // claimable_dispatcher.create(beneficiary, 180, 30, 1000000.into(), 10, 1);

    // // Test invalid TGE percentage

    // claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 101, 1);

    // // Test invalid ticket type

    claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 10, 5);

    stop_cheat_caller_address(claimable_address);
}

