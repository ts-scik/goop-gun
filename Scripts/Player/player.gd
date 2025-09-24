class_name PlayerController
extends CharacterBody3D
## Manages all player input + movement (except for the camera)

# Movement constants
@export_category("Movement Variables")
@export_group("Jumping")
@export var GRAVITY : float = 9.8
@export var PM_JUMP_VELOCITY : float = 4.5 # jump velocity
@export_group("Movement")
@export var PM_WALKSPEED : float = 4.0 # move velocity
@export var PM_RUNSPEED : float = 7.0 # run velocity
@export var PM_CROUCHSPEED : float = 2.0 # crouch velocity
@export var PM_ACCELERATE : float = 8.0 # Acceleration factor on ground
@export var PM_AIRACCELERATE : float = 1.0 # Acceleration factor in air
@export_group("Friction")
@export var PM_FRICTION : float = 6.0 # Friction factor when on ground TODO - tweak
@export var PM_STOPSPEED : float = 0.75 # Minimum speed factor for friction calculation

# Child nodes
@onready var camera_controller_anchor : Marker3D = $HeadPos
@onready var camera_controller : CameraController= get_node("CameraController")
@onready var gun_controller : GunController = get_node("CameraController/GunController")
@onready var pause_menu : CanvasLayer = get_node("PauseMenu")
@onready var HUD : CanvasLayer = get_node("HUD")

# Local player variables
var paused = false
var health : int = 3
var score : int = 0
# Variables for movement
var was_on_floor : bool = false # Whether we were on floor at start of frame
var fly_enabled : bool = false # debug for fly movement
var is_crouching : bool = false # Flag for crouching
var is_running : bool = false # Flag for running
var crouch_toggle : bool = false # Whether we're using toggle-crouch
# Variables for foosteps
var footstep_timer : float = 0.0
var footstep_time_length : float = 0.5
# Variables for gun handling
var aim_held : bool = false # Flag for ADS input
var aim_toggle : bool = false # Whether or not we're using toggle-aim

# Variables for input buffering
var input_buffer : Array[float] = []
# Enum for bufferable inputs
enum {
	JUMP_INPUT = 0,
	SHOOT_INPUT = 1
}
# Dictionary reference for how long to buffer any given bufferable input type
const input_timers : Dictionary = {
	JUMP_INPUT : 0.1,
	SHOOT_INPUT : 0.05,
}


## Set multiplayer auth
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


## Connect signals, display HUD
func _ready() -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# Store ourselves in the gamemanager
	GameManager.local_player = self

	# Input buffer Setup
	input_buffer.resize(input_timers.size())
	input_buffer.fill(0.0)
	
	# UI Setup
	pause_menu.value_update.connect(_on_menu_value_update)
	_HUD_setup()


## Setup HUD
# Called during _ready()
func _HUD_setup() -> void:
	HUD.show()
	HUD.update_health(health)
	HUD.get_node("SpeedContainer/Speed").set_tracked_node(self)


## Handle instantaneous inputs (pausing, scoreboard, jump, mouse)
func _input(event) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# Mouse
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle shooting
		if event.is_action_pressed("shoot"):
			buffer_input(SHOOT_INPUT)
		# Handle aim press
		elif event.is_action_pressed("aim"):
			# Hold-to-aim -> enable aiming
			if(!aim_toggle): aim_held = true
			# Toggle-aim -> toggle aiming
			else: aim_held = !aim_held
		# Handle aim release (only for hold-to-aim)
		elif !aim_toggle and event.is_action_released("aim"):
			# Hold-to-aim -> disable aiming
			aim_held = false

	# Crouching/running
	# TODO !!

	# Pause menu
	if event.is_action_pressed("pause"):
		_on_menu_key()
	# Scoreboard
	elif event.is_action_pressed("scoreboard"):
		HUD.update_scores()
		HUD.scoreboard.show()
	elif event.is_action_released("scoreboard"):
		HUD.scoreboard.hide()
	# Die
	elif event.is_action_pressed("kill"):
		die.rpc()
	elif event.is_action_pressed("jump"):
		buffer_input(JUMP_INPUT)


## Handle buffered inputs
func _process(delta: float) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# Try to shoot
	var can_shoot : bool = true #TODO
	can_shoot = aim_held # TODO
	if(can_shoot):
		var buffered_shoot = input_buffer_retrieve(SHOOT_INPUT) # check for buffered shoot input
		if(buffered_shoot):
			camera_controller.camera_shoot()
			gun_controller.shoot.rpc()
	
	# Update the input buffer -- do this at the *end* of the frame
	input_buffer_update(delta)


