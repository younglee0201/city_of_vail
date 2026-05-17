extends Node2D
class_name Player

var grid_pos: Vector2i = Vector2i.ZERO


func place_at(grid_position: Vector2i, screen_position: Vector2) -> void:
	grid_pos = grid_position
	position = screen_position
