extends Node3D

var rooms : Array
var world_grid : Dictionary = {}
var world_edge_grid : Dictionary = {}
enum {BLANK_MARK = 0, EXIT_MARK = 1, WALL_MARK = 2}
var player_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations
var barrel_spawn_positions : Array[Marker3D] # Stores global_position variables of spawn locations


## Generates world data
func generate_world_data() -> Array:
	print("starting world data generation...")
	# TODO: move this
	# Populate an array with our possible rooms + their data
	var room_names = ["rm_01","rm_02","rm_03","rm_04","rm_05","rm_06","rm_07","rm_08"]
	for n in room_names:
		rooms.append(load("res://Prefabs/Level/Rooms/Resources/"+n+".tres"))
	var main_room = rooms[7]
	
	# Set up our world data storage
	var world_data = []
	world_grid = {}
	world_edge_grid = {}

	# recursively add all our rooms
	#var max_depth = 5
	var max_depth = GameManager.max_room_depth
	world_data = add_rooms(main_room,world_data, max_depth)
	print("finished world data generation!!")
	return world_data


## Recursively adds rooms to world_data
func add_rooms(start_room : RoomData, world_data : Array, max_depth : int) -> Array:
	# Add the start room
	var pos := Vector3i.ZERO
	var base_rot := 0
	world_data.append([start_room.Name, pos, base_rot]) # Add the room to world_data
	var exits = get_exits_mark_fills(start_room, pos, base_rot) # Get exits and mark fills
	# Recursively add rooms at all the exits
	for exit in exits:
		world_data.append_array(add_room_recursive(exit[0], exit[1], 1, max_depth))
	return world_data


## Marks positions on world grid, for [room] at [pos] with rotation [rot]
## Also returns all exit positions + intended exit room rotations
func get_exits_mark_fills(room : RoomData, pos : Vector3i, rot : int) -> Array:
	var exits = []
	# Mark each cell
	for cell in room.Cells:
		var cell_pos_local : Vector3i = cell[0]
		var cell_edges : Array = cell[1]
		# Rotate the cell relative to cell origin (if necessary)
		var cell_rotated := Vector3i.ZERO
		if(cell_pos_local != cell_rotated): # If the cell pos is (0,0,0), don't rotate it
			cell_rotated = scik.Vector3i_rotated(cell_pos_local, Vector3i.UP, 90*-rot)
		var cell_pos : Vector3i = cell_rotated + pos
		# Mark the cell as used in our world_grid (TODO: hate that this is a dict)
		var cell_pos_as_string := vector3i_as_string(cell_pos)
		world_grid[cell_pos_as_string] = true
		
		# Mark each edge of the cell + get its exits
		# TODO: this doesn't work for the y-axis
		for edge_idx in cell_edges.size():
			var offset := Vector3i(0,0,1)
			# Determine the edge's position relative to cell origin
			var edge_rotated := scik.Vector3i_rotated(offset, Vector3i.UP, 90*-((edge_idx+rot)%4))
			# Get edge position on grid (currently doubling coords instead of using offset of 0.5)
			var edge_pos : Vector3i = edge_rotated + (2*pos) + (2*cell_rotated)
			var edge_pos_as_string := vector3i_as_string(edge_pos)
			
			# If this is an exit, try adding it to our exits list
			if(cell_edges[edge_idx] == EXIT_MARK):
				var already_handled = false
				# If this edge is already in the world_edge_grid, check what's there
				if(world_edge_grid.has(edge_pos_as_string)):
					var current_edge = world_edge_grid[edge_pos_as_string]
					# If what's there is a wall or an existing exit, mark it as Won't Do
					if(current_edge == WALL_MARK) or (current_edge == EXIT_MARK):
						already_handled = true
				# If we checked, and we're sure we want to place this room, let's do it!
				if not already_handled:
					var exit_pos = edge_rotated+cell_pos # exit room position (wrt to parent pos)
					var exit_base_rot = (edge_idx+rot)%4 # exit room's intended rotation (wrt to parent rot)
					exits.append([exit_pos, exit_base_rot])
					
			# Mark the cell on our world_ede_grid (TODO: hate that this is a dict)
			world_edge_grid[edge_pos_as_string] = cell_edges[edge_idx]
	return exits


