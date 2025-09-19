extends Node3D

@export var player_scene : PackedScene # player scene
@export var barrel_scene : PackedScene # barrel scene
@export var player_spawner : MultiplayerSpawner # player MultiplayerSpawner node
@export var barrel_spawner : MultiplayerSpawner

var player_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations
var barrel_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations

var rooms : Array
var main_room
var world_grid : Dictionary = {}

## Store all the spawn positions
func _ready()-> void:
	player_spawner.spawn_function = _ms_player
	barrel_spawner.spawn_function = _ms_barrel
	
	# Populate an array with our possible rooms + their data
	var room_names = ["rm_01","rm_02","rm_03","rm_04"]
	for n in room_names:
		rooms.append(load("res://Prefabs/Level/Rooms/Resources/"+n+".tres"))
	main_room = load("res://Prefabs/Level/Rooms/Resources/"+"rm_01"+".tres")


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


## Generates world data
func generate_world_data() -> Array:
	# Populate an array with booleans to store our grid
	var world_data = []

	# recursively add all our rooms
	var max_depth = 10
	world_data = add_rooms(main_room,world_data, max_depth)
	return world_data


## Recursively adds rooms to world_data
func add_rooms(start_room : RoomData, world_data : Array, max_depth : int) -> Array:
	# Add the start room
	var pos = Vector3.ZERO
	world_grid[str(int(pos.x))+str(int(pos.y))+str(int(pos.z))] = true
	world_data.append([start_room, pos, 0])
	# Recursively add rooms at all the exits
	for exit in start_room.Exits:
	#var exit = start_room.Exits[0]
	#if(1==1):
		print("new branch")
		var exit_pos = exit[0]
		var exit_facing = exit[1]
		world_data.append_array(add_room_recursive(exit_pos, exit_facing, 1, max_depth))
	return world_data


## Recursively adds a room + its exits to world_data
func add_room_recursive(pos : Vector3, facing : int, curr_depth : int, max_depth : int) -> Array:
	#print(pos, facing, "\td: ",curr_depth)
	# Early return if our position is marked
	if is_occupied([pos]):
		#print("backtrack")
		return []
	# Early return if we're past max recursion dept
	if (curr_depth > max_depth):
		#print("max_depth")
		return []
	# Check what rooms can be legally added
	var valid_room_rots : Array = []
	for room in rooms:
		# Check for valid rotations of the rooms
		var valid_rotations = try_placement(room, pos, facing)
		if valid_rotations.size() > 0:
			valid_room_rots.append([room, valid_rotations])
	# If no rooms can be added, return
	if(valid_room_rots.is_empty()):
		#print("dead-end")
		return []
	# Randomly select from available rooms+rotations
	var chosen_room_rot = valid_room_rots[randi_range(0,valid_room_rots.size()-1)]
	var chosen_room : RoomData = chosen_room_rot[0]
	var chosen_rotation : int = chosen_room_rot[1][randi_range(0,chosen_room_rot[1].size()-1)]
	chosen_rotation = (chosen_rotation+facing)%4
	# Then, place the room in world_grid
	for cell in chosen_room.Fills:
		var rotated_cell = cell.rotated(Vector3.UP, -PI/2*chosen_rotation)
		rotated_cell += pos
		world_grid[str(int(rotated_cell.x))+str(int(rotated_cell.y))+str(int(rotated_cell.z))]=true
	# Then, place the room in world_grid
	var result_data = []
	result_data.append([chosen_room, pos, chosen_rotation])
	# Finally, recursively place a room at each exit
	for exit in chosen_room.Exits:
		var exit_pos = pos + exit[0].rotated(Vector3.UP, -PI/2*chosen_rotation)
		var exit_facing = (exit[1] + chosen_rotation)%4
		result_data.append_array(add_room_recursive(exit_pos, exit_facing, curr_depth+1, max_depth))
	return result_data


## Return all valid rotations of [room] at given [pos] with starting [facing]
func try_placement(room : RoomData, pos : Vector3, facing : int) -> Array:
	var valid_rotations = []
	for rot in room.CW_Rotations:
		#if(rot != 0): break #TODO: DEBUG
		var potential_fills : Array[Vector3] = []
		for cell in room.Fills:
			# TODO: does Vector3.rotated() below work how i think it does??
			var cell_rotated = cell.rotated(Vector3.UP, -PI/2 * (rot+facing))
			potential_fills.append(cell_rotated + pos)
		if !is_occupied(potential_fills): valid_rotations.append(rot)
	return valid_rotations


## Returns true if any positions in [potential_fills] are occupied in world_grid
func is_occupied(potential_fills : Array[Vector3]) -> bool:
	for pos in potential_fills:
		if world_grid.has(str(int(pos.x))+str(int(pos.y))+str(int(pos.z))): return true
	return false


## Loads in gameworld - new and improved!!
func load_world(world_data : Array) -> void:
	for room_data in world_data:
		#print(room_data)
		var room_name : String = room_data[0].room_scene_name
		var pos = room_data[1]
		var facing = room_data[2]
		var room_node : ModularRoom = load("res://Prefabs/Level/Rooms/Scenes/"+room_name+".tscn").instantiate()
		$Rooms.add_child(room_node)
		room_node.global_position = grid_to_world(pos.x, pos.y, pos.z)
		room_node.rotate_y(-PI/2*facing)
		if not room_node.PlayerSpawns.is_empty():
			player_spawn_positions.append_array(room_node.PlayerSpawns)
		if not room_node.BarrelSpawns.is_empty():
			barrel_spawn_positions.append_array(room_node.BarrelSpawns)


## Loads in gameworld
func old_load_world(world_data : Array) -> void:
	for x in world_data.size():
		for y in world_data[x].size():
			var pos = Vector2(x,y)
			var c_room_name = world_data[pos.x][pos.y]
			var c_room : ModularRoom = load("res://Prefabs/Level/Rooms/Scenes/"+c_room_name+".tscn").instantiate()
			add_child(c_room)
			c_room.global_position = grid_to_world(pos.x, 0, pos.y)
			player_spawn_positions.append_array(c_room.PlayerSpawns)
			barrel_spawn_positions.append_array(c_room.BarrelSpawns)


## Converts world_data grid position to real coordinates
func grid_to_world(x, y, z) -> Vector3:
	var grid_size = 15
	return Vector3(x*grid_size, y*grid_size, z*grid_size)
