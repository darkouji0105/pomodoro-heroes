extends Control

# 加護を選ぶビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 3つとも **Secondary**（並列の選択肢）。⚠ 真鍮は1つも置かない。
#   ⚠ どれか1つを主要色にすると「これを選べ」という画面になる。
# ⚠⚠ 中身は「**左に名前 ／ 右に値**」（2026-09-09・人間のモック）。
#   ⚠ 値は `Balance.pomodoro.protection_*` の**最後のしきい値**から引く
#   （＝その加護の到達点。⚠ 途中のふつうの宝箱は出さない）。
#   ⚠ ここに分数や宝箱の名前を**直書きしない**。⚠ `.tres` を変えたら表示も変わる。
# ⚠ ボタンの中に行を入れるため、⚠ 中身は `MOUSE_FILTER_IGNORE` にして
#   ⚠ 押した先がボタンに届くようにする。

signal protection_selected(protection_id: String)

@onready var light_button: UiButton = $Layout/Choices/LightButton
@onready var middle_button: UiButton = $Layout/Choices/MiddleButton
@onready var hard_button: UiButton = $Layout/Choices/HardButton


func _ready() -> void:
	light_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_LIGHT))
	middle_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_MIDDLE))
	hard_button.pressed.connect(func() -> void: protection_selected.emit(GameStateKeys.PROTECTION_HARD))

	$Layout/TitleLabel.text = tr("ui_pomodoro_select_protection")

	_fill_choice(light_button, "ui_pomodoro_protection_light", Balance.pomodoro.protection_light)
	_fill_choice(middle_button, "ui_pomodoro_protection_middle", Balance.pomodoro.protection_middle)
	_fill_choice(hard_button, "ui_pomodoro_protection_hard", Balance.pomodoro.protection_hard)


# ⚠ 「左に名前・右に値」。
#   ⚠⚠ **名前はボタン自身の文字のまま**にする。⚠ ボタンの高さはここから出るので、
#   ⚠ 空にすると 3つとも 17px の平たい帯になる（⚠ 実測。⚠ 226 → 160 に縮んだ）。
#   ⚠ 右の値だけを重ねる。⚠ 押した先がボタンに届くよう `MOUSE_FILTER_IGNORE`。
func _fill_choice(button: UiButton, name_key: String, config: ProtectionTypeConfig) -> void:
	button.label_key = name_key
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var value_label: Label = Label.new()
	value_label.name = "ValueLabel"
	value_label.text = _goal_text(config)
	value_label.theme_type_variation = &"MutedLabel"
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(value_label)

	# ⚠ 内側の余白はボタンの StyleBox から引く（⚠ ここに数値を書かない）。
	var style: StyleBox = button.get_theme_stylebox(&"normal")
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.offset_left = style.content_margin_left if style != null else 0.0
	value_label.offset_right = -style.content_margin_right if style != null else 0.0


# ⚠ その加護の到達点。⚠ 一番遅いしきい値と、そこでもらえる宝箱。
#   ⚠ 予定が空なら空文字（⚠ `.tres` を空にしても落ちない）。
func _goal_text(config: ProtectionTypeConfig) -> String:
	if config == null or config.schedule.is_empty():
		return ""
	var goal: ChestScheduleEntry = config.schedule[config.schedule.size() - 1]
	return tr("ui_pomodoro_chest_at").format([goal.threshold_min, tr("ui_chest_" + goal.chest_type)])
