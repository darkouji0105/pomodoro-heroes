extends Control

# 振り返りのビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 警告は `visible` で消さない。⚠ コンテナに入れた以上、消すと下のボタンが上へ詰まる。
#   ⚠ 透明にして**高さだけ残す**（人間のモックの指示「行が詰まらない」）。

signal reflection_completed(text: String)

# ⚠ 振り返りに要る最低の文字数。⚠ 2箇所で使うので定数にした。
#   ⚠⚠ 本来は `Balance.pomodoro` に置くべき数値だが、⚠ 今回の範囲外なので宿題に回す。
const MIN_REFLECTION_LENGTH: int = 20

@onready var timer_ring: TimerRing = $Layout/TimerRing
@onready var instruction_label: Label = $Layout/InputBlock/InstructionLabel
@onready var reflection_edit: TextEdit = $Layout/InputBlock/ReflectionEdit
@onready var warning_label: Label = $Layout/InputBlock/WarningLabel
@onready var complete_button: UiButton = $Layout/CompleteButton


func _ready() -> void:
	reflection_edit.text_changed.connect(_on_text_changed)

	$Layout/TitleLabel.text = tr("ui_pomodoro_reflection_title")
	instruction_label.text = tr("ui_pomodoro_reflection_instruction")
	# ⚠ 入力欄の下書きの字（2026-09-09）。⚠ 上と同じ理由。
	reflection_edit.placeholder_text = tr("ui_pomodoro_reflection_placeholder")

	_on_text_changed()


func _on_text_changed() -> void:
	var length: int = reflection_edit.text.strip_edges().length()
	var remaining: int = MIN_REFLECTION_LENGTH - length

	complete_button.disabled = (remaining > 0)
	# ⚠ 消さずに透明にする（行を詰まらせないため）。
	warning_label.modulate.a = 1.0 if remaining > 0 else 0.0
	if remaining > 0:
		warning_label.text = tr("ui_pomodoro_reflection_warning_chars").format([remaining])


func _on_complete_pressed() -> void:
	reflection_completed.emit(reflection_edit.text)


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)
