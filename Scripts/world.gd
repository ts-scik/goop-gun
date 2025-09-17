extends Node3D

@export var player_scene : PackedScene # player scene
@export var barrel_scene : PackedScene # barrel scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node
@export var barrel_spawner : MultiplayerSpawner

var spawn_positions : Array[Vector3] # Stores global_position variables of spawn locations


## Store all the spawn positions
func _ready()-> void:
	var spawn_position_nodes = scik.find_children_of_type($Spawns, Marker3D)
	for spawn in spawn_position_nodes:
		spawn_positions.append(spawn.global_position)
	player_spawner.spawn_function = _ms_player
	barrel_spawner.spawn_function = _ms_barrel


## Function for spawning in a player with given pid
func spawn_player(authority_pid : int) -> void:
	var player : PlayerController = player_spawner.spawn(authority_pid)
	player.global_position = spawn_positions[randi_range(0,spawn_positions.size()-1)]


## Function for spawning in relevant entities
func spawn_entities() -> void:
	var barrel : RigidBody3D = barrel_spawner.spawn(1)
	barrel.global_position = Vector3(4,0.5,-4)


## Custom spawn function override for PlayerSpawner
func _ms_player(authority_pid : int) -> PlayerController:
	var player : PlayerController = player_scene.instantiate()
	player.name = str(authority_pid)
	return player


## Custom spawn function override for BarrelSpawner
func _ms_barrel(_authority_pid : int) -> RigidBody3D:
	var barrel : RigidBody3D = barrel_scene.instantiate()
	return barrel
