class_name RoomData
extends Resource

@export var Fills : Array[Vector3] = [Vector3.ZERO] #grid positions filled by this room
@export var Exits : Array = [ # exit positions relative to this room
	[Vector3(0,0,1), 0],
	[Vector3(-1,0,0), 1],
	[Vector3(0,0,-1), 2],
	[Vector3(1,0,0), 3],
]
@export var CW_Rotations : Array[int] = [0,1,2,3] # valid #s of CW rotations of this room
@export var room_scene_name : String = "rm_XX-name" # scene for this room
