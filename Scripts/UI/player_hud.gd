extends CanvasLayer
class_name PlayerHUD

@onready var healthbar = get_node("Base/Health")
@onready var scoreboard = get_node("Base/ScoreContainer")


func update_health(value : int):
	healthbar.value = value


func update_scores():
	#TODO: this currently only updates when players open the scoreboard, not in real time
	var player_ids = NetworkManager.players_dict.keys()
	player_ids.sort()
	$Base/ScoreContainer/Players/ScoreList.clear()
	for p in player_ids:
		$Base/ScoreContainer/Players/ScoreList.add_item(NetworkManager.players_dict[p]["name"])
		$Base/ScoreContainer/Players/ScoreList.add_item(str(NetworkManager.players_dict[p]["score"]))