## Recursively adds a room + its exits to world_data
func add_room_recursive(pos : Vector3i, base_rot : int, curr_depth : int, max_depth : int) -> Array:
	#print(pos, base_rot, "\td: ",curr_depth)
	if is_occupied(pos): # Early return if our position is marked
		#print("backtrack") # -- hopefully shouldn't hit this?? TODO - hitting it a bit
		return []
	if (curr_depth > max_depth): return [] # Early return if we're past max recursion/path depth
	# Get a random valid room + valid rotation of that room
	var chosen_room_and_rotation = get_random_room_rot(pos, base_rot)
	if(chosen_room_and_rotation.is_empty()): return [] # Early return if there weren't any legal rooms
	var chosen_room : RoomData = chosen_room_and_rotation[0]
	var chosen_rotation : int = chosen_room_and_rotation[1] # rotation IN GRID
	var pos_adj = pos
	if(chosen_room.Origin != Vector3i.ZERO):
		pos_adj = pos + scik.Vector3i_rotated(chosen_room.Origin, Vector3.UP, -90*base_rot)
	# Place the chosen room
	var exits = get_exits_mark_fills(chosen_room, pos_adj, chosen_rotation) # Place the chosen room in world_grid
	var result_data = [] # Place the room in world_data 
	result_data.append([chosen_room.Name, pos_adj, chosen_rotation])
	# Recursively place a room at each exit
	for exit in exits:
		result_data.append_array(add_room_recursive(exit[0], exit[1], curr_depth+1, max_depth))
	return result_data


## Returns a randomly selected valid room+rotation at [pos] with start rotation [base_rot]
func get_random_room_rot(pos : Vector3i, base_rot : int) -> Array:
	var valid_room_rots : Array = []
	# Check all rooms
	for room in rooms:
		# Adjust position in case of non-standard origin
		var pos_adj = pos
		if(room.Origin != Vector3i.ZERO):
			pos_adj = pos + scik.Vector3i_rotated(room.Origin, Vector3.UP, -90*base_rot)
		# Check for valid rotations of the rooms
		var valid_rotations = get_valid_rotations(room, pos_adj, base_rot)
		if valid_rotations.size() > 0: # If we got any valid rotations back, add them
			valid_room_rots.append([room, valid_rotations])
	if(valid_room_rots.is_empty()): return [] # Early return if no rooms can be added
	# Randomly select from available rooms+rotations
	# TODO - rooms should have some weight factor for their being chosen
	var chosen_room_rot = valid_room_rots[randi_range(0,valid_room_rots.size()-1)]
	var chosen_room : RoomData = chosen_room_rot[0]
	var chosen_rot : int = chosen_room_rot[1][randi_range(0,chosen_room_rot[1].size()-1)]
	return [chosen_room, chosen_rot]


## Return all valid rotations of [room] at given [pos] with starting [facing]
# Returned rotations should be in world_grid space (take base_rot into account!)
func get_valid_rotations(room : RoomData, pos : Vector3i, base_rot : int) -> Array:
	var valid_rotations = []
	# Check validity of each legal rotation for the room
	for rot in room.CW_Rotations:
		var is_valid_rot = check_valid_room_placement(room, pos, (base_rot+rot)%4)
		if(is_valid_rot): valid_rotations.append((base_rot+rot)%4)
	return valid_rotations


