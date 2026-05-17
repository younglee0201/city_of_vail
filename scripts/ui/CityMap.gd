extends Node2D

const GRID_COLS: int = 17
const GRID_ROWS: int = 13
const MASK_PATH := "res://resources/data/city_mask.json"
const HEART_CELLS := [
	Vector2i(8, 6),
]
const NEIGHBOR_DELTAS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

const GROUND_TEX_PATHS := [
	"res://resources/assets/ground/ground_001.png",
	"res://resources/assets/ground/ground_002.png",
	"res://resources/assets/ground/ground_003.png",
]
const HEART_TEX_PATH := "res://resources/assets/heart/heart_001.png"
const TILE_SIZE := Vector2i(120, 120)
const UNIT_Y_OFFSET := 0
const TILE_ATLAS_COORD := Vector2i(0, 0)
const Z_STRUCTURE := 0
const Z_UNIT := 10
const ZOOM_STEP: float = 1.1
const ZOOM_MIN_FALLBACK: float = 0.5
const ZOOM_MAX_FALLBACK: float = 2.5
const PLAYER_VISIBLE_RADIUS_TILES: float = 1.5
const ENEMY_SPAWN_BASE: int = 1
const ENEMY_SPAWN_INCREMENT_INTERVAL: int = 3
const ENEMY_SPAWN_INCREMENT_FROM_ROUND: int = 1
const HIGHLIGHT_COLOR := Color(1.0, 0.55, 0.0, 0.4)
const Z_HIGHLIGHT: int = 5


class MovementHighlight extends Node2D:
	var cells: Array = []
	var tile_size_px: int = 120
	var color: Color = Color(1.0, 0.55, 0.0, 0.4)

	func set_cells(new_cells: Array) -> void:
		cells = new_cells
		queue_redraw()

	func _draw() -> void:
		var size: Vector2 = Vector2(tile_size_px, tile_size_px)
		for cell in cells:
			var pos: Vector2 = Vector2(cell.x * tile_size_px, cell.y * tile_size_px)
			draw_rect(Rect2(pos, size), color, true)

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/enemy/Enemy.tscn")
@export var turn_manager_path: NodePath

@onready var turn_manager: TurnManager = get_node(turn_manager_path) as TurnManager

var player: Player
var enemies: Array[Enemy] = []
var pending_battle_enemy: Enemy = null
var pending_battle_was_player_move: bool = false
var current_battle_dialog: AcceptDialog = null
var mask: Array = []
var walkable_cells: Array[Vector2i] = []
var edge_walkable_cells: Array[Vector2i] = []
var dist_to_heart: Dictionary = {}
var tile_map_layer: TileMapLayer
var structure_layer: Node2D
var highlight_layer: MovementHighlight
var camera: CameraController
var camera_home: Vector2 = Vector2.ZERO
var min_zoom: float = ZOOM_MIN_FALLBACK
var max_zoom: float = ZOOM_MAX_FALLBACK


func _ready() -> void:
	_load_mask()
	_build_walkable_caches()
	_setup_tilemap()
	_setup_structure_layer()
	_setup_highlight_layer()
	_paint_map()
	_place_buildings()
	_place_heart()
	_setup_camera()
	_spawn_player(_random_player_start())
	if turn_manager != null:
		turn_manager.turn_ended.connect(_on_turn_ended)
		turn_manager.round_advanced.connect(_on_round_advanced)
		turn_manager.moves_changed.connect(_on_moves_changed)


func _setup_highlight_layer() -> void:
	highlight_layer = MovementHighlight.new()
	highlight_layer.name = "MovementHighlight"
	highlight_layer.tile_size_px = TILE_SIZE.x
	highlight_layer.color = HIGHLIGHT_COLOR
	highlight_layer.z_index = Z_HIGHLIGHT
	add_child(highlight_layer)


func _setup_camera() -> void:
	camera_home = _grid_to_screen(HEART_CELLS[0])
	min_zoom = _compute_fit_zoom()
	max_zoom = _compute_max_zoom()
	camera = CameraController.new()
	camera.name = "MapCamera"
	camera.zoom = Vector2(min_zoom, min_zoom)
	camera.global_position = camera_home
	add_child(camera)
	camera.make_current()


func _compute_fit_zoom() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var map_height_px: float = float(GRID_ROWS * TILE_SIZE.y)
	if map_height_px <= 0.0 or viewport_size.y <= 0.0:
		return ZOOM_MIN_FALLBACK
	return viewport_size.y / map_height_px


func _compute_max_zoom() -> float:
	var viewport_size: Vector2 = get_viewport_rect().size
	var tile: float = float(TILE_SIZE.y)
	if tile <= 0.0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return ZOOM_MAX_FALLBACK
	var span_px: float = (PLAYER_VISIBLE_RADIUS_TILES * 2.0) * tile
	return minf(viewport_size.y / span_px, viewport_size.x / span_px)


