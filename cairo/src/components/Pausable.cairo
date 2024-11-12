// // // Define the pause states using an enum
// // #[starknet::component]
// // pub mod Pausable {
// //     use cairo_starknet::helpers::constants;
// //     use cairo_starknet::interfaces::Ipausable::IPausable;

// //     #[derive(Drop, Copy, Serde)]
// //     pub enum PauseState {
// //     Active,
// //     PartialPause,
// //     FullPause
// //     }

// //     #[storage]
// //     struct Storage {
// //         current_state: PauseState
// //     }

// //     #[event]
// //     #[derive(Drop, starknet::Event)]
// //     enum Event {
// //         PauseStateChanged: PauseStateChanged,
// //     }

// //     #[derive(Drop, starknet::Event)]
// //     struct PauseStateChanged {
// //         new_state: PauseState,
// //     }

// //     #[derive(Drop, PartialEq)]
// //     enum PausableError {
// //         EnforcedPause,
// //         EnforcedPartialPause,
// //         InvalidStateChange,
// //     }

// //     fn panic_with_felt252(err: felt252) {
// //         core::panic_with_felt252(err)
// //     }

// //     impl PausableErrorIntoFelt252 of Into<PausableError, felt252> {
// //         fn into(self: PausableError) -> felt252 {
// //             match self {
// //                 PausableError::EnforcedPause => 'Contract is fully paused',
// //                 PausableError::EnforcedPartialPause => 'Contract is partially paused',
// //                 PausableError::InvalidStateChange => 'Invalid state change'
// //             }
// //         }
// //     }

// //     #[embeddable_as(Pausable)]
// //     impl PausableImpl<
// //         TContractState, 
// //         impl TContractStateDestruct: Drop<TContractState>,
// //         impl TContractStateComponent: HasComponent<TContractState>
// //     > of IPausable<ComponentState<TContractState>> {
// //         fn get_current_state(self: @ComponentState<TContractState>) -> PauseState {
// //             self.current_state.read()
// //         }

// //         fn is_active(self: @ComponentState<TContractState>) -> bool {
// //             match self.current_state.read() {
// //                 PauseState::Active => true,
// //                 _ => false
// //             }
// //         }

// //         fn is_partial_paused(self: @ComponentState<TContractState>) -> bool {
// //             match self.current_state.read() {
// //                 PauseState::PartialPause => true,
// //                 _ => false
// //             }
// //         }

// //         fn is_full_paused(self: @ComponentState<TContractState>) -> bool {
// //             match self.current_state.read() {
// //                 PauseState::FullPause => true,
// //                 _ => false
// //             }
// //         }
// //     }

// //     #[generate_trait]
// //     impl InternalFunctions<
// //         TContractState,
// //         impl TContractStateDestruct: Drop<TContractState>,
// //         impl TContractStateComponent: HasComponent<TContractState>
// //     > of InternalFunctionsTrait<TContractState> {
// //         fn initializer(ref self: ComponentState<TContractState>) {
// //             self.current_state.write(PauseState::Active);
// //         }

// //         fn _require_active(self: @ComponentState<TContractState>) {
// //             let current_state = self.current_state.read();
// //             match current_state {
// //                 PauseState::Active => {},
// //                 PauseState::PartialPause => {
// //                     panic_with_felt252(PausableError::EnforcedPartialPause.into())
// //                 },
// //                 PauseState::FullPause => {
// //                     panic_with_felt252(PausableError::EnforcedPause.into())
// //                 }
// //             }
// //         }

// //         fn _require_active_or_partial(self: @ComponentState<TContractState>) {
// //             let current_state = self.current_state.read();
// //             match current_state {
// //                 PauseState::Active => {},
// //                 PauseState::PartialPause => {},
// //                 PauseState::FullPause => {
// //                     panic_with_felt252(PausableError::EnforcedPause.into())
// //                 }
// //             }
// //         }

// //         fn _update_operational_state(
// //             ref self: ComponentState<TContractState>,
// //             new_state: PauseState
// //         ) {
// //             self.current_state.write(new_state);

// //             // Emit state change event
// //             self.emit(Event::PauseStateChanged(
// //                 PauseStateChanged { new_state }
// //             ));
// //         }
// //     }
// // }

