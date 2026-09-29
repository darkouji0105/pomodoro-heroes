# res://scenes/pomodoro/focus_tools_screen.gd
# 集中の道具（2026-09-29・回UI-仕組み⑤・手本 PomoSkin）。
#
# ⚠ 人間「⚠ 1あ　⚠ 2あ　⚠ 3あ　⚠ 4い」：⚠ 砂時計・ろうそく・柱時計は最初から全部持っている（⚠ 選ぶだけ）／
#   ⚠ 水時計と「まだ見ぬ道具」は目録に「まだ持っていない」と薄く ／ ⚠ 入口はポモドーロの画面（`PomodoroLinks`）・戻るとポモドーロ。
# ⚠ 左＝見本（⚠ 集中中の姿を動かして見せる）／ ⚠ 右＝紙の「道具の目録」（⚠ 行を押すと見本が変わる）・⚠ 右下「◯◯を使う」。
# ⚠ 選んだ道具は `GameSettings`（⚠ 見た目の好み＝設定のファイル・セーブではない）。
# ⚠ 手本の見本の札（本部の置き物・デスクトップの小窓）は出さない（⚠ まだ無い＝小窓は回UI-仕組み⑥）。

class_name FocusToolsScreen
extends Control

const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"
const THEME_TYPE: StringName = &"FocusTool"
# ⚠ 目録にだけ出す、まだ持っていない道具（⚠ 絵は無い＝「？」）。
const LOCKED_TOOLS: Array[String] = ["water_clock", "unknown"]

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body

# ⚠ 目録で押して選んでいる道具（⚠ まだ「使う」を押していない）。
var _picked: String = ""
var _preview: FocusTool = null
var _preview_time: Label = null


func _ready() -> void:
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	_picked = GameSettings.focus_tool()
	_rebuild()


func _process(delta: float) -> void:
	# ⚠ 見本を動かす（⚠ `preview_cycle_ms` で1回りして頭から）。
	if _preview == null or not is_instance_valid(_preview):
		return
	var cycle: float = maxf(1.0, float(get_theme_constant(&"preview_cycle_ms", THEME_TYPE)) / 1000.0)
	_preview.progress = fmod(_preview.progress + delta / cycle, 1.0)
	if _preview_time != null:
		var remain: int = int(float(GameSettings.focus_minutes() * 60) * (1.0 - _preview.progress))
		_preview_time.text = "%02d:%02d" % [remain / 60, remain % 60]


func _rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(_build_preview())
	body.add_child(_build_catalog())


# --- 左：見本 -----------------------------------------------------------

func _build_preview() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Preview"
	panel.theme_type_variation = &"ShopBoardPanel"
	panel.custom_minimum_size.x = float(get_theme_constant(&"preview_width", THEME_TYPE))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_focus_tools_preview")
	column.add_child(caption)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_preview = FocusTool.create(_picked, float(get_theme_constant(&"focus_size", THEME_TYPE)))
	_preview.name = "PreviewTool"
	column.add_child(_preview)
	var focus: Label = Label.new()
	focus.theme_type_variation = &"CaptionLabel"
	focus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus.text = tr("ui_focus_tool_caption")
	column.add_child(focus)
	_preview_time = Label.new()
	_preview_time.name = "PreviewTime"
	_preview_time.theme_type_variation = &"TimerLabel"
	_preview_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_preview_time)
	var bottom: Control = Control.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom)
	return panel


# --- 右：道具の目録 -------------------------------------------------------

func _build_catalog() -> PaperSheet:
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Catalog"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	sheet.add_child(column)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_focus_tools_catalog"
	heading.right_text = "%d / %d" % [FocusTool.OWNED_TOOLS.size(), FocusTool.OWNED_TOOLS.size() + LOCKED_TOOLS.size()]
	column.add_child(heading)
	var current: String = GameSettings.focus_tool()
	for tool_id: String in FocusTool.OWNED_TOOLS:
		column.add_child(_tool_row(tool_id, true, tool_id == current))
	for tool_id: String in LOCKED_TOOLS:
		column.add_child(_tool_row(tool_id, false, false))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(foot)
	var use: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "")
	use.name = "UseButton"
	use.text = tr("ui_focus_tools_use") % tr("ui_focus_tool_" + _picked)
	use.disabled = _picked == current
	use.pressed.connect(_on_use_pressed)
	foot.add_child(use)
	return sheet


func _tool_row(tool_id: String, owned: bool, in_use: bool) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Tool_" + tool_id
	row.selected = tool_id == _picked
	if owned:
		row.pressed.connect(_on_tool_pressed.bind(tool_id))
	else:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.modulate.a = float(get_theme_constant(&"locked_alpha_pct", THEME_TYPE)) / 100.0
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var side: float = float(get_theme_constant(&"row_icon", THEME_TYPE))
	if owned:
		var icon: FocusTool = FocusTool.create(tool_id, side, false)
		icon.progress = 0.35
		line.add_child(icon)
	else:
		var unknown: Label = Label.new()
		unknown.custom_minimum_size = Vector2(side, side)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.text = tr("ui_records_unknown")
		line.add_child(unknown)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_line: HBoxContainer = HBoxContainer.new()
	column.add_child(name_line)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr("ui_focus_tool_" + tool_id)
	name_line.add_child(name_label)
	if in_use:
		var stamp: Stamp = Stamp.new()
		stamp.name = "InUseStamp"
		stamp.label_key = "ui_focus_tools_in_use"
		stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_line.add_child(stamp)
	if not owned:
		var note: Label = Label.new()
		note.theme_type_variation = &"CaptionLabel"
		note.text = tr("ui_focus_tools_not_owned")
		column.add_child(note)
	var state: Label = Label.new()
	state.name = "StateLabel"
	state.theme_type_variation = &"CaptionLabel"
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	state.text = tr("ui_focus_tools_owned") if owned else tr("ui_focus_tools_how")
	line.add_child(state)
	return row


func _on_tool_pressed(tool_id: String) -> void:
	if tool_id == _picked:
		return
	_picked = tool_id
	# ⚠ 押した行を押している最中に外さない（⚠ 次のフレームで描き直す）。
	_rebuild.call_deferred()


func _on_use_pressed() -> void:
	GameSettings.set_value(GameSettings.SECTION_POMODORO, GameSettings.KEY_FOCUS_TOOL, _picked)
	_rebuild.call_deferred()


func _on_back_pressed() -> void:
	SceneManager.change_scene(POMODORO_PATH)
