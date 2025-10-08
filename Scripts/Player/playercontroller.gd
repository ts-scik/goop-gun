## Manages all player input + movement (except for the camera)
class_name PlayerController
extends CharacterBody3D

# Movement constants
@export_category("Movement Variables")
@export_group("Jumping")
@export var GRAVITY : float = 9.8
@export var PM_JUMP_VELOCITY : float = 4.5 # jump velocity
@export_group("Movement")
@export var PM_WALKSPEED : float = 2.5 # move velocity
@export var PM_RUNSPEED : float = 5 # run velocity
@export var PM_CROUCHSPEED : float = 1.5 # crouch velocity
@export var PM_ACCELERATE : float = 8.0 # Acceleration factor on ground
@export var PM_AIRACCELERATE : float = 1.0 # Acceleration factor in air
@export_group("Friction")
@export var PM_FRICTION : float = 6.0 # Friction factor when on ground
@export var PM_STOPSPEED : float = 0.75 # Minimum speed factor for friction calculation
# Variables for foosteps
var footstep_timer : float = 0.0
@export_group("Footsteps")
@export var footstep_time_length : float = 0.75
@export var footstep_peak_pct : float = 0.65

# Child nodes
@onready var camera_controller_anchor : Marker3D = $HeadPos
@onready var camera_controller : CameraController = get_node("CameraController")
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
# Variables for gun handling
var aim_held : bool = false # Flag for ADS input
var aim_toggle : bool = false # Whether or not we're using toggle-aim

# Variables for input buffering
var input_buffer : InputBuffer
enum {
	JUMP_INPUT = 0,
	SHOOT_INPUT = 1,
}
const input_timers : Dictionary = {
	JUMP_INPUT : 0.07,
	SHOOT_INPUT : 0.2,
}


## Set up input buffer
func _enter_tree() -> void:
	# Buffer setup
	input_buffer = InputBuffer.new(input_timers)


## Handle instantaneous inputs (pausing, scoreboard, jump, mouse)
# TODO - should this all be here?
func _input(event) -> void:	
	# Mouse
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("shoot_btn"):
			input_buffer.buffer_input(SHOOT_INPUT)
		elif event.is_action_pressed("aim_btn"):
			# Toggle-aim
			if(aim_toggle):
				aim_held = !aim_held
			# Hold-to-aim (press)
			else:
				aim_held = true
		elif event.is_action_released("aim_btn") and !aim_toggle:
			# Hold-to-aim (release)
			aim_held = false

	# Crouching/running/jumping
	if event.is_action_pressed("jump"):
		input_buffer.buffer_input(JUMP_INPUT)
	elif event.is_action_pressed("run"):
		# runninng - TODO -- should we be doing this here? should there be a "can run"?
		is_running = true
	elif event.is_action_released("run"):
		is_running = false
	elif event.is_action_pressed("crouch"):
		# TODO - should there be a "can crouch" type deal??
		# toggle crouch
		if crouch_toggle:
			is_crouching = !is_crouching
		# hold to crouch (press)
		else:
			is_crouching = true
	elif event.is_action_released("crouch") and !crouch_toggle:
		# hold to crouch (release)
		is_crouching = false
	# TODO !!

	# Pause menu
	if event.is_action_pressed("pause"):
		_on_menu_key()
	# Die
	elif event.is_action_pressed("kill"):
		die()


## Handles gamepad aiming/shooting
## Effectively converts LT/RT into buttons
# TODO - there must be a better way of doing this
var recent_gamepad_shoot := false
var recent_gamepad_aim := false
func _input_shoot_ads_gamepad() -> void:
	var shoot_amount = Input.get_action_strength("shoot_axis")
	var aim_amount = Input.get_action_strength("aim_axis")
	
	var shoot_threshold = 0.25 # TODO - export
	var aim_threshold = 0.1 # TODO - export
	
	# Release -- reset flags
	if(recent_gamepad_shoot and shoot_amount < shoot_threshold):
		recent_gamepad_shoot = false
	if(recent_gamepad_aim and aim_amount < aim_threshold):
		if(!aim_toggle):
			aim_held = false
		recent_gamepad_aim = false
	
	# Press -- set flags
	if(!recent_gamepad_shoot and shoot_amount > shoot_threshold):
		input_buffer.buffer_input(SHOOT_INPUT)
		recent_gamepad_shoot = true
	if(!recent_gamepad_aim and aim_amount > aim_threshold):
		if(aim_toggle):
			aim_held = !aim_held
		else:
			aim_held = true
		recent_gamepad_aim = true


