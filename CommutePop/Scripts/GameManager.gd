extends Node

signal score_changed(score: int)
signal time_changed(time_left: float)
signal game_finished(result: Dictionary)
signal revive_used
signal new_record(score: int)

const SAVE_PATH := "user://save.json"
const DEFAULT_TIME := 30.0
const DEFAULT_TARGET_SCORE := 1000

var score := 0
var high_score := 0
var time_left: float = DEFAULT_TIME
var target_score := DEFAULT_TARGET_SCORE
var revive_available := true
var pending_resume := false
var last_run_is_new_record := false
var _game_running := false

func _ready() -> void:
	high_score = load_high_score()

func _process(delta: float) -> void:
	if not _game_running:
		return
	var prev_ceil := ceili(time_left)
	time_left = maxf(time_left - delta, 0.0)
	if ceili(time_left) != prev_ceil:
		time_changed.emit(time_left)
	if time_left <= 0.0:
		_game_running = false
		finish_run()

func start_run() -> void:
	pending_resume = false
	score = 0
	time_left = DEFAULT_TIME
	target_score = DEFAULT_TARGET_SCORE
	revive_available = true
	_game_running = true
	score_changed.emit(score)
	time_changed.emit(time_left)

func begin_or_resume_run() -> void:
	if pending_resume:
		pending_resume = false
		_game_running = true
		score_changed.emit(score)
		time_changed.emit(time_left)
		return
	start_run()

func register_clear(_block_count: int, score_gained: int) -> void:
	score += score_gained
	score_changed.emit(score)

func finish_run(last_clear_count: int = 0) -> void:
	_game_running = false
	var is_new_record := score > high_score and score > 0
	high_score = maxi(high_score, score)
	last_run_is_new_record = is_new_record
	save_high_score(high_score)
	if is_new_record:
		new_record.emit(high_score)
	var won := score >= target_score
	game_finished.emit({
		"is_new_record": is_new_record,
		"score": score,
		"high_score": high_score,
		"target_score": target_score,
		"won": won,
		"last_clear_count": last_clear_count,
		"revive_available": revive_available
	})


func can_revive() -> bool:
	return revive_available

func apply_revive() -> void:
	if not revive_available:
		return
	revive_available = false
	time_left += 10.0
	pending_resume = true
	revive_used.emit()

func apply_double_score() -> int:
	score *= 2
	high_score = max(high_score, score)
	save_high_score(high_score)
	score_changed.emit(score)
	return score

func save_high_score(value: int) -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var rf := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if rf:
			var parsed: Variant = JSON.parse_string(rf.get_as_text())
			if parsed is Dictionary:
				data = parsed
	data["high_score"] = value
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))

func load_high_score() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	return int(parsed.get("high_score", 0))
