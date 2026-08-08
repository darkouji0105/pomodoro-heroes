class_name PomodoroPreset
extends Resource

# ポモドーロのプリセット1件分（short/standard/long等）。

@export var preset_id: String
@export var focus_duration_sec: int
@export var short_break_sec: int
@export var long_break_sec: int
@export var long_break_interval: int
@export var default_total_sets: int
