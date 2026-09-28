# res://scenes/base/settings_screen.gd
# 設定（2026-09-28・回UI-仕組み③・手本 Settings・決定 `BS-13`）。
#
# ⚠ 人間「⚠ 1あ　⚠ 2あ　⚠ 3い　⚠ 4あ」：
#   ⚠ 紙のタブ **表示 ／ 音 ／ ポモドーロと小窓 ／ データ**（⚠ 手本の4つ・中身はいま作れるものだけ）。
#   ⚠ 表示＝全画面か窓 ／ 音＝全体・効果音・BGM の音量 ／ ポモドーロ＝集中（25・45・50分）と休憩（5・10・15分）を別々に選ぶ。
#   ⚠ 小窓の2行と「休憩に入ったら話しかける」は薄く「まだ」（⚠ 小窓は回UI-仕組み⑥・話しかける仲間は仕組みが無い）。
#   ⚠ データ＝セーブを消すは置かない（「⚠ 3い」＝タイトルの「はじめから」だけ）・案内の1行だけ。
#   ⚠ 入口は本部の「設定」（「⚠ 4あ」）。⚠ 「戻る」で本部。
# ⚠ 値は `GameSettings`（⚠ セーブと別のファイル `user://settings.cfg`）。⚠ 押したらすぐ書く・すぐ効かせる。
# ⚠ 再描画に await を持たせない（AGENTS.md）。

class_name SettingsScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"Settings"
const TAB_KEYS: Array[String] = ["ui_settings_tab_display", "ui_settings_tab_audio", "ui_settings_tab_pomodoro", "ui_settings_tab_data"]
const TAB_DISPLAY: int = 0
const TAB_AUDIO: int = 1
const TAB_POMODORO: int = 2
const TAB_DATA: int = 3
const VOLUME_STEP: int = 10

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Main
@onready var sheet_body: VBoxContainer = $Margin/Layout/Main/Sheet/SheetBody

var _tab: int = TAB_DISPLAY


func _ready() -> void:
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	main_stack.custom_minimum_size.x = float(get_theme_constant(&"sheet_width", THEME_TYPE))
	var tabs: PaperTabs = PaperTabs.new()
	tabs.name = "Tabs"
	tabs.set_tabs(TAB_KEYS, _tab)
	tabs.tab_changed.connect(_on_tab_changed)
	main_stack.add_child(tabs)
	main_stack.move_child(tabs, 0)
	_rebuild()


func _on_tab_changed(index: int) -> void:
	_tab = index
	_rebuild()


func _rebuild() -> void:
	for child: Node in sheet_body.get_children():
		sheet_body.remove_child(child)
		child.queue_free()
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = TAB_KEYS[_tab]
	heading.ornament = true
	sheet_body.add_child(heading)
	match _tab:
		TAB_AUDIO:
			_build_audio()
		TAB_POMODORO:
			_build_pomodoro()
		TAB_DATA:
			_build_data()
		_:
			_build_display()


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
	sheet_body.add_child(row)
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
		button.pressed.connect(handler.bind(values[i]))
		box.add_child(button)
	return box


# --- 表示 ---

func _build_display() -> void:
	var labels: Array[String] = [tr("ui_settings_windowed"), tr("ui_settings_fullscreen")]
	_row("FullscreenRow", "ui_settings_display_mode", "", _choices("Display", [false, true], labels, GameSettings.is_fullscreen(), _on_fullscreen_chosen))


func _on_fullscreen_chosen(value: bool) -> void:
	GameSettings.set_value(GameSettings.SECTION_DISPLAY, GameSettings.KEY_FULLSCREEN, value)
	GameSettings.apply_display()
	_rebuild()


# --- 音 ---

func _build_audio() -> void:
	for spec: Array in [
		["MasterRow", "ui_settings_volume_master", GameSettings.KEY_MASTER],
		["SeRow", "ui_settings_volume_se", GameSettings.KEY_SE],
		["BgmRow", "ui_settings_volume_bgm", GameSettings.KEY_BGM],
	]:
		var key: String = str(spec[2])
		var box: HBoxContainer = HBoxContainer.new()
		var slider: HSlider = HSlider.new()
		slider.name = "Slider"
		slider.theme_type_variation = &"SettingsSlider"
		slider.min_value = 0
		slider.max_value = GameSettings.VOLUME_MAX_PCT
		slider.step = VOLUME_STEP
		slider.value = GameSettings.volume_pct(key)
		slider.custom_minimum_size.x = float(get_theme_constant(&"slider_width", THEME_TYPE))
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(slider)
		var value: Label = Label.new()
		value.name = "ValueLabel"
		value.custom_minimum_size.x = float(get_theme_constant(&"value_width", THEME_TYPE))
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text = tr("ui_settings_percent") % GameSettings.volume_pct(key)
		box.add_child(value)
		# ⚠ つまみを動かしている間も書いて鳴らす（⚠ 描き直さない＝つまみを掴んだまま消さない）。
		slider.value_changed.connect(_on_volume_changed.bind(key, value))
		_row(str(spec[0]), str(spec[1]), "", box)


func _on_volume_changed(pct: float, key: String, label: Label) -> void:
	GameSettings.set_value(GameSettings.SECTION_AUDIO, key, int(pct))
	SoundManager.refresh_volumes()
	label.text = tr("ui_settings_percent") % int(pct)


# --- ポモドーロと小窓 ---

func _build_pomodoro() -> void:
	var focus_values: Array = Balance.pomodoro.focus_minute_choices.duplicate()
	var break_values: Array = Balance.pomodoro.break_minute_choices.duplicate()
	var focus_labels: Array[String] = []
	for minutes: Variant in focus_values:
		focus_labels.append(tr("ui_settings_minutes") % int(minutes))
	var break_labels: Array[String] = []
	for minutes: Variant in break_values:
		break_labels.append(tr("ui_settings_minutes") % int(minutes))
	_row("FocusRow", "ui_settings_focus", "", _choices("Focus", focus_values, focus_labels, GameSettings.focus_minutes(), _on_focus_chosen))
	_row("BreakRow", "ui_settings_break", "", _choices("Break", break_values, break_labels, GameSettings.break_minutes(), _on_break_chosen))
	# ⚠ まだ無いもの（⚠ 手本の行は見せて「まだ」と分かるようにする）。
	for spec: Array in [
		["MiniWindowRow", "ui_settings_mini_window", "ui_settings_mini_window_note"],
		["MiniWindowTopRow", "ui_settings_mini_window_top", "ui_settings_mini_window_top_note"],
		["TalkRow", "ui_settings_talk", ""],
	]:
		var later: Label = Label.new()
		later.name = "LaterLabel"
		later.theme_type_variation = &"CaptionLabel"
		later.text = tr("ui_settings_later")
		var row: LedgerRow = _row(str(spec[0]), str(spec[1]), str(spec[2]), later)
		row.modulate.a = float(get_theme_constant(&"later_alpha_pct", THEME_TYPE)) / 100.0


func _on_focus_chosen(minutes: int) -> void:
	GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_FOCUS_MINUTES, minutes)
	_rebuild()


func _on_break_chosen(minutes: int) -> void:
	GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_BREAK_MINUTES, minutes)
	_rebuild()


# --- データ（⚠ セーブを消すは置かない＝「⚠ 3い」） ---

func _build_data() -> void:
	_row("DataNoteRow", "ui_settings_data_reset", "ui_settings_data_reset_note", null)
	_row("SettingsFileRow", "ui_settings_data_separate", "ui_settings_data_separate_note", null)


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
