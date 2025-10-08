## State for camera+gun management when transitioning from Aimed -> Unaimed
extends StandardCameraState


## [ABSTRACT IMPL]
## Returns desired FOV value at current frame
func _determine_zoom_fov() -> float:
	if not cmk.enable_aim_zoom or cmk.ads_ratio() <= 0.0:
		return cmk.desired_fov
	return lerpf(
		cmk.desired_fov,
		cmk.desired_fov * cmk.aimed_fov_percent,
		cmk.ads_ratio()
	)


## [ABSTRACT IMPL]
## Animates gun in/out of aiming position
func _get_gun_target_transform(delta) -> Transform3D:
	# --- Ending an aim --- #
	# get unaimed target pos/rot
	var unaimed_tf = _get_gun_unaimed_tf()
	
	# update the aim timer
	cmk.ads_timer = max(cmk.ads_timer - delta, 0.0)
	
	# Aim transition lerp
	var out_tf : Transform3D
	out_tf.origin = lerp(
		unaimed_tf.origin,
		cmk.gck.last_aimed_target_pos,
		cmk.ads_ratio()
	)
	out_tf.basis = Basis.from_euler(
		lerp(
			unaimed_tf.basis.get_euler(),
			cmk.gck.last_aimed_target_rot,
			cmk.ads_ratio()
		)
	)
	
	# snap to target tf
	cmk.gck.rotation = out_tf.basis.get_euler() # rotation, not basis -- preserve scale
	cmk.gck.position = out_tf.origin
	return out_tf


## [ABSTRACT IMPL]
## Determines whether we should change state
func _check_state_transitions() -> void:
	# If we're no longer trying to aim out, aim in
	# ... unless we're trying to aim while sprinting, and still above the sprint aim cap
	var max_aim_amt = cmk.ads_time * 0.4 if cmk.pmk.is_running else cmk.ads_time 
	if cmk.pmk.aim_held and cmk.ads_timer < max_aim_amt:
		finished.emit("AimIn")
	# If we've fully aimed out, transition to Unaimed
	if cmk.ads_ratio() <= 0.0:
		finished.emit("Unaimed")
