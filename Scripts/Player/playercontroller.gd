## Manages all player input + movement (except for the camera)
class_name PlayerController
extends CharacterBody3D

# Movement constants
@export_category("Movement Variables")
@export_group("Jumping")
@export var GRAVITY: float			= 9.8	## Gravity velocity
@export var PM_JUMP_VELOCITY: float	= 4.5	## Jump velocity
@export_group("Movement")
@export var PM_WALKSPEED: float		= 2.5	## Move velocity
@export var PM_RUNSPEED: float		= 5.0	## Run velocity
@export var PM_CROUCHSPEED: float	= 1.5	## Crouch velocity
@export var PM_ACCELERATE: float	= 8.0		## Acceleration factor on ground
@export var PM_AIRACCELERATE: float	= 1.0	## Acceleration factor in air
@export_group("Friction")
@export var PM_FRICTION: float		= 6.0	## Friction factor when on ground
@export var PM_STOPSPEED: float		= 0.75	## Minimum speed factor for friction calculation
# Variables for foosteps
var footstep_timer: float = 0.0 ## Timer-holder for footsteps
@export_group("Footsteps")
@export var footstep_time_length: float	= 0.75	## Total time length of footstep
@export var footstep_peak_pct: float	= 0.65	## Point where footstep cannot be reversed

# Child nodes
@onready var camera_controller_anchor: Marker3D = $HeadPos
@onready var camera_controller: CameraController = $CameraController
@onready var gun_controller: GunController = $CameraController/GunController
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var HUD: CanvasLayer = $HUD

# Local player variables
var paused: bool = false	## Flag for pause menu
var health: int = 3			## HP
# Variables for movement
var was_on_floor:	bool = false	## Whether we were on floor at start of frame
var fly_enabled:	bool = false	## Flag for debug fly movement
var is_crouching:	bool = false	## Flag for crouching
var is_running:		bool = false	## Flag for running
var crouch_toggle:	bool = false	## Whether we're using toggle-crouch

# Variables for input buffering
var input_buffer: InputBuffer
enum {	## Types of bufferable inputs
	JUMP_INPUT = 0,
	SHOOT_INPUT = 1,
}
const input_timers: Dictionary = {	## Timers for bufferable inputs
	JUMP_INPUT : 0.07,
	SHOOT_INPUT : 0.08,
}


## Set up input buffer
func _enter_tree() -> void:
	# Buffer setup
	input_buffer = InputBuffer.new(input_timers)
	add_child(input_buffer)


## Handle instantaneous inputs (pausing, scoreboard, jump, mouse)
# TODO - should this all be here? (No!)
func _input(event) -> void:	
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

	# Pause menu
	if event.is_action_pressed("pause"):
		_on_menu_key()
	# Die
	elif event.is_action_pressed("kill"):
		die()


## Handle player movement
func _physics_process(delta: float) -> void:
	# TODO - should any of this be here? (No!)
	# Set walking/on_ground flag
	was_on_floor = is_on_floor()
	
	# Walking state
	if was_on_floor:
		pmove.PM_WalkMove(self, delta)
		move_and_slide()
	# Airborne state
	else:
		pmove.PM_AirMove(self, delta)
		move_and_slide()
		# If we just landed,
		if is_on_floor():
			play_footstep_sound()
			gun_controller.start_gun_shake(0.6, 2.0, 4)
			#print("landed!")
	
	# Foostep management
	_handle_footsteps(delta)


## Handles footstep sounds, viewbob
# footstep_timer goes from (0 -> footstep_time_length)
# timer increments while user is on ground and pressing input directions
# at the peak of our bob, we trigger a sound + gun_shake, but only if user
# is pressing a movement direction and is grounded *at that moment*
# TODO - should this be here? (Probably not!)
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
			gun_controller.start_gun_shake(footstep_time_length * gun_controller.footstep_gun_shake_time_pct)
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
