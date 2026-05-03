extends Node2D

const GRID_COLS: int = 36
const GRID_ROWS: int = 12
const CELL_SIZE: int = 48
const FILL_COLOR := Color(0.15, 0.18, 0.22)
const BORDER_COLOR := Color(0.4, 0.42, 0.46)
const HEART_COLOR := Color(0.5, 0.2, 0.28)
const BORDER_WIDTH: float = 2.0
const HEART_X_RANGE := Vector2i(17, 18)
const HEART_Y_RANGE := Vector2i(5, 6)
const HEART_CELLS := [
	Vector2i(17, 5), Vector2i(17, 6),
	Vector2i(18, 5), Vector2i(18, 6),
]
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 3.0
const ZOOM_STEP: float = 1.1

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
@export var player_start: Vector2i = Vector2i(17, 5)
@export var turn_manager_path: NodePath

@onready var turn_manager: TurnManager = get_node(turn_manager_path) as TurnManager

var player: Player
var enemies: Array[Enemy] = []
var pending_battle_enemy: Enemy = null
var pending_battle_was_player_move: bool = false
var current_battle_dialog: AcceptDialog = null


func _ready() -> void:
	_spawn_player(player_start)
	if turn_manager != null:
		turn_manager.turn_ended.connect(_on_turn_ended)
		turn_manager.round_advanced.connect(_on_round_advanced)
	_spawn_enemy()
	queue_redraw()


func _draw() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := Vector2i(col, row)
			var rect := Rect2(col * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			var fill := HEART_COLOR if cell in HEART_CELLS else FILL_COLOR
			draw_rect(rect, fill, true)
			draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(ZOOM_STEP)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / ZOOM_STEP)
			return
	if pending_battle_enemy != null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if turn_manager == null or turn_manager.moves_remaining <= 0:
		return
	var dir := Vector2i.ZERO
	match event.keycode:
		KEY_UP, KEY_W:
			dir = Vector2i(0, -1)
		KEY_DOWN, KEY_S:
			dir = Vector2i(0, 1)
		KEY_LEFT, KEY_A:
			dir = Vector2i(-1, 0)
		KEY_RIGHT, KEY_D:
			dir = Vector2i(1, 0)
		_:
			return
	var new_pos := player.grid_pos + dir
	if not _in_bounds(new_pos):
		return
	player.place_at(new_pos, CELL_SIZE)
	var enemy_here := _enemy_at(new_pos)
	if enemy_here != null:
		pending_battle_enemy = enemy_here
		pending_battle_was_player_move = true
		_show_battle_dialog(enemy_here)
	else:
		turn_manager.consume_move()


func _on_turn_ended() -> void:
	_move_enemies()


func _on_round_advanced(_round_no: int) -> void:
	_spawn_enemy()


func _spawn_player(grid_pos: Vector2i) -> void:
	player = player_scene.instantiate() as Player
	add_child(player)
	player.place_at(grid_pos, CELL_SIZE)


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.place_at(_random_edge_cell(), CELL_SIZE)
	enemies.append(enemy)


func _random_edge_cell() -> Vector2i:
	match randi_range(0, 3):
		0:
			return Vector2i(randi_range(0, GRID_COLS - 1), 0)
		1:
			return Vector2i(randi_range(0, GRID_COLS - 1), GRID_ROWS - 1)
		2:
			return Vector2i(0, randi_range(0, GRID_ROWS - 1))
		_:
			return Vector2i(GRID_COLS - 1, randi_range(0, GRID_ROWS - 1))


func _move_enemies() -> void:
	for enemy in enemies:
		if enemy == pending_battle_enemy:
			continue
		enemy.place_at(_step_toward_center(enemy.grid_pos), CELL_SIZE)
	for enemy in enemies:
		if enemy != pending_battle_enemy and enemy.grid_pos == player.grid_pos:
			pending_battle_enemy = enemy
			pending_battle_was_player_move = false
			_show_battle_dialog(enemy)
			return


func _step_toward_center(pos: Vector2i) -> Vector2i:
	var target_x: int = clampi(pos.x, HEART_X_RANGE.x, HEART_X_RANGE.y)
	var target_y: int = clampi(pos.y, HEART_Y_RANGE.x, HEART_Y_RANGE.y)
	var dx := target_x - pos.x
	var dy := target_y - pos.y
	if dx == 0 and dy == 0:
		return pos
	if absi(dx) >= absi(dy) and dx != 0:
		return pos + Vector2i(signi(dx), 0)
	return pos + Vector2i(0, signi(dy))


func _enemy_at(pos: Vector2i) -> Enemy:
	for enemy in enemies:
		if enemy.grid_pos == pos:
			return enemy
	return null


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_COLS and pos.y >= 0 and pos.y < GRID_ROWS


func _zoom_camera(factor: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var new_value: float = clamp(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_value, new_value)


func _show_battle_dialog(enemy: Enemy) -> void:
	current_battle_dialog = AcceptDialog.new()
	current_battle_dialog.title = "Battle!"
	current_battle_dialog.dialog_text = "敵人在 (%d, %d) 出現！\n\n[戰鬥系統 placeholder — 按下按鈕擊敗敵人]" % [enemy.grid_pos.x, enemy.grid_pos.y]
	current_battle_dialog.ok_button_text = "擊敗"
	current_battle_dialog.confirmed.connect(_on_battle_resolved)
	current_battle_dialog.canceled.connect(_on_battle_resolved)
	add_child(current_battle_dialog)
	current_battle_dialog.popup_centered()


func _on_battle_resolved() -> void:
	if current_battle_dialog != null:
		current_battle_dialog.queue_free()
		current_battle_dialog = null
	var resolved_enemy := pending_battle_enemy
	var was_player_move := pending_battle_was_player_move
	pending_battle_enemy = null
	pending_battle_was_player_move = false
	if resolved_enemy != null:
		enemies.erase(resolved_enemy)
		resolved_enemy.queue_free()
	if was_player_move and turn_manager != null:
		turn_manager.consume_move()