func _setup_tilemap() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_SQUARE
	tile_set.tile_size = TILE_SIZE

	for i in GROUND_TEX_PATHS.size():
		var source := TileSetAtlasSource.new()
		source.texture = load(GROUND_TEX_PATHS[i]) as Texture2D
		source.texture_region_size = TILE_SIZE
		source.create_tile(TILE_ATLAS_COORD)
		tile_set.add_source(source, i)

	tile_map_layer = TileMapLayer.new()
	tile_map_layer.name = "GroundLayer"
	tile_map_layer.tile_set = tile_set
	add_child(tile_map_layer)
	move_child(tile_map_layer, 0)


func _setup_structure_layer() -> void:
	structure_layer = Node2D.new()
	structure_layer.name = "StructureLayer"
	structure_layer.y_sort_enabled = true
	structure_layer.z_index = Z_STRUCTURE
	add_child(structure_layer)


func _paint_map() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := Vector2i(col, row)
			var src_id: int = randi() % GROUND_TEX_PATHS.size()
			tile_map_layer.set_cell(cell, src_id, TILE_ATLAS_COORD, 0)


func _grid_to_screen(grid_pos: Vector2i) -> Vector2:
	return tile_map_layer.map_to_local(grid_pos)


func _grid_to_unit_screen(grid_pos: Vector2i) -> Vector2:
	return _grid_to_screen(grid_pos) + Vector2(0, UNIT_Y_OFFSET)


func _place_buildings() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := Vector2i(col, row)
			if cell in HEART_CELLS:
				continue
			var building_id: int = _mask_at(cell)
			if building_id == 0:
				continue
			var entry: BuildingData.BuildingEntry = BuildingData.by_id(building_id)
			if entry == null:
				push_warning("city_mask.json references building id %d at %s, not in buildings.json" % [building_id, cell])
				continue
			var tex_path: String = BuildingData.random_texture_path(entry)
			if tex_path == "":
				push_warning("Building id %d (icon=%s) has no art" % [entry.id, entry.icon])
				continue
			_spawn_structure_sprite(cell, load(tex_path) as Texture2D)


func _place_heart() -> void:
	_spawn_structure_sprite(HEART_CELLS[0], load(HEART_TEX_PATH) as Texture2D)


