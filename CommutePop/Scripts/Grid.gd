extends Node2D
class_name Grid

signal blocks_cleared(count: int, score_gained: int)
signal combo_changed(combo: int)

@export var grid_size: int = 6
@export var block_scene: PackedScene

const BLOCK_SPACING := 82
const MIN_MATCH_COUNT := 2
const COMBO_WINDOW_SECONDS := 3.0

var cells: Dictionary = {}
var interaction_locked := false
var combo_count := 0
var combo_timer := 0.0

func _ready() -> void:
	randomize()
	generate_grid()

func _process(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0 and combo_count != 0:
			combo_count = 0
			combo_changed.emit(combo_count)

func reset_board() -> void:
	interaction_locked = true
	for block in cells.values():
		block.queue_free()
	cells.clear()
	combo_count = 0
	combo_timer = 0.0
	generate_grid()
	interaction_locked = false
	combo_changed.emit(combo_count)

func generate_grid() -> void:
	for row in range(grid_size):
		for col in range(grid_size):
			spawn_block(col, row, false)

func _input(event: InputEvent) -> void:
	if interaction_locked:
		return
	var local_pos: Vector2
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		local_pos = get_local_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		var global_pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * event.position
		local_pos = to_local(global_pos)
	else:
		return
	var col := int(local_pos.x / BLOCK_SPACING)
	var row := int(local_pos.y / BLOCK_SPACING)
	if col < 0 or col >= grid_size or row < 0 or row >= grid_size:
		return
	get_viewport().set_input_as_handled()
	_on_block_tapped(col, row)

func spawn_block(col: int, row: int, animated: bool) -> Area2D:
	var block: Area2D = block_scene.instantiate()
	block.color_id = randi() % 4
	block.set_grid_position(col, row, animated)
	add_child(block)
	cells[Vector2i(col, row)] = block
	return block

func _on_block_tapped(col: int, row: int) -> void:
	if interaction_locked:
		return
	var matched := find_connected(Vector2i(col, row))
	if matched.size() < MIN_MATCH_COUNT:
		return
	interaction_locked = true
	var combo_multiplier := _consume_combo_multiplier()
	var score_gained := _calculate_score(matched.size(), combo_multiplier)
	await remove_blocks(matched)
	fall_blocks()
	refill_grid()
	blocks_cleared.emit(matched.size(), score_gained)
	interaction_locked = false

func find_connected(origin: Vector2i) -> Array[Vector2i]:
	if not cells.has(origin):
		return []
	var target_color: int = cells[origin].color_id
	var visited := {}
	var queue: Array[Vector2i] = [origin]
	var connected: Array[Vector2i] = []
	var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		connected.append(current)
		for direction in directions:
			var next_pos: Vector2i = current + direction
			if not cells.has(next_pos):
				continue
			if visited.has(next_pos):
				continue
			if cells[next_pos].color_id == target_color:
				queue.append(next_pos)
	return connected

func remove_blocks(positions: Array[Vector2i]) -> void:
	var pending: Array = []
	for pos in positions:
		var block = cells.get(pos)
		if block == null:
			continue
		cells.erase(pos)
		pending.append(block.play_disappear())
	for state in pending:
		await state

func fall_blocks() -> void:
	for col in range(grid_size):
		var write_row := grid_size - 1
		for read_row in range(grid_size - 1, -1, -1):
			var current_pos := Vector2i(col, read_row)
			if not cells.has(current_pos):
				continue
			var new_pos := Vector2i(col, write_row)
			var block = cells[current_pos]
			if new_pos != current_pos:
				cells.erase(current_pos)
				cells[new_pos] = block
				block.set_grid_position(col, write_row, true)
			write_row -= 1

func refill_grid() -> void:
	# 按列分组，计算每列需要补充多少个，从上方依次落下
	var col_empty_count: Dictionary = {}
	for row in range(grid_size):
		for col in range(grid_size):
			if not cells.has(Vector2i(col, row)):
				col_empty_count[col] = col_empty_count.get(col, 0) + 1
	for row in range(grid_size):
		for col in range(grid_size):
			var pos := Vector2i(col, row)
			if cells.has(pos):
				continue
			var empty_above: int = int(col_empty_count.get(col, 1))
			var block = spawn_block(col, row, false)
			# 从格子上方 empty_above 格的位置落入
			block.position = Vector2(col * BLOCK_SPACING, -BLOCK_SPACING * empty_above)
			block.set_grid_position(col, row, true)

func _calculate_score(match_count: int, combo_multiplier: int) -> int:
	var base_score := match_count * 10
	var bonus := 0
	if match_count == 4:
		bonus = 50
	elif match_count >= 5:
		bonus = 150 + (match_count - 5) * 30
	return (base_score + bonus) * combo_multiplier

func _consume_combo_multiplier() -> int:
	if combo_timer > 0.0:
		combo_count += 1
	else:
		combo_count = 1
	combo_timer = COMBO_WINDOW_SECONDS
	combo_changed.emit(combo_count)
	return mini(combo_count, 5)