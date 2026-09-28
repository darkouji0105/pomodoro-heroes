# res://scenes/guild/records_screen.gd
# 記録（2026-09-28・回UI-仕組み②・手本 Records）。
#
# ⚠ 人間「⚠ 1い　⚠ 2あ　⚠ 3い　⚠ 4あ　⚠ 5あ」：
#   ⚠ 紙のタブ **アイテム図鑑 ／ 集中の履歴 ／ キャラの情報 ／ ダンジョンの情報**（⚠ いまあるデータで出せるぶん＝「⚠ 1い」）。
#   ⚠ 図鑑は「初めて手に入れた記録 n / 全体」・装備 ／ 装飾 ／ 素材 ごとに絵と「？」の枠（⚠ 素材も図鑑に載る＝「⚠ 2あ」）。
#   ⚠ 手本の左の「遺物」の欄は置かない（⚠ 遺物 `EQ-8` はまだ無い＝「⚠ 3い」）。
#   ⚠ 持ち物の画面の図鑑タブは外した（「⚠ 4あ」）。⚠ 施設の帯の「記録」はここを開く。
#   ⚠ 集中の履歴は合計と今日だけ（⚠ 日ごとの履歴は記録していない＝「⚠ 5あ」）。
# ⚠ 何を持っているか・数は全部 `GameManager` の口（⚠ ここで数え直さない）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 状態は変えない画面（⚠ 見るだけ）。

class_name RecordsScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const THEME_TYPE: StringName = &"Records"
const TAB_KEYS: Array[String] = ["ui_records_tab_codex", "ui_records_tab_focus", "ui_records_tab_characters", "ui_records_tab_dungeons"]
const TAB_CODEX: int = 0
const TAB_FOCUS: int = 1
const TAB_CHARACTERS: int = 2
const TAB_DUNGEONS: int = 3

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Main
@onready var sheet_body: VBoxContainer = $Margin/Layout/Main/Sheet/SheetBody

var _tab: int = TAB_CODEX
var _tabs: PaperTabs = null


func _ready() -> void:
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.RECORDS)
	_tabs = PaperTabs.new()
	_tabs.name = "Tabs"
	_tabs.set_tabs(TAB_KEYS, _tab)
	_tabs.tab_changed.connect(_on_tab_changed)
	main_stack.add_child(_tabs)
	main_stack.move_child(_tabs, 0)
	_rebuild()


func _on_tab_changed(index: int) -> void:
	_tab = index
	_rebuild()


func _rebuild() -> void:
	for child: Node in sheet_body.get_children():
		sheet_body.remove_child(child)
		child.queue_free()
	match _tab:
		TAB_FOCUS:
			_build_focus()
		TAB_CHARACTERS:
			_build_characters()
		TAB_DUNGEONS:
			_build_dungeons()
		_:
			_build_codex()


func _heading(title_key: String, right: String = "") -> SheetHeading:
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = title_key
	heading.right_text = right
	heading.ornament = true
	return heading


func _scroll_list() -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


# --- アイテム図鑑（⚠ 手本「初めて手に入れた記録」） --------------------------

func _build_codex() -> void:
	var found: int = 0
	var total: int = 0
	for kind: String in GameManager.CODEX_KINDS:
		for item_id: String in GameManager.get_codex_ids(kind):
			total += 1
			if GameManager.is_codex_discovered(item_id):
				found += 1
	var heading: SheetHeading = _heading("ui_records_codex_title", "%d / %d" % [found, total])
	heading.name = "CodexHeading"
	sheet_body.add_child(heading)
	var list: VBoxContainer = _scroll_list()
	for kind: String in GameManager.CODEX_KINDS:
		list.add_child(_codex_section(kind))


# 種類ひとつ：見出し「装備　4 / 15」＋ 絵と「？」の枠。⚠ 手に入れていない品は名前も絵も出さない（⚠ 中身が割れる）。
func _codex_section(kind: String) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = "Section_" + kind
	var ids: Array[String] = GameManager.get_codex_ids(kind)
	var found: int = 0
	for item_id: String in ids:
		if GameManager.is_codex_discovered(item_id):
			found += 1
	var line: HBoxContainer = HBoxContainer.new()
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_records_kind_" + kind)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var count: Label = Label.new()
	count.name = "CountLabel"
	count.text = "%d / %d" % [found, ids.size()]
	line.add_child(count)
	section.add_child(line)
	var cells: HFlowContainer = HFlowContainer.new()
	cells.name = "Cells"
	cells.theme_type_variation = &"RecordsCells"
	section.add_child(cells)
	for item_id: String in ids:
		if GameManager.is_codex_discovered(item_id):
			var icon: ItemIcon = ItemIcon.create(item_id)
			icon.name = "Found_" + item_id
			icon.tooltip_text = tr(GameManager.item_name_key(item_id))
			cells.add_child(icon)
		else:
			cells.add_child(_unknown_cell(item_id))
	section.add_child(HSeparator.new())
	return section


func _unknown_cell(item_id: String) -> PanelContainer:
	var cell: PanelContainer = PanelContainer.new()
	cell.name = "Unknown_" + item_id
	cell.theme_type_variation = &"RecordsUnknownCell"
	var side: float = float(get_theme_constant(&"cell", THEME_TYPE))
	cell.custom_minimum_size = Vector2(side, side)
	var mark: Label = Label.new()
	mark.theme_type_variation = &"CaptionLabel"
	mark.text = tr("ui_records_unknown")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(mark)
	return cell


