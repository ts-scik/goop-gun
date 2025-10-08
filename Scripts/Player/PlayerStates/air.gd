extends PlayerState

## Called by the state machine when receiving unhandled input events.
func handle_input(_event: InputEvent) -> void:
	pass

## Called by the state machine on the engine's main loop tick.
func update(_delta: float) -> void:
	pass

## Called by the state machine on the engine's physics update tick.
# TODO - this should contain more actual code
func physics_update(delta: float) -> void:
	pmove.PM_AirMove(pmk, delta)
	pmk.move_and_slide()
	# If we just landed,
	if pmk.is_on_floor():
		pmk.play_footstep_sound()
		pmk.gun_controller.start_gun_shake(0.6, 2.0, 4)
		#print("landed!")
		finished.emit("Walk")

## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_previous_state_path: String, _data := {}) -> void:
	#print("entered airstate!")
	pass

## Called by the state machine before changing the active state. Use this function
## to clean up the state.
func exit() -> void:
	pass
