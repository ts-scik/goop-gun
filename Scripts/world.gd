extends Node3D

@export var player_scene : PackedScene # player scene
@export var barrel_scene : PackedScene # barrel scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node
@export var barrel_spawner : MultiplayerSpawner

var rooms_generator

## Store all the spawn positions
func _ready()-> void:
	player_spawner.spawn_function = _ms_player
	barrel_spawner.spawn_function = _ms_barrel
	rooms_generator = self.get_node("Rooms")


"""
func _process(_delta: float) -> void:
	# Pause menu
	if Input.is_action_just_pressed("pause"):
		world_grid = {}
		for i in $Rooms.get_children():
			i.queue_free()
		var my_data = generate_world_data()
		load_world(my_data)
"""


## Function for spawning in a player with given pid
func spawn_player(authority_pid : int) -> void:
	var player : PlayerController = player_spawner.spawn(authority_pid)
	var chosen_spawn : Marker3D = rooms_generator.player_spawn_positions[randi_range(0,rooms_generator.player_spawn_positions.size()-1)]
	player.position = chosen_spawn.global_position
	player.rotation.y = chosen_spawn.global_rotation.y


## Function for spawning in relevant entities
func spawn_entities() -> void:
	var barrel : RigidBody3D = barrel_spawner.spawn(1)
	barrel.global_position = rooms_generator.barrel_spawn_positions[randi_range(0,rooms_generator.barrel_spawn_positions.size()-1)].global_position


## Custom spawn function override for PlayerSpawner
func _ms_player(authority_pid : int) -> PlayerController:
	var player : PlayerController = player_scene.instantiate()
	player.name = str(authority_pid)
	return player


## Custom spawn function override for BarrelSpawner
func _ms_barrel(_authority_pid : int) -> RigidBody3D:
	var barrel : RigidBody3D = barrel_scene.instantiate()
	return barrel


func generate_world_data():
	return rooms_generator.generate_world_data()
	

func load_world(world_data : Array):
	rooms_generator.load_world(world_data)
