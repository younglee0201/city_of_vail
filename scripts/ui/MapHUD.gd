extends CanvasLayer

@export var turn_manager_path: NodePath

@onready var turn_manager: TurnManager = get_node(turn_manager_path) as TurnManager
@onready var description_panel: TextureRect = $UIRoot/DescriptionPanel
@onready var round_label: Label = $UIRoot/TopBar/RoundLabel
@onready var turn_label: Label = $UIRoot/TopBar/TurnLabel
@onready var dice_label: Label = $UIRoot/TopBar/DiceLabel
@onready var moves_label: Label = $UIRoot/TopBar/MovesLabel
@onready var roll_button: Button = $UIRoot/RollButton
@onready var next_round_button: Button = $UIRoot/NextRoundButton

var next_round_dialog: ConfirmationDialog = null


func _ready() -> void:
	turn_manager.turn_started.connect(_on_state_changed)
	turn_manager.round_advanced.connect(_on_round_advanced)
	turn_manager.round_finished.connect(_on_state_changed)
	turn_manager.dice_rolled.connect(_on_state_changed)
	turn_manager.moves_changed.connect(_on_state_changed)
	roll_button.pressed.connect(_on_roll_pressed)
	next_round_button.pressed.connect(_on_next_round_pressed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			description_panel.visible = not description_panel.visible
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_SPACE and not turn_manager.has_rolled and not turn_manager.awaiting_next_round:
			turn_manager.roll_dice()


func _on_roll_pressed() -> void:
	if not turn_manager.has_rolled:
		turn_manager.roll_dice()


func _on_next_round_pressed() -> void:
	if next_round_dialog != null:
		return
	next_round_dialog = ConfirmationDialog.new()
	next_round_dialog.title = "下一回合"
	next_round_dialog.dialog_text = "確定進入下一回合？"
	next_round_dialog.ok_button_text = "是"
	next_round_dialog.cancel_button_text = "否"
	next_round_dialog.confirmed.connect(_on_next_round_confirmed)
	next_round_dialog.canceled.connect(_close_next_round_dialog)
	add_child(next_round_dialog)
	next_round_dialog.popup_centered()


func _on_next_round_confirmed() -> void:
	_close_next_round_dialog()
	turn_manager.advance_round()


func _close_next_round_dialog() -> void:
	if next_round_dialog != null:
		next_round_dialog.queue_free()
		next_round_dialog = null


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
	roll_button.disabled = turn_manager.has_rolled or turn_manager.awaiting_next_round
	next_round_button.disabled = not turn_manager.awaiting_next_round
