class_name BaseNetworkManager
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
var players_loaded : Array = []

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_left()
signal game_error(what)
signal log_update(text)
signal server_lost()
signal game_started()
signal game_loading()
signal all_players_loaded()


## Connects necessary signals
func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)


## Starts server
func start_server(new_player_name : String = "DefaultName") -> void:
	# Create our server
	my_player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	# Register ourselves
	log_update.emit("Started server!")
	# Adds self to dictionary
	players_dict[multiplayer.get_unique_id()] = {"name": new_player_name, "score": 0, "color": Color.WHITE}
	player_list_changed.emit()


## Starts a client
func start_client(ip : String = DEFAULT_IP_ADDRESS, new_player_name : String = "DefaultName") -> void:
	# Create our client
	my_player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, DEFAULT_PORT)
	log_update.emit("Connecting to ip: "+ip+"...")
	multiplayer.set_multiplayer_peer(peer)


# Callback from SceneTree.
## Hangles {peer_connected} signal from client with id [id]
func _player_connected(id) -> void:
	print("Connected to peer with id: ", id)
	pass


# Callback from SceneTree.
## Handles {peer_disconnected} signal from client with id [id]
func _player_disconnected(id) -> void:
	# Log the player disconnecting (this occurs on ALL instances)
	print("Lost connection to peer with id: ", id)
	log_update.emit("peer "+players_dict[id]["name"]+" disconnected!")
	# Early return if not multiplayer authority
	if !is_multiplayer_authority(): return
	# Check if game is in progress
	if GameManager.is_playing:
		# If so, delete the disconnected player's player object.
		game_error.emit("Player " + players_dict[id]["name"] + " disconnected") # emit a player-lost error
		var path = NodePath("/root/MainScene/World/"+str(id)) # get the path to player's PlayerController
		if(has_node(path)): get_node(path).queue_free() # delete the lost player's PlayerController
	# Unregister the lost player.
	_unregister_player(id) # let everyone else know what's happened


# Callback from SceneTree, only for clients (not server).
## Handles {connected_to_server} signal
func _connected_ok() -> void:
	log_update.emit("Connected to server!") # We just connected to a server
	_register_player.rpc_id(get_multiplayer_authority(),my_player_name) # Ask the server to register us
	connection_succeeded.emit()


# Callback from SceneTree, only for clients (not server).
## Handles {connection_failed} signal
func _connected_fail() -> void:
	multiplayer.set_multiplayer_peer(null) # Remove peer
	log_update.emit("Connection failed! :(")
	connection_failed.emit()


# Callback from SceneTree, only for clients (not server).
## Handles {server_disconnected} signal
func _server_disconnected() -> void:
	game_error.emit("Server disconnected")
	_end_of_connection_cleanup()
	server_lost.emit()


## Ends session for Client or Server who wishes to leave the game
## Closes multiplayer peers, unloads the world, resets variables
func leave_game() -> void:
	peer.close() # Closes peer
	multiplayer.set_multiplayer_peer(null) # Remove peer
	_end_of_connection_cleanup()
	game_left.emit()


func _end_of_connection_cleanup() -> void:
	if(GameManager.is_playing): end_game() # Ends game, if it were running
	players_dict.clear()
	var path = NodePath("/root/MainScene/World")
	if(has_node(path)): get_node(path).queue_free()


## Registers a player on Server, then signals the clients
## Clients call this on Server when they connect
@rpc("any_peer","call_local","reliable",LOBBY_CHANNEL)
func _register_player(new_player_name) -> void:
	# Setup
	assert(multiplayer.is_server()) # Assert -- this is a SERVER-ONLY function
	var id = multiplayer.get_remote_sender_id() # Store the sender ID
	# Send existing gamestate data to the new client
	_full_player_sync.rpc_id(id, players_dict, GameManager.is_playing)
	# Add the new player to dictionary
	new_player_name = _make_playername_unique(new_player_name)
	var new_player : Dictionary = {"name": new_player_name, "score": 0, "color": Color.WHITE}
	players_dict[id] = new_player
	# Handle multiplayerUI
	player_list_changed.emit()
	log_update.emit(new_player["name"]+" connected!")
	# Sync new player data with all clients (including the new one!)
	_single_player_sync.rpc(id,new_player) # Send the newly-added player to all clients
	
	# If this is a late-joiner:
	if(GameManager.is_playing): _handle_late_joiner(id)	


## Takes a [new_player_name], returns it unique-ified
func _make_playername_unique(new_player_name : String) -> String:
	# Add (#) suffix to names already in use
	var offset = 0
	var curr_names = get_player_list()
	var fixed_player_name = new_player_name
	while curr_names.has(fixed_player_name):
		offset += 1
		fixed_player_name = new_player_name + "(" + str(offset) + ")"
	return fixed_player_name


## Removes player from lobby
## Doesn't need an RPC, because we call it directly from the server elsewhere
func _unregister_player(id):
	assert(multiplayer.is_server())
	players_dict.erase(id)
	if(GameManager.is_playing):
		players_loaded.erase(id)
	player_list_changed.emit()
	_single_player_remove.rpc(id)


# TODO: combine this and other sync functions
## Syncs the players list + gamestate on clients
## Server calls this on Clients when a new user connects
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _full_player_sync(new_players_dict : Dictionary, new_is_playing : bool) -> void:
	players_dict = new_players_dict
	GameManager.is_playing = new_is_playing
	player_list_changed.emit()
	log_update.emit("Received synchronized playerdata!")


