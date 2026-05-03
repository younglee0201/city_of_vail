extends Control

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
