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
# ⚠⚠ 10-07（回HB-1・人間「⚠ 育成にいくつかまとめる」→ 研究・鍛冶場・詰所）：⚠ 帯は6つ。
#   ⚠ 育成の仲間（キャラ・編成・鍛冶場・研究）の画面では、⚠ 帯のすぐ上に**育成の中のタブ**を1段敷く。
#   ⚠ 帯の灯りは「育成」に乗る。⚠ 渡す `active_id` は今までどおり画面ごとの ID（`FORGE` など）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

# ⚠ 施設のID。⚠ 本部・詰所・記録は画面IDを持たないので、⚠ 帯の中だけの名前を付ける。
# ⚠ `BARRACKS` / `FORGE` / `RESEARCH` は 10-07 から育成の中のタブの ID（⚠ 帯には出ない）。
const HQ: String = "hq"
const BOARD: String = "board"
const BARRACKS: String = "barracks"
const TRAINING: String = "training"
const FORGE: String = "forge"
const BELONGINGS: String = "belongings"
const RECORDS: String = "records"
const RESEARCH: String = "research"
const SHOP: String = "shop"
# ⚠ 10-07（回HB-3・`EQ-8`・人間「⚠ ３あ」）：⚠ 拠点の遺物（育成の中のタブ）。
const GUILD_RELIC: String = "guild_relic"

const KEY_PATH: String = "path"
const KEY_UNLOCK: String = "unlock"   # ⚠ `""` ならいつも出す
const KEY_DATA: String = "data"

const SUB_THEME_TYPE: StringName = &"FacilitySubBar"