## Handle buffered inputs
func _process(_delta: float) -> void:
	# Handle gamepad shoot/ads
	_input_shoot_ads_gamepad()
	
	# Try to shoot
	# TODO - should this be here? probably not!!
	var reshoot_cutoff : float = 0.75 # TODO export
	var can_shoot : bool = (gun_controller.shoot_time_remaining() >= reshoot_cutoff and camera_controller.is_aiming)
	if(can_shoot):
		var buffered_shoot = input_buffer.buffer_retrieve(SHOOT_INPUT) # check for buffered shoot input
		if(buffered_shoot):
			camera_controller.camera_shoot()
			gun_controller.shoot()


## Handle player movement
func _physics_process(delta: float) -> void:
	# TODO - should any of this be here?
	# Set walking/on_ground flag
	was_on_floor = is_on_floor()
	
	# Foostep management
	_handle_footsteps(delta)


## Handles footstep sounds, viewbob
# footstep_timer goes from (0 -> footstep_time_length)
# timer increments while user is on ground and pressing input directions
# at the peak of our bob, we trigger a sound + gun_shake, but only if user
# is pressing a movement direction and is grounded *at that moment*
# TODO - should this be here?
var dip_passed : bool = false
func _handle_footsteps(delta) -> void:
	var direction : Vector3 = pmove.PM_Wishdir(self)
	var peak_threshold = footstep_peak_pct * footstep_time_length
	var rate : float = 1.0
	if(is_running):
		rate *= PM_RUNSPEED / PM_WALKSPEED
	if(is_crouching):
		rate *= PM_CROUCHSPEED / PM_WALKSPEED
	
	# If we're on the ground and moving, move the timer forward
	if(was_on_floor and direction):
		footstep_timer = min(footstep_timer + (delta*rate), footstep_time_length)
		# If we *just* passed the peak, trigger our sound and gunshake
		if(footstep_timer >= peak_threshold) and (dip_passed == false):
			play_footstep_sound()
			gun_controller.start_gun_shake(footstep_time_length)
		# If the timer has topped out, reset the timer
		if(footstep_timer >= footstep_time_length):
			footstep_timer = 0.0
			dip_passed = false
	# If we've stopped moving, but haven't hit the peak yet, reverse
	elif(footstep_timer < peak_threshold):
		footstep_timer = max(footstep_timer - delta, 0)
	# If we've stopped moving, and we've already passed the peak, just finish the anim
	else:
		footstep_timer = min(footstep_timer + delta, footstep_time_length)
	
	# Flag if we've passed the peak
	if(footstep_timer >= peak_threshold):
		dip_passed = true


## Randomly selects and then plays a footstep sound
# TODO -- this is really bad -- we're loading the file in every time
func play_footstep_sound() -> void:
	if($FootstepSound.playing): return
	var selection :int = randi_range(0,8)
	$FootstepSound.stream = load("res://Sounds/footsteps/boots/"+str(selection)+".ogg")
	$FootstepSound.play()


## Take damage when hit
# TODO - we should be able to shoot ourselves, and take damage from enemies
# TODO - we should get as parameter where the shot came from (as a vector)
func receive_damage(dmg : int = 1):
	health -= dmg
	HUD.update_health(health)
	if health <= 0:
		die()


## Die if out of health
func die():
	reset_physics_interpolation()
	health = 3
	# TODO - actually respawn
	HUD.update_health(health)


## Handle showing/hiding the menu
func _on_menu_key() -> void:
	paused = !paused
	if(paused):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu.show()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		pause_menu.hide()
