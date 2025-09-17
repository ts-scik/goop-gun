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
# Variables for foosteps
var footstep_timer : float = 0.0
var footstep_time_length : float = 0.5


## Set multiplayer auth
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


## Connect signals, display HUD
func _ready() -> void:
	if not is_multiplayer_authority(): return
	pause_menu.value_update.connect(_on_menu_value_update)
	
	HUD.show()
	HUD.update_health(health)


## Handle non-physics inputs (pausing, scoreboard)
func _process(_delta: float) -> void:
	if NetworkManager.peer.get_connection_status() == 0 : return # early return if we have no server
	if not is_multiplayer_authority(): return # Early return if we don't have authority (players should move themselves)
	# Pause menu
	if Input.is_action_just_pressed("pause"):
		_on_menu_key()
	# Scoreboard
	# TODO: adjust this so the scoreboard can be updating all the time
	if Input.is_action_just_pressed("scoreboard"):
		HUD.update_scores()
		HUD.scoreboard.show()
	elif Input.is_action_just_released("scoreboard"):
		HUD.scoreboard.hide()


## Handle player movement
func _physics_process(delta: float) -> void:
	# TODO: adjust this so players don't have *total* authority
	if NetworkManager.peer.get_connection_status() == 0 : return # early return if we have no server
	if not is_multiplayer_authority(): return # Early return if we don't have authority (players should move themselves)
	
	# Apply gravity if we're airborne
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Jump if we're on the floor
	# TODO: buffer jump inputs
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity .y += JUMP_VELOCITY
	
	# Handle movement inputs
	# TODO: update so we're not directly modifying velocity, add inertia, etc
	# TODO: keep track of movement to initiate a headbob animation
	# TODO: add footstep sounds
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized())
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if(footstep_timer<=0 and is_on_floor()):
			footstep_timer = footstep_time_length
			play_footstep_sound.rpc()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if(footstep_timer > 0):
		footstep_timer -= delta
	
	# Handle movement animation based on movement direction
	# TODO: update so that this is the camera's responsibility (?)
	# TODO: update so that gun animation is dependent on headbob
	gun_container.handle_movement_anim(direction)
	
	# Actually do our movement
	move_and_slide()


## Randomly selects and then plays a footstep sound
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
		if(!has_node("/root/MainScene/World")):
			position = Vector3.ZERO
		else:
			var positions : Array = get_node("/root/MainScene/World").spawn_positions
			var selection = randi_range(0, positions.size()-1)
			position = positions[selection]
		HUD.update_health(health)
	print("i am dead! killed by the evil ",shooter)
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
