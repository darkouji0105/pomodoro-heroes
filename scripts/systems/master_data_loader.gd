class_name MasterDataLoader
extends RefCounted

# 4 つの JSON を読み込み、ID で引けるようにする静的クラス。
# Autoload にはしない（5 つ固定ルール。EXEC §2）。
# 戦闘中しか呼ばれない想定。

# 読み込み方式:
#   1) load() 方式: Godot 4 は .json を JSON リソースとしてインポートするため、
#      load(path) as JSON の .data で Dictionary が取れる（これを最初に試す）
#   2) FileAccess 方式: 上記が null の場合のみ FileAccess.open() + JSON.parse_string()
# どちらで動いたかは _load_mode に記録し、IMPL_LOG に書く。
# EXPORT 時に .json を含めるフィルタ設定が必要か人間が決めるため。

const DIR_PATH: String = "res://resources/balance/master/"

const PATH_CHARACTERS: String = DIR_PATH + "characters.json"
const PATH_ENEMIES: String = DIR_PATH + "enemies.json"
const PATH_PARTIES: String = DIR_PATH + "parties.json"
const PATH_STAGES: String = DIR_PATH + "stages.json"
const PATH_SKILLS: String = DIR_PATH + "skills.json"

static var _load_mode: String = ""     # "load" or "file_access" or ""（未試行）
static var _cache_characters: Dictionary = {}
static var _cache_enemies: Dictionary = {}
static var _cache_parties: Dictionary = {}
static var _cache_stages: Dictionary = {}
static var _cache_skills: Dictionary = {}
static var _cache_loaded: bool = false