## Handle player movement
func _physics_process(delta: float) -> void:
	# TODO: adjust this so players don't have *total* authority ??
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# Set walking/on_ground flag
	was_on_floor = is_on_floor()

	# Handle movement inputs
	if fly_enabled:
		# fly movement (for debug)
		PM_FlyMove(delta)
	elif was_on_floor:
		# walking on ground
		PM_WalkMove(delta)
	else:
		# airborne
		PM_AirMove(delta)
	
	# Foostep management
	_handle_footsteps(delta)
	
	# Actually do our movement
	move_and_slide()


## Returns player's current wishdir (normalized!)
func PM_Wishdir() -> Vector3:
	var fmove := Input.get_axis("back","forward")
	var smove := Input.get_axis("left","right")
	# (forward * fmove + right * smove).normalized()
	return ( ( -transform.basis.z * fmove ) + ( transform.basis.x * smove ) ).normalized()


## Applies friction to velocity
func PM_Friction(delta : float) -> void:
	var vec : Vector3 = velocity # what is this even for
	if was_on_floor:
		# TODO : should this be on vec or velocity??
		vec.y = 0 # ignore slope movement
	
	var speed : float = vec.length()
	var minspeed : float = PM_CROUCHSPEED / 10.0
	if speed < minspeed: # if we're moving <10% of PM_SPEED, just stop moving and early return
		velocity.x = 0
		velocity.z = 0
		return
	
	# apply ground friction
	var drop : float = 0
	if was_on_floor:
		var control : float = max(speed, PM_STOPSPEED)
		drop += control * PM_FRICTION * delta

	# scale the velocity
	var newspeed : float = max(speed - drop, 0) / speed
	velocity = (velocity * newspeed)


## Quake-style movement acceleration
func PM_Accelerate(wishdir : Vector3, wishspeed : float, accel : float, frame_time : float) -> void:
	var currentspeed : float = velocity.dot(wishdir)
	var addspeed : float = wishspeed - currentspeed
	if (addspeed <= 0):
		return
	var accelspeed : float = min( ( accel * frame_time * wishspeed ), addspeed ) 
	velocity += (accelspeed * wishdir)


## Returns player speed multiplied by input axes
func PM_InputScale() -> float:
	var forwardmove : float = Input.get_axis("back","forward")
	var rightmove : float = Input.get_axis("left","right")
	
	var maxmove : float = max( abs( forwardmove ), abs( rightmove ) )
	if ( !maxmove ):
		return 0
	
	# Crouchrunning
	if(is_running and is_crouching):
		return (PM_RUNSPEED / PM_CROUCHSPEED) * maxmove # TODO - jank?
	# Running
	if(is_running):
		return PM_RUNSPEED * maxmove
	# Crouching
	if(is_crouching):
		return PM_CROUCHSPEED * maxmove
	# Walking
	return PM_WALKSPEED * maxmove


## Jumping
func PM_CheckJump() -> bool:
	# TODO : not doing this at all how quake does it
	if was_on_floor: # check if we were on ground at frame start
		var buffered_jump = input_buffer_retrieve(JUMP_INPUT) # check for buffered jump input
		if !buffered_jump: # early return if we have no buffered input
			return false
		was_on_floor = false # flag that we're no longer on the floor
		velocity.y += PM_JUMP_VELOCITY # add jump velocity
		#velocity.y = PM_JUMP_VELOCITY # TODO - quake does this instead... which is better?
		return true
	return false


## Grounded movement
func PM_WalkMove(delta) -> void:
	# Check/Perform jump
	if PM_CheckJump():
		PM_AirMove(delta)
		return

	PM_Friction(delta)
	var wishdir : Vector3 = PM_Wishdir()
	var wishspeed := wishdir.length() * PM_InputScale()
	
	var accelerate : float
	if !was_on_floor: # this is really for knockback, slippery surfaces, etc
		accelerate = PM_AIRACCELERATE
	else:
		accelerate = PM_ACCELERATE
	PM_Accelerate(wishdir, wishspeed, accelerate, delta)


## Airborne movement
func PM_AirMove(delta) -> void:
	PM_Friction(delta)
	var mv_scale : float = PM_InputScale()
	var wishdir : Vector3 = PM_Wishdir()
	wishdir.y = 0
	var wishspeed := wishdir.length()
	wishspeed *= mv_scale
	
	# not on ground, so little effect on velocity
	PM_Accelerate(wishdir, wishspeed, PM_AIRACCELERATE, delta)
	
	# gravity?? -- quake doesn't do this here TODO - should this be in ground movement too?
	if not was_on_floor: velocity.y -= GRAVITY * delta


## Handles fly movement
func PM_FlyMove(delta) -> void:
	var flyspeed = 1000
	velocity.y = 0
	if Input.is_action_pressed("jump"):
		velocity.y = delta*flyspeed
	elif Input.is_action_pressed("crouch"):
		velocity.y = -delta*flyspeed


