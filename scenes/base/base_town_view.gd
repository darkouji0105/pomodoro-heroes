class_name BaseTownView
extends PanelContainer

# 「ギルド」＝ギルドの施設を選ぶ板（2026-10-07・回HB-1・`NAV-21`／⚠ 10-18 作り直し・回UI-1018-6・`NAV-34`）。
#
# ⚠⚠ 10-23（人間「⚠ ギルドは建物形式ではなく複数panelから選ぶようにしたい」・`NAV-34`）：⚠ 建物の絵・道・歩く3人をやめ、**パネル**を並べた。
#   ⚠ 上の段＝毎日すること4つ（冒険の門・宝物庫・集中の塔・訓練場）の大きいパネル（真鍮の縁＝`DeskFeaturePanel`）。
#   ⚠ 下＝ほかの施設の小さいパネル（3列）。⚠ パネル＝アイコン・名前・小さい字（いま何があるか）・知らせがあれば赤い栞。⚠ 押すとその施設へ。
# ⚠ 行き先は帯の表（`BaseFacilityBar.path_of()`）＝⚠ ここに2本目を書かない。⚠ 開けない施設は出さない。
# ⚠ 帯の「ギルド」の栞は `has_attention()`（⚠ パネルの栞と同じ判定）。
# ⚠ 寸法は Theme の `BaseDesk`（⚠ 机の札と同じ）。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番）。

const THEME_TYPE: StringName = &"BaseDesk"
const POMODORO: String = "pomodoro"
const CHEST: String = "chest"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"
const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const BOARD_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const SMALL_COLUMNS: int = 3

const KEY_ID: String = "id"
const KEY_BIG: String = "big"
const KEY_LABEL: String = "label"
const KEY_ICON: String = "icon"

# ⚠ 並び＝上の段（大きい）→ 下（小さい）。⚠ アイコンは今ある絵の名前（`IconTextures`）。
const BUILDINGS: Array[Dictionary] = [
	{KEY_ID: BaseFacilityBar.BOARD, KEY_BIG: true, KEY_LABEL: "ui_town_board", KEY_ICON: "hq_adventure"},
	{KEY_ID: CHEST, KEY_BIG: true, KEY_LABEL: "ui_town_chest", KEY_ICON: "item_chest"},
	{KEY_ID: POMODORO, KEY_BIG: true, KEY_LABEL: "ui_town_pomodoro", KEY_ICON: "timer_play"},
	{KEY_ID: BaseFacilityBar.TRAINING, KEY_BIG: true, KEY_LABEL: "ui_town_training", KEY_ICON: "hq_grow"},
	{KEY_ID: BaseFacilityBar.BARRACKS, KEY_BIG: false, KEY_LABEL: "ui_facility_barracks", KEY_ICON: "nav_training"},
	{KEY_ID: BaseFacilityBar.FORGE, KEY_BIG: false, KEY_LABEL: "ui_facility_forge", KEY_ICON: "nav_workshop"},
	{KEY_ID: BaseFacilityBar.RESEARCH, KEY_BIG: false, KEY_LABEL: "ui_town_research", KEY_ICON: "nav_research"},
	{KEY_ID: BaseFacilityBar.GUILD_RELIC, KEY_BIG: false, KEY_LABEL: "ui_town_relic", KEY_ICON: "item_relic"},
	{KEY_ID: BaseFacilityBar.SHOP, KEY_BIG: false, KEY_LABEL: "ui_town_shop", KEY_ICON: "nav_shop"},
	{KEY_ID: BaseFacilityBar.RECORDS, KEY_BIG: false, KEY_LABEL: "ui_town_records", KEY_ICON: "hq_board"},
]


static func create() -> BaseTownView:
	var view: BaseTownView = BaseTownView.new()
	view.name = "TownView"
	return view


var _panels: Dictionary = {}  # id -> PaperSheet
var _notes: Dictionary = {}   # id -> Label


