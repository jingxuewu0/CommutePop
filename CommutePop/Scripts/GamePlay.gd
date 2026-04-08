extends Control

@onready var score_label: Label = %ScoreLabel
@onready var timer_label: Label = %TimerLabel
@onready var combo_label: Label = %ComboLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_hint: Label = %ProgressHint
@onready var restart_button: Button = %RestartButton
@onready var home_button: Button = %HomeButton
@onready var grid: Grid = %Grid

var _combo_tween: Tween

func _ready() -> void:
	GameManager.begin_or_resume_run()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.game_finished.connect(_on_game_finished)
	grid.blocks_cleared.connect(_on_blocks_cleared)
	grid.combo_changed.connect(_on_combo_changed)
	restart_button.pressed.connect(_on_restart_pressed)
	home_button.pressed.connect(_on_home_pressed)
	progress_bar.max_value = GameManager.target_score
	progress_hint.text = "目标：%d 分" % GameManager.target_score
	_on_score_changed(GameManager.score)
	_on_time_changed(GameManager.time_left)
	_on_combo_changed(0)

func _exit_tree() -> void:
	if GameManager.score_changed.is_connected(_on_score_changed):
		GameManager.score_changed.disconnect(_on_score_changed)
	if GameManager.time_changed.is_connected(_on_time_changed):
		GameManager.time_changed.disconnect(_on_time_changed)
	if GameManager.game_finished.is_connected(_on_game_finished):
		GameManager.game_finished.disconnect(_on_game_finished)

func _on_blocks_cleared(block_count: int, score_gained: int) -> void:
	GameManager.register_clear(block_count, score_gained)

func _on_score_changed(score: int) -> void:
	score_label.text = "%d" % score
	progress_bar.value = score

func _on_time_changed(time_left: float) -> void:
	timer_label.text = "%d" % ceili(time_left)
	if time_left <= 5.0:
		timer_label.add_theme_color_override("font_color", Color("ff6b6b"))
	else:
		timer_label.add_theme_color_override("font_color", Color("ffd93d"))

func _on_combo_changed(combo: int) -> void:
	if _combo_tween:
		_combo_tween.kill()
	if combo <= 1:
		_combo_tween = create_tween()
		_combo_tween.tween_property(combo_label, "modulate:a", 0.0, 0.3)
		return
	combo_label.text = "连击 x%d！" % combo
	combo_label.modulate.a = 1.0
	combo_label.scale = Vector2(1.0, 1.0)
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.08)
	_combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_game_finished(_result: Dictionary) -> void:
	get_tree().change_scene_to_file("res://Scenes/ResultScreen.tscn")