extends Control

@onready var title_label: Label = %Title
@onready var score_label: Label = %ScoreLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var status_label: Label = %StatusLabel
@onready var revive_button: Button = %ReviveButton
@onready var double_score_button: Button = %DoubleScoreButton
@onready var replay_button: Button = %ReplayButton
@onready var home_button: Button = %HomeButton

func _ready() -> void:
	_refresh_ui({
		"score": GameManager.score,
		"high_score": GameManager.high_score,
		"target_score": GameManager.target_score,
		"won": GameManager.score >= GameManager.target_score,
		"revive_available": GameManager.can_revive()
	})
	revive_button.pressed.connect(_on_revive_pressed)
	double_score_button.pressed.connect(_on_double_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	home_button.pressed.connect(_on_home_pressed)

func _refresh_ui(result: Dictionary) -> void:
	var score: int = result.get("score", 0)
	var high_score: int = result.get("high_score", 0)
	var target_score: int = result.get("target_score", 0)
	var won: bool = result.get("won", false)
	var revive_available: bool = result.get("revive_available", false)
	score_label.text = "%d" % score
	high_score_label.text = "%d" % high_score
	if won:
		title_label.text = "🎉 达成目标！"
		title_label.add_theme_color_override("font_color", Color("6bcb77"))
		status_label.text = "恭喜！你达成了 %d 分目标！" % target_score
		status_label.add_theme_color_override("font_color", Color("6bcb77"))
	else:
		title_label.text = "本局结算"
		title_label.remove_theme_color_override("font_color")
		status_label.text = "距目标还差 %d 分" % maxi(target_score - score, 0)
		status_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.55, 0.9))
	revive_button.visible = revive_available

func _on_revive_pressed() -> void:
	revive_button.disabled = true
	await AdManager.show_reward_ad(func():
		GameManager.apply_revive()
	)
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_double_pressed() -> void:
	double_score_button.disabled = true
	await AdManager.show_reward_ad(func():
		GameManager.apply_double_score()
	)
	_refresh_ui({
		"score": GameManager.score,
		"high_score": GameManager.high_score,
		"target_score": GameManager.target_score,
		"won": GameManager.score >= GameManager.target_score,
		"revive_available": GameManager.can_revive()
	})

func _on_replay_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")