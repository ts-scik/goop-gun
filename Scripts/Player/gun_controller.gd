class_name GunController
extends Node3D
## Manages a player's gun animations/sounds/shooting

@onready var anim_tree : AnimationTree = get_node("GunAnimationTree")
@onready var anim_player : AnimationPlayer = get_node("GunAnimator")
@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var ray : RayCast3D = get_node("GunRaycast")


## Shoots
@rpc("authority","call_local","unreliable")
func shoot():
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle animation
	anim_player.stop()
	anim_player.play("shoot")


## Handles animations
#TODO: i hate this
func handle_movement_anim(direction : Vector3):
	if(direction.x != 0 or direction.z != 0):
		anim_tree.set("parameters/conditions/stopped", false)
		anim_tree.set("parameters/conditions/walking", true)
	else:
		anim_tree.set("parameters/conditions/walking", false)
		anim_tree.set("parameters/conditions/stopped", true)
