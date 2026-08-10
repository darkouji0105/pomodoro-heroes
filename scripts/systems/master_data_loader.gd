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