// // #[starknet::component]
// // pub mod Pausable {
// //     use starknet::ContractAddress;
// //     use cairo_starknet::helpers::constants;
// //     use cairo_starknet::interfaces::Ipausable::IPausable;

// //     #[derive(Drop, Copy, Serde)]
// //     pub enum PauseState {
// //         Active,
// //         PartialPause,
// //         FullPause
// //     }

// //     #[storage]
// //     struct Storage {
// //         current_state: PauseState
// //     }

// //     #[event]
// //     #[derive(Drop, starknet::Event)]
// //     enum Event {
// //         PauseStateChanged: PauseStateChanged,
// //     }

// //     #[derive(Drop, starknet::Event)]
// //     struct PauseStateChanged {
// //         new_state: PauseState,
// //     }

// //     #[derive(Drop, PartialEq)]
// //     enum PausableError {
// //         EnforcedPause,
// //         EnforcedPartialPause,
// //         InvalidStateChange,
// //     }

// //     fn panic_with_felt252(err: felt252) {
// //         core::panic_with_felt252(err)
// //     }

// //     impl PausableErrorIntoFelt252 of Into<PausableError, felt252> {
// //         fn into(self: PausableError) -> felt252 {
// //             match self {
// //                 PausableError::EnforcedPause => 'Contract is fully paused',
// //                 PausableError::EnforcedPartialPause => 'Contract is partially paused',
// //                 PausableError::InvalidStateChange => 'Invalid state change'
// //             }
// //         }
// //     }

// //     #[embeddable_as(Pausable)]
// //     impl PausableImpl<
// //         TContractState,
// //         impl TContractStateDestruct: Drop<TContractState>,
// //         impl TContractStateComponent: HasComponent<TContractState>
// //     > of IPausable<ComponentState<TContractState>> {
// //         fn get_current_state(self: @ComponentState<TContractState>) -> PauseState {
// //             let state = self.current_state.read();
// //             state
// //         }

// //         fn is_active(self: @ComponentState<TContractState>) -> bool {
// //             match self.get_current_state() {
// //                 PauseState::Active => true,
// //                 _ => false
// //             }
// //         }

// //         fn is_partial_paused(self: @ComponentState<TContractState>) -> bool {
// //             match self.get_current_state() {
// //                 PauseState::PartialPause => true,
// //                 _ => false
// //             }
// //         }

// //         fn is_full_paused(self: @ComponentState<TContractState>) -> bool {
// //             match self.get_current_state() {
// //                 PauseState::FullPause => true,
// //                 _ => false
// //             }
// //         }
// //     }

// //     #[generate_trait]
// //     impl InternalFunctions<
// //         TContractState,
// //         impl TContractStateDestruct: Drop<TContractState>,
// //         impl TContractStateComponent: HasComponent<TContractState>
// //     > of InternalFunctionsTrait<TContractState> {
// //         fn initializer(ref self: ComponentState<TContractState>) {
// //             self.current_state.write(PauseState::Active);
// //         }

// //         fn _require_active(self: @ComponentState<TContractState>) {
// //             match self.get_current_state() {
// //                 PauseState::Active => {},
// //                 PauseState::PartialPause => {
// //                     panic_with_felt252(PausableError::EnforcedPartialPause.into())
// //                 },
// //                 PauseState::FullPause => {
// //                     panic_with_felt252(PausableError::EnforcedPause.into())
// //                 }
// //             }
// //         }

// //         fn _require_active_or_partial(self: @ComponentState<TContractState>) {
// //             match self.get_current_state() {
// //                 PauseState::Active => {},
// //                 PauseState::PartialPause => {},
// //                 PauseState::FullPause => {
// //                     panic_with_felt252(PausableError::EnforcedPause.into())
// //                 }
// //             }
// //         }

// //         fn _update_operational_state(
// //             ref self: ComponentState<TContractState>,
// //             new_state: PauseState
// //         ) {
// //             self.current_state.write(new_state);

// //             // Emit state change event
// //             self.emit(Event::PauseStateChanged(
// //                 PauseStateChanged { new_state }
// //             ));
// //         }
// //     }
// // }

