class_name PlayerController
extends CharacterBody3D
## Manages all player input + movement (except for the camera)


# Movement constants
const JUMP_VELOCITY = 4.5
const SPEED = 8.0
const GRAVITY = 9.8

# Child nodes
@onready var camera_controller_anchor : Marker3D = $HeadPos
@onready var gun_container = get_node("CameraController/GunController")
@onready var player_camera_ctrlr = get_node("CameraController")
@onready var pause_menu : CanvasLayer = get_node("PauseMenu")
@onready var HUD : CanvasLayer = get_node("HUD")

# Local player variables
var paused = false
var health : int = 3
var score : int = 0
# Variables for movement
var pml_walking : bool = false
# Variables for foosteps
var footstep_timer : float = 0.0
var footstep_time_length : float = 0.5


## Set multiplayer auth
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


## Connect signals, display HUD
func _ready() -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	pause_menu.value_update.connect(_on_menu_value_update)
	_HUD_setup()


## Setup HUD
# Called during _ready()
func _HUD_setup() -> void:
	HUD.show()
	HUD.update_health(health)
	
	HUD.get_node("SpeedContainer/Speed").set_tracked_node(self)


## Handle non-physics inputs (pausing, scoreboard)
func _input(event) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return

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


## Handle player movement
func _physics_process(delta: float) -> void:
	# TODO: adjust this so players don't have *total* authority ??
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# Set walking/on_ground flag
	pml_walking = is_on_floor()

	# Handle movement inputs
	var fly_debug = false # TODO DEBUG
	if fly_debug: # TODO DEBUG
		fly_movement(delta)
	elif pml_walking:
		# walking on ground
		PM_WalkMove(delta)
	else:
		# airborne
		PM_AirMove(delta)
	
	# TODO: keep track of movement to initiate a headbob animation
	# TODO: add footstep sounds
	var direction = get_direction()
	if direction:
		if(footstep_timer<=0 and pml_walking):
			footstep_timer = footstep_time_length
			play_footstep_sound.rpc()
	if(footstep_timer > 0):
		footstep_timer -= delta
	
	# Handle movement animation based on movement direction
	# TODO: update so that this is the camera's responsibility (?)
	# TODO: update so that gun animation is dependent on headbob
	gun_container.handle_movement_anim(direction)
	
	# Actually do our movement
	move_and_slide()


## Returns player's current wishdir (normalized!)
# TODO : combine this and wishvel below
func get_direction() -> Vector3:
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized())
	return direction


## Returns player's current wishvel -- NOT NORMALIZED
func get_wishvel() -> Vector3:
	var fmove := Input.get_axis("back","forward")
	var smove := Input.get_axis("left","right")
	var wishvel : Vector3 = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x
	wishvel.x = (forward.x * fmove) + (right.x * smove)
	wishvel.z = (forward.z * fmove) + (right.z * smove)
	wishvel.y = (forward.y * fmove) + (right.y * smove)
	return wishvel


## Applies friction to velocity
func PM_Friction(delta : float) -> void:
	var PM_FRICTION : float = 4.0 # Friction factor when on ground -- TODO : tweak this, make const
	var PM_STOPSPEED : float = 10.0 # Friction gets multiplied by PM_STOPSPEED when we're moving slower than PM_STOPSPEED -- TODO : why??, make const
	
	var vec : Vector3 = velocity
	if pml_walking: #pml.walking
		vec.y = 0 # ignore slope movement
	
	var speed : float = vec.length()
	if speed < 1: # if we're moving super-slow, just stop moving and early return
		velocity.x = 0
		velocity.z = 0
		return
	
	var drop : float = 0
	
	# apply ground friction
	if pml_walking: #??? pml.walking
		var control : float
		if(speed < PM_STOPSPEED):
			control = PM_STOPSPEED
		else:
			control = speed
		drop += control * PM_FRICTION * delta

	# scale the velocity
	var newspeed : float = speed - drop
	if (newspeed < 0):
		newspeed = 0
	newspeed /= speed
	
	velocity.x = velocity.x * newspeed
	velocity.z = velocity.z * newspeed
	velocity.y = velocity.y * newspeed # ?????


## Quake-style movement acceleration
func PM_Accelerate(wishdir : Vector3, wishspeed : float, accel : float, frame_time : float) -> void:
	var addspeed : float
	var accelspeed : float
	var currentspeed : float
	
	currentspeed = velocity.dot(wishdir)
	addspeed = wishspeed - currentspeed
	if (addspeed <= 0):
		return
	accelspeed = accel * frame_time * wishspeed
	if (accelspeed > addspeed):
		accelspeed = addspeed
	
	velocity.x += accelspeed * wishdir.x
	velocity.z += accelspeed * wishdir.z
	velocity.y += accelspeed * wishdir.y # ?????


