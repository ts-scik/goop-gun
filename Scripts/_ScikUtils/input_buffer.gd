## Buffers inputs for player use.
## Each input type is buffered for a configurable amount of time in seconds.
## The buffer can be paused with a flag.
## Buffered inputs can be checked at any time, with optional removal.
class_name InputBuffer

# Variables for input buffering
var buffer : Array[float] = []
# Dictionary reference for how long to buffer any given bufferable input type
var input_timers : Dictionary
# Whether buffer should be currently updating its timers
var buffer_active : bool


## Set up the buffer
## Requires dictionary of format {TIMER_ENUM : BUFFERTIME, ...}
## Said dictionary configures buffer time per input type
## e.g. {JUMP_INPUT : 0.07, SHOOT_INPUT : 0.2,}
func _init(passed_input_timers : Dictionary) -> void:
	# Store input timers
	self.input_timers = passed_input_timers
	# Input buffer Setup
	self.buffer.resize(self.input_timers.size())
	self.buffer.fill(0.0)
	# Set buffer to Active
	self.buffer_active = true


## Updates input timers in buffer (if buffer is active)
func _process(delta) -> void:
	# early return if buffer is inactive
	if !buffer_active:
		return
	# update all timers in the buffer
	buffer_update.call_deferred(delta)


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
	# If action is buffered, zero it and return true
	if (buffer_check(action_idx)):
		buffer[action_idx] = 0.0
		return true
	return false
