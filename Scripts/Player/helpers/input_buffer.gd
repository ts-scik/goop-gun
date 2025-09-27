class_name InputBuffer
## Buffers inputs for player use

# Variables for input buffering
var buffer : Array[float] = []
# Enum for bufferable inputs
enum {
	JUMP_INPUT = 0,
	SHOOT_INPUT = 1,
}
# Dictionary reference for how long to buffer any given bufferable input type
const input_timers : Dictionary = {
	JUMP_INPUT : 0.07,
	SHOOT_INPUT : 0.2,
}


## Set up the buffer
func _init() -> void:
	# Input buffer Setup
	buffer.resize(input_timers.size())
	buffer.fill(0.0)


## Takes an [action] and attempts to buffer it
## Returns [true] on successful buffer, [false] on buffer fail
func buffer_input(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(buffer.get(action_idx) != null)
	# Action is already buffered
	if(buffer[action_idx] > 0.0):
		return false
	# Action is unbuffered
	else:
		buffer[action_idx] = input_timers[action_idx]
		return true


## Updates the input buffer, zeroing out any expired inputs
func buffer_update(delta : float) -> Array[int]:
	var pop_array : Array[int] = []
	for idx in buffer.size():
		buffer[idx] -= delta
		if(buffer[idx] <= 0.0):
			buffer[idx] = 0.0
			pop_array.append(idx)
	return pop_array


## If we have [action] buffered, return {true}. Else, return {false}.
func buffer_check(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(buffer.get(action_idx) != null)
	
	# If action is buffered, return true
	if(buffer[action_idx] > 0.0):
		return true
	return false


## If we have [action] buffered, zero it and return {true}
## Else, return {false}
func buffer_retrieve(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(buffer.get(action_idx) != null)
	
	# If action is buffered, zero it and return true
	if (buffer[action_idx] > 0.0):
		buffer[action_idx] = 0.0
		return true
	return false
