extends Node3D

@export var player_scene : PackedScene # player scene
@export var barrel_scene : PackedScene # barrel scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node
@export var barrel_spawner : MultiplayerSpawner

var player_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations
var barrel_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations


## Store all the spawn positions
func _ready()-> void:
	#var spawn_position_nodes = scik.find_children_of_type($Spawns, Marker3D)
	#for spawn in spawn_position_nodes:
	#	spawn_positions.append(spawn.global_position)
	player_spawner.spawn_function = _ms_player
	barrel_spawner.spawn_function = _ms_barrel


## Function for spawning in a player with given pid
func spawn_player(authority_pid : int) -> void:
	var player : PlayerController = player_spawner.spawn(authority_pid)
	player.global_position = player_spawn_positions[randi_range(0,player_spawn_positions.size()-1)].global_position


## Function for spawning in relevant entities
func spawn_entities() -> void:
	var barrel : RigidBody3D = barrel_spawner.spawn(1)
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


## Loads in gameworld
func load_world(world_data : Array) -> void:
	for x in world_data.size():
		for y in world_data[x].size():
			var pos = Vector2(x,y)
			var c_room_name = world_data[pos.x][pos.y]
			var c_room : ModularRoom = load("res://Prefabs/Level/Rooms/"+c_room_name+".tscn").instantiate()
			add_child(c_room)
			c_room.global_position = grid_to_world(pos.x, 0, pos.y)
			player_spawn_positions.append_array(c_room.PlayerSpawns)
			barrel_spawn_positions.append_array(c_room.BarrelSpawns)


## Converts world_data grid position to real coordinates
func grid_to_world(x, y, z) -> Vector3:
	var grid_size = 15
	return Vector3(x*grid_size, y*grid_size, z*grid_size)
