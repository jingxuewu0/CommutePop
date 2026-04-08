extends Node

## SoundManager — 管理全部音效的全局单例
## 使用预加载的 WAV 文件播放，通过 pitch_scale 产生音调变化。

const SAVE_KEY_SOUND := "sound_enabled"

# 预加载音效资源
var _sfx_click: AudioStream = preload("res://Assets/Sounds/click_beep.wav")
# var _sfx_pop: AudioStream = preload("res://Assets/Sounds/pop_success.wav")
var _sfx_pop: AudioStream = preload("res://Assets/Sounds/mouth-pop2.wav")
var _sfx_fanfare: AudioStream = preload("res://Assets/Sounds/fanfare_short.wav")

var sound_enabled := true

# 多个播放器：允许同帧叠加不同音效
var _click_player: AudioStreamPlayer
var _pop_players: Array[AudioStreamPlayer] = []
var _pop_index := 0
var _fanfare_player: AudioStreamPlayer
var _alarm_player: AudioStreamPlayer

func _ready() -> void:
	_load_settings()
	_build_players()

# ── 公开 API ──────────────────────────────────────────────

## 无效点击（低沉短促的 click）
func play_tap_invalid() -> void:
	_play(_click_player, _sfx_click, -10.0, 0.7)

## 按钮点击
func play_button() -> void:
	_play(_click_player, _sfx_click, -8.0, 1.0)

## 消除音（方块越多音调越高）
func play_clear(match_count: int) -> void:
	var pitch := 0.9 + clampf((match_count - 2) * 0.12, 0.0, 0.8)
	var player := _pop_players[_pop_index]
	_pop_index = (_pop_index + 1) % _pop_players.size()
	_play(player, _sfx_pop, -4.0, pitch)

## 连击音（连击越多音调越高，叠加在消除音之上）
func play_combo(combo: int) -> void:
	var pitch := 1.0 + (combo - 2) * 0.15
	var player := _pop_players[_pop_index]
	_pop_index = (_pop_index + 1) % _pop_players.size()
	_play(player, _sfx_pop, -2.0, clampf(pitch, 1.0, 2.0))

## 倒计时警报（快节奏高音 click）
func play_alarm() -> void:
	_play(_alarm_player, _sfx_click, -6.0, 1.5)

## 新纪录 / 通关庆祝
func play_new_record() -> void:
	_play(_fanfare_player, _sfx_fanfare, -2.0, 1.0)

## 通关音（略低于新纪录以区分）
func play_win() -> void:
	_play(_fanfare_player, _sfx_fanfare, -4.0, 0.9)

func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	_save_settings()

# ── 内部实现 ──────────────────────────────────────────────

func _build_players() -> void:
	_click_player = _make_player()
	# 消除/连击可能同帧重叠，准备 4 个 pop 播放器轮转
	for i in range(4):
		_pop_players.append(_make_player())
	_fanfare_player = _make_player()
	_alarm_player = _make_player()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p

func _play(player: AudioStreamPlayer, stream: AudioStream,
		volume_db: float, pitch: float) -> void:
	if not sound_enabled:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

func _load_settings() -> void:
	if not FileAccess.file_exists(GameManager.SAVE_PATH):
		return
	var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	if result is Dictionary:
		sound_enabled = result.get(SAVE_KEY_SOUND, true)

func _save_settings() -> void:
	# 合并写入，避免覆盖 high_score
	var data: Dictionary = {}
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data[SAVE_KEY_SOUND] = sound_enabled
	var file := FileAccess.open(GameManager.SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
