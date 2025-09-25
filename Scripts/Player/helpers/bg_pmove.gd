class_name pmove
## Based on quake 3 "bg_pmove.c"


## Handles per-physics-frame movement updates
static func movement_update(pmk : PlayerController, delta : float) -> void:
	# Handle movement inputs
	if pmk.fly_enabled:
		# fly movement (for debug)
		PM_FlyMove(pmk, delta)
	elif pmk.was_on_floor:
		# walking on ground
		PM_WalkMove(pmk, delta)
	else:
		# airborne
		PM_AirMove(pmk, delta)


## Returns player's current wishdir (normalized!)
static func PM_Wishdir(pmk : PlayerController) -> Vector3:
	var fmove := Input.get_axis("back","forward")
	var smove := Input.get_axis("left","right")
	# (forward * fmove + right * smove).normalized()
	return ( ( -pmk.transform.basis.z * fmove ) + ( pmk.transform.basis.x * smove ) ).normalized()


## Applies friction to velocity
static func PM_Friction(pmk : PlayerController, delta : float) -> void:
	var vec : Vector3 = pmk.velocity # what is this even for
	if pmk.was_on_floor:
		# TODO : should this be on vec or velocity??
		vec.y = 0 # ignore slope movement
	
	var speed : float = vec.length()
	var minspeed : float = pmk.PM_CROUCHSPEED / 10.0
	if speed < minspeed: # if we're moving <10% of PM_SPEED, just stop moving and early return
		pmk.velocity.x = 0
		pmk.velocity.z = 0
		return
	
	# apply ground friction
	var drop : float = 0
	if pmk.was_on_floor:
		var control : float = max(speed, pmk.PM_STOPSPEED)
		drop += control * pmk.PM_FRICTION * delta

	# scale the velocity
	var newspeed : float = max(speed - drop, 0) / speed
	pmk.velocity *= newspeed


## Quake-style movement acceleration
static func PM_Accelerate(pmk : PlayerController, wishdir : Vector3, wishspeed : float, accel : float, frame_time : float) -> void:
	var currentspeed : float = pmk.velocity.dot(wishdir)
	var addspeed : float = wishspeed - currentspeed
	if (addspeed <= 0):
		return
	var accelspeed : float = min( ( accel * frame_time * wishspeed ), addspeed ) 
	pmk.velocity += (accelspeed * wishdir)


## Returns player speed multiplied by input axes
static func PM_InputScale(pmk : PlayerController) -> float:
	var forwardmove : float = Input.get_axis("back","forward")
	var rightmove : float = Input.get_axis("left","right")
	
	var maxmove : float = max( abs( forwardmove ), abs( rightmove ) )
	if ( !maxmove ):
		return 0
	
	# Crouchrunning
	if(pmk.is_running and pmk.is_crouching):
		return (pmk.PM_RUNSPEED / pmk.PM_CROUCHSPEED) * maxmove # TODO - jank?
	# Running
	if(pmk.is_running):
		return pmk.PM_RUNSPEED * maxmove
	# Crouching
	if(pmk.is_crouching):
		return pmk.PM_CROUCHSPEED * maxmove
	# Walking
	return pmk.PM_WALKSPEED * maxmove


## Jumping
static func PM_CheckJump(pmk : PlayerController) -> bool:
	# TODO : not doing this at all how quake does it
	if pmk.was_on_floor: # check if we were on ground at frame start
		var buffered_jump = pmk.input_buffer.buffer_retrieve(pmk.JUMP_INPUT) # check for buffered jump input
		if !buffered_jump: # early return if we have no buffered input
			return false
		pmk.was_on_floor = false # flag that we're no longer on the floor
		pmk.velocity.y += pmk.PM_JUMP_VELOCITY # add jump velocity
		#pmk.velocity.y = pmk.PM_JUMP_VELOCITY # TODO - quake does this instead... which is better?
		return true
	return false


## Grounded movement
static func PM_WalkMove(pmk : PlayerController, delta) -> void:
	# Check/Perform jump
	if PM_CheckJump(pmk):
		PM_AirMove(pmk, delta)
		return

	PM_Friction(pmk, delta)
	var wishdir : Vector3 = PM_Wishdir(pmk)
	var wishspeed := wishdir.length() * PM_InputScale(pmk)
	
	var accelerate : float
	if !pmk.was_on_floor: # this is really for knockback, slippery surfaces, etc
		accelerate = pmk.PM_AIRACCELERATE
	else:
		accelerate = pmk.PM_ACCELERATE
	PM_Accelerate(pmk, wishdir, wishspeed, accelerate, delta)


## Airborne movement
static func PM_AirMove(pmk : PlayerController, delta : float) -> void:
	PM_Friction(pmk, delta)
	var mv_scale : float = PM_InputScale(pmk)
	var wishdir : Vector3 = PM_Wishdir(pmk)
	wishdir.y = 0
	var wishspeed := wishdir.length()
	wishspeed *= mv_scale
	
	# not on ground, so little effect on velocity
	PM_Accelerate(pmk, wishdir, wishspeed, pmk.PM_AIRACCELERATE, delta)
	
	# gravity?? -- quake doesn't do this here TODO - should this be in ground movement too?
	if not pmk.was_on_floor:
		pmk.velocity.y -= pmk.GRAVITY * delta


## Handles fly movement
static func PM_FlyMove(pmk : PlayerController, delta : float) -> void:
	var flyspeed = 1000
	pmk.velocity.y = 0
	if Input.is_action_pressed("jump"):
		pmk.velocity.y = delta*flyspeed
	elif Input.is_action_pressed("crouch"):
		pmk.velocity.y = -delta*flyspeed
