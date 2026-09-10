extends Control

# 振り返りのビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 警告は `visible` で消さない。⚠ コンテナに入れた以上、消すと下のボタンが上へ詰まる。
#   ⚠ 透明にして**高さだけ残す**（人間のモックの指示「行が詰まらない」）。

signal reflection_completed(text: String)

# ⚠⚠ 振り返りに要る最低の文字数は `Balance.pomodoro.reflection_min_chars`
#   （2026-09-10 に直した）。⚠ 前はここに `20` を直書きしていた。
#   ⚠ 欄は前から在ったのに誰も読んでいなかった＝⚠ Inspector で変えても何も起きなかった。
#   ⚠ 読む口はこの1本。⚠ 画面の文言もここが出す数で組み立てる（⚠ 2箇所に書かない）。

@onready var timer_ring: TimerRing = $Layout/TimerRing
@onready var instruction_label: Label = $Layout/InputBlock/InstructionLabel
@onready var reflection_edit: TextEdit = $Layout/InputBlock/ReflectionEdit
@onready var warning_label: Label = $Layout/InputBlock/WarningLabel
@onready var complete_button: UiButton = $Layout/CompleteButton


func _ready() -> void:
	reflection_edit.text_changed.connect(_on_text_changed)

	$Layout/TitleLabel.text = tr("ui_pomodoro_reflection_title")
	# ⚠ 文言の中の文字数も Config の値から入れる（⚠ 前は ja.csv に「20文字以上」と
	#   書いてあり、⚠ Config を変えると文と実際の判定が食い違った）。
	instruction_label.text = tr("ui_pomodoro_reflection_instruction").format([_min_chars()])
	# ⚠ 入力欄の下書きの字（2026-09-09）。⚠ 上と同じ理由。
	reflection_edit.placeholder_text = tr("ui_pomodoro_reflection_placeholder").format([_min_chars()])

	_on_text_changed()


# 振り返りに要る最低の文字数。⚠ `Balance.pomodoro` を読む唯一の口。
#   ⚠ 未割り当てでも画面が落ちないように、⚠ 読めなければ 0（＝いつでも確定できる）。
#   ⚠ 赤は `Balance` 側の検査が出す（⚠ ここで2本目の赤を足さない）。
func _min_chars() -> int:
	if Balance == null or Balance.pomodoro == null:
		return 0
	return int(Balance.pomodoro.reflection_min_chars)


func _on_text_changed() -> void:
	var length: int = reflection_edit.text.strip_edges().length()
	var remaining: int = _min_chars() - length

	complete_button.disabled = (remaining > 0)
	# ⚠ 消さずに透明にする（行を詰まらせないため）。
	warning_label.modulate.a = 1.0 if remaining > 0 else 0.0
	if remaining > 0:
		warning_label.text = tr("ui_pomodoro_reflection_warning_chars").format([remaining])


func _on_complete_pressed() -> void:
	reflection_completed.emit(reflection_edit.text)


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)
