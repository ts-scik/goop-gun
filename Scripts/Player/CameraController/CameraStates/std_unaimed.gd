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
	# get unaimed target pos/rot
	var unaimed_tf = _get_gun_unaimed_tf()
	
	# snap to target tf
	cmk.gck.rotation = unaimed_tf.basis.get_euler() # rotation, not basis -- preserve scale
	cmk.gck.position = unaimed_tf.origin
	
	return unaimed_tf


## [ABSTRACT IMPL]
## Determines whether we should change state
func _check_state_transitions() -> void:
	# If we're trying to aim, start doing it!
	if cmk.pmk.aim_held:
		finished.emit("AimIn")
