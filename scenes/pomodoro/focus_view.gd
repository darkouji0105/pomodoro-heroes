extends Control

# 集中中のビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 「1 / 4 Sets」は**器（pomodoro.tscn）が持つ**ようになった。
#   ⚠ 休憩・振り返りでも同じ位置に出したいため。ここでは触らない。
# ⚠ 見出しは無いが `HeadingSlot`（空の HeadingLabel）で**高さだけ確保している**。
#   ⚠ これが無いと、休憩・振り返りへ移った瞬間にタイマーが上下に跳ねる。

signal start_requested(title: String)

@onready var timer_ring: TimerRing = $Layout/TimerRing
@onready var instruction_label: Label = $Layout/InputBlock/InstructionLabel
@onready var title_edit: LineEdit = $Layout/InputBlock/TitleEdit
@onready var start_button: UiButton = $Layout/StartButton


func setup(preset: PomodoroPreset) -> void:
	update_timer(preset.focus_duration_sec, float(preset.focus_duration_sec))
	title_edit.max_length = Balance.pomodoro.session_title_max_length

	instruction_label.text = tr("ui_pomodoro_input_title")
	# ⚠ 入力欄の下書きの字（2026-09-09）。⚠ `.tscn` に日本語が直書きされていて、
	#   ⚠ ここでも上書きしていなかった＝⚠ 翻訳表を通っていない唯一の文字だった。
	title_edit.placeholder_text = tr("ui_pomodoro_title_placeholder")


# ⚠ 前のセットのタイトルを引き継ぐ口（2026-09-09）。
#   ⚠ 前は器が `view.get_node("TitleEdit")` で中を掴んでいた。
#   ⚠ ノード名を変えた瞬間に黙って壊れるので、関数にした。
func set_title_text(value: String) -> void:
	title_edit.text = value


func _on_start_pressed() -> void:
	var title: String = title_edit.text.strip_edges()
	if title == "":
		title = "Work"

	title_edit.editable = false
	start_button.disabled = true
	start_requested.emit(title)


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)
