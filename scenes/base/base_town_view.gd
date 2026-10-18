class_name BaseTownView
extends PanelContainer

# 「ギルド」＝ギルドを見渡す街（2026-10-07・回HB-1・`NAV-21`／⚠ 10-18 作り直し・回UI-1018-6・web版の手本 `05_base_town.png`・`NAV-34`）。
#
# ⚠ 緑の地に建物を置き、⚠ 宝物庫（真ん中）から道を引く。⚠ 建物を押すとその施設へ。⚠ 編成の3人が建物の間を歩く。
# ⚠ **毎日すること4つは大きい建物**（⚠ 冒険の門・宝物庫・集中の塔・訓練場）。⚠ 知らせがある建物には赤いしおり紐（`attention_of()`）。
# ⚠⚠ 絵はまだ無い（⚠ 段階13・素材待ち）＝⚠ 建物は線と面で描いた仮の形（`TownBuilding`）。⚠ 絵が入ったら `TownBuilding` の中身を差し替える。
# ⚠ 行き先は帯の表（`BaseFacilityBar.path_of()`）＝⚠ ここに2本目を書かない。⚠ 開けない施設は建てない。
# ⚠ 置き場所は地の大きさに対する割合（⚠ 形の値なのでここに置く）。⚠ 寸法と色は Theme の `BaseTown` 型。
# ⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。

const THEME_TYPE: StringName = &"BaseTown"
const POMODORO: String = "pomodoro"
const CHEST: String = "chest"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"
const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const BOARD_PATH: String = "res://scenes/adventure/adventure_select.tscn"

const KEY_ID: String = "id"
const KEY_SHAPE: String = "shape"
const KEY_BIG: String = "big"
const KEY_AT: String = "at"
const KEY_LABEL: String = "label"

# ⚠ 手本の並び（⚠ 宝物庫が真ん中・道はそこから延びる）。
const BUILDINGS: Array[Dictionary] = [
	{KEY_ID: BaseFacilityBar.RECORDS, KEY_SHAPE: TownBuilding.SHAPE_HOUSE, KEY_BIG: false, KEY_AT: Vector2(0.22, 0.2), KEY_LABEL: "ui_town_records"},
	{KEY_ID: BaseFacilityBar.BOARD, KEY_SHAPE: TownBuilding.SHAPE_GATE, KEY_BIG: true, KEY_AT: Vector2(0.48, 0.2), KEY_LABEL: "ui_town_board"},
	{KEY_ID: BaseFacilityBar.SHOP, KEY_SHAPE: TownBuilding.SHAPE_SHOP, KEY_BIG: false, KEY_AT: Vector2(0.71, 0.18), KEY_LABEL: "ui_town_shop"},
	{KEY_ID: POMODORO, KEY_SHAPE: TownBuilding.SHAPE_TOWER, KEY_BIG: true, KEY_AT: Vector2(0.15, 0.47), KEY_LABEL: "ui_town_pomodoro"},
	{KEY_ID: BaseFacilityBar.TRAINING, KEY_SHAPE: TownBuilding.SHAPE_HALL, KEY_BIG: true, KEY_AT: Vector2(0.8, 0.47), KEY_LABEL: "ui_town_training"},
	{KEY_ID: CHEST, KEY_SHAPE: TownBuilding.SHAPE_VAULT, KEY_BIG: true, KEY_AT: Vector2(0.48, 0.68), KEY_LABEL: "ui_town_chest"},
	{KEY_ID: BaseFacilityBar.BARRACKS, KEY_SHAPE: TownBuilding.SHAPE_HOUSE, KEY_BIG: false, KEY_AT: Vector2(0.09, 0.8), KEY_LABEL: "ui_facility_barracks"},
	{KEY_ID: BaseFacilityBar.FORGE, KEY_SHAPE: TownBuilding.SHAPE_FORGE, KEY_BIG: false, KEY_AT: Vector2(0.29, 0.86), KEY_LABEL: "ui_facility_forge"},
	{KEY_ID: BaseFacilityBar.RESEARCH, KEY_SHAPE: TownBuilding.SHAPE_LAB, KEY_BIG: false, KEY_AT: Vector2(0.67, 0.86), KEY_LABEL: "ui_town_research"},
	{KEY_ID: BaseFacilityBar.GUILD_RELIC, KEY_SHAPE: TownBuilding.SHAPE_ALTAR, KEY_BIG: false, KEY_AT: Vector2(0.87, 0.82), KEY_LABEL: "ui_town_relic"},
]
# ⚠ 立ち止まる長さ（⚠ 秒）の幅。
const PAUSE_MIN_SEC: float = 0.8
const PAUSE_MAX_SEC: float = 2.4


static func create() -> BaseTownView:
	var view: BaseTownView = BaseTownView.new()
	view.name = "TownView"
	return view


var _map: Control = null
var _buildings: Dictionary = {}  # id -> TownBuilding
var _walkers: Array[Control] = []
var _walking: bool = false


