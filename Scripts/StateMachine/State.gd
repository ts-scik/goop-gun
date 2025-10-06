## Virtual base class for all states.
## Extend this class and override its methods to implement a state.
@abstract
class_name State extends Node

## Emitted when the state finishes and wants to transition to another state.
signal finished(next_state_path: String, data: Dictionary)

## Called by the state machine when receiving unhandled input events.
@abstract
func handle_input(_event: InputEvent) -> void

## Called by the state machine on the engine's main loop tick.
@abstract
func update(_delta: float) -> void

## Called by the state machine on the engine's physics update tick.
@abstract
func physics_update(_delta: float) -> void

## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
@abstract
func enter(previous_state_path: String, data := {}) -> void

## Called by the state machine before changing the active state. Use this function
## to clean up the state.
@abstract
func exit() -> void