func _spawn_structure_sprite(cell: Vector2i, tex: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = _grid_to_screen(cell) + Vector2(0, float(TILE_SIZE.y) / 2.0)
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	structure_layer.add_child(sprite)
	return sprite


func _load_mask() -> void:
	var file := FileAccess.open(MASK_PATH, FileAccess.READ)
	if file == null:
		push_error("city_mask.json not found at %s" % MASK_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("city_mask.json is not a valid JSON object")
		return
	mask = (parsed as Dictionary).get("mask", [])


func _mask_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= mask.size():
		return -1
	var row: Array = mask[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return -1
	return int(row[cell.x])


func _is_walkable(cell: Vector2i) -> bool:
	return _mask_at(cell) == 0


func _build_walkable_caches() -> void:
	walkable_cells.clear()
	edge_walkable_cells.clear()
	dist_to_heart.clear()
	var min_row := GRID_ROWS
	var max_row := -1
	var min_col := GRID_COLS
	var max_col := -1
	for row in GRID_ROWS:
		for col in GRID_COLS:
			var cell := Vector2i(col, row)
			if not _is_walkable(cell):
				continue
			walkable_cells.append(cell)
			min_row = mini(min_row, row)
			max_row = maxi(max_row, row)
			min_col = mini(min_col, col)
			max_col = maxi(max_col, col)
	for cell in walkable_cells:
		if cell in HEART_CELLS:
			continue
		if cell.y == min_row or cell.y == max_row or cell.x == min_col or cell.x == max_col:
			edge_walkable_cells.append(cell)
	var target: Vector2i = HEART_CELLS[0]
	if not _is_walkable(target):
		return
	var queue: Array[Vector2i] = [target]
	dist_to_heart[target] = 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = dist_to_heart[cur]
		for delta in NEIGHBOR_DELTAS:
			var nxt: Vector2i = cur + delta
			if not _is_walkable(nxt) or dist_to_heart.has(nxt):
				continue
			dist_to_heart[nxt] = d + 1
			queue.append(nxt)


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
	if not _in_bounds(new_pos) or not _is_walkable(new_pos):
		return
	player.place_at(new_pos, _grid_to_unit_screen(new_pos))
	var enemy_here := _enemy_at(new_pos)
	if enemy_here != null:
		pending_battle_enemy = enemy_here
		pending_battle_was_player_move = true
		_show_battle_dialog(enemy_here)
	else:
		turn_manager.consume_move()


func _on_turn_ended() -> void:
	_move_enemies()


func _on_moves_changed(_remaining: int) -> void:
	_update_movement_highlights()


func _update_movement_highlights() -> void:
	if highlight_layer == null:
		return
	if player == null or turn_manager == null or pending_battle_enemy != null:
		highlight_layer.set_cells([])
		return
	var moves: int = turn_manager.moves_remaining
	if moves <= 0:
		highlight_layer.set_cells([])
		return
	highlight_layer.set_cells(_reachable_cells(player.grid_pos, moves))


func _reachable_cells(start: Vector2i, max_steps: int) -> Array:
	var result: Array = []
	if max_steps <= 0:
		return result
	var visited: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = visited[cur]
		if d >= max_steps:
			continue
		for delta in NEIGHBOR_DELTAS:
			var nxt: Vector2i = cur + delta
			if not _is_walkable(nxt) or visited.has(nxt):
				continue
			visited[nxt] = d + 1
			queue.append(nxt)
			result.append(nxt)
	return result


func _on_round_advanced(round_no: int) -> void:
	for i in _enemies_to_spawn(round_no):
		var enemy := _spawn_enemy()
		await _focus_camera_on(enemy)


func _enemies_to_spawn(round_no: int) -> int:
	var rounds_since: int = maxi(0, round_no - ENEMY_SPAWN_INCREMENT_FROM_ROUND)
	return ENEMY_SPAWN_BASE + rounds_since / ENEMY_SPAWN_INCREMENT_INTERVAL


func _spawn_player(grid_pos: Vector2i) -> void:
	player = player_scene.instantiate() as Player
	player.z_index = Z_UNIT
	add_child(player)
	player.place_at(grid_pos, _grid_to_unit_screen(grid_pos))


func _spawn_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.z_index = Z_UNIT
	add_child(enemy)
	var pos := _random_edge_cell()
	enemy.place_at(pos, _grid_to_unit_screen(pos))
	enemies.append(enemy)
	return enemy


func _focus_camera_on(enemy: Enemy) -> void:
	if camera == null:
		return
	var pan_duration := 0.4
	camera.move_to(enemy.global_position, pan_duration)
	await get_tree().create_timer(pan_duration + 2.0).timeout
	camera.move_to(camera_home, pan_duration)
	await get_tree().create_timer(pan_duration).timeout


func _random_player_start() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in walkable_cells:
		if cell not in HEART_CELLS:
			candidates.append(cell)
	if candidates.is_empty():
		push_error("No walkable cells available for player spawn")
		return Vector2i.ZERO
	return candidates[randi() % candidates.size()]


func _random_edge_cell() -> Vector2i:
	if edge_walkable_cells.is_empty():
		push_error("No edge walkable cells available for enemy spawn")
		return Vector2i.ZERO
	return edge_walkable_cells[randi() % edge_walkable_cells.size()]


func _move_enemies() -> void:
	for enemy in enemies:
		if enemy == pending_battle_enemy:
			continue
		var next_pos := _step_toward_center(enemy.grid_pos)
		enemy.place_at(next_pos, _grid_to_unit_screen(next_pos))
	for enemy in enemies:
		if enemy != pending_battle_enemy and enemy.grid_pos == player.grid_pos:
			pending_battle_enemy = enemy
			pending_battle_was_player_move = false
			_show_battle_dialog(enemy)
			return


func _step_toward_center(pos: Vector2i) -> Vector2i:
	if not dist_to_heart.has(pos):
		return pos
	var current_dist: int = dist_to_heart[pos]
	if current_dist == 0:
		return pos
	var best := pos
	var best_dist := current_dist
	for delta in NEIGHBOR_DELTAS:
		var nxt: Vector2i = pos + delta
		if not dist_to_heart.has(nxt):
			continue
		var nd: int = dist_to_heart[nxt]
		if nd < best_dist:
			best_dist = nd
			best = nxt
	return best


func _enemy_at(pos: Vector2i) -> Enemy:
	for enemy in enemies:
		if enemy.grid_pos == pos:
			return enemy
	return null


func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_COLS and pos.y >= 0 and pos.y < GRID_ROWS


func _zoom_camera(factor: float) -> void:
	if camera == null:
		return
	var old_zoom: float = camera.zoom.x
	var new_zoom: float = clamp(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(new_zoom, old_zoom):
		return
	camera.zoom = Vector2(new_zoom, new_zoom)
	if player != null:
		var t: float = 1.0 - min_zoom / new_zoom
		var cam_pos: Vector2 = camera_home + (player.global_position - camera_home) * t
		camera.global_position = _clamp_cam_to_player_visible(cam_pos, new_zoom)


func _clamp_cam_to_player_visible(cam_pos: Vector2, zoom_value: float) -> Vector2:
	if player == null or zoom_value <= 0.0:
		return cam_pos
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view_w: float = viewport_size.x / (2.0 * zoom_value)
	var half_view_h: float = viewport_size.y / (2.0 * zoom_value)
	var margin: float = PLAYER_VISIBLE_RADIUS_TILES * float(TILE_SIZE.y)
	var max_offset_x: float = maxf(0.0, half_view_w - margin)
	var max_offset_y: float = maxf(0.0, half_view_h - margin)
	var diff: Vector2 = cam_pos - player.global_position
	diff.x = clampf(diff.x, -max_offset_x, max_offset_x)
	diff.y = clampf(diff.y, -max_offset_y, max_offset_y)
	return player.global_position + diff


func _show_battle_dialog(enemy: Enemy) -> void:
	_update_movement_highlights()
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
	else:
		_update_movement_highlights()