## Takes an [action] and attempts to buffer it
## Returns [true] on successful buffer, [false] on buffer fail
func buffer_input(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(input_buffer.get(action_idx) != null)
	# Action is already buffered
	if(input_buffer[action_idx] > 0.0):
		return false
	# Action is unbuffered
	else:
		input_buffer[action_idx] = input_timers[action_idx]
		return true


## Updates the input buffer, zeroing out any expired inputs
func input_buffer_update(delta : float) -> Array[int]:
	var pop_array : Array[int] = []
	for idx in input_buffer.size():
		input_buffer[idx] -= delta
		if(input_buffer[idx] <= 0.0):
			input_buffer[idx] = 0.0
			pop_array.append(idx)
	return pop_array


## If we have [action] buffered, return {true}. Else, return {false}.
func input_buffer_check(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(input_buffer.get(action_idx) != null)
	
	# If action is buffered, return true
	if(input_buffer[action_idx] > 0.0):
		return true
	return false


## If we have [action] buffered, zero it and return {true}
## Else, return {false}
func input_buffer_retrieve(action_idx : int) -> bool:
	# Assert to avoid index OOB
	assert(input_buffer.get(action_idx) != null)
	
	# If action is buffered, zero it and return true
	if (input_buffer[action_idx] > 0.0):
		input_buffer[action_idx] = 0.0
		return true
	return false


## Handles footstep sounds, viewbob
func _handle_footsteps(delta) -> void:
	var direction : Vector3 = PM_Wishdir()
	
	# On-ground footstep update
	if(was_on_floor):
		# TODO: keep track of movement to initiate a headbob animation
		if direction:
			if(footstep_timer <= 0):
				footstep_timer = footstep_time_length
				play_footstep_sound.rpc()
	
	# Update footstep timer
	if(footstep_timer > 0.0):
		footstep_timer = max(footstep_timer - delta, 0.0)
	
	# Handle movement animation based on movement direction
	# TODO: update so that this is the camera's responsibility (?)
	# TODO: update so that gun animation is dependent on headbob
	gun_controller.handle_movement_anim(direction)


## Randomly selects and then plays a footstep sound
# TODO -- this is really bad -- we're loading the file in every time
@rpc("authority","call_local","unreliable") # It's okay if a footstep sound is dropped
func play_footstep_sound() -> void:
	if($FootstepSound.playing): return
	var selection :int = randi_range(0,8)
	$FootstepSound.stream = load("res://Sounds/footsteps/boots/"+str(selection)+".ogg")
	$FootstepSound.play()


## Take damage when hit
# TODO - we should be able to shoot ourselves, and take damage from enemies
# TODO - we should get as parameter where the shot came from (as a vector)
@rpc("any_peer","reliable") # Any peer can tell us we've been shot
func receive_damage(dmg : int = 1, shooter : String = ""):
	print("ack!! i, ", multiplayer.get_unique_id(),", was shot by ", NetworkManager.players_dict[int(shooter)]["name"] + "\t" + shooter)
	health -= dmg
	HUD.update_health(health)
	if health <= 0:
		die.rpc(shooter)


## Die if out of health
# TODO TODO: is borken
# TODO: we should tell the server we've died, and ask it to handle the respawning
# TODO: add some kind of death animation / respawn time
# TODO: add better respawn logic
@rpc("any_peer","call_local","reliable")
func die(shooter : String = ""):
	reset_physics_interpolation()
	if(is_multiplayer_authority()):
		health = 3
		# TODO: this whole chunk should be moved into a spawn function
		if(!has_node("/root/MainScene/World")):
			position = Vector3.ZERO
			print("zeroed")
		else:
			var spawns : Array = get_node("/root/MainScene/World").player_spawn_positions
			var selection = randi_range(0, spawns.size()-1)
			var chosen_spawn : Marker3D = spawns[selection]
			self.position = chosen_spawn.global_position
			self.rotation.y = chosen_spawn.global_rotation.y
		HUD.update_health(health)
	if(NetworkManager.players_dict.has(int(shooter))):
		NetworkManager.players_dict[int(shooter)]["score"]+=1
	HUD.update_scores()


## Handle showing/hiding the menu
func _on_menu_key() -> void:
	paused = !paused
	if(paused):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.show()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_menu.hide()


## Handle main menu value updates
# TODO - hate that this is here
func _on_menu_value_update(value, parameter : String) -> void:
	match(parameter):
		"master_vol":
			if(value == 0.0):
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
			else:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
				var new_vol = GameManager.volume_curve.sample_baked(value/100)
				print(new_vol)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),(new_vol))
		"mouse_sense":
			camera_controller.mouse_sensitivity = value / 1000
		"cam_sense":
			camera_controller.camera_sensitivity = value / 10
		"aim_sense":
			camera_controller.aim_sensitivity = value / 1000
		"debug_box":
			camera_controller.toggle_debug(value, "box")
		"debug_dot":
			camera_controller.toggle_debug(value, "dot")
		"aim_toggle":
			aim_toggle = value
		"crouch_toggle":
			crouch_toggle = value
