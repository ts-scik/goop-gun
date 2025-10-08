## State for camera+gun management when completely Unaimed
extends StandardCameraState


## [OVERRIDE]
## Override -- we don't want gun sway for unaimed state
func _determine_gun_sway(_delta) -> Vector3:
	return Vector3.ZERO


## [ABSTRACT IMPL]
## Determines current zoom fov -- returns fully-unzoomed FOV, since we're unaimed
func _determine_zoom_fov() -> float:
	return cmk.desired_fov


## [ABSTRACT IMPL]
## Animates gun in/out of aiming position
func _get_gun_target_transform(_delta) -> Transform3D:
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var unaimed_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.holstered_pos) + # holstered position (relative to player)
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this -- # TODO -- why??
	)
	var unaimed_target_rot : Vector3 = cmk.gck.holstered_rot - Vector3(cmk.rotation.x,0,0)
	
	# Determine unaimed TF
	var out_tf : Transform3D = Transform3D(
		Basis.from_euler(unaimed_target_rot),
		unaimed_target_pos
	)
	
	# snap to target tf
	cmk.gck.rotation = out_tf.basis.get_euler() # rotation rather than basis, so we maintain scale
	cmk.gck.position = out_tf.origin
	
	return out_tf


## [ABSTRACT IMPL]
## Determines whether we should change state
func _check_state_transitions() -> void:
	# If we're trying to aim, start doing it!
	if cmk.pmk.aim_held:
		finished.emit("AimIn")
