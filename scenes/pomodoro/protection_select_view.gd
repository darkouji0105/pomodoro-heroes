extends Control

signal protection_selected(protection_id: String)

@onready var light_button = $VBoxContainer/LightButton
@onready var middle_button = $VBoxContainer/MiddleButton
@onready var hard_button = $VBoxContainer/HardButton

func _ready() -> void:
	light_button.pressed.connect(func(): protection_selected.emit(GameStateKeys.PROTECTION_LIGHT))
	middle_button.pressed.connect(func(): protection_selected.emit(GameStateKeys.PROTECTION_MIDDLE))
	hard_button.pressed.connect(func(): protection_selected.emit(GameStateKeys.PROTECTION_HARD))
	
	# tr() を使う
	$TitleLabel.text = tr("ui_pomodoro_select_protection")
	light_button.text = tr("ui_pomodoro_protection_light")
	middle_button.text = tr("ui_pomodoro_protection_middle")
	hard_button.text = tr("ui_pomodoro_protection_hard")
