extends Node3D

@export var player_scene : PackedScene
@export var player_spawner : MultiplayerSpawner
var spawn_positions : Array[Vector3]


func _ready()-> void:
	var spawn_position_nodes = scik.find_children_of_type($Spawns, Marker3D)
	for spawn in spawn_position_nodes:
		spawn_positions.append(spawn.global_position)
	player_spawner.spawn_function = _ms_player


func spawn_player(authority_pid : int) -> void:
	player_spawner.spawn(authority_pid)


func _ms_player(authority_pid : int) -> PlayerController:
	var player = player_scene.instantiate()
	player.name = str(authority_pid)
	
	return player
