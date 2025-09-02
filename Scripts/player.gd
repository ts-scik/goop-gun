extends CharacterBody3D
class_name PlayerController

const JUMP_VELOCITY = 7.5
const SPEED = 8.0

var gravity = 9.8

@onready var camera_controller_anchor : Marker3D = $HeadPos
@export var gun_animation_tree : AnimationTree

var paused = false
signal menu(is_paused : bool)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity .y += JUMP_VELOCITY
		
	if Input.is_action_just_pressed("pause"):
		if(paused == false):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			paused = true
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			paused = false
		menu.emit(paused)
		
		
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized())
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	# handle animation
	# TODO: consider making this a signal
	if(direction.x != 0 or direction.z != 0):
		gun_animation_tree.set("parameters/conditions/stopped", false)
		gun_animation_tree.set("parameters/conditions/walking", true)
	else:
		gun_animation_tree.set("parameters/conditions/walking", false)
		gun_animation_tree.set("parameters/conditions/stopped", true)
	move_and_slide()
