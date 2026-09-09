extends Control

# 休憩のビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 見出し（休憩 / 長い休憩）が集中中との差になる。⚠ 集中中は同じ位置が空。
# ⚠ スキップは **Secondary**。⚠ 真鍮にすると「休憩を飛ばすことを勧める画面」になる。

signal skip_requested

@onready var timer_label: Label = $Layout/TimerLabel
@onready var type_label: Label = $Layout/TypeLabel


func setup(seconds: int, is_long: bool) -> void:
	update_timer(seconds)
	type_label.text = tr("ui_pomodoro_break_long") if is_long else tr("ui_pomodoro_break_short")


func _on_skip_pressed() -> void:
	skip_requested.emit()


func update_timer(seconds: int) -> void:
	var m: int = seconds / 60
	var s: int = seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]
