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
	# skills.json は自由度が高いぶん「書けるが壊れている」組み合わせが増えた。
	# resolver 側だけで防ぐと実戦で撃つまで気づけないので、読んだ直後に全件見る
	# （PLAN_SKILL_TEMPLATE.md 5-4）。characters.json も読み終わっているので、
	# 射程と attack_range のクロス検証もここでできる。
	# ⚠ _cache_characters を読むので、この行は _ensure_loaded() の最終行であること。
	_validate_all_skills()


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



# ========================================================================
# アイテム台帳・レシピ関連（EXEC_GUILD_WORKSHOP.md §5-1）。既存関数には触らず、末尾に追記。
#
# get_shop_slots() と同じく _ensure_loaded() には組み込まず、遅延ロードする。
#
# items.json の形：   { "items":   [ {item_id, storage, item_type, sort_order}, ... ] }
# recipes.json の形： { "recipes": [ {recipe_id, duration_sec, inputs[], outputs[], ...}, ... ] }
#
# どちらも JSON 側は Array だが、ここで item_id / recipe_id をキーにした
# Dictionary へ組み替えて返す。呼び出し側が毎回 for で探さなくて済むようにするため。
# ========================================================================

const PATH_ITEMS: String = DIR_PATH + "items.json"
const PATH_RECIPES: String = DIR_PATH + "recipes.json"

static var _cache_items: Dictionary = {}
static var _items_loaded: bool = false
static var _cache_recipes: Dictionary = {}
static var _recipes_loaded: bool = false


# アイテムIDの定義を返す。未登録なら空 Dictionary。
# 「そのIDが素材なのかインベントリ品なのか」を知っているのはこの台帳だけ。
static func get_item(item_id: String) -> Dictionary:
	_ensure_items_loaded()
	if not _cache_items.has(item_id):
		return {}
	return (_cache_items[item_id] as Dictionary).duplicate(true)


# item_id -> 定義 の Dictionary を返す。
static func get_all_items() -> Dictionary:
	_ensure_items_loaded()
	return _cache_items.duplicate(true)


# レシピ定義を返す。未登録なら空 Dictionary。
static func get_recipe(recipe_id: String) -> Dictionary:
	_ensure_recipes_loaded()
	if not _cache_recipes.has(recipe_id):
		return {}
	return (_cache_recipes[recipe_id] as Dictionary).duplicate(true)


# recipe_id -> 定義 の Dictionary を返す。
# GameManager がレシピを状態へ流し込むときに使う（get_all_research_nodes() と同じ役割）。
static func get_all_recipes() -> Dictionary:
	_ensure_recipes_loaded()
	return _cache_recipes.duplicate(true)


static func _ensure_items_loaded() -> void:
	if _items_loaded:
		return
	_items_loaded = true
	_cache_items = _index_by(_load_json(PATH_ITEMS), "items", "item_id", PATH_ITEMS)


static func _ensure_recipes_loaded() -> void:
	if _recipes_loaded:
		return
	_recipes_loaded = true
	_cache_recipes = _index_by(_load_json(PATH_RECIPES), "recipes", "recipe_id", PATH_RECIPES)


# { list_key: [ {id_key: "...", ...}, ... ] } を { "...": {...} } へ組み替える。
# id が無い要素・重複した id はログを出して捨てる。
# 黙って上書きすると、レシピを増やしたときに片方だけ消えて原因が分からなくなる。
static func _index_by(root: Dictionary, list_key: String, id_key: String, path: String) -> Dictionary:
	var result: Dictionary = {}
	if root.is_empty():
		push_error("[MasterDataLoader] empty or unreadable: " + path)
		return result
	var list: Variant = root.get(list_key, [])
	if not (list is Array):
		push_error("[MasterDataLoader] '" + list_key + "' is not Array: " + path)
		return result
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			push_error("[MasterDataLoader] non-Dictionary entry in " + path)
			continue
		var definition: Dictionary = entry
		var id: String = str(definition.get(id_key, ""))
		if id == "":
			push_error("[MasterDataLoader] entry without " + id_key + " in " + path)
			continue
		if result.has(id):
			push_error("[MasterDataLoader] duplicated " + id_key + " '" + id + "' in " + path)
			continue
		result[id] = definition
	print("[MasterDataLoader] loaded %d entries from %s" % [result.size(), path])
	return result


