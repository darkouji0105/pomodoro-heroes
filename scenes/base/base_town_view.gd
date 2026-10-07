class_name BaseTownView
extends VBoxContainer

# 本部の「拠点の全体」（2026-10-07・回HB-1・`NAV-21`・人間「⚠ 拠点が見れるビューもとグルで見れるようにする　ギルドのデスクと拠点全体ビューって感じ」→「両方」）。
#
# ⚠ 建物を並べ（⚠ 押すとその施設へ）、⚠ 下の道を編成の3人が歩く。
# ⚠⚠ 絵はまだ無い（⚠ 段階13・素材待ち）＝⚠ 建物は札、⚠ 歩く人は顔（`CharacterAvatar`）の仮の形。
#   ⚠ 絵が入ったら、⚠ `_make_building()` と `_make_walker()` の中身を差し替える。
# ⚠ 建物の並びと行き先は帯と同じ口（`BaseFacilityBar`）＝⚠ ここに2本目を書かない。⚠ 開けない施設は出さない。
# ⚠ 寸法は Theme の `BaseDesk` 型。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。

const THEME_TYPE: StringName = &"BaseDesk"
# ⚠ 建物の並び（⚠ 本部は「いまいる所」なので建てない）。
const BUILDING_IDS: Array[String] = [
	BaseFacilityBar.BOARD, BaseFacilityBar.TRAINING, BaseFacilityBar.BARRACKS, BaseFacilityBar.FORGE,
	BaseFacilityBar.RESEARCH, BaseFacilityBar.GUILD_RELIC, BaseFacilityBar.BELONGINGS, BaseFacilityBar.RECORDS, BaseFacilityBar.SHOP,
]
# ⚠ 立ち止まる長さ（⚠ 秒）の幅。
const PAUSE_MIN_SEC: float = 0.8
const PAUSE_MAX_SEC: float = 2.4


static func create() -> BaseTownView:
	var view: BaseTownView = BaseTownView.new()
	view.name = "TownView"
	return view


var _buildings: HBoxContainer = null
var _road: Control = null
var _walking: bool = false


func _ready() -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_buildings = HBoxContainer.new()
	_buildings.name = "Buildings"
	_buildings.alignment = BoxContainer.ALIGNMENT_CENTER
	_buildings.theme_type_variation = &"BaseBuildingRow"   # ⚠ 間は `BaseDesk/building_gap`
	add_child(_buildings)
	_road = Control.new()
	_road.name = "Road"
	_road.custom_minimum_size.y = float(get_theme_constant(&"road", THEME_TYPE))
	_road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_road.draw.connect(_draw_road)
	_road.resized.connect(_start_walking)
	add_child(_road)
	for id: String in BUILDING_IDS:
		if BaseFacilityBar.is_open(id):
			_buildings.add_child(_make_building(id))
	for raw: Variant in GameManager.get_party_members():
		var character_id: String = str(raw)
		if character_id != "":
			_road.add_child(_make_walker(character_id))
	refresh_attention()
	GameManager.pending_chests_changed.connect(_on_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(refresh_attention)
	GameManager.research_node_unlocked.connect(_on_changed_str)
	GameManager.character_growth_changed.connect(_on_changed_str)
	GameManager.shop_changed.connect(_on_changed_str)
	GameManager.inventory_changed.connect(_on_changed_str)


# ⚠ 名前と行き先は帯・育成の中のタブの表から（⚠ 「育成」の建物＝キャラの一覧）。
func _make_building(id: String) -> Button:
	var entry: Dictionary = {}
	for raw: Dictionary in BaseFacilityBar.facilities() + BaseFacilityBar.training_tabs():
		if str(raw.get(FacilityBar.ENTRY_ID, "")) == id and str(raw.get(BaseFacilityBar.KEY_PATH, "")) != "":
			entry = raw
	var button: Button = Button.new()
	button.name = "Building_" + id
	button.custom_minimum_size = Vector2(
		float(get_theme_constant(&"building_width", THEME_TYPE)),
		float(get_theme_constant(&"building_height", THEME_TYPE)))
	var label_key: String = "ui_facility_training" if id == BaseFacilityBar.TRAINING else str(entry.get(FacilityBar.ENTRY_LABEL_KEY, ""))
	button.text = tr(label_key)
	button.pressed.connect(SceneManager.change_scene.bind(str(entry.get(BaseFacilityBar.KEY_PATH, ""))))
	return button


func _make_walker(character_id: String) -> CharacterAvatar:
	var walker: CharacterAvatar = CharacterAvatar.create(character_id, get_theme_constant(&"walker", THEME_TYPE))
	walker.name = "Walker_" + character_id
	walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return walker


func refresh_attention() -> void:
	for child: Node in _buildings.get_children():
		var id: String = str(child.name).trim_prefix("Building_")
		RibbonMark.set_on(child as Control, BaseFacilityBar.attention_of(id))


# ⚠ 道の大きさが決まってから歩き出す（⚠ 決まる前は幅 0）。
func _start_walking() -> void:
	if _walking or _road.size.x <= 0.0:
		return
	_walking = true
	var walker_size: float = float(get_theme_constant(&"walker", THEME_TYPE))
	var span: float = maxf(_road.size.x - walker_size, 0.0)
	var count: int = _road.get_child_count()
	for i: int in range(count):
		var walker: Control = _road.get_child(i) as Control
		walker.size = Vector2(walker_size, walker_size)
		walker.position = Vector2(span * float(i + 1) / float(count + 1), (_road.size.y - walker_size) * 0.5)
		_walk(walker)


# ⚠ 道の上の好きな所まで歩き、⚠ 少し立ち止まって、また歩く。⚠ Tween は顔に持たせる（⚠ 顔が消えれば一緒に止まる）。
func _walk(walker: Control) -> void:
	if not is_instance_valid(walker) or _road == null:
		return
	var span: float = maxf(_road.size.x - walker.size.x, 0.0)
	var target: float = randf_range(0.0, span)
	var speed: float = maxf(float(get_theme_constant(&"walk_speed", THEME_TYPE)), 1.0)
	var tween: Tween = walker.create_tween()
	tween.tween_property(walker, "position:x", target, absf(target - walker.position.x) / speed + 0.01)
	tween.tween_interval(randf_range(PAUSE_MIN_SEC, PAUSE_MAX_SEC))
	tween.finished.connect(_walk.bind(walker))


func _draw_road() -> void:
	_road.draw_line(Vector2(0.0, 0.0), Vector2(_road.size.x, 0.0), get_theme_color(&"road", THEME_TYPE), 1.0)


func _on_changed_int(_value: int) -> void:
	refresh_attention()


func _on_changed_str(_value: String) -> void:
	refresh_attention()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	refresh_attention()
