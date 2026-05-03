extends CanvasLayer

@export var turn_manager_path: NodePath

@onready var turn_manager: TurnManager = get_node(turn_manager_path) as TurnManager
@onready var round_label: Label = $UIRoot/TopBar/RoundLabel
@onready var turn_label: Label = $UIRoot/TopBar/TurnLabel
@onready var dice_label: Label = $UIRoot/TopBar/DiceLabel
@onready var moves_label: Label = $UIRoot/TopBar/MovesLabel
@onready var roll_button: Button = $UIRoot/RollButton


func _ready() -> void:
	turn_manager.turn_started.connect(_on_state_changed)
	turn_manager.round_advanced.connect(_on_round_advanced)
	turn_manager.dice_rolled.connect(_on_state_changed)
	turn_manager.moves_changed.connect(_on_state_changed)
	roll_button.pressed.connect(_on_roll_pressed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not turn_manager.has_rolled:
			turn_manager.roll_dice()


func _on_roll_pressed() -> void:
	if not turn_manager.has_rolled:
		turn_manager.roll_dice()


func _on_state_changed(_a = null, _b = null) -> void:
	_refresh()


func _on_round_advanced(_round_no: int) -> void:
	_refresh()


func _refresh() -> void:
	round_label.text = "Round %d" % turn_manager.round_number
	turn_label.text = "Turn %d/%d" % [turn_manager.turn_in_round, TurnManager.TURNS_PER_ROUND]
	if turn_manager.has_rolled:
		dice_label.text = "Dice: %d" % turn_manager.dice_value
	else:
		dice_label.text = "Dice: -"
	moves_label.text = "Moves: %d" % turn_manager.moves_remaining
	roll_button.disabled = turn_manager.has_rolled
