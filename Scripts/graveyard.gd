extends Node

@export var gun_container : GunController
@export var player_camera : Camera3D
var gun_hold_distance = 0.5
var mouse_position = Vector2.ZERO
## Updates the gun's position+rotation (for if gun exists in global space)
func update_gun_global_space():
	# Update whether gun is global/local
	gun_container.top_level = true
	# Update the gun's position
	gun_container.global_position = (player_camera.project_position(mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	var player_camera_interp = player_camera.get_global_transform_interpolated().origin # get interpolated player_camera position in local space
	var gun_container_interp = gun_container.get_global_transform_interpolated().origin # get interpolated gun_container position in local space
	var fw_dir = gun_container_interp - player_camera_interp # find vector from player camera to gun_container (interpolated)
	var up_dir = self.basis.y
	gun_container.basis = Basis.looking_at(fw_dir, up_dir, false)
