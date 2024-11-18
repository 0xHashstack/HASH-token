// use starknet::ContractAddress;
// use starknet::{get_caller_address, get_contract_address};
// use starknet::storage_access::StorageAccess;
// use starknet::storage_access::StorageBaseAddress;
// use starknet::SyscallResult;

// #[starknet::interface]
// pub trait IPausable<TContractState> {
//     fn get_current_state(self: @TContractState) -> PauseState;
//     fn is_active(self: @TContractState) -> bool;
//     fn is_partial_paused(self: @TContractState) -> bool;
//     fn is_full_paused(self: @TContractState) -> bool;
// }

// #[derive(Drop, Copy, Serde, PartialEq)]
// #[repr(felt252)]
// pub enum PauseState {
//     Active,
//     PartialPause,
//     FullPause
// }

// // Implement StorageAccess for PauseState
// impl StorageAccessPauseState of StorageAccess<PauseState> {
//     fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<PauseState> {
//         let val = StorageAccess::<felt252>::read(address_domain, base)?;
//         match val {
//             0 => Result::Ok(PauseState::Active),
//             1 => Result::Ok(PauseState::PartialPause),
//             2 => Result::Ok(PauseState::FullPause),
//             _ => Result::Err(array!['Invalid PauseState value'])
//         }
//     }

//     fn write(address_domain: u32, base: StorageBaseAddress, value: PauseState) -> SyscallResult<()> {
//         let val = match value {
//             PauseState::Active => 0,
//             PauseState::PartialPause => 1,
//             PauseState::FullPause => 2,
//         };
//         StorageAccess::<felt252>::write(address_domain, base, val)
//     }

//     fn size() -> u8 {
//         1
//     }
// }

// #[starknet::component]
// pub mod pausable_component {
//     use super::{PauseState, IPausable};
//     use starknet::{get_caller_address, ContractAddress};

//     #[storage]
//     struct Storage {
//         current_state: PauseState,
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     pub enum Event {
//         PauseStateChanged: PauseStateChanged
//     }

//     #[derive(Drop, starknet::Event)]
//     pub struct PauseStateChanged {
//         #[key]
//         pub caller: ContractAddress,
//         pub new_state: PauseState,
//     }

//     #[generate_trait]
//     pub trait InternalTrait {
//         fn _assert_active(self: @ComponentState<TContractState>);
//         fn _assert_not_full_paused(self: @ComponentState<TContractState>);
//         fn _update_state(ref self: ComponentState<TContractState>, new_state: PauseState);
//         fn initializer(ref self: ComponentState<TContractState>);
//     }

//     #[generate_trait]
//     impl InternalImpl<TContractState> of InternalTrait<TContractState> {
//         fn _assert_active(self: @ComponentState<TContractState>) {
//             let state = self.current_state.read().unwrap();
//             assert(state == PauseState::Active, 'Contract must be active');
//         }

//         fn _assert_not_full_paused(self: @ComponentState<TContractState>) {
//             let state = self.current_state.read().unwrap();
//             assert(state != PauseState::FullPause, 'Contract must not be fully paused');
//         }

//         fn _update_state(ref self: ComponentState<TContractState>, new_state: PauseState) {
//             self.current_state.write(new_state).unwrap();
//             self.emit(Event::PauseStateChanged(PauseStateChanged { 
//                 caller: get_caller_address(), 
//                 new_state 
//             }));
//         }

//         fn initializer(ref self: ComponentState<TContractState>) {
//             self.current_state.write(PauseState::Active).unwrap();
//         }
//     }

//     #[embeddable_as(IPausableImpl)]
//     impl PausableImpl<
//         TContractState, impl TContractStateHasComponent: HasComponent<TContractState>
//     > of IPausable<ComponentState<TContractState>> {
//         fn get_current_state(self: @ComponentState<TContractState>) -> PauseState {
//             self.current_state.read().unwrap()
//         }

//         fn is_active(self: @ComponentState<TContractState>) -> bool {
//             self.current_state.read().unwrap() == PauseState::Active
//         }

//         fn is_partial_paused(self: @ComponentState<TContractState>) -> bool {
//             self.current_state.read().unwrap() == PauseState::PartialPause
//         }

//         fn is_full_paused(self: @ComponentState<TContractState>) -> bool {
//             self.current_state.read().unwrap() == PauseState::FullPause
//         }
//     }
// }