## Checks whether or not a given [room] placement [pos], at a given rotation [rot], would be valid
func check_valid_room_placement(room : RoomData, pos : Vector3i, rot : int) -> bool:
	for cell in room.Cells:
		# Determine the cell's position in world grid, given the rotation
		var cell_pos_local = cell[0]
		var cell_rotated_local := Vector3i.ZERO
		if(cell_pos_local != cell_rotated_local): # If the cell pos is (0,0,0), don't rotate it
			cell_rotated_local = scik.Vector3i_rotated(cell_pos_local, Vector3i.UP, 90*-(rot%4))
		var cell_pos_grid : Vector3i = cell_rotated_local + pos
		# Determine the world_edge_grid offset for the edges (means we have to pass less variables)
		var edge_grid_offset : Vector3i = (2*pos) + (2*cell_rotated_local)
		var cell_edges : Array = cell[1]
		# Determine if the cell is valid
		var is_valid_cell = check_valid_cell_placement(cell_pos_grid, cell_edges, rot, edge_grid_offset)
		if not is_valid_cell: return false # Early return if a given cell was invalid
	return true


## Checks whether or not a given cell placement [cell_pos_grid], with edges [cell_edges], at a given rotation [rot], would be valid
## edge_grid_offset is passed separately to avoid extra variables -- calculated by ((2*pos)+(2*cell_rotated_local))
func check_valid_cell_placement(cell_pos_grid : Vector3i, cell_edges : Array, rot : int, edge_grid_offset : Vector3i) -> bool:
	# Step 1 - check if the cell would even fit
	if is_occupied(cell_pos_grid): return false # Early return if the cell is occupied
	# Step 2 - check if the edges would be Ugly
	# TODO: this doesn't work for the y-axis
	for edge_idx in cell_edges.size():
		# Start by determining where the edge even is
		var offset := Vector3i(0,0,1)
		# Determine the edge's position relative to cell origin
		var edge_rotated_local := scik.Vector3i_rotated(offset, Vector3i.UP, 90*-((edge_idx+rot)%4))
		# Get edge position on grid (currently doubling coords instead of using offset of 0.5)
		var edge_pos_edgegrid : Vector3i = edge_rotated_local + edge_grid_offset
		var edge_pos_edgegrid_as_string := vector3i_as_string(edge_pos_edgegrid)
		if world_edge_grid.has(edge_pos_edgegrid_as_string):
			var grid_edge_type = world_edge_grid[edge_pos_edgegrid_as_string]
			# Determine if edges would be ugly
			if(grid_edge_type != 0):
				var cell_edge_type = cell_edges[edge_idx]
				# TODO - could just be "if cell_edge_type != grid_edge_type" but i'm worried about future edge type additions
				if(cell_edge_type == WALL_MARK and grid_edge_type == EXIT_MARK): return false # Early return for edge mismatch
				elif(cell_edge_type == EXIT_MARK and grid_edge_type == WALL_MARK): return false # Early return for edge mismatch
	return true


## Returns true if any positions in [world_grid_positions] are occupied in world_grid
func is_occupied(pos : Vector3i) -> bool:
	var pos_as_string := vector3i_as_string(pos)
	if world_grid.has(pos_as_string): return true
	return false


## Takes a vector3i and stringifies it
func vector3i_as_string(v : Vector3i) -> String:
	var x := str(v.x)
	var y := str(v.y)
	var z := str(v.z)
	return x+y+z


## Converts world_data grid position to real coordinates
func grid_to_world(pos : Vector3i) -> Vector3:
	var grid_size = Vector3i(15,10,15)
	return Vector3(pos.x*grid_size.x, pos.y*grid_size.y, pos.z*grid_size.z)


## Loads in gameworld
func load_world(world_data : Array) -> void:
	print("starting world load...")
	for room_data in world_data:
		# Parse the room data
		var room_name : String = room_data[0]
		var pos : Vector3i = room_data[1]
		var rot : int = room_data[2]
		# Spawn the room
		var room_node : ModularRoom = load("res://Prefabs/Level/Rooms/Scenes/"+room_name+".tscn").instantiate()
		self.add_child(room_node)
		# Place the room
		room_node.global_position = grid_to_world(pos)
		room_node.rotate_y(-PI/2*rot)
		# Save the room's spawn data
		if not room_node.PlayerSpawns.is_empty():
			player_spawn_positions.append_array(room_node.PlayerSpawns)
		if not room_node.BarrelSpawns.is_empty():
			barrel_spawn_positions.append_array(room_node.BarrelSpawns)
	print("finished world load!!")
