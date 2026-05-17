extends Node2D
class_name Enemy

const TEXTURES: Array[Texture2D] = [
	preload("res://resources/assets/thief/thief_001.png"),
	preload("res://resources/assets/thief/thief_002.png"),
	preload("res://resources/assets/thief/thief_003.png"),
]

@onready var sprite: Sprite2D = $Sprite2D

var grid_pos: Vector2i = Vector2i.ZERO


func _ready() -> void:
	sprite.texture = TEXTURES[randi() % TEXTURES.size()]


func place_at(grid_position: Vector2i, screen_position: Vector2) -> void:
	grid_pos = grid_position
	position = screen_position
