extends Control

@onready var state_label: Label = $Layout/StateLabel
@onready var save_button: PrimaryButton = $Layout/SaveButton
@onready var back_to_title_button: PrimaryButton = $Layout/BackToTitleButton

func _ready() -> void:
	_update_state_display()
	
	save_button.pressed.connect(_on_save_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)

func _update_state_display() -> void:
	var state: Dictionary = GameManager.get_state()
	var gold: int = int(state.get(GameStateKeys.GOLD, 0))
	var gems: int = int(state.get(GameStateKeys.GEMS, 0))
	var stamina_dict: Dictionary = state.get(GameStateKeys.STAMINA, {})
	var stamina_curr: int = int(stamina_dict.get(GameStateKeys.STAMINA_CURRENT, 0))
	var stamina_max: int = int(stamina_dict.get(GameStateKeys.STAMINA_MAX, 0))
	var last_saved: String = str(state.get(GameStateKeys.LAST_SAVED_AT, "none"))
	
	state_label.text = "gold: %d\ngems: %d\nstamina: %d/%d\nlast_saved: %s" % [
		gold, gems, stamina_curr, stamina_max, last_saved
	]

func _on_save_pressed() -> void:
	var ok: bool = SaveManager.save_game()
	_update_state_display()
	state_label.text += "\n\n[Save Action] success: %s\npath: %s" % [ok, SaveManager.SAVE_PATH]

func _on_back_to_title_pressed() -> void:
	SceneManager.change_scene("res://scenes/title/title_screen.tscn")
