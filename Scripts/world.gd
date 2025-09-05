extends Node3D

var spawn_positions : Array[Vector3]

func _ready()-> void:
	var spawn_position_nodes = scik.find_children_of_type($Spawns, Marker3D)
	for spawn in spawn_position_nodes:
		spawn_positions.append(spawn.global_position)
