extends Node3D

@export var player_scene : PackedScene # player scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node

var spawn_positions : Array[Vector3] # Stores global_position variables of spawn locations


func _ready()-> void:
	var spawn_position_nodes = scik.find_children_of_type($Spawns, Marker3D)
	for spawn in spawn_position_nodes:
		spawn_positions.append(spawn.global_position)
	player_spawner.spawn_function = _ms_player


func spawn_player(authority_pid : int) -> void:
	var player : PlayerController = player_spawner.spawn(authority_pid)
	player.global_position = spawn_positions[randi_range(0,spawn_positions.size()-1)]


## Custom spawn function override for PlayerSpawner
func _ms_player(authority_pid : int) -> PlayerController:
	var player : PlayerController= player_scene.instantiate()
	player.name = str(authority_pid)
	return player
