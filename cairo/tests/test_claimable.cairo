use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use starknet::contract_address::contract_address_const;
use starknet::{ContractAddress, get_block_timestamp, ClassHash};
use core::traits::Into;

// Correct dispatcher imports
use cairo::interfaces::iclaimable::{IClaimableDispatcher, IClaimableDispatcherTrait, Ticket};
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
    let beneficiary: Array<ContractAddress> = array![contract_address_const::<3>()];
    let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };

    // // Start as owner to create vesting
    // // start_prank(CheatTarget::One(claimable), owner);
    start_cheat_caller_address(claimable_address, owner);

    println!("Im here token---2");

    let amount: Array<u256> = array![10000000];
    let cliff: u64 = 30;
    let vesting: u64 = 180;
    let tge: u64 = 10;
    let ticket_type: u8 = 1;

    claimable_dispatcher
        .batch_create(
            beneficiary,
            cliff, // 30 days cliff
            vesting, // 180 days vesting
            amount,
            tge, // 10% TGE
            ticket_type // ticket type
        );

    // assert(ticket_id == 1, 'TIcket Id doesnot matched');
    let ticket_id = 1;

    // // Stop being ownerc
    stop_cheat_caller_address(claimable_address);
    let current_time = get_block_timestamp();

    // Advance time past cliff
    start_cheat_block_timestamp(claimable_address, current_time + cliff * 86400);

    let available = claimable_dispatcher.available(ticket_id);
    println!("tokens available:{:?}", available);
    assert(available == 1000000, 'Should have tokens available');

    let recipient = contract_address_const::<3>();
    start_cheat_caller_address(claimable_address, recipient);
    let claim_success: bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
    assert(claim_success, 'Claim should succeed');

    stop_cheat_block_timestamp(claimable_address);

    // Verify recipient received tokens
    let balance: u256 = IERC20Dispatcher { contract_address: token_address }.balance_of(recipient);
    assert(balance == available, 'Wrong amount received');
}
#[test]
#[fork(
    url: "https://starknet-mainnet.infura.io/v3/edd0fd50d7d948d58c513f38e5622da2", block_tag: latest
)]
fn test_mainnet_data() {
    let claim_contract: ContractAddress = contract_address_const::<
        0x137fe540218938f9b424a3b8882b4fbf80f4df197e9d465fe8a4911225fd1e5
    >(); //mainnet address claims

    let beneficiaries: Array<ContractAddress> = array![contract_address_const::<0x078c58d7b47978b84eC6b557A5F697DCfE48f8c98ec97F850201d420c31bBAc6
    >()];

    let beneficiary:ContractAddress = *beneficiaries.at(0);

    println!("beneficiary:{:?} ",beneficiary);

    let claimable_dispatcher = IClaimableDispatcher { contract_address: claim_contract };
    let declare_result = declare("Claimable").unwrap();
    let class_hash = *declare_result.contract_class().class_hash;

    let super_admin: ContractAddress = contract_address_const::<
        0x276adfd1753b4f74e20ffddfb97f6be68cf3e6e9aa7bffb8c535e2f39e41749
    >();

    // Get initial tickets
    let initial_tickets = claimable_dispatcher.my_beneficiary_tickets(beneficiary);
    println!("Initial tickets: {:?}", initial_tickets);

    let initial_snapshot = @initial_tickets;

    let ticket_initial: Ticket = claimable_dispatcher.view_ticket(*initial_snapshot[1]);

    println!("ticket_initial: {:?}", ticket_initial);

    // claim the tge amount for ticket 4501

    println!(
        "avaialbe amount Before states {:?}", claimable_dispatcher.available(*initial_snapshot[0])
    );

    println!(
        "avaialbe amount Before states {:?}", claimable_dispatcher.available(*initial_snapshot[1])
    );

    // start_cheat_caller_address(claim_contract, beneficiary);
    // claimable_dispatcher.claim_ticket(*initial_snapshot[1], beneficiary);
    // stop_cheat_caller_address(claim_contract);

    // Upgrade and transfer
    start_cheat_caller_address(claim_contract, super_admin);
    claimable_dispatcher.upgrade_class_hash(class_hash);
    let ticket_type: u8 = 3;
    claimable_dispatcher.transfer_tickets(beneficiaries, ticket_type);
    stop_cheat_caller_address(claim_contract);

    // Get final tickets
    let final_tickets = claimable_dispatcher.my_beneficiary_tickets(beneficiary);
    println!("Final tickets: {:?}", final_tickets);

    let final_snapshot = @final_tickets;
    // let ticket: Ticket = claimable_dispatcher.view_ticket(*final_snapshot[1]);
    // println!("Ticket Final: {:?}", ticket);

    // assertEq(claimable_dispatcher.available(ticket_4501)>0,"Some Error occurred");

    println!(
        "available amount after migrating states {:?}",
        claimable_dispatcher.available(*final_snapshot[0])
    );
    println!(
        "available amount after migrating states {:?}",
        claimable_dispatcher.available(*final_snapshot[1])
    );

    start_cheat_caller_address(claim_contract,beneficiary);
    claimable_dispatcher.claim_tokens(beneficiary);
    stop_cheat_caller_address(claim_contract);


    println!(
        "available amount after migrating states {:?}",
        claimable_dispatcher.view_ticket(*final_snapshot[0])
    );
    println!(
        "available amount after migrating states {:?}",
        claimable_dispatcher.view_ticket(*final_snapshot[1])
    );

    
}
// #[test]
// fn test_vesting_linear_realease() {
//     // println!("Im here token---");

