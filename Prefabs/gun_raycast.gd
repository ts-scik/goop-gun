extends RayCast3D

const BULLET_DECAL = preload("res://Prefabs/bullet_decal.tscn")


## Shoots the raycast
func shoot():
	force_raycast_update()
	if is_colliding():
		if get_collider() is RigidBody3D:
			var rb : RigidBody3D = get_collider()
			var hit_pos_offset = get_collision_point() - rb.global_position
			rb.apply_force(-global_basis.z*300, hit_pos_offset)
		if get_collider() is StaticBody3D or get_collider() is CSGShape3D:
			_bullet_decal(get_collision_point(), get_collision_normal())


## Applies bullet decal
func _bullet_decal(pos:Vector3, normal:Vector3) -> void:
	var decal : Node3D = BULLET_DECAL.instantiate()
	get_tree().current_scene.add_child(decal)
	decal.position = pos
	
	if abs(normal) != abs(Vector3.UP):
		decal.look_at(decal.position+normal, Vector3.UP)
		decal.transform = decal.transform.rotated_local(Vector3.LEFT, TAU/4)
	decal.rotate(normal, randf_range(0, TAU))
	
	await get_tree().create_timer(1.5).timeout
	decal.queue_free()