func _ready() -> void:
	theme_type_variation = &"CorkBoardPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Panels"
	column.theme_type_variation = &"BaseDeskColumn"
	add_child(column)
	var big_row: HBoxContainer = HBoxContainer.new()
	big_row.name = "DailyRow"
	big_row.theme_type_variation = &"BaseDeskRow"
	column.add_child(big_row)
	var small_grid: GridContainer = GridContainer.new()
	small_grid.name = "OtherGrid"
	small_grid.columns = SMALL_COLUMNS
	column.add_child(small_grid)
	for entry: Dictionary in BUILDINGS:
		var id: String = str(entry[KEY_ID])
		if not is_building_open(id):
			continue
		var big: bool = bool(entry[KEY_BIG])
		var panel: PaperSheet = _panel(id, str(entry[KEY_LABEL]), str(entry[KEY_ICON]), big)
		(big_row if big else small_grid).add_child(panel)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var legend: Label = Label.new()
	legend.name = "Legend"
	legend.theme_type_variation = &"TownLegendLabel"
	legend.text = tr("ui_town_legend")
	column.add_child(legend)
	refresh_attention()
	GameManager.pending_chests_changed.connect(_on_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(refresh_attention)
	GameManager.research_node_unlocked.connect(_on_changed_str)
	GameManager.character_growth_changed.connect(_on_changed_str)
	GameManager.shop_changed.connect(_on_changed_str)
	GameManager.inventory_changed.connect(_on_changed_str)


# パネル1枚：⚠ アイコンの箱 ／ 名前 ／ 小さい字。⚠ 押すとその施設へ。
func _panel(id: String, label_key: String, icon_name: String, big: bool) -> PaperSheet:
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Building_" + id
	sheet.show_corners = false
	sheet.theme_type_variation = &"DeskFeaturePanel" if big else &"DeskCardPanel"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(row)
	var side: float = float(get_theme_constant(&"icon_box", THEME_TYPE))
	var box: PanelContainer = PanelContainer.new()
	box.name = "IconBox"
	box.theme_type_variation = &"DeskIconBox"
	box.custom_minimum_size = Vector2(side, side)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var picture: TextureRect = TextureRect.new()
	picture.texture = IconTextures.for_chest() if id == CHEST else IconTextures.for_hq(icon_name)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.self_modulate = get_theme_color(&"icon", THEME_TYPE)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.theme_type_variation = &"TightList"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"DeskFeatureTitleLabel" if big else &"DeskCardTitleLabel"
	title.text = tr(label_key)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)
	var note: Label = Label.new()
	note.name = "NoteLabel"
	note.theme_type_variation = &"CaptionLabel"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(note)
	var _hit: Button = UiButton.attach_hit(sheet, _on_building_pressed.bind(id))
	_panels[id] = sheet
	_notes[id] = note
	return sheet


static func is_building_open(id: String) -> bool:
	match id:
		POMODORO:
			return GameManager.is_screen_unlocked(GameStateKeys.SCREEN_POMODORO)
		CHEST:
			return true
	return BaseFacilityBar.is_open(id)


func _path_of(id: String) -> String:
	match id:
		POMODORO:
			return POMODORO_PATH
		CHEST:
			return CHEST_PATH
	return BaseFacilityBar.path_of(id)


func _on_building_pressed(id: String) -> void:
	var path: String = _path_of(id)
	if path != "":
		SceneManager.change_scene(path)


# ⚠ パネルの小さい字（⚠ いま何があるか）と、しおり紐。
func refresh_attention() -> void:
	for id: String in _panels:
		var note: Label = _notes[id]
		note.text = _note_of(id)
		note.visible = note.text != ""
		RibbonMark.set_on(_panels[id] as Control, building_attention(id))


# ⚠ パネルのしおり紐（⚠ 宝物庫＝届いた宝箱 ／ ほか＝帯の紐と同じ口）。
static func building_attention(id: String) -> bool:
	return GameManager.get_pending_chest_count() > 0 if id == CHEST else BaseFacilityBar.attention_of(id)


# ⚠ ギルドのどこかに知らせがあるか（10-19・回SEE29-B・人間「⚠ ギルドに何か通知があるなら画面の下部のタブにしおりを」）。
#   ⚠ 帯の「ギルド」の紐が引く（⚠ 出しているパネルだけ）。
static func has_attention() -> bool:
	for entry: Dictionary in BUILDINGS:
		var id: String = str(entry[KEY_ID])
		if is_building_open(id) and building_attention(id):
			return true
	return false


func _note_of(id: String) -> String:
	match id:
		BaseFacilityBar.BOARD:
			var open_stories: int = 0
			for raw: Variant in MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY):
				if GameManager.is_story_stage_unlocked(str(raw)) and not GameManager.is_stage_cleared(str(raw)):
					open_stories += 1
			return tr("ui_town_note_board") % (open_stories + MasterDataLoader.get_all_dungeon_ids().size())
		POMODORO:
			return tr("ui_town_note_pomodoro")
		CHEST:
			var chests: int = GameManager.get_pending_chest_count()
			return tr("ui_town_note_chest") % chests if chests > 0 else ""
		BaseFacilityBar.TRAINING:
			var ready: int = GameManager.get_level_up_ready_characters().size()
			return tr("ui_town_note_training") % ready if ready > 0 else ""
		BaseFacilityBar.RESEARCH:
			var count: int = GameManager.get_unlockable_research_count()
			return tr("ui_town_note_research") % count if count > 0 else ""
		BaseFacilityBar.SHOP:
			return tr("ui_town_note_shop") if BaseFacilityBar.attention_of(id) else ""
	return ""


func _on_changed_int(_value: int) -> void:
	refresh_attention()


func _on_changed_str(_value: String) -> void:
	refresh_attention()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	refresh_attention()
