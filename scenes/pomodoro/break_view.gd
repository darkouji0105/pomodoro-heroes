extends Control

signal skip_requested

@onready var timer_label = $TimerLabel
@onready var type_label = $TypeLabel
@onready var skip_button = $SkipButton

func setup(seconds: int, is_long: bool) -> void:
	update_timer(seconds)
	type_label.text = tr("ui_pomodoro_break_long") if is_long else tr("ui_pomodoro_break_short")
	skip_button.text = tr("ui_pomodoro_break_skip")

func _on_skip_pressed() -> void:
	skip_requested.emit()

func update_timer(seconds: int) -> void:
	var m = seconds / 60
	var s = seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]
