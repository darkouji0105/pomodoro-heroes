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
# ⚠ 作業中に出す大きいタイトル（2026-09-09・人間の宿題「作業中のタイトルを大きく」）。
#   ⚠ 入力欄と**同じ場所・同じ幅**に出す。⚠ 上（タイマーの輪）は1pxも動かない。
#   ⚠ 2行で打ち切る（`max_lines_visible = 2`）。⚠ 長い題で下のボタンを押し下げないため。
@onready var work_title: Label = $Layout/InputBlock/WorkTitle
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

	# ⚠ 入力欄を大きいタイトルに差し替える。⚠ 説明の字は**消さずに透明**にする
	#   （⚠ 消すと下が詰まって、⚠ 開始を押した瞬間にボタンが上へ跳ねる）。
	instruction_label.modulate.a = 0.0
	title_edit.editable = false
	title_edit.visible = false
	work_title.text = title
	work_title.visible = true
	start_button.disabled = true
	start_requested.emit(title)


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)
