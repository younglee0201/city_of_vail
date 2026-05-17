extends Node
class_name TurnManager

signal turn_started(turn_in_round: int, round_number: int)
signal turn_ended
signal round_finished(round_number: int)
signal round_advanced(round_number: int)
signal dice_rolled(value: int)
signal moves_changed(remaining: int)

const TURNS_PER_ROUND: int = 3

var round_number: int = 1
var turn_in_round: int = 1
var moves_remaining: int = 0
var dice_value: int = 0
var has_rolled: bool = false
var awaiting_next_round: bool = false


func roll_dice() -> int:
	if has_rolled or awaiting_next_round:
		return dice_value
	dice_value = randi_range(1, 6)
	moves_remaining = dice_value
	has_rolled = true
	dice_rolled.emit(dice_value)
	moves_changed.emit(moves_remaining)
	return dice_value


func consume_move() -> void:
	if moves_remaining <= 0:
		return
	moves_remaining -= 1
	moves_changed.emit(moves_remaining)
	if moves_remaining == 0:
		_end_turn()


func advance_round() -> void:
	if not awaiting_next_round:
		return
	round_number += 1
	turn_in_round = 1
	awaiting_next_round = false
	has_rolled = false
	dice_value = 0
	round_advanced.emit(round_number)
	turn_started.emit(turn_in_round, round_number)
	moves_changed.emit(moves_remaining)


func _end_turn() -> void:
	turn_ended.emit()
	if turn_in_round >= TURNS_PER_ROUND:
		awaiting_next_round = true
		round_finished.emit(round_number)
		return
	turn_in_round += 1
	has_rolled = false
	dice_value = 0
	turn_started.emit(turn_in_round, round_number)
	moves_changed.emit(moves_remaining)
