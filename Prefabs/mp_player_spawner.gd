extends MultiplayerSpawner

@export var network_player : PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	
func spawn_player(id: int) -> void:
	GameManager.player_scores[id] = 0
	if !multiplayer.is_server(): return
	if !GameManager.is_playing: return
	if has_node(str(id)):
		print("A player with ID", id, "already exists.")
		return
		
	var player : Node = network_player.instantiate()
	player.name = str(id)
	get_node(spawn_path).call_deferred("add_child", player)
	if(has_node("/root/World")):
		var positions : Array = get_node("/root/World").spawn_positions
		var selection = randi_range(0, positions.size()-1)
		player.position = positions[selection]
