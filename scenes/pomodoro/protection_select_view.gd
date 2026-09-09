extends Control

# 加護を選ぶビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 3つとも **Secondary**（並列の選択肢）。⚠ 真鍮は1つも置かない。
#   ⚠ どれか1つを主要色にすると「これを選べ」という画面になる。
# ⚠ 文言は `.tscn` の `label_key` が持つ（UiButton が `tr()` する）。ここで代入しない。

signal protection_selected(protection_id: String)

@onready var light_button: UiButton = $Layout/Choices/LightButton
@onready var middle_button: UiButton = $Layout/Choices/MiddleButton
@onready var hard_button: UiButton = $Layout/Choices/HardButton


func _ready() -> void:
	light_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_LIGHT))
	middle_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_MIDDLE))
	hard_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_HARD))

	$Layout/TitleLabel.text = tr("ui_pomodoro_select_protection")