# TODO: combine this and other sync functions
## Adds a new player to clients
## Server calls this on Clients when a new user connects
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _single_player_sync(new_pid : int, new_player : Dictionary) -> void:
	# Add the new player's data
	players_dict[new_pid] = new_player
	player_list_changed.emit()
	log_update.emit(new_player["name"]+" connected!")
	# If we just got sent our own data, we should update our local name to match
	if new_pid == multiplayer.get_unique_id():
		my_player_name = players_dict[multiplayer.get_unique_id()]["name"]


# TODO: combine this and other sync functions
## Removes a player form clients
## Server calls this on Clients when a user disconnects
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _single_player_remove(pid : int) -> void:
	players_dict.erase(pid)
	if(GameManager.is_playing):
		players_loaded.erase(pid)
	player_list_changed.emit()


## Returns all player names
func get_player_list() -> Array:
	var players_list : Array = []
	for id in players_dict:
		players_list.append(players_dict[id]["name"])
	return players_list


## Returns player name on this machine
func get_player_name() -> String:
	return my_player_name


## Sets up the game -- SERVER-ONLY
func setup_game() -> void:
	# Get prepared for setup
	assert(multiplayer.is_server())
	peer.refuse_new_connections = true # Stop accepting connections
	GameManager.is_playing = false
	game_loading.emit()
	get_tree().set_pause(true) # Pause the game while setting up
	# Spawn world -- should sync because of multiplayer synchronizer
	var world = load("res://Prefabs/world.tscn").instantiate()
	get_node("/root/MainScene").add_child(world)
	# Signal to players that we're getting set-up
	_server_start_setup.rpc(false)
	# Generate the world (server)
	#GameManager.world_data = _generate_world_data() # create our world_data, and store it
	GameManager.world_data = await world.generate_world_data()
	await _generate_world() # actually generate the world
	players_loaded.append(multiplayer.get_unique_id()) # mark that we've finished loading
	# Generate the world (clients)
	_receive_world_data.rpc(GameManager.world_data) # Send the worlddata to players, and ask them to generate it client-side
	if (players_loaded.size() != players_dict.size()): # If we have peers, wait for everyone to finish loading the world in
		await all_players_loaded
	# Spawn everything in
	world.spawn_entities() # Spawn in enemies, items -- use MultiplayerSpawner to avoid weirdness
	for pid in players_dict: world.spawn_player(pid) # Spawn in players
	# End-of-setup cleanup
	_server_finish_setup.rpc(players_loaded) # Signal to clients that we're done setting up
	peer.refuse_new_connections = false # Resume accepting connections
	start_game()


## Signal from Server to Clients, to indicate game is being set up
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _server_start_setup(is_playing : bool) -> void:
	GameManager.is_playing = is_playing
	game_loading.emit()
	get_tree().set_pause(true) # Pause the game while setting up


## Signal from Server to Clients, giving them the world data, with which to set up the game
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _receive_world_data(world_data : Array) -> void:
	GameManager.world_data = world_data # store world_data in our GameManager singleton
	_generate_world() # do the actual world generation/loading


## Generates world, using given world_data
func _generate_world() -> void:
	var world = get_tree().get_root().get_node("MainScene/World")
	await world.load_world(GameManager.world_data)
	if(!multiplayer.is_server()):
		_signal_loaded.rpc_id(get_multiplayer_authority()) # tell the server that we've finished our meal


## Signal from Clients to Server, signalling that they're ready to roll
@rpc("any_peer","call_remote","reliable",LOBBY_CHANNEL)
func _signal_loaded() -> void:
	assert(multiplayer.is_server())
	var id = multiplayer.get_remote_sender_id()
	players_loaded.append(id)
	# If all players have loaded,
	if (players_loaded.size() == players_dict.size()):
		print("Everyone is loaded!")
		all_players_loaded.emit()


## Signal from Server to Clients, to indicate game is being started
@rpc("authority","call_remote","reliable",LOBBY_CHANNEL)
func _server_finish_setup(received_ready_players : Array) -> void:
	players_loaded = received_ready_players
	start_game()


## Starts the game
func start_game() -> void:
	GameManager.is_playing = true
	get_tree().set_pause(false) # Unpause and unleash the game!
	game_started.emit()


## Handles late-joined players
func _handle_late_joiner(pid) -> void:
	# Pause gameplay
	get_tree().set_pause(true) # Pause the game while setting up
	_server_start_setup.rpc(true) # Ask all clients to pause their game
	# Send world_data
	_receive_world_data.rpc_id(pid, GameManager.world_data) # send world data to late joiner
	await all_players_loaded # Wait for player to finish
	# Spawn in newly-joined player
	var world = get_tree().get_root().get_node("MainScene/World")
	world.spawn_player(pid)
	# Signal to clients that we're done setting up
	_server_finish_setup.rpc(players_loaded) # Ask all clients to unpause their game
	get_tree().set_pause(false) # Unpause and unleash the game!


## Ends the game
func end_game() -> void:
	if(!GameManager.is_playing): return # early return if the game isn't in session
	get_tree().paused = true # pause while we do cleanup
	GameManager.is_playing = false # set not playing
	players_loaded.clear() # clear the players_loaded
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_ended.emit()
	get_tree().paused = false # unpause, cleanup complete