# --- 集中の履歴（⚠ 合計と今日だけ＝「⚠ 5あ」） ------------------------------

func _build_focus() -> void:
	sheet_body.add_child(_heading("ui_records_tab_focus"))
	var list: VBoxContainer = _scroll_list()
	list.add_child(_value_row("TotalRow", tr("ui_records_focus_total"), tr("ui_records_count") % GameManager.get_total_pomodoro_completed()))
	list.add_child(_value_row("TodayRow", tr("ui_records_focus_today"), tr("ui_records_minutes") % GameManager.get_cumulative_focus_minutes_today()))
	var last: String = str(GameManager.get_state().get(GameStateKeys.LAST_POMODORO_END_AT, ""))
	var last_text: String = tr("ui_records_none")
	if last != "":
		last_text = Time.get_datetime_string_from_unix_time(int(float(last) + Time.get_time_zone_from_system().get("bias", 0) * 60), true)
	list.add_child(_value_row("LastRow", tr("ui_records_focus_last"), last_text))
	var note: Label = Label.new()
	note.name = "FocusNote"
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("ui_records_focus_note")
	list.add_child(note)


func _value_row(row_name: String, caption_text: String, value_text: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.theme_type_variation = &"SheetHeadingLabel"
	value.text = value_text
	line.add_child(value)
	return row


# --- キャラの情報（⚠ 行を押すとその人の育成） ------------------------------

func _build_characters() -> void:
	sheet_body.add_child(_heading("ui_records_tab_characters"))
	var list: VBoxContainer = _scroll_list()
	var stat_keys: Array[String] = [GameStateKeys.STAT_HP, GameStateKeys.STAT_ATK, GameStateKeys.STAT_MAG, GameStateKeys.STAT_DEF]
	for raw: Variant in GameManager.get_party_candidates():
		var character_id: String = str(raw)
		var row: LedgerRow = LedgerRow.new()
		row.name = "Character_" + character_id
		row.compact = true
		row.pressed.connect(_on_character_pressed.bind(character_id))
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		line.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"photo", THEME_TYPE)))
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(column)
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.theme_type_variation = &"SheetHeadingLabel"
		name_label.text = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
		column.add_child(name_label)
		var level: Label = Label.new()
		level.name = "LevelLabel"
		level.theme_type_variation = &"CaptionLabel"
		var role: String = character_id if GameManager.is_debug_character(character_id) else tr("ui_role_" + character_id)
		level.text = "%s ／ %s %d" % [role, tr("ui_dossier_lv"), int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))]
		column.add_child(level)
		var stats: Dictionary = GameManager.get_effective_stats(character_id)
		for stat_key: String in stat_keys:
			var stat: Label = Label.new()
			stat.name = "Stat_" + stat_key
			stat.custom_minimum_size.x = float(get_theme_constant(&"stat_width", THEME_TYPE))
			stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			stat.text = "%s %d" % [tr("ui_training_stat_" + stat_key), int(stats.get(stat_key, 0))]
			line.add_child(stat)
		list.add_child(row)


func _on_character_pressed(character_id: String) -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: character_id})


# --- ダンジョンの情報（⚠ 話ごとの済・難ダンジョンの途中） --------------------

func _build_dungeons() -> void:
	var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
	var cleared: int = 0
	for stage_id: Variant in order:
		if GameManager.is_stage_cleared(str(stage_id)):
			cleared += 1
	sheet_body.add_child(_heading("ui_records_tab_dungeons", "%d / %d" % [cleared, order.size()]))
	var list: VBoxContainer = _scroll_list()
	var normal: Label = Label.new()
	normal.theme_type_variation = &"CaptionLabel"
	normal.text = tr("ui_quest_tab_normal")
	list.add_child(normal)
	for index: int in range(order.size()):
		var stage_id: String = str(order[index])
		var title: String = "%s　%s" % [tr("ui_quest_episode") % (index + 1), tr(str(MasterDataLoader.get_stage(stage_id).get("name_key", stage_id)))]
		var state_key: String = "ui_records_cleared" if GameManager.is_stage_cleared(stage_id) else "ui_records_not_cleared"
		if GameManager.is_in_floor() and str(GameManager.get_floor_run().get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")) == stage_id:
			state_key = "ui_records_in_progress"
		list.add_child(_value_row("Stage_" + stage_id, title, tr(state_key)))
	var hard: Label = Label.new()
	hard.theme_type_variation = &"CaptionLabel"
	hard.text = tr("ui_quest_tab_hard")
	list.add_child(hard)
	var current_dungeon: String = str(GameManager.get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")) if GameManager.is_in_dungeon() else ""
	for dungeon_id: String in MasterDataLoader.get_all_dungeon_ids():
		var name_text: String = tr(str(MasterDataLoader.get_dungeon(dungeon_id).get("name_key", dungeon_id)))
		list.add_child(_value_row("Dungeon_" + dungeon_id, name_text, tr("ui_records_in_progress") if dungeon_id == current_dungeon else tr("ui_records_none")))


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