static func get_character(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_characters.has(id):
		push_error("[MasterDataLoader] character id not found: " + id)
		return {}
	return (_cache_characters[id] as Dictionary).duplicate(true)


static func get_enemy(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_enemies.has(id):
		push_error("[MasterDataLoader] enemy id not found: " + id)
		return {}
	return (_cache_enemies[id] as Dictionary).duplicate(true)


static func get_party(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_parties.has(id):
		push_error("[MasterDataLoader] party id not found: " + id)
		return {}
	return (_cache_parties[id] as Dictionary).duplicate(true)


static func get_stage(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_stages.has(id):
		push_error("[MasterDataLoader] stage id not found: " + id)
		return {}
	return (_cache_stages[id] as Dictionary).duplicate(true)


# 4 ファイルまとめて読み込み、static cache に乗せる。
# 最初のファイルが load() で取れなければ、以降は全部 FileAccess 方式で読む。
static func _ensure_loaded() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	_cache_characters = _load_json(PATH_CHARACTERS)
	_cache_enemies = _load_json(PATH_ENEMIES)
	_cache_parties = _load_json(PATH_PARTIES)
	_cache_stages = _load_json(PATH_STAGES)
	_cache_skills = _load_json(PATH_SKILLS)


# load() を試し、null なら FileAccess にフォールバック。
static func _load_json(path: String) -> Dictionary:
	# 第1試行: load() 方式
	if _load_mode == "" or _load_mode == "load":
		var res: JSON = load(path) as JSON
		if res != null and res.data is Dictionary:
			_load_mode = "load"
			return (res.data as Dictionary).duplicate(true)
		# load() で取れなかった理由をログ
		if res == null:
			print("[MasterDataLoader] load() returned null for: " + path + " — falling back to FileAccess")
		else:
			print("[MasterDataLoader] load() returned non-Dictionary for: " + path + " — falling back to FileAccess")
		_load_mode = "file_access"
	# 第2試行: FileAccess 方式
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[MasterDataLoader] FileAccess.open failed: " + path + " err=" + str(FileAccess.get_open_error()))
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("[MasterDataLoader] JSON.parse_string failed: " + path)
		return {}
	return (parsed as Dictionary).duplicate(true)


# ========================================================================
# スキル関連（EXEC §2）。既存関数には触らず、末尾に追記。
# 既存4ファイルと同じタイミングでロードされる（_ensure_loaded() の末尾で
# 一緒に _cache_skills を埋める）。
# ========================================================================

static func get_skill(skill_id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_skills.has(skill_id):
		push_error("[MasterDataLoader] skill id not found: " + skill_id)
		return {}
	return (_cache_skills[skill_id] as Dictionary).duplicate(true)


# ========================================================================
# ステージ並び順（EXEC §3）。既存関数・定数・static var には一切触らず、
# 末尾追記だけで完結させる（PRE_PLAN §8-2 準拠）。
# GDScript は const / static var の宣言を関数のあとに書ける。
# ========================================================================

const PATH_STAGE_ORDER: String = DIR_PATH + "stage_order.json"

static var _cache_stage_order: Dictionary = {}
static var _stage_order_loaded: bool = false


static func get_stage_order(mode: String) -> Array:
	# 遅延ロード。_ensure_loaded() には組み込まない（この関数だけが独立して動く形にする）
	if not _stage_order_loaded:
		_stage_order_loaded = true
		_cache_stage_order = _load_json(PATH_STAGE_ORDER)
	if not _cache_stage_order.has(mode):
		push_error("[MasterDataLoader] stage_order mode not found: " + mode)
		return []
	var order: Variant = _cache_stage_order[mode]
	if not (order is Array):
		push_error("[MasterDataLoader] stage_order['" + mode + "'] is not Array: " + str(order))
		return []
	return (order as Array).duplicate(true)


# ========================================================================
# 研究ノード（EXEC_GUILD_RESEARCH.md §5-2）。既存関数・定数・static var には
# 一切触らず、末尾追記だけで完結させる。
# get_stage_order() と同じく _ensure_loaded() には組み込まず、遅延ロードする。
# 研究画面と GameManager._sync_research_tree_from_master() からのみ呼ばれる。
# ========================================================================

const PATH_RESEARCH: String = DIR_PATH + "research.json"

static var _cache_research: Dictionary = {}
static var _research_loaded: bool = false


static func get_research_node(node_id: String) -> Dictionary:
	_ensure_research_loaded()
	if not _cache_research.has(node_id):
		push_error("[MasterDataLoader] research node id not found: " + node_id)
		return {}
	return (_cache_research[node_id] as Dictionary).duplicate(true)


# ノード定義を全件返す。GameManager が research_tree へ流し込むために使う。
# キー一覧を返す関数が無いと、呼び出し側でノードIDを決め打ちすることになるため用意する
# （training_screen.gd の CHARACTER_IDS と同じ問題を繰り返さない）。
static func get_all_research_nodes() -> Dictionary:
	_ensure_research_loaded()
	return _cache_research.duplicate(true)


static func _ensure_research_loaded() -> void:
	if _research_loaded:
		return
	_research_loaded = true
	_cache_research = _load_json(PATH_RESEARCH)


# ========================================================================
# ショップのラインナップ（EXEC_GUILD_SHOP.md §5-2）。既存関数・定数・static var には
# 一切触らず、末尾追記だけで完結させる。
# get_research_node() と同じく _ensure_loaded() には組み込まず、遅延ロードする。
#
# shop.json の形： { "daily": [ {slot_id, item_id, cost{...}, ...}, ... ] }
# 他の4ファイルと違い、値が Dictionary ではなく Array であることに注意。
# ========================================================================

const PATH_SHOP: String = DIR_PATH + "shop.json"

static var _cache_shop: Dictionary = {}
static var _shop_loaded: bool = false


# 指定したショップ種別のスロット定義を返す。定義が無ければ空配列。
static func get_shop_slots(shop_type: String) -> Array:
	_ensure_shop_loaded()
	if not _cache_shop.has(shop_type):
		push_error("[MasterDataLoader] shop type not found: " + shop_type)
		return []
	var slots: Variant = _cache_shop[shop_type]
	if not (slots is Array):
		push_error("[MasterDataLoader] shop['" + shop_type + "'] is not Array: " + str(slots))
		return []
	return (slots as Array).duplicate(true)


# shop.json に定義されているショップ種別を全て返す。
# GameManager がラインナップを流し込むときに使う。
# 種別を決め打ちさせないために用意する（get_all_research_nodes() と同じ理由）。
static func get_all_shop_types() -> Array:
	_ensure_shop_loaded()
	var types: Array = []
	for shop_type: Variant in _cache_shop:
		types.append(str(shop_type))
	return types


static func _ensure_shop_loaded() -> void:
	if _shop_loaded:
		return
	_shop_loaded = true
	_cache_shop = _load_json(PATH_SHOP)
