class_name PomodoroSettingsPanel
extends VBoxContainer

# ポモドーロの設定の行（2026-10-02・人間「⚠ ポモドーロ関連の設定はポモドーロ画面からできるように」）。
#
# ⚠ 集中の長さ ／ 休憩の長さ ／ 小窓 ／ 小窓をいつも前に ／ 休憩明けの自動開始 ／ 1日の目標（10-05・回P-3）／ 話しかける（まだ）。
# ⚠ 置き場は2つ：⚠ ポモドーロの画面の紙の窓（`PomodoroLinks`）／ ⚠ 設定の画面の「ポモドーロと小窓」タブ（⚠ 同じ部品）。
# ⚠ 押したらすぐ `GameSettings` に書き、⚠ 自分を描き直す（⚠ 押した札を押している最中に外さない＝次のフレーム）。
# ⚠ 見た目の値は Theme の `Settings` 型（⚠ 設定の画面と同じ）。⚠ 行と札の名前は検査が読む（`FocusRow` `Focus_45` `Mini_true` …）。

signal changed

const THEME_TYPE: StringName = &"Settings"


func _ready() -> void:
	name = "PomodoroSettingsPanel"
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var focus_values: Array = Balance.pomodoro.focus_minute_choices.duplicate()
	var break_values: Array = Balance.pomodoro.break_minute_choices.duplicate()
	var focus_labels: Array[String] = []
	for minutes: Variant in focus_values:
		focus_labels.append(tr("ui_settings_minutes") % int(minutes))
	var break_labels: Array[String] = []
	for minutes: Variant in break_values:
		break_labels.append(tr("ui_settings_minutes") % int(minutes))
	_row("FocusRow", "ui_settings_focus", "", _choices("Focus", focus_values, focus_labels, GameSettings.focus_minutes(),
		_on_chosen.bind(GameSettings.KEY_FOCUS_MINUTES)))
	_row("BreakRow", "ui_settings_break", "", _choices("Break", break_values, break_labels, GameSettings.break_minutes(),
		_on_chosen.bind(GameSettings.KEY_BREAK_MINUTES)))
	# ⚠ 小窓（2026-09-29・回UI-仕組み⑥）：⚠ オフ｜オン。
	var off_on: Array[String] = [tr("ui_settings_off"), tr("ui_settings_on")]
	_row("MiniWindowRow", "ui_settings_mini_window", "ui_settings_mini_window_note",
		_choices("Mini", [false, true], off_on, GameSettings.mini_window(), _on_chosen.bind(GameSettings.KEY_MINI_WINDOW)))
	_row("MiniWindowTopRow", "ui_settings_mini_window_top", "ui_settings_mini_window_top_note",
		_choices("MiniTop", [false, true], off_on, GameSettings.mini_window_on_top(), _on_chosen.bind(GameSettings.KEY_MINI_ON_TOP)))
	# ⚠ 回P-3（2026-10-05）：⚠ 休憩明けの自動開始（オフ｜オン）／ ⚠ 1日の目標（なし｜60分 …）。
	_row("AutoStartRow", "ui_settings_auto_start", "ui_settings_auto_start_note",
		_choices("AutoStart", [false, true], off_on, GameSettings.auto_start_focus(), _on_chosen.bind(GameSettings.KEY_AUTO_START)))
	var goal_values: Array = Balance.pomodoro.daily_goal_minute_choices.duplicate()
	var goal_labels: Array[String] = []
	for minutes: Variant in goal_values:
		goal_labels.append(tr("ui_settings_goal_none") if int(minutes) == 0 else tr("ui_settings_minutes") % int(minutes))
	_row("DailyGoalRow", "ui_settings_daily_goal", "",
		_choices("Goal", goal_values, goal_labels, GameSettings.daily_goal_minutes(), _on_chosen.bind(GameSettings.KEY_DAILY_GOAL)))
	# ⚠ まだ無いもの（⚠ 話しかけるのは人間「⚠ 3い」＝今回は作らない）。
	var later: Label = Label.new()
	later.name = "LaterLabel"
	later.theme_type_variation = &"CaptionLabel"
	later.text = tr("ui_settings_later")
	var row: LedgerRow = _row("TalkRow", "ui_settings_talk", "", later)
	row.modulate.a = float(get_theme_constant(&"later_alpha_pct", THEME_TYPE)) / 100.0


# 1行：左に名前（⚠ 下に小さな説明）・右に操作。
func _row(row_name: String, caption_key: String, note_key: String, control: Control) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var caption: Label = Label.new()
	caption.text = tr(caption_key)
	column.add_child(caption)
	if note_key != "":
		var note: Label = Label.new()
		note.theme_type_variation = &"CaptionLabel"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = tr(note_key)
		column.add_child(note)
	if control != null:
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(control)
	add_child(row)
	return row


# 並んだ札から1つ選ぶ（⚠ 手本の「25分｜45分｜50分」）。⚠ 選んでいる札は `PaperChoiceSelected`。
func _choices(prefix: String, values: Array, labels: Array[String], current: Variant, handler: Callable) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.name = prefix + "Choices"
	box.theme_type_variation = &"SettingsChoices"
	for i: int in range(values.size()):
		var button: Button = UiButton.create_paper_choice("")
		button.name = "%s_%s" % [prefix, str(values[i])]
		button.text = labels[i]
		button.custom_minimum_size.x = float(get_theme_constant(&"choice_width", THEME_TYPE))
		if values[i] == current:
			button.theme_type_variation = &"PaperChoiceSelected"
		# ⚠ `handler` は鍵が bind 済み（`_on_chosen.bind(key)`）＝⚠ 値を前に足して呼ぶ。
		button.pressed.connect(_apply.bind(handler, values[i]))
		box.add_child(button)
	return box


func _apply(handler: Callable, value: Variant) -> void:
	handler.call(value)


func _on_chosen(value: Variant, key: String) -> void:
	GameSettings.set_value(GameSettings.SECTION_POMODORO, key, value)
	changed.emit()
	_rebuild.call_deferred()
