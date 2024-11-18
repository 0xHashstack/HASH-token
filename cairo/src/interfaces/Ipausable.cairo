use cairo::helpers::constants;
// Define the pause states using an enum
#[derive(Drop, Copy, Serde)]
pub enum PauseState {
    Active,
    PartialPause,
    FullPause
}

#[starknet::interface]
pub trait IPausable<T1> {
    fn get_current_state(self: @T1) -> PauseState;
    fn is_active(self: @T1) -> bool;
    fn is_partial_paused(self: @T1) -> bool;
    fn is_full_paused(self: @T1) -> bool;
}

fn get_state_felt(state: PauseState) -> felt252 {
    match state {
        PauseState::Active => constants::Active,
        PauseState::PartialPause => constants::PartialPause,
        PauseState::FullPause => constants::FullPause
    }
}

