extends Area2D

@export var col: int = 0
@export var row: int = 0
@export var color_id: int = 0 : set = set_color_id

const COLORS := [
	Color("ff6b6b"),
	Color("ffd93d"),
	Color("4d96ff"),
	Color("6bcb77")
]

@onready var color_rect: ColorRect = %ColorRect

func _ready() -> void:
	input_pickable = true
	_refresh_visual()

func set_grid_position(new_col: int, new_row: int, animated: bool = false) -> void:
	col = new_col
	row = new_row
	var target := Vector2(col * 82, row * 82)
	if animated:
		var tween := create_tween()
		tween.tween_property(self, "position", target, 0.12).set_trans(Tween.TRANS_SINE)
	else:
		position = target

func set_color_id(value: int) -> void:
	color_id = clampi(value, 0, COLORS.size() - 1)
	_refresh_visual()

func _refresh_visual() -> void:
	if color_rect == null:
		return
	color_rect.color = COLORS[color_id]

func play_disappear():
	# 全并行模式 + delay，避免 modulate 和 modulate:a 冲突
	var tween := create_tween()
	tween.set_parallel(true)
	# 阶段1 (0~0.06s)：弹出放大
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 阶段1 (0~0.05s)：闪白
	tween.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	# 阶段2 (0.06s 后)：缩小 + 淡出 + 旋转
	tween.tween_property(self, "scale", Vector2.ZERO, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.06)
	tween.tween_property(self, "modulate:a", 0.0, 0.14).set_delay(0.06)
	tween.tween_property(self, "rotation", randf_range(-0.4, 0.4), 0.16).set_delay(0.06)
	tween.finished.connect(queue_free)
	return tween.finished

## 无效点击：左右微抖，提示"不够消除"
func play_shake() -> void:
	var origin := position
	var tween := create_tween()
	tween.tween_property(self, "position:x", origin.x - 6, 0.04)
	tween.tween_property(self, "position:x", origin.x + 6, 0.04)
	tween.tween_property(self, "position:x", origin.x - 4, 0.04)
	tween.tween_property(self, "position:x", origin.x, 0.04)