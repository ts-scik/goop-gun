class_name RoomData
extends Resource

enum {BLANK_MARK = 0, EXIT_MARK = 1, WALL_MARK = 2}

@export var Name : String = "rm_XX-name" # scene for this room
@export var Origin : Vector3i = Vector3i.ZERO
@export var Cells : Array = [ # list of cells and their edges
	[Vector3i.ZERO,[EXIT_MARK,EXIT_MARK,EXIT_MARK,EXIT_MARK]]
] #TODO : what about the y-axis?
@export var CW_Rotations : Array[int] = [0,1,2,3] # valid #s of CW rotations of this room
