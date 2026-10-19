class_name PomodoroSettingsCard
extends PaperSheet

# ポモドーロの画面の左上の「いまの設定」の札（2026-10-19・回SEE29-C・決定 `NAV-37`）。
#
# ⚠ 人間「⚠ ポモドーロ画面から設定できるようにすればいいから今のデバッグパネルのところに何分とか休憩とか見れるようにするパネルを作りたい」
#   →「⚠ ３あ」＝分を見せるだけ・押すと今の設定の窓（`PomodoroLinks.open_settings()`＝⚠ 窓は1つの口）。
# ⚠ 中身：題「ポモドーロの設定」／ 集中◯分・休憩◯分・長い休憩◯分。⚠ 値は `GameSettings` から毎回引く（⚠ 書き写さない）。
# ⚠ 窓で変えたら `refresh()`（⚠ ポモドーロの画面の `apply_settings()` から呼ぶ）。
# ⚠ 集中中・休憩中も押せる（⚠ `NAV-28`＝集中中もポモドーロの設定）。⚠ 小窓のときは小窓が上に重なる＝見えない。
# ⚠ 紙（`PaperSheet`）＝中の字は墨（⚠ 素の面だと分の行が紙の上で白い字のまま読めなかった＝撮った絵）。
# ⚠ ポモドーロの画面でしか使わない＝scenes/pomodoro/（AGENTS.md）。⚠ 置き場所は Theme の `PomodoroSettings`。

const THEME_TYPE: StringName = &"PomodoroSettings"

var _line: Label = null


static func create() -> PomodoroSettingsCard:
	var card: PomodoroSettingsCard = PomodoroSettingsCard.new()
	card.name = "PomodoroSettingsCard"
	return card


func _ready() -> void:
	show_corners = false
	theme_type_variation = &"DeskCardPanel"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(float(get_theme_constant(&"card_left", THEME_TYPE)), float(get_theme_constant(&"card_top", THEME_TYPE)))
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"TightList"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"CaptionLabel"
	title.text = tr("ui_pomodoro_settings_open")
	column.add_child(title)
	_line = Label.new()
	_line.name = "MinutesLabel"
	column.add_child(_line)
	var hit: Button = UiButton.attach_hit(self, _on_pressed)
	hit.tooltip_text = tr("ui_pomodoro_settings_card_hint")
	refresh()


# 今の長さ（⚠ 窓で変えたあとにも呼ぶ）。
func refresh() -> void:
	if _line == null:
		return
	_line.text = tr("ui_pomodoro_settings_card_line") % [GameSettings.focus_minutes(), GameSettings.break_minutes(), GameSettings.long_break_minutes()]
	reset_size()


func _on_pressed() -> void:
	var _dialog: ModalDialog = PomodoroLinks.open_settings(get_tree().current_scene)
