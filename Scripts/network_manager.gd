#class_name NetworkManager
extends Node

const DEFAULT_IP_ADDRESS : String = "localhost"
const DEFAULT_PORT : int = 47757

const MAX_PEERS = 16
var peer : ENetMultiplayerPeer = null
var custom_port : int = -1

enum {LOBBY_CHANNEL = 1, GAMEPLAY_CHANNEL = 2}

# Name for my player.
var my_player_name : String

# Names for remote players in id:name format.
var players_dict : Dictionary = {}
var players_ready : Array = []

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)
signal log_update(text)
signal server_lost()


## Connects necessary signals
func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)


## Starts server
func start_server(new_player_name : String = "DefaultName") -> void:
	my_player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	log_update.emit("Started server!")
	_register_player.rpc_id(multiplayer.get_unique_id(),new_player_name) # register self


## Starts a client
func start_client(ip : String = DEFAULT_IP_ADDRESS, new_player_name : String = "DefaultName") -> void:
	my_player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, DEFAULT_PORT)
	#print("connecting to ip: ", ip)
	log_update.emit("connecting to ip: "+ip+"...")
	multiplayer.set_multiplayer_peer(peer)


# Callback from SceneTree.
## Hangles {peer_connected} signal from client with id [id]
func _player_connected(id) -> void:
	log_update.emit("new peer "+str(id)+" connected!")
	pass


# Callback from SceneTree.
## Handles {peer_disconnected} signal from client with id [id]
func _player_disconnected(id) -> void:
	log_update.emit("peer "+str(id)+" disconnected!")
	
	# Early return if not multiplayer authority
	if !is_multiplayer_authority(): return
	# Check if game is in progress
	if GameManager.is_playing:
		# If so, delete the disconnected player's player object.
		if multiplayer.is_server():
			game_error.emit("Player " + players_dict[id] + " disconnected")
			var path = NodePath("/root/World/"+str(id))
			print(path)
			if(has_node(path)):
				get_node(path).queue_free()
	# Unregister the lost player.
	_unregister_player(id)


# Callback from SceneTree, only for clients (not server).
## Handles {connected_to_server} signal
func _connected_ok() -> void:
	log_update.emit("connected to server!") # We just connected to a server
	_register_player.rpc_id(get_multiplayer_authority(),my_player_name)
	connection_succeeded.emit()


# Callback from SceneTree, only for clients (not server).
## Handles {server_disconnected} signal
func _server_disconnected() -> void:
	game_error.emit("Server disconnected")
	get_tree().paused = true
	end_game()
	get_tree().paused = false
	server_lost.emit()


# Callback from SceneTree, only for clients (not server).
## Handles {connection_failed} signal
func _connected_fail() -> void:
	multiplayer.set_multiplayer_peer(null) # Remove peer
	log_update.emit("connection failed")
	connection_failed.emit()


## Registers a player on Server, then signals the clients
## Clients call this on Server when they connect
@rpc("any_peer","call_local","reliable",LOBBY_CHANNEL)
func _register_player(new_player_name) -> void:
	assert(multiplayer.is_server())
	var id = multiplayer.get_remote_sender_id()
	var offset = 0
	var fixed_player_name = new_player_name
	while players_dict.values().has(fixed_player_name):
		offset += 1
		fixed_player_name = new_player_name + "(" + str(offset) + ")"
	players_dict[id] = fixed_player_name
	GameManager.player_scores[id] = 0
	player_list_changed.emit()
	_sync_players.rpc(players_dict, GameManager.player_scores, GameManager.is_playing)
	
	if(GameManager.is_playing):
		var world = get_tree().get_root().get_node("MainScene/World")
		world.spawn_player(id)


## Removes player from lobby
## Doesn't need an RPC, because we call it directly from the server elsewhere
func _unregister_player(id):
	assert(multiplayer.is_server())
	players_dict.erase(id)
	GameManager.player_scores.erase(id)
	player_list_changed.emit()
	_sync_players.rpc(players_dict, GameManager.player_scores, GameManager.is_playing)


## Syncs the players list + scores on clients
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _sync_players(new_players_dict, new_player_scores, new_is_playing) -> void:
	players_dict = new_players_dict
	my_player_name = players_dict[multiplayer.get_unique_id()]
	GameManager.player_scores = new_player_scores
	GameManager.is_playing = new_is_playing
	player_list_changed.emit()
	log_update.emit("Received synchronized playerdata!")


## Returns all player names
func get_player_list():
	return players_dict.values()


## Returns player name on this machine
func get_player_name():
	return my_player_name


## Loads in the world
func _load_world() -> void:
	# Set is_playing
	GameManager.is_playing = true
	# Change scene.
	var world = load("res://Prefabs/world.tscn").instantiate()
	get_tree().get_root().get_node("MainScene").add_child(world)
	get_tree().set_pause(false) # Unpause and unleash the game!


## Starts the game
func start_game() -> void:
	_load_world()
	var world = get_tree().get_root().get_node("MainScene/World")
	for player in players_dict:
		world.spawn_player(player)


## Ends the game
func end_game() -> void:
	GameManager.is_playing = false
	var path = NodePath("/root/MainScene/World")
	if(has_node(path)):
		get_node(path).queue_free()
	players_dict.clear()
	GameManager.player_scores.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ended.emit()