//     let (claimable_address, token_address) = setup();

//     let owner: ContractAddress = contract_address_const::<1>();
//     let beneficiary: ContractAddress = contract_address_const::<3>();
//     let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };

//     // // Start as owner to create vesting
//     // // start_prank(CheatTarget::One(claimable), owner);
//     start_cheat_caller_address(claimable_address, owner);

//     // println!("Im here token---2");

//     let amount: u256 = 10_000_000;
//     let cliff: u64 = 30;
//     let vesting: u64 = 180;
//     let tge: u64 = 10;
//     let ticket_type: u8 = 1;

//     let ticket_id: u64 = claimable_dispatcher
//         .create(
//             beneficiary,
//             cliff, // 30 days cliff
//             vesting, // 180 days vesting
//             amount,
//             tge, // 10% TGE
//             ticket_type // ticket type
//         );

//     assert(ticket_id == 1, 'TIcket Id doesnot matched');

//     // // Stop being owner
//     stop_cheat_caller_address(claimable_address);

//     let mut current_time = get_block_timestamp() + (cliff - 1) * 86400;

//     start_cheat_block_timestamp(claimable_address, current_time);

//     let recipient = beneficiary;
//     start_cheat_caller_address(claimable_address, beneficiary);
//     let claim_success: bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
//     assert(claim_success, 'Claim should succeed');

//     stop_cheat_block_timestamp(claimable_address);
//     // // Stop being owner
//     stop_cheat_caller_address(claimable_address);

//     // let current_time = get_block_timestamp() + 86400;
//     // let current_time = get_block_timestamp() + (cliff-1)* 86400;
//     // let current_time = get_block_timestamp() + (cliff)* 86400;
//     // let current_time = get_block_timestamp() + (cliff+1)* 86400;
//     // let current_time = get_block_timestamp() + (cliff+(vesting/2))* 86400;
//     current_time = get_block_timestamp() + (cliff + vesting - 1) * 86400;
//     // let current_time = get_block_timestamp() + (cliff+vesting/2 +23)* 86400;

//     // Advance time past cliff
//     start_cheat_block_timestamp(claimable_address, current_time);

//     let available = claimable_dispatcher.available(ticket_id);
//     println!("tokens available:{:?}", available);
//     // assert(available == 1000000, 'Should have tokens available');
//     // assert(available == 1050000, 'Should have tokens available'); // ------> clif + 1
//     // assert(available == 1000_000 + 4500_000, 'Should have tokens available'); // ------> clif
//     +
//     // vesting/2
//     assert(
//         available == (50_000 * 179), 'Should have tokens available'
//     ); // ------> clif + vesting - 1
//     // assert(available == 10000000, 'Should have tokens available');

//     //     let recipient = beneficiary;
//     //     start_cheat_caller_address(claimable_address,beneficiary);
//     //     let claim_success:bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
//     //     assert(claim_success, 'Claim should succeed');
//     //     stop_cheat_caller_address(claimable_address);

//     stop_cheat_block_timestamp(claimable_address);
//     //     // Verify recipient received tokens
// //     let balance:u256 = IERC20Dispatcher { contract_address: token_address
// //     }.balance_of(recipient);
// //     assert(balance == available, 'Wrong amount received');
// }

// #[test]
// // #[should_panic(expected: ('Unauthorized',))]
// // #[should_panic(expected: ('Invalid beneficiary',))]
// // #[should_panic(expected: ('Invalid amount',))]
// // #[should_panic(expected: ('Invalid vesting period',))]
// // #[should_panic(expected: ('Invalid TGE percentage',))]
// #[should_panic(expected: ('Invalid ticket type',))]
// fn test_create_ticket_validation() {
//     let (claimable_address, _) = setup();
//     let claimable_dispatcher = IClaimableDispatcher { contract_address: claimable_address };
//     let owner = contract_address_const::<1>();
//     let beneficiary = contract_address_const::<2>();

//     // // Test unauthorized creation
//     // start_cheat_caller_address(claimable_address, beneficiary);
//     //     claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 10, 1);
//     // stop_cheat_caller_address(claimable_address);

//     // Test invalid parameters
//     start_cheat_caller_address(claimable_address, owner);

//     // Test zero beneficiary

//     // claimable_dispatcher.create(contract_address_const::<0>(), 30, 180, 1000000.into(), 10,
//     1);

//     // // Test zero amount

//     // claimable_dispatcher.create(beneficiary, 30, 180, 0.into(), 10, 1);

//     // // Test invalid vesting period

//     // claimable_dispatcher.create(beneficiary, 180, 30, 1000000.into(), 10, 1);

//     // // Test invalid TGE percentage

//     // claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 101, 1);

//     // // Test invalid ticket type

//     claimable_dispatcher.create(beneficiary, 30, 180, 1000000.into(), 10, 5);

//     stop_cheat_caller_address(claimable_address);
// }


