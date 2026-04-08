extends Control

@onready var high_score_label: Label = %HighScoreLabel
@onready var start_button: Button = %StartButton
@onready var toggle_sound_button: Button = %ToggleSoundButton

@onready var title: Label = $ContentContainer/VBoxContainer/TitleArea/Title
@onready var subtitle: Label = $ContentContainer/VBoxContainer/TitleArea/Subtitle
@onready var score_area: PanelContainer = $ContentContainer/VBoxContainer/HighScoreArea

func _ready() -> void:
	high_score_label.text = "%d" % GameManager.high_score
	start_button.pressed.connect(_on_start_pressed)
	toggle_sound_button.pressed.connect(_on_toggle_sound_pressed)
	_update_sound_button()
	_play_entrance()

func _update_sound_button() -> void:
	toggle_sound_button.text = "音效：%s" % ("开" if SoundManager.sound_enabled else "关")

func _on_start_pressed() -> void:
	SoundManager.play_button()
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_toggle_sound_pressed() -> void:
	SoundManager.set_sound_enabled(not SoundManager.sound_enabled)
	_update_sound_button()

## 入场动画：标题下滑、副标题淡入、分数区缩放、按钮依次弹入
func _play_entrance() -> void:
	# 初始状态
	title.modulate.a = 0.0
	title.position.y -= 40
	subtitle.modulate.a = 0.0
	score_area.modulate.a = 0.0
	score_area.scale = Vector2(0.8, 0.8)
	score_area.pivot_offset = score_area.size / 2.0
	start_button.modulate.a = 0.0
	start_button.scale = Vector2(0.8, 0.8)
	start_button.pivot_offset = start_button.size / 2.0
	toggle_sound_button.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	# 标题
	tw.tween_property(title, "modulate:a", 1.0, 0.4)
	tw.tween_property(title, "position:y", title.position.y + 40, 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 副标题
	tw.tween_property(subtitle, "modulate:a", 1.0, 0.3).set_delay(0.15)
	# 分数区
	tw.tween_property(score_area, "modulate:a", 1.0, 0.3).set_delay(0.25)
	tw.tween_property(score_area, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	# 开始按钮
	tw.tween_property(start_button, "modulate:a", 1.0, 0.3).set_delay(0.4)
	tw.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.4)
	# 音效按钮
	tw.tween_property(toggle_sound_button, "modulate:a", 1.0, 0.3).set_delay(0.55)
