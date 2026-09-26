class_name BaseFacilityBar
extends FacilityBar

# 拠点の施設の帯（2026-09-26・回UI-3・決定 `NAV-6`）。
#
# ⚠ `FacilityBar`（見た目だけの部品）に「⚠ どの施設がどの画面か」を持たせたもの。
#   ⚠ **並びと行き先はここが唯一の正**（⚠ 画面ごとに書かない＝7画面が同じ帯を出す）。
# ⚠ ギルドのカード（`GuildScreen`）の代わり。⚠ ギルドの画面は消した。
# ⚠ 解放していない施設は**出さない**（⚠ 前のカードの「空き枠」とは違う。⚠ 帯は詰める）。
# ⚠ 遷移は `SceneManager` だけ（`NAV-3`）。
# ⚠ 使い方：画面の `_ready()` で `BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.HQ)`。
#   ⚠ 帯を画面の下に敷き、⚠ 中身（`content`）の下端を帯の高さぶん上げる。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

# ⚠ 施設のID。⚠ 本部・詰所・記録は画面IDを持たないので、⚠ 帯の中だけの名前を付ける。
const HQ: String = "hq"
const BARRACKS: String = "barracks"
const TRAINING: String = "training"
const FORGE: String = "forge"
const BELONGINGS: String = "belongings"
const RECORDS: String = "records"
const RESEARCH: String = "research"
const SHOP: String = "shop"

const KEY_PATH: String = "path"
const KEY_UNLOCK: String = "unlock"   # ⚠ `""` ならいつも出す
const KEY_DATA: String = "data"

# ⚠⚠ 並び（`NAV-6`・仮）。⚠ 手本の5つ ＋ 研究・ショップ（人間「⚠ 7あ」）。
# ⚠⚠ 「育成」は**つなぎ**（⚠ 人間が「詰所＝編成」を選んだため、⚠ 育成の一覧へ入る道が他に無い）。
#   ⚠ 詰所を手本の形（身上書 → 育成）に作り直す回で帯から外す。
# ⚠ 「記録」は記録の画面ができるまで**倉庫の図鑑タブ**を開く（⚠ 人間の選択）。
static func facilities() -> Array[Dictionary]:
	return [
		{ENTRY_ID: HQ, ENTRY_LABEL_KEY: "ui_facility_hq",
			KEY_PATH: "res://scenes/base/base_screen.tscn", KEY_UNLOCK: ""},
		{ENTRY_ID: BARRACKS, ENTRY_LABEL_KEY: "ui_facility_barracks",
			KEY_PATH: "res://scenes/adventure/party_preset_screen.tscn", KEY_UNLOCK: ""},
		{ENTRY_ID: TRAINING, ENTRY_LABEL_KEY: "ui_facility_training",
			KEY_PATH: "res://scenes/guild/training_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_TRAINING},
		{ENTRY_ID: FORGE, ENTRY_LABEL_KEY: "ui_facility_forge",
			KEY_PATH: "res://scenes/guild/workshop_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WORKSHOP},
		{ENTRY_ID: BELONGINGS, ENTRY_LABEL_KEY: "ui_facility_belongings",
			KEY_PATH: "res://scenes/guild/warehouse_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE},
		{ENTRY_ID: RECORDS, ENTRY_LABEL_KEY: "ui_facility_records",
			KEY_PATH: "res://scenes/guild/warehouse_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE,
			KEY_DATA: {TransferKeys.WAREHOUSE_TAB: TransferKeys.WAREHOUSE_TAB_CODEX}},
		{ENTRY_ID: RESEARCH, ENTRY_LABEL_KEY: "ui_facility_research",
			KEY_PATH: "res://scenes/guild/research_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_RESEARCH},
		{ENTRY_ID: SHOP, ENTRY_LABEL_KEY: "ui_facility_shop",
			KEY_PATH: "res://scenes/guild/shop_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_SHOP},
	]


# ⚠ 解放しているものだけ。
static func visible_facilities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in facilities():
		var unlock: String = str(entry.get(KEY_UNLOCK, ""))
		if unlock == "" or GameManager.is_screen_unlocked(unlock):
			result.append(entry)
	return result


# ⚠ 画面の下に帯を敷く。⚠ `content` は画面いっぱいに広がる中身（⚠ `Margin` / `Layout`）。
static func attach(screen: Control, content: Control, active_id: String) -> BaseFacilityBar:
	var bar: BaseFacilityBar = BaseFacilityBar.new()
	bar.name = "FacilityBar"
	bar._content = content
	screen.add_child(bar)
	bar.set_facilities(visible_facilities(), active_id)
	return bar


var _content: Control = null
var _entries: Dictionary = {}  # id -> entry


func _ready() -> void:
	super._ready()
	var height: float = float(get_theme_constant(&"height", THEME_TYPE))
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -height
	if _content != null:
		_content.offset_bottom = -height
		# ⚠ 中身が帯のぶん入りきらないとき、⚠ 上へ伸びると見出しと「戻る」がずれて右上の通貨と重なる
		#   （⚠ 回UI-3 の絵：育成の一覧が検証用3人ぶん長い）。⚠ **下（帯の裏）へだけ伸ばす**。
		_content.grow_vertical = Control.GROW_DIRECTION_END
	facility_pressed.connect(_on_facility_pressed)


func set_facilities(entries: Array[Dictionary], active_id: String = "") -> void:
	_entries.clear()
	for entry: Dictionary in entries:
		_entries[str(entry.get(ENTRY_ID, ""))] = entry
	super.set_facilities(entries, active_id)


func _on_facility_pressed(id: String) -> void:
	var entry: Dictionary = _entries.get(id, {})
	var path: String = str(entry.get(KEY_PATH, ""))
	if path == "":
		push_warning("[BaseFacilityBar] 行き先の無い施設: " + id)
		return
	var data: Dictionary = entry.get(KEY_DATA, {})
	if data.is_empty():
		SceneManager.change_scene(path)
	else:
		SceneManager.change_scene_with_data(path, data)
