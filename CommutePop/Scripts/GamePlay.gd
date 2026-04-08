extends Control

@onready var score_label: Label = %ScoreLabel
@onready var timer_label: Label = %TimerLabel
@onready var combo_label: Label = %ComboLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_hint: Label = %ProgressHint
@onready var restart_button: Button = %RestartButton
@onready var home_button: Button = %HomeButton
@onready var pause_button: Button = %PauseButton
@onready var grid: Grid = %Grid
@onready var countdown_label: Label = %CountdownLabel

var _combo_tween: Tween
var _timer_tween: Tween
var _score_tween: Tween
var _progress_tween: Tween
var _paused := false
const _TUTORIAL_KEY := "tutorial_shown"

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.game_finished.connect(_on_game_finished)
	grid.blocks_cleared.connect(_on_blocks_cleared)
	grid.combo_changed.connect(_on_combo_changed)
	restart_button.pressed.connect(_on_restart_pressed)
	home_button.pressed.connect(_on_home_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	progress_bar.max_value = GameManager.target_score
	progress_hint.text = "目标：%d 分" % GameManager.target_score
	_on_score_changed(0)
	_on_time_changed(GameManager.DEFAULT_TIME)
	_on_combo_changed(0)
	# 禁止交互，先播放开局倒计时
	grid.interaction_locked = true
	# 首次游玩先展示教程
	if _is_first_play():
		await _show_tutorial()
	_play_countdown()

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
	# Progress bar 平滑过渡
	if _progress_tween:
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(progress_bar, "value", float(score), 0.25)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 分数弹跳动画（score=0 初始化时跳过）
	if score == 0:
		return
	score_label.pivot_offset = score_label.size / 2.0
	if _score_tween:
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_score_tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.12)

func _on_time_changed(time_left: float) -> void:
	timer_label.text = "%d" % ceili(time_left)
	if time_left <= 5.0:
		timer_label.add_theme_color_override("font_color", Color("ff6b6b"))
		SoundManager.play_alarm()
		# 脉冲放大动画（从中心缩放）
		timer_label.pivot_offset = timer_label.size / 2.0
		if _timer_tween:
			_timer_tween.kill()
		_timer_tween = create_tween()
		_timer_tween.tween_property(timer_label, "scale", Vector2(1.4, 1.4), 0.1)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_timer_tween.tween_property(timer_label, "scale", Vector2(1.0, 1.0), 0.2)
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
	combo_label.pivot_offset = combo_label.size / 2.0
	# 颜色阶梯：2连=黄，3连=橙，4连+=红
	var c := Color("ffd93d")
	if combo >= 4:
		c = Color("ff6b6b")
	elif combo >= 3:
		c = Color("ff9f43")
	combo_label.add_theme_color_override("font_color", c)
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.08)
	_combo_tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12)

func _on_restart_pressed() -> void:
	SoundManager.play_button()
	get_tree().reload_current_scene()

func _on_home_pressed() -> void:
	SoundManager.play_button()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_game_finished(_result: Dictionary) -> void:
	if _result.get("won", false):
		SoundManager.play_win()
	AdManager.record_game_played()
	if AdManager.should_show_interstitial():
		await AdManager.show_interstitial_ad()
	get_tree().change_scene_to_file("res://Scenes/ResultScreen.tscn")

## 开局 3-2-1-Go 倒计时
func _play_countdown() -> void:
	countdown_label.visible = true
	countdown_label.pivot_offset = countdown_label.size / 2.0
	for text in ["3", "2", "1", "Go!"]:
		countdown_label.text = text
		countdown_label.scale = Vector2(0.3, 0.3)
		countdown_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(countdown_label, "modulate:a", 0.3, 0.5)
		SoundManager.play_button()
		await get_tree().create_timer(0.7).timeout
	# 倒计时结束：隐藏标签，启动游戏
	countdown_label.visible = false
	GameManager.begin_or_resume_run()
	grid.interaction_locked = false

## 暂停/继续
func _on_pause_pressed() -> void:
	SoundManager.play_button()
	_paused = not _paused
	get_tree().paused = _paused
	pause_button.text = "继续" if _paused else "暂停"
	grid.interaction_locked = _paused

## ── 新手教学 ──────────────────────────────────────────

func _is_first_play() -> bool:
	if not FileAccess.file_exists(GameManager.SAVE_PATH):
		return true
	var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
	if file == null:
		return true
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get(_TUTORIAL_KEY, false):
		return false
	return true

func _mark_tutorial_shown() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		var rf := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
		if rf:
			var parsed: Variant = JSON.parse_string(rf.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data[_TUTORIAL_KEY] = true
	var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _show_tutorial() -> void:
	# 半透明遮罩 + 居中教学文字 + 点击关闭
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -280
	vbox.offset_top = -200
	vbox.offset_right = 280
	vbox.offset_bottom = 200
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	overlay.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "🎮 游戏玩法"
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", Color("ffd93d"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var tips := [
		"👆 点击方块，相邻同色块一起消除",
		"🔗 至少连接 2 个同色方块才能消除",
		"⚡ 快速消除可触发连击加分",
		"⏱ 在倒计时结束前尽量拿高分！",
	]
	for tip in tips:
		var lbl := Label.new()
		lbl.text = tip
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	var hint := Label.new()
	hint.text = "点击任意位置开始"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	# 入场动画
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.3)

	# 等待点击
	await overlay.gui_input
	SoundManager.play_button()
	_mark_tutorial_shown()

	# 退场
	var tw2 := create_tween()
	tw2.tween_property(overlay, "modulate:a", 0.0, 0.2)
	await tw2.finished
	overlay.queue_free()