# ⚠⚠ 並び（`NAV-6`・仮）。⚠ 10-07 から6つ（⚠ 研究・鍛冶場・詰所は育成の中のタブへ）。
# ⚠ 「育成」はいつも出す（⚠ 中の「編成」がいつも開ける）。⚠ 押すと中のタブの先頭（⚠ 開けるもの）へ。
static func facilities() -> Array[Dictionary]:
	return [
		{ENTRY_ID: HQ, ENTRY_LABEL_KEY: "ui_facility_hq",
			KEY_PATH: "res://scenes/base/base_screen.tscn", KEY_UNLOCK: ""},
		# ⚠ 2026-10-06（`NAV-6`）：⚠ 依頼掲示板。⚠ 10-07（回HB-1・人間「⚠ ２じゃあ」）から本部の「冒険」は無い＝⚠ 出撃の入口はここだけ。
		{ENTRY_ID: BOARD, ENTRY_LABEL_KEY: "ui_facility_board",
			KEY_PATH: "res://scenes/adventure/adventure_select.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_ADVENTURE_SELECT},
		{ENTRY_ID: TRAINING, ENTRY_LABEL_KEY: "ui_facility_training", KEY_PATH: "", KEY_UNLOCK: ""},
		{ENTRY_ID: BELONGINGS, ENTRY_LABEL_KEY: "ui_facility_belongings",
			KEY_PATH: "res://scenes/guild/warehouse_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE},
		# ⚠ 09-28（回UI-仕組み②）：⚠ 記録の画面（⚠ 前は持ち物の図鑑タブ）。
		{ENTRY_ID: RECORDS, ENTRY_LABEL_KEY: "ui_facility_records",
			KEY_PATH: "res://scenes/guild/records_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE},
		# ⚠ 2026-10-03（人間「⚠ ショップがないどこからいくの」→「⚠ 1あ」）：⚠ **いつも出す**（⚠ ノルマ札を買う所＝難ダンジョンは最初から入れる）。
		{ENTRY_ID: SHOP, ENTRY_LABEL_KEY: "ui_facility_shop",
			KEY_PATH: "res://scenes/guild/shop_screen.tscn", KEY_UNLOCK: ""},
	]


# ⚠⚠ 育成の中のタブ（10-07・回HB-1）。⚠ 並びは キャラ → 編成 → 鍛冶場 → 研究。
#   ⚠ 09-27 の「⚠ キャラの配置とキャラ個別のものはべつにしよう」は**画面を分けたまま**守る（⚠ 同じ育成の中の別のタブ）。
static func training_tabs() -> Array[Dictionary]:
	return [
		{ENTRY_ID: TRAINING, ENTRY_LABEL_KEY: "ui_training_tab_characters",
			KEY_PATH: "res://scenes/guild/training_list_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_TRAINING},
		{ENTRY_ID: BARRACKS, ENTRY_LABEL_KEY: "ui_facility_barracks",
			KEY_PATH: "res://scenes/adventure/party_preset_screen.tscn", KEY_UNLOCK: ""},
		{ENTRY_ID: FORGE, ENTRY_LABEL_KEY: "ui_facility_forge",
			# ⚠ 2026-09-27（回UI-仕組み①・人間「⚠ 2あ」）：⚠ 鍛冶場は「鍛える」タブから開く（⚠ 作業場は「作る」タブ）。
			# ⚠ 09-28 人間「⚠ 鍛冶場を装備以外のところからいけるようにしたい」：⚠ 持ち物と同じ解放で出す（⚠ 「作る」タブは作業場の解放まで出ない）。
			KEY_PATH: "res://scenes/guild/forge_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE},
		{ENTRY_ID: RESEARCH, ENTRY_LABEL_KEY: "ui_facility_research",
			KEY_PATH: "res://scenes/guild/research_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_RESEARCH},
	]


# ⚠ 帯にも育成の中にも出ない部屋（⚠ 拠点の全体の建物・今日の紙が引く）。
#   ⚠ 10-07（見る回22回目・人間「⚠ 鍛冶場の中に遺物のカテゴリを」）：⚠ 遺物は鍛冶場のタブ（`ForgeScreen.tab_entries()`）へ移した。
static func other_rooms() -> Array[Dictionary]:
	return [
		{ENTRY_ID: GUILD_RELIC, ENTRY_LABEL_KEY: "ui_facility_guild_relic",
			KEY_PATH: "res://scenes/guild/guild_relic_screen.tscn", KEY_UNLOCK: GameStateKeys.SCREEN_WAREHOUSE},
	]


# ⚠ 解放しているものだけ。
static func visible_facilities() -> Array[Dictionary]:
	return _unlocked(facilities())


static func visible_training_tabs() -> Array[Dictionary]:
	return _unlocked(training_tabs())


static func _unlocked(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var unlock: String = str(entry.get(KEY_UNLOCK, ""))
		if unlock == "" or GameManager.is_screen_unlocked(unlock):
			result.append(entry)
	return result


# ⚠ その施設（⚠ 育成の中のタブも）がいま開けるか。
static func is_open(id: String) -> bool:
	for entry: Dictionary in facilities() + training_tabs() + other_rooms():
		if str(entry.get(ENTRY_ID, "")) == id:
			var unlock: String = str(entry.get(KEY_UNLOCK, ""))
			return unlock == "" or GameManager.is_screen_unlocked(unlock)
	return false


# ⚠ その ID が育成の中のタブか。
static func is_training_tab(id: String) -> bool:
	for entry: Dictionary in training_tabs():
		if str(entry.get(ENTRY_ID, "")) == id:
			return true
	return false


# ⚠ 帯で「育成」を押したときの行き先＝⚠ 中のタブの先頭（⚠ 開けるもの）。
static func training_path() -> String:
	var tabs: Array[Dictionary] = visible_training_tabs()
	return "" if tabs.is_empty() else str(tabs[0].get(KEY_PATH, ""))


# ⚠ 画面の下に帯を敷く。⚠ `content` は画面いっぱいに広がる中身（⚠ `Margin` / `Layout`）。
#   ⚠ 育成の中のタブの ID を渡すと、⚠ 見出しの下に部屋のタブ（紙のタブ）を差し込む。
#   ⚠ 10-07（見る回22回目・人間「⚠ 育成のところは、部屋の切り替えみたいな感じでタブを切り替えて移動できるように」→「上に紙のタブ」）：
#     ⚠ 前は帯の上の細い段（`FacilityBar`）。⚠ 見出しが無い画面では帯の上に置く（⚠ 落ちないための逃げ道）。
static func attach(screen: Control, content: Control, active_id: String) -> BaseFacilityBar:
	var bar: BaseFacilityBar = BaseFacilityBar.new()
	bar.name = "FacilityBar"
	bar._content = content
	if is_training_tab(active_id):
		var entries: Array[Dictionary] = visible_training_tabs()
		var keys: Array[String] = []
		var ids: Array[String] = []
		var selected: int = 0
		for i: int in range(entries.size()):
			keys.append(str(entries[i].get(ENTRY_LABEL_KEY, "")))
			ids.append(str(entries[i].get(ENTRY_ID, "")))
			if ids[i] == active_id:
				selected = i
		var tabs: PaperTabs = PaperTabs.new()
		tabs.name = "TrainingTabs"
		tabs.variation_prefix = "RoomTab"
		tabs.set_tabs(keys, selected)
		tabs.set_meta(META_ROOM_IDS, ids)
		# ⚠ 押す相手を名前で引けるように（⚠ 検査・前の帯の段と同じ名前）。
		for i: int in range(ids.size()):
			tabs.get_child(i).name = "Facility_" + ids[i]
		var header: Node = content.get_node_or_null("Layout/Header")
		if header != null:
			# ⚠ 見出しとタブを隙間なく重ねる（⚠ 縦の器 `PaperTabStack`＝間0）。⚠ 画面の縦の間（`SectionGap`）を1つ減らす。
			var layout: Node = header.get_parent()
			var stack: VBoxContainer = VBoxContainer.new()
			stack.name = "HeaderStack"
			stack.theme_type_variation = &"PaperTabStack"
			layout.add_child(stack)
			layout.move_child(stack, header.get_index())
			header.reparent(stack, false)
			stack.add_child(tabs)
		else:
			screen.add_child(tabs)
		bar._tabs = tabs
	screen.add_child(bar)
	bar.set_facilities(visible_facilities(), TRAINING if is_training_tab(active_id) else active_id)
	return bar


var _content: Control = null
var _entries: Dictionary = {}  # id -> entry
var _tabs: PaperTabs = null  # ⚠ 育成の部屋のタブ（⚠ 育成の仲間の画面だけ）

const META_ROOM_IDS: StringName = &"room_ids"


# ⚠ 部屋のタブでいま開いている部屋の ID（⚠ 検査用）。
static func room_id_of(tabs: PaperTabs) -> String:
	if tabs == null or not tabs.has_meta(META_ROOM_IDS):
		return ""
	var ids: Array = tabs.get_meta(META_ROOM_IDS)
	return str(ids[tabs.current]) if tabs.current < ids.size() else ""


func _ready() -> void:
	super._ready()
	var height: float = float(get_theme_constant(&"height", THEME_TYPE))
	var covered: float = height
	if _tabs != null:
		# ⚠ 育成の仲間の画面では帯を細くする（⚠ 部屋のタブが見出しの下で場所を取るぶん）。
		#   ⚠ 中身の高さを削ると、⚠ 育成の身上書と「ビルド」の行が裏に隠れた（10-07 の絵）。
		height = float(get_theme_constant(&"group_height", THEME_TYPE))
		custom_minimum_size.y = height
		_tabs.tab_changed.connect(_on_room_tab_changed)
		if _tabs.get_parent() == get_parent():
			# ⚠ 見出しの無い画面（逃げ道）：⚠ 帯のすぐ上に置く。
			var tabs_height: float = float(get_theme_constant(&"height", SUB_THEME_TYPE))
			_tabs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			_tabs.offset_top = -height - tabs_height
			_tabs.offset_bottom = -height
			covered = height + tabs_height
		else:
			covered = height
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -height
	if _content != null:
		_content.offset_bottom = -covered
		# ⚠ 中身が帯のぶん入りきらないとき、⚠ 上へ伸びると見出しと「戻る」がずれて右上の通貨と重なる
		#   （⚠ 回UI-3 の絵：育成の一覧が検証用3人ぶん長い）。⚠ **下（帯の裏）へだけ伸ばす**。
		_content.grow_vertical = Control.GROW_DIRECTION_END
	facility_pressed.connect(_on_facility_pressed)
	# ⚠ しおり紐（2026-10-07・人間「⚠ Aはしおり的な奴がUIテストにあるのでそれを」）：⚠ 用事がある施設に。⚠ 状態が変わったら引き直す。
	refresh_attention()
	GameManager.pending_chests_changed.connect(_on_state_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(refresh_attention)
	GameManager.research_node_unlocked.connect(_on_state_changed_str)
	GameManager.character_growth_changed.connect(_on_state_changed_str)
	GameManager.shop_changed.connect(_on_state_changed_str)
	GameManager.inventory_changed.connect(_on_state_changed_str)


# ⚠⚠ 用事がある施設（⚠ 判定は全部 GameManager の口＝ここに2本目を書かない）。
#   ⚠ 本部＝届いた宝箱 ／ 育成（キャラ）＝昇級できる人がいる ／ 鍛冶場＝作業場の品が完成 ／ 持ち物＝NEW の品
#   ／ 研究＝解放できる ／ ショップ＝品揃えが替わってまだ見ていない。⚠ 掲示板・編成・記録は出さない。
#   ⚠ 帯の「育成」は中のタブのどれかに用事があれば出す（`facility_attention()`）。
static func attention_of(id: String) -> bool:
	match id:
		HQ:
			return GameManager.get_pending_chest_count() > 0
		TRAINING:
			for raw: Variant in GameManager.get_party_candidates():
				if GameManager.can_level_up_now(str(raw)):
					return true
			return false
		FORGE:
			return GameManager.has_completed_craft()
		BELONGINGS:
			return GameManager.has_new_items()
		RESEARCH:
			return GameManager.has_unlockable_research()
		SHOP:
			return not GameManager.is_shop_line_up_seen()
	return false


# ⚠ 帯の1つ（⚠ 「育成」は中の開けるタブをまとめて見る）。
static func facility_attention(id: String) -> bool:
	if id != TRAINING:
		return attention_of(id)
	for entry: Dictionary in visible_training_tabs():
		if attention_of(str(entry.get(ENTRY_ID, ""))):
			return true
	return false


func refresh_attention() -> void:
	for id: String in _entries:
		set_attention(id, facility_attention(id))
	if _tabs != null and _tabs.has_meta(META_ROOM_IDS):
		var ids: Array = _tabs.get_meta(META_ROOM_IDS)
		for i: int in range(ids.size()):
			_tabs.set_attention(i, attention_of(str(ids[i])))


# ⚠ 検査用：⚠ 育成の部屋のタブ（⚠ 無ければ null）。
func training_tabs_bar() -> PaperTabs:
	return _tabs


func _on_state_changed_int(_value: int) -> void:
	refresh_attention()


func _on_state_changed_str(_value: String) -> void:
	refresh_attention()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	refresh_attention()


func set_facilities(entries: Array[Dictionary], active_id: String = "") -> void:
	_entries.clear()
	for entry: Dictionary in entries:
		_entries[str(entry.get(ENTRY_ID, ""))] = entry
	super.set_facilities(entries, active_id)
	refresh_attention()


func _on_facility_pressed(id: String) -> void:
	var entry: Dictionary = _entries.get(id, {})
	var path: String = training_path() if id == TRAINING else str(entry.get(KEY_PATH, ""))
	_go(id, path, entry.get(KEY_DATA, {}))


func _on_room_tab_changed(index: int) -> void:
	var ids: Array = _tabs.get_meta(META_ROOM_IDS) if _tabs != null and _tabs.has_meta(META_ROOM_IDS) else []
	if index >= 0 and index < ids.size():
		_on_tab_pressed(str(ids[index]))


func _on_tab_pressed(id: String) -> void:
	for entry: Dictionary in visible_training_tabs():
		if str(entry.get(ENTRY_ID, "")) == id:
			_go(id, str(entry.get(KEY_PATH, "")), entry.get(KEY_DATA, {}))
			return
	push_warning("[BaseFacilityBar] 開けない育成のタブ: " + id)


func _go(id: String, path: String, data: Dictionary) -> void:
	if path == "":
		push_warning("[BaseFacilityBar] 行き先の無い施設: " + id)
		return
	if data.is_empty():
		SceneManager.change_scene(path)
	else:
		SceneManager.change_scene_with_data(path, data)