## Returns the scale factor to apply to cmd movements
## "This allows clients to use axial -127 to 127 values for all directions without getting a sqrt(2) distortion in speed."
func PM_CmdScale() -> float:
	var scale_factor : float = 1.0 # ??? why 127 in quake? TODO
	var speed : int = 6 # player's speed? TODO: move this elswehere
	
	var forwardmove : float = Input.get_axis("back","forward")
	var rightmove : float = Input.get_axis("left","right")
	
	var maxim : float = abs( forwardmove )
	if( abs( rightmove ) > maxim):
		maxim = abs ( rightmove )
	if ( !maxim ):
		return 0
	
	# TODO: something is going wrong here
	#var total : float = sqrt( (forwardmove * forwardmove)+ (rightmove * rightmove) )
	#var mv_scale : float = speed * maxim / (scale_factor * total)
	
	var mv_scale : float = speed * maxim / scale_factor
	return mv_scale


## Jumping
# not doing this at all how quake does it
func PM_CheckJump() -> bool:
	# TODO : buffer jump input
	if Input.is_action_just_pressed("jump") and pml_walking:
	#if Input.is_action_pressed("jump"):
		pml_walking = false # flag that we're no longer on the floor
		velocity.y += JUMP_VELOCITY
		#velocity.y = JUMP_VELOCITY # TODO - quake does this instead... which is better?
		return true
	
	return false


## Grounded movement
const PM_ACCELERATE : float = 10.0
const PM_AIRACCELERATE : float = 1.0
func PM_WalkMove(delta) -> void:
	# Check/Perform jump
	if PM_CheckJump():
		PM_AirMove(delta)
		return

	PM_Friction(delta)
	var mv_scale : float = PM_CmdScale()
	var wishvel : Vector3 = get_wishvel()
	var wishdir : Vector3 = wishvel.normalized() # ??? should normalize ???
	var wishspeed := wishdir.length() # ???
	wishspeed *= mv_scale

	# TODO : clamp wishspeed if crouching
	
	var accelerate : float
	if !pml_walking: # this is really for knockback, slippery surfaces, etc
		accelerate = PM_AIRACCELERATE
	else:
		accelerate = PM_ACCELERATE
	PM_Accelerate(wishdir, wishspeed, accelerate, delta)


## Airborne movement
func PM_AirMove(delta) -> void:
	PM_Friction(delta)
	var mv_scale : float = PM_CmdScale()
	var wishvel : Vector3 = get_wishvel()
	wishvel.y = 0
	var wishdir : Vector3 = wishvel.normalized() # ??? should normalize ???
	var wishspeed := wishdir.length() # ???
	wishspeed *= mv_scale
	
	# not on ground, so little effect on velocity
	PM_Accelerate(wishdir, wishspeed, PM_AIRACCELERATE, delta)
	
	# gravity?? -- quake doesn't do this here TODO
	if not pml_walking: velocity.y -= GRAVITY * delta


## Randomly selects and then plays a footstep sound
# TODO -- this is really bad -- we're loading the file in every time
@rpc("authority","call_local","unreliable") # It's okay if a footstep sound is dropped
func play_footstep_sound() -> void:
	if($FootstepSound.playing): return
	var selection :int = randi_range(0,8)
	$FootstepSound.stream = load("res://Sounds/footsteps/boots/"+str(selection)+".ogg")
	$FootstepSound.play()


## Take damage when hit
@rpc("any_peer","reliable") # Any peer can tell us we've been shot
func receive_damage(dmg : int = 1, shooter : String = ""):
	print("ack!! i, ", multiplayer.get_unique_id(),", was shot by ", NetworkManager.players_dict[int(shooter)]["name"] + "\t" + shooter)
	health -= dmg
	HUD.update_health(health)
	if health <= 0:
		die.rpc(shooter)


## Die if out of health
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
		print("i am dead! killed by the evil ",shooter)
		NetworkManager.players_dict[int(shooter)]["score"]+=1
	HUD.update_scores()


## Handles fly movement
func fly_movement(delta) -> void:
	var flyspeed = 1000
	velocity.y = 0
	if Input.is_action_pressed("jump"):
		velocity.y = delta*flyspeed
	elif Input.is_action_pressed("crouch"):
		velocity.y = -delta*flyspeed


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
			player_camera_ctrlr.mouse_sensitivity = value / 1000
		"cam_sense":
			player_camera_ctrlr.camera_sensitivity = value / 10
		"aim_sense":
			player_camera_ctrlr.aim_sensitivity = value / 1000
		"debug_box":
			player_camera_ctrlr.toggle_debug(value, "box")
		"debug_dot":
			player_camera_ctrlr.toggle_debug(value, "dot")
		"aim_toggle":
			player_camera_ctrlr.aim_toggle = value
