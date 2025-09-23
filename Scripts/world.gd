extends Node3D

@export var player_scene : PackedScene # player scene
@export var barrel_scene : PackedScene # barrel scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node
@export var barrel_spawner : MultiplayerSpawner

var rooms_generator : RoomsGenerator

## Store all the spawn positions
func _ready()-> void:
	player_spawner.spawn_function = _ms_player
	barrel_spawner.spawn_function = _ms_barrel
	rooms_generator = self.get_node("RoomsGenerator")


## Function for spawning in a player with given pid
func spawn_player(authority_pid : int) -> void:
	var player : PlayerController = player_spawner.spawn(authority_pid)
	var player_spawn_positions = rooms_generator.player_spawn_positions
	if player_spawn_positions.is_empty():
		player.position = Vector3.ZERO
		return
	var chosen_spawn : Marker3D = player_spawn_positions[randi_range(0,player_spawn_positions.size()-1)]
	player.position = chosen_spawn.global_position
	player.rotation.y = chosen_spawn.global_rotation.y


## Function for spawning in relevant entities
func spawn_entities() -> void:
	var barrel : RigidBody3D = barrel_spawner.spawn(1)
	var barrel_spawn_positions = rooms_generator.barrel_spawn_positions
	if barrel_spawn_positions.is_empty():
		barrel.global_position = Vector3.ZERO + (Vector3.FORWARD * 3)
		return
	barrel.global_position = barrel_spawn_positions[randi_range(0,barrel_spawn_positions.size()-1)].global_position


## Custom spawn function override for PlayerSpawner
func _ms_player(authority_pid : int) -> PlayerController:
	var player : PlayerController = player_scene.instantiate()
	player.name = str(authority_pid)
	return player


## Custom spawn function override for BarrelSpawner
func _ms_barrel(_authority_pid : int) -> RigidBody3D:
	var barrel : RigidBody3D = barrel_scene.instantiate()
	return barrel


## Generates and returns world_data for world setup and sharing with clients
func generate_world_data() -> Array:
	return []
	#return rooms_generator.generate_world_data()


## Loads in the world
func load_world(world_data : Array):
	#rooms_generator.load_world(world_data)
	var geometry = load ("res://Prefabs/Level/geometry.tscn").instantiate()
	add_child(geometry)
