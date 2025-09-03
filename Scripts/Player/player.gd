extends CharacterBody3D
class_name PlayerController

const JUMP_VELOCITY = 4.5
const SPEED = 8.0
const GRAVITY = 9.8

@onready var camera_controller_anchor : Marker3D = $HeadPos
@onready var gun_container = get_node("CameraController/GunController")
@onready var player_camera_ctrlr = get_node("CameraController")
@onready var pause_menu : CanvasLayer = get_node("PauseMenu")
var paused = false
var player_name = "DefaultName"


## Set multiplayer auth
func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


## Connect signals
func _ready() -> void:
	if not is_multiplayer_authority(): return
	pause_menu.value_update.connect(_on_menu_value_update)


## Handle pausing
func _process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	if Input.is_action_just_pressed("pause"):
			if(paused == false):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				paused = true
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				paused = false
			_on_menu_key(paused)


## Handle player movement
func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): return
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity .y += JUMP_VELOCITY
	
	# Handle movement inputs
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized())
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# Handle movement animation
	gun_container.handle_movement_anim(direction)
	
	# Actually do our movement
	move_and_slide()


## Handle showing/hiding the menu
func _on_menu_key(is_paused: bool) -> void:
	if(is_paused):
		pause_menu.show()
	else:
		pause_menu.hide()


## Handle main menu value updates
func _on_menu_value_update(value, parameter : String) -> void:
	match(parameter):
		"cam_sense":
			player_camera_ctrlr.camera_sensitivity = value / 1000
		"aim_sense":
			player_camera_ctrlr.aim_sensitivity = value / 1000
		"debug":
			player_camera_ctrlr.toggle_debug(value)
