extends Camera2D
class_name CameraController

var _move_tween: Tween


func move_to(world_pos: Vector2, duration: float = 0.0) -> void:
	_kill_move_tween()
	if duration <= 0.0:
		global_position = world_pos
		return
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", world_pos, duration)


func move_by(delta: Vector2, duration: float = 0.0) -> void:
	move_to(global_position + delta, duration)


func _kill_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
