extends Node2D
class_name Enemy

const SIZE: float = 14.0
const FILL_COLOR := Color(0.85, 0.25, 0.25)
const OUTLINE_COLOR := Color(0.25, 0.05, 0.05)
const OUTLINE_WIDTH: float = 2.0

var grid_pos: Vector2i = Vector2i.ZERO


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(0, -SIZE),
		Vector2(SIZE * 0.866, SIZE * 0.5),
		Vector2(-SIZE * 0.866, SIZE * 0.5),
	])
	draw_colored_polygon(points, FILL_COLOR)
	var outline := PackedVector2Array([points[0], points[1], points[2], points[0]])
	draw_polyline(outline, OUTLINE_COLOR, OUTLINE_WIDTH)


func place_at(grid_position: Vector2i, cell_size: int) -> void:
	grid_pos = grid_position
	position = Vector2(
		grid_position.x * cell_size + cell_size * 0.5,
		grid_position.y * cell_size + cell_size * 0.5
	)
