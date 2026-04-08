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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.finished.connect(queue_free)
	return tween.finished