# ========================================================================
# ステータスノード（EXEC_LEVEL_ROLE_SHIFT.md §5-2）。既存関数・定数・static var には
# 一切触らず、末尾追記だけで完結させる。
# get_research_node() と同じく _ensure_loaded() には組み込まず、遅延ロードする。
#
# character_nodes.json の形：
#   { node_id: {character_id, stat, tier, cost, value, prerequisites[]} }
# research.json と同じく node_id をキーにした Dictionary。_index_by() は要らない。
#
# ⚠ 数値（tier / cost / value）は float で来る。呼び出し側で int() を付けること。
# ========================================================================

const PATH_CHARACTER_NODES: String = DIR_PATH + "character_nodes.json"

static var _cache_character_nodes: Dictionary = {}
static var _character_nodes_loaded: bool = false


static func get_character_node(node_id: String) -> Dictionary:
	_ensure_character_nodes_loaded()
	if not _cache_character_nodes.has(node_id):
		push_error("[MasterDataLoader] character node id not found: " + node_id)
		return {}
	return (_cache_character_nodes[node_id] as Dictionary).duplicate(true)


# ノード定義を全件返す。GameManager がボーナスを合計するときと、
# 画面が枝を組み立てるときに使う。
# キー一覧を返す関数が無いと呼び出し側でノードIDを決め打ちすることになるため用意する
# （get_all_research_nodes() と同じ理由）。
static func get_all_character_nodes() -> Dictionary:
	_ensure_character_nodes_loaded()
	return _cache_character_nodes.duplicate(true)


static func _ensure_character_nodes_loaded() -> void:
	if _character_nodes_loaded:
		return
	_character_nodes_loaded = true
	_cache_character_nodes = _load_json(PATH_CHARACTER_NODES)
	print("[MasterDataLoader] loaded %d entries from %s" % [
		_cache_character_nodes.size(), PATH_CHARACTER_NODES
	])


# ========================================================================
# スキルのロード時検証（EXEC_SKILL_TEMPLATE_PHASE1.md §8）。
# 器が4軸（activation / target / effects[]）になり、「書けるが壊れている」
# 組み合わせが増えた。resolver 側だけの防御にすると実戦で撃つまで分からないので、
# 読んだ直後に全件見る（PLAN_SKILL_TEMPLATE.md 5-4）。
#
# ⚠ 検証が走るのは「最初にマスターデータを引いたとき」であって、ゲームの起動直後
#   ではない。GameManager._ready() は research / shop / recipes の別キャッシュしか
#   触らないため、_ensure_loaded() は育成画面か戦闘画面に入って初めて動く。
# ========================================================================

# skills.json のエントリを全件返す。get_all_research_nodes() と同じ形。
static func get_all_skills() -> Dictionary:
	_ensure_loaded()
	return _cache_skills.duplicate(true)


static func _validate_all_skills() -> void:
	var error_count: int = 0
	var warning_count: int = 0
	for skill_id: Variant in _cache_skills:
		var entry: Variant = _cache_skills[skill_id]
		var data: Dictionary = (entry as Dictionary) if entry is Dictionary else {}
		for issue: Variant in SkillSchema.validate(str(skill_id), data):
			if not (issue is Dictionary):
				continue
			var message: String = "[MasterDataLoader] skills.json " + str((issue as Dictionary).get("message", ""))
			if str((issue as Dictionary).get("level", "")) == SkillSchema.LEVEL_ERROR:
				error_count += 1
				push_error(message)
			else:
				warning_count += 1
				push_warning(message)
		# 射程 × 攻撃射程のクロス検証。スキル射程が通常攻撃の射程より短いと、
		# 移動AIが attack_range で止まるため足が止まって永久に撃てない（無音で死ぬ）。
		if data.has("target") and (data["target"] is Dictionary):
			var target: Dictionary = data["target"] as Dictionary
			if target.has("range"):
				var cid: String = str(data.get("user_character_id", ""))
				if _cache_characters.has(cid) and (_cache_characters[cid] is Dictionary):
					var attack_range: float = float((_cache_characters[cid] as Dictionary).get("attack_range", 0.0))
					if float(target.get("range", 0.0)) < attack_range:
						error_count += 1
						push_error("[MasterDataLoader] skills.json %s: target.range が %s の attack_range (%.1f) より短い" % [
							str(skill_id), cid, attack_range
						])

	# _load_json() は成功時に何も出さない。これが唯一の「読めた」の合図。
	print("[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings" % [
		_cache_skills.size(), error_count, warning_count
	])
