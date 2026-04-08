extends Control

@onready var high_score_label: Label = %HighScoreLabel
@onready var start_button: Button = %StartButton
@onready var toggle_sound_button: Button = %ToggleSoundButton

var sound_enabled := true

func _ready() -> void:
	high_score_label.text = "%d" % GameManager.high_score
	start_button.pressed.connect(_on_start_pressed)
	toggle_sound_button.pressed.connect(_on_toggle_sound_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_toggle_sound_pressed() -> void:
	sound_enabled = not sound_enabled
	toggle_sound_button.text = "音效：%s" % ("开" if sound_enabled else "关")
