class_name PlayerHUD
extends CanvasLayer

@onready var healthbar = get_node("Base/Health")
@onready var scoreboard = get_node("Base/ScoreContainer")


## Update the healthbar value
func update_health(value : int):
	healthbar.value = value


## Update our scores
func update_scores():
	var player_ids = NetworkManager.players_dict.keys()
	player_ids.sort()
	$Base/ScoreContainer/Players/ScoreList.clear()
	for p in player_ids:
		$Base/ScoreContainer/Players/ScoreList.add_item(NetworkManager.players_dict[p]["name"])
		$Base/ScoreContainer/Players/ScoreList.add_item(str(NetworkManager.players_dict[p]["score"]))
