extends Control

@onready var title_label: Label = %Title
@onready var score_label: Label = %ScoreLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var status_label: Label = %StatusLabel
@onready var revive_button: Button = %ReviveButton
@onready var double_score_button: Button = %DoubleScoreButton
@onready var replay_button: Button = %ReplayButton
@onready var home_button: Button = %HomeButton

@onready var card: PanelContainer = $Center/Card

func _ready() -> void:
	var result := {
		"score": GameManager.score,
		"high_score": GameManager.high_score,
		"target_score": GameManager.target_score,
		"won": GameManager.score >= GameManager.target_score,
		"revive_available": GameManager.can_revive(),
		"is_new_record": GameManager.last_run_is_new_record
	}
	_refresh_ui(result)
	revive_button.pressed.connect(_on_revive_pressed)
	double_score_button.pressed.connect(_on_double_pressed)
	replay_button.pressed.connect(_on_replay_pressed)
	home_button.pressed.connect(_on_home_pressed)
	_play_card_entrance()

func _refresh_ui(result: Dictionary) -> void:
	var score: int = result.get("score", 0)
	var high_score: int = result.get("high_score", 0)
	var target_score: int = result.get("target_score", 0)
	var won: bool = result.get("won", false)
	var revive_available: bool = result.get("revive_available", false)
	var is_new_record: bool = result.get("is_new_record", false)
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
	# 0分时隐藏双倍按钮（没意义）
	double_score_button.visible = score > 0
	# 分数滚动计数动画
	_animate_score_count(score)
	if is_new_record:
		# 延迟一点播放新纪录效果，让分数滚完
		get_tree().create_timer(0.6).timeout.connect(_play_new_record_effect)

## 分数从 0 滚到实际值的计数动画
func _animate_score_count(target: int) -> void:
	score_label.text = "0"
	var tween := create_tween()
	tween.tween_method(func(v: float):
		score_label.text = "%d" % int(v)
	, 0.0, float(target), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 滚完后做一次弹跳
	tween.finished.connect(func():
		score_label.pivot_offset = score_label.size / 2.0
		var tw := create_tween()
		tw.tween_property(score_label, "scale", Vector2(1.2, 1.2), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.12)
	)

## 新纪录庆祝：高分标签放大弹出 + 标题闪烁 + 播放庆祝音
func _play_new_record_effect() -> void:
	SoundManager.play_new_record()
	# 高分标签弹出
	high_score_label.add_theme_color_override("font_color", Color("ffd93d"))
	high_score_label.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(high_score_label, "scale", Vector2(1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(high_score_label, "scale", Vector2(1.0, 1.0), 0.15)
	# 标题替换为新纪录提示并闪烁
	title_label.text = "🏆 新纪录！"
	title_label.add_theme_color_override("font_color", Color("ffd93d"))
	var title_tw := create_tween().set_loops(3)
	title_tw.tween_property(title_label, "modulate:a", 0.4, 0.15)
	title_tw.tween_property(title_label, "modulate:a", 1.0, 0.15)

func _on_revive_pressed() -> void:
	SoundManager.play_button()
	revive_button.disabled = true
	await AdManager.show_reward_ad(func():
		GameManager.apply_revive()
	)
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_double_pressed() -> void:
	SoundManager.play_button()
	double_score_button.disabled = true
	await AdManager.show_reward_ad(func():
		GameManager.apply_double_score()
	)
	_refresh_ui({
		"score": GameManager.score,
		"high_score": GameManager.high_score,
		"target_score": GameManager.target_score,
		"won": GameManager.score >= GameManager.target_score,
		"revive_available": GameManager.can_revive(),
		"is_new_record": false
	})

func _on_replay_pressed() -> void:
	SoundManager.play_button()
	get_tree().change_scene_to_file("res://Scenes/GamePlay.tscn")

func _on_home_pressed() -> void:
	SoundManager.play_button()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

## 结算卡片入场：从缩小+透明弹入
func _play_card_entrance() -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.6, 0.6)
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "scale", Vector2(1.0, 1.0), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.25)