extends Node2D
class_name Player

const RADIUS: float = 16.0
const FILL_COLOR := Color(0.95, 0.72, 0.3)
const OUTLINE_COLOR := Color(0.18, 0.12, 0.05)
const OUTLINE_WIDTH: float = 2.0

var grid_pos: Vector2i = Vector2i.ZERO


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FILL_COLOR)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, OUTLINE_COLOR, OUTLINE_WIDTH)


func place_at(grid_position: Vector2i, cell_size: int) -> void:
	grid_pos = grid_position
	position = Vector2(
		grid_position.x * cell_size + cell_size * 0.5,
		grid_position.y * cell_size + cell_size * 0.5
	)