// use starknet::ContractAddress;
// use core::starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};

// #[starknet::interface]
// trait IPausable<TContractState> {
//     fn get_current_state(self: @TContractState) -> PauseState;
//     fn is_active(self: @TContractState) -> bool;
//     fn is_partial_paused(self: @TContractState) -> bool;
//     fn is_full_paused(self: @TContractState) -> bool;
// }

// #[derive(Drop, Copy, Serde)]
// pub enum PauseState {
//     Active,
//     PartialPause,
//     FullPause
// }

// #[starknet::component]
// pub mod Pausable {
//     use super::{PauseState, IPausable};
//     use starknet::ContractAddress;
//     use core::starknet::storage::{StorageMapMemberAccessTrait, StorageMemberAccessTrait};

//     #[storage]
//     struct Storage {
//         current_state: PauseState
//     }

//     #[event]
//     #[derive(Drop, starknet::Event)]
//     enum Event {
//         PauseStateChanged: PauseStateChanged,
//     }

//     #[derive(Drop, starknet::Event)]
//     struct PauseStateChanged {
//         new_state: PauseState,
//     }

//     #[derive(Drop, PartialEq)]
//     enum PausableError {
//         EnforcedPause,
//         EnforcedPartialPause,
//         InvalidStateChange,
//     }

//     fn panic_with_felt252(err: felt252) {
//         core::panic_with_felt252(err)
//     }

//     impl PausableErrorIntoFelt252 of Into<PausableError, felt252> {
//         fn into(self: PausableError) -> felt252 {
//             match self {
//                 PausableError::EnforcedPause => 'Contract is fully paused',
//                 PausableError::EnforcedPartialPause => 'Contract is partially paused',
//                 PausableError::InvalidStateChange => 'Invalid state change'
//             }
//         }
//     }

//     #[embeddable_as(Pausable)]
//     impl PausableImpl<
//         TContractState,
//         impl TContractStateDestruct: Drop<TContractState>,
//         impl TContractStateComponent: HasComponent<TContractState>
//     > of IPausable<ComponentState<TContractState>> {
//         fn get_current_state(self: @ComponentState<TContractState>) -> PauseState {
//             let current_state = StorageMemberAccessTrait::<PauseState>::read(self.current_state.address());
//             current_state
//         }

//         fn is_active(self: @ComponentState<TContractState>) -> bool {
//             match self.get_current_state() {
//                 PauseState::Active => true,
//                 _ => false
//             }
//         }

//         fn is_partial_paused(self: @ComponentState<TContractState>) -> bool {
//             match self.get_current_state() {
//                 PauseState::PartialPause => true,
//                 _ => false
//             }
//         }

//         fn is_full_paused(self: @ComponentState<TContractState>) -> bool {
//             match self.get_current_state() {
//                 PauseState::FullPause => true,
//                 _ => false
//             }
//         }
//     }

//     #[generate_trait]
//     impl InternalFunctions<
//         TContractState,
//         impl TContractStateDestruct: Drop<TContractState>,
//         impl TContractStateComponent: HasComponent<TContractState>
//     > of InternalFunctionsTrait<TContractState> {
//         fn initializer(ref self: ComponentState<TContractState>) {
//             StorageMemberAccessTrait::<PauseState>::write(
//                 self.current_state.address(),
//                 PauseState::Active
//             );
//         }

//         fn _require_active(self: @ComponentState<TContractState>) {
//             match self.get_current_state() {
//                 PauseState::Active => {},
//                 PauseState::PartialPause => {
//                     panic_with_felt252(PausableError::EnforcedPartialPause.into())
//                 },
//                 PauseState::FullPause => {
//                     panic_with_felt252(PausableError::EnforcedPause.into())
//                 }
//             }
//         }

//         fn _require_active_or_partial(self: @ComponentState<TContractState>) {
//             match self.get_current_state() {
//                 PauseState::Active => {},
//                 PauseState::PartialPause => {},
//                 PauseState::FullPause => {
//                     panic_with_felt252(PausableError::EnforcedPause.into())
//                 }
//             }
//         }

//         fn _update_operational_

