## State for camera+gun management when transitioning from Unaimed -> Aimed
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
	# --- Starting an aim --- #
	# get unaimed target pos/rot
	var unaimed_tf = _get_gun_unaimed_tf()
	
	# cap our max aim amount if the player is running
	var max_aim_amt : float = cmk.ads_time * 0.4 if cmk.pmk.is_running else cmk.ads_time 
	
	# update the aim timer
	cmk.ads_timer = min(cmk.ads_timer + delta, max_aim_amt)
	
	# Store our last-aimed targets --
	# We're transitioning to an aimed TF target, and we're storing that TF target
	cmk.gck.last_aimed_target_pos = Vector3(0,0,-cmk.gck.gun_hold_distance)
	cmk.gck.last_aimed_target_rot = Vector3.ZERO
	
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
	# If we're no longer trying to aim, aim out
	if !cmk.pmk.aim_held:
		finished.emit("AimOut")
	# If we're finished aiming in, set to Aimed
	elif cmk.ads_ratio() >= 1.0:
		finished.emit("Aimed")
