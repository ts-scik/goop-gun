class_name GunRaycast
extends RayCast3D

const BULLET_DECAL = preload("res://Prefabs/Player/bullet_decal.tscn")


## Shoots the raycast
# TODO - update this (currently can only shoot other clients)
func shoot():
	force_raycast_update()
	if is_colliding():
		if get_collider() is PlayerController and is_multiplayer_authority():
			var hit_player : PlayerController = get_collider()
			var dmg = 1
			#print("i am ", multiplayer.get_unique_id(), " shooting ", hit_player)
			#TODO: actually do something on hit
			#hit_player.receive_damage(hit_player.get_multiplayer_authority(), dmg, str(multiplayer.get_unique_id()))
		elif get_collider() is RigidBody3D:
			var rb : RigidBody3D = get_collider()
			var hit_pos_offset = get_collision_point() - rb.global_position
			rb.apply_force(-global_basis.z*300, hit_pos_offset)
			#print("apply_force", " auth : ", get_multiplayer_authority())
		elif get_collider() is StaticBody3D or get_collider() is CSGShape3D:
			_bullet_decal(get_collision_point(), get_collision_normal())
			#print("applied_decal at", get_collision_point()," auth : ", get_multiplayer_authority())


## Applies bullet decal
# TODO - look this over
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
