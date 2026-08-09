extends Control

signal start_requested(title: String)

@onready var timer_label = $TimerLabel
@onready var set_label = $SetLabel
@onready var title_edit = $TitleEdit
@onready var start_button = $StartButton

func setup(preset: PomodoroPreset, current_set: int, total_sets: int) -> void:
	update_timer(preset.focus_duration_sec)
	set_label.text = "%d / %d Sets" % [current_set, total_sets]
	title_edit.max_length = Balance.pomodoro.session_title_max_length
	
	$InstructionLabel.text = tr("ui_pomodoro_input_title")
	start_button.text = tr("ui_pomodoro_start_focus")

func _on_start_pressed() -> void:
	var title = title_edit.text.strip_edges()
	if title == "":
		title = "Work"
	
	title_edit.editable = false
	start_button.disabled = true
	start_requested.emit(title)

func update_timer(seconds: int) -> void:
	var m = seconds / 60
	var s = seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]