func _ready() -> void:
	theme_type_variation = &"TownMapPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map = Control.new()
	_map.name = "Map"
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_roads)
	_map.resized.connect(_layout)
	add_child(_map)
	for entry: Dictionary in BUILDINGS:
		var id: String = str(entry[KEY_ID])
		if not _is_open(id):
			continue
		var building: TownBuilding = TownBuilding.create(id, str(entry[KEY_SHAPE]), bool(entry[KEY_BIG]), str(entry[KEY_LABEL]))
		building.pressed.connect(_on_building_pressed.bind(id))
		_map.add_child(building)
		_buildings[id] = building
	for raw: Variant in GameManager.get_party_members():
		if str(raw) != "":
			var walker: CharacterAvatar = CharacterAvatar.create(str(raw), get_theme_constant(&"walker", THEME_TYPE))
			walker.name = "Walker_" + str(raw)
			walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_map.add_child(walker)
			_walkers.append(walker)
	var legend: Label = Label.new()
	legend.name = "Legend"
	legend.theme_type_variation = &"TownLegendLabel"
	legend.text = tr("ui_town_legend")
	_map.add_child(legend)
	refresh_attention()
	GameManager.pending_chests_changed.connect(_on_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(refresh_attention)
	GameManager.research_node_unlocked.connect(_on_changed_str)
	GameManager.character_growth_changed.connect(_on_changed_str)
	GameManager.shop_changed.connect(_on_changed_str)
	GameManager.inventory_changed.connect(_on_changed_str)


func _is_open(id: String) -> bool:
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


# ⚠ 建物の下の小さい字（⚠ いま何があるか）と、しおり紐。
func refresh_attention() -> void:
	for id: String in _buildings:
		var building: TownBuilding = _buildings[id]
		building.set_note(_note_of(id))
		var on: bool = GameManager.get_pending_chest_count() > 0 if id == CHEST else BaseFacilityBar.attention_of(id)
		RibbonMark.set_on(building.shape_control(), on)


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


# ⚠ 地の大きさが決まってから建物を置く（⚠ 割合 × 大きさ・建物の中心）。
func _layout() -> void:
	if _map.size.x <= 0.0:
		return
	for entry: Dictionary in BUILDINGS:
		var id: String = str(entry[KEY_ID])
		if not _buildings.has(id):
			continue
		var building: TownBuilding = _buildings[id]
		building.size = building.get_combined_minimum_size()
		building.position = _point_of(entry) - Vector2(building.size.x * 0.5, building.anchor_y())
	var legend: Control = _map.get_node("Legend") as Control
	legend.size = legend.get_combined_minimum_size()
	var pad: float = float(get_theme_constant(&"legend_pad", THEME_TYPE))
	legend.position = Vector2(pad, _map.size.y - legend.size.y - pad)
	_map.queue_redraw()
	_start_walking()


func _point_of(entry: Dictionary) -> Vector2:
	var at: Vector2 = entry[KEY_AT]
	return Vector2(_map.size.x * at.x, _map.size.y * at.y)


# ⚠ 宝物庫から各建物へ（⚠ 横に出てから曲がる2次の曲線）。
func _draw_roads() -> void:
	var hub: Vector2 = Vector2.ZERO
	for entry: Dictionary in BUILDINGS:
		if str(entry[KEY_ID]) == CHEST:
			hub = _point_of(entry)
	var color: Color = get_theme_color(&"road", THEME_TYPE)
	var width: float = float(get_theme_constant(&"road_width", THEME_TYPE))
	for entry: Dictionary in BUILDINGS:
		var id: String = str(entry[KEY_ID])
		if id == CHEST or not _buildings.has(id):
			continue
		var to: Vector2 = _point_of(entry)
		var control: Vector2 = Vector2(to.x, hub.y)
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in range(0, 17):
			var t: float = float(step) / 16.0
			var u: float = 1.0 - t
			points.append(hub * u * u + control * 2.0 * u * t + to * t * t)
		_map.draw_polyline(points, color, width, true)
		_map.draw_circle(to, width * 0.5, color)
	_map.draw_circle(hub, width * 0.5, color)


# ⚠ 歩く人：⚠ 建物の前から前へ歩き、⚠ 少し立ち止まる。⚠ Tween は顔に持たせる（⚠ 顔が消えれば一緒に止まる）。
func _start_walking() -> void:
	if _walking or _walkers.is_empty() or _buildings.is_empty():
		return
	_walking = true
	for walker: Control in _walkers:
		var side: float = float(get_theme_constant(&"walker", THEME_TYPE))
		walker.size = Vector2(side, side)
		walker.position = _random_stop(walker)
		_walk(walker)


func _random_stop(walker: Control) -> Vector2:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in BUILDINGS:
		if _buildings.has(str(entry[KEY_ID])):
			entries.append(entry)
	var point: Vector2 = _point_of(entries[randi() % entries.size()])
	# ⚠ 建物の右下（⚠ 名札に重ならない所）。
	return point + Vector2(float(get_theme_constant(&"walker_side", THEME_TYPE)), -walker.size.y - float(get_theme_constant(&"walker_offset", THEME_TYPE)))


func _walk(walker: Control) -> void:
	if not is_instance_valid(walker) or _map == null:
		return
	var target: Vector2 = _random_stop(walker)
	var speed: float = maxf(float(get_theme_constant(&"walk_speed", THEME_TYPE)), 1.0)
	var tween: Tween = walker.create_tween()
	tween.tween_property(walker, "position", target, walker.position.distance_to(target) / speed + 0.01)
	tween.tween_interval(randf_range(PAUSE_MIN_SEC, PAUSE_MAX_SEC))
	tween.finished.connect(_walk.bind(walker))


func _on_changed_int(_value: int) -> void:
	refresh_attention()


func _on_changed_str(_value: String) -> void:
	refresh_attention()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	refresh_attention()
