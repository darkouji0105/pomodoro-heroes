extends Control

signal reflection_completed(text: String)

@onready var timer_label = $TimerLabel
@onready var reflection_edit = $ReflectionEdit
@onready var complete_button = $CompleteButton
@onready var warning_label = $WarningLabel

func _ready() -> void:
	complete_button.disabled = true
	reflection_edit.text_changed.connect(_on_text_changed)
	
	$TitleLabel.text = tr("ui_pomodoro_reflection_title")
	$InstructionLabel.text = tr("ui_pomodoro_reflection_instruction")
	complete_button.text = tr("ui_pomodoro_reflection_complete")
	warning_label.text = tr("ui_pomodoro_reflection_warning")

func _on_text_changed() -> void:
	var text = reflection_edit.text.strip_edges()
	complete_button.disabled = (text.length() < 20)
	warning_label.visible = (text.length() < 20)

func _on_complete_pressed() -> void:
	reflection_completed.emit(reflection_edit.text)

func update_timer(seconds: int) -> void:
	var m = seconds / 60
	var s = seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]
