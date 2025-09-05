extends Node

const DEFAULT_IP_ADDRESS : String = "localhost"
const DEFAULT_PORT : int = 47757

const MAX_PEERS = 16
var peer : ENetMultiplayerPeer = null

# Name for my player.
var player_name : String

# Names for remote players in id:name format.
var players = {}
var players_ready : Array = []

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)


## Starts server
func start_server(new_player_name : String = "DefaultName") -> void:
	player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	players[1] = new_player_name
	GameManager.player_scores[1] = 0


## Starts a client
func start_client(ip : String = DEFAULT_IP_ADDRESS, new_player_name : String = "DefaultName") -> void:
	player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, DEFAULT_PORT)
	print(ip)
	multiplayer.set_multiplayer_peer(peer)
	players[multiplayer.get_unique_id()] = new_player_name
	GameManager.player_scores[multiplayer.get_unique_id()] = 0


# Callback from SceneTree.
func _player_connected(id):
	# Registration of a client beings here, tell the connected player that we are here.
	register_player.rpc_id(id, player_name)
	if(multiplayer.is_server()):
		pass
		#update_gamestate.rpc()


# Callback from SceneTree.
func _player_disconnected(id):
	if GameManager.is_playing: # Game is in progress.
		if multiplayer.is_server():
			game_error.emit("Player " + players[id] + " disconnected")
			var path = NodePath("/root/World/"+str(id))
			print(path)
			if(has_node(path)):
				get_node(path).queue_free()
		unregister_player(id)
	else: # Game is not in progress.
		# Unregister this player.
		unregister_player(id)


# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	# We just connected to a server
	print("connected")
	connection_succeeded.emit()


# Callback from SceneTree, only for clients (not server).
func _server_disconnected():
	game_error.emit("Server disconnected")
	multiplayer.set_multiplayer_peer(null)
	get_tree().paused = true
	end_game()
	get_tree().paused = false


# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	multiplayer.set_multiplayer_peer(null) # Remove peer
	print("connection failed")
	connection_failed.emit()


@rpc("authority","reliable")
func update_gamestate():
	GameManager.is_playing = true
	pass

## Adds player to lobby
@rpc("any_peer")
func register_player(new_player_name):
	var id = multiplayer.get_remote_sender_id()
	var offset = 0
	var fixed_player_name = new_player_name
	while players.values().has(fixed_player_name):
		offset += 1
		fixed_player_name = new_player_name + "(" + str(offset) + ")"
	players[id] = fixed_player_name
	player_list_changed.emit()
	GameManager.player_scores[id] = 0


## Removes player from lobby
func unregister_player(id):
	players.erase(id)
	GameManager.player_scores.erase(id)
	player_list_changed.emit()


func get_player_list():
	return players.values()


func get_player_name():
	return player_name


func end_game():
	GameManager.is_playing = false
	for id in players:
		var path = NodePath("/root/World/"+str(id))
		if(has_node(path)):
			get_node(path).queue_free()
	players.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ended.emit()
