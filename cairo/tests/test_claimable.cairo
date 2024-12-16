#[cfg(test)]
mod tests {
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
        stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp
    };
    use starknet::contract_address::contract_address_const;
    use starknet::{ContractAddress,get_block_timestamp};
    use core::traits::Into;

    // Correct dispatcher imports
    use cairo::interfaces::iclaimable::{IClaimableDispatcher, IClaimableDispatcherTrait};
    use cairo::interfaces::ierc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

    const DAY: u64 = 86400;
    const MONTH: u64 = DAY * 30;

    fn deploy_mock_token() -> ContractAddress {
        let erc20_class = declare("MockERC20").unwrap().contract_class();
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

        let amount: felt252 = 20000000000000000;

        IMockERC20Dispatcher { contract_address: token_address }.mint(claimable_address, amount);

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

        let amount = IMockERC20Dispatcher{contract_address: token_address}.balance_of(claimable_address);

        assert(token_address == hash_token, 'Token Not Set');
        assert(claimable_owner == owner, 'Owner Not Set');
        assert(amount==20000000000000000,'Balance Not matched');
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

        let amount:u256 = 10000000;
        let cliff:u64 = 30;
        let vesting:u64 =180;
        let tge:u64 = 10;
        let ticket_type:u8 = 1;

        let ticket_id:u64 = claimable_dispatcher
            .create(
                beneficiary,
                cliff, // 30 days cliff
                vesting, // 180 days vesting
                amount,
                tge, // 10% TGE
                ticket_type // ticket type
            );


        assert(ticket_id==1,'TIcket Id doesnot matched');    

        // // Stop being owner
        stop_cheat_caller_address(claimable_address);
        let current_time = get_block_timestamp();

    //     // Advance time past cliff
        start_cheat_block_timestamp(claimable_address,  current_time + cliff * 86400);


        let available = claimable_dispatcher.available(ticket_id);
        println!("tokens available:{:?}",available);
        assert(available == 1000000 , 'Should have tokens available');


        let recipient = beneficiary;
        start_cheat_caller_address(claimable_address,beneficiary);
        let claim_success:bool = claimable_dispatcher.claim_ticket(ticket_id, recipient);
        assert(claim_success, 'Claim should succeed');

        stop_cheat_block_timestamp(claimable_address);

        // Verify recipient received tokens
        // let balance:u256 = IMockERC20Dispatcher { contract_address: token_address }.balance_of(recipient).into();
        // assert(balance == available, 'Wrong amount received');
    }
}

