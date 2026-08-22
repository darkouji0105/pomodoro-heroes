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
# 召喚ユニットの素データ（段階6・EXEC_SKILL_SPAWN.md §3-1）。
#
# ⚠ enemies.json と分けてある（人間の確認待ち・EXEC §0-1 の1）。混ぜると
#   ウェーブの enemy_type_id にも書けてしまい、どちらの用途で置かれた行なのかを
#   ロード時に判定できない。リリース後はIDを改名できないので後から分けられない。
# ⚠ エントリの形は enemies.json の1件と同じ（BattleUnit.create() が読む欄が全部そこ）。
# ⚠ skills / passives は書けない（E101）。段階6では召喚はスキルを撃たない。
const PATH_SUMMONS: String = DIR_PATH + "summons.json"
# スキルは複数ファイルに割ってある（EXEC_SKILL_MULTIFILE.md）。
#
# 【なぜ割るか】段階3の後半で購読と条件が乗ると1スキルが30〜50行になる。
# 1本にまとめたままだと4人目のキャラで500行を超え、差分が読めなくなる。
#
# ⚠ 必須と任意を分けてある。debug は「無いのが正常」（リリース前に消すもの）で、
#   無いことを警告しない。キャラ別のほうは無ければ赤（そのキャラのスキルが
#   丸ごと消え、戦闘でボタンが出なくなるが、エラーが無いと原因を追えない）。
# ⚠ キャラを増やすときはここに1行足す。ファイル名は user_character_id と
#   綴りを揃えること（機械的に対応が取れなくなる）。
# 【1キャラ＝1フォルダ】（人間の決定・2026-08-16）
#
#   characters/char_swordsman/skills.json    … そのキャラのスキル
#   characters/char_swordsman/nodes.json     … そのキャラのステータスノード
#   characters/char_swordsman/passives.json  … ⚠ パッシブを実装する回にここへ置く
#
# ⚠ 能力値（characters.json）はフォルダへ動かさない。GameManager が育成・装備・
#   研究から何度も引いており、そこを触ると挙動の話になる。フォルダは「量が多くて
#   キャラ別に閉じているもの」だけを持つ。
#
# ⚠ 走査しない。フォルダを増やしたらここに1行足す（人間の決定）。
#   DirAccess で数えると、エクスポート後の .pck でフォルダが見えるかが未検証で、
#   .json のエクスポートフィルタ自体も未決の宿題のため。
# ⚠ 足し忘れると、そのキャラのスキルとノードが無音で消える（エラーが出ない）。
const DIR_CHARACTERS: String = DIR_PATH + "characters/"

const CHARACTER_DIRS_REQUIRED: Array[String] = [
	DIR_CHARACTERS + "char_swordsman/",
	DIR_CHARACTERS + "char_archer/",
	DIR_CHARACTERS + "char_priest/",
]
# 検証用。⚠ 無いのが正常（リリース前にフォルダごと消す）。
const CHARACTER_DIRS_OPTIONAL: Array[String] = [
	DIR_CHARACTERS + "char_debug_status/",
	DIR_CHARACTERS + "char_debug_life/",
	DIR_CHARACTERS + "char_debug_mix/",
]

# 敵のスキル（EXEC_ENEMY_PARITY.md）。⚠ キャラと同じ階層・同じ形にする（人間の決定）。
#
#   enemies/enemy_dbg_react/skills.json    … その敵のスキル
#
# ⚠ 走査しない。フォルダを増やしたらここに1行足す（キャラ側と同じ罠・宿題13）。
# ⚠ 敵は nodes.json を持たない。任意扱いなので「無い」で警告は出ない。
const DIR_ENEMIES: String = DIR_PATH + "enemies/"

# ⚠ 今は空。本編の敵（enemy_slime など）にスキルを載せたらここに1行足す。
#   足し忘れると、その敵のスキルが無音で消える（エラーが出ない）。
const ENEMY_DIRS_REQUIRED: Array[String] = []

# 検証用。⚠ 無いのが正常（リリース前にフォルダごと消す）。
const ENEMY_DIRS_OPTIONAL: Array[String] = [
	DIR_ENEMIES + "enemy_dbg_react/",
	DIR_ENEMIES + "enemy_dbg_followup/",
	DIR_ENEMIES + "enemy_dbg_buff/",
	DIR_ENEMIES + "enemy_dbg_dot/",
	DIR_ENEMIES + "enemy_dbg_heal/",
	DIR_ENEMIES + "enemy_dbg_ranged/",
	DIR_ENEMIES + "enemy_dbg_cond/",
	# 介入点3種（EXEC_SKILL_INTERVENTION.md）
	DIR_ENEMIES + "enemy_dbg_revive/",
	DIR_ENEMIES + "enemy_dbg_immune/",
	DIR_ENEMIES + "enemy_dbg_recv/",
]

static var _load_mode: String = ""     # "load" or "file_access" or ""（未試行）
static var _cache_characters: Dictionary = {}
static var _cache_enemies: Dictionary = {}
static var _cache_parties: Dictionary = {}
static var _cache_stages: Dictionary = {}
static var _cache_summons: Dictionary = {}
static var _cache_skills: Dictionary = {}
static var _cache_loaded: bool = false


static func get_character(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_characters.has(id):
		push_error("[MasterDataLoader] character id not found: " + id)
		return {}
	return (_cache_characters[id] as Dictionary).duplicate(true)


# character_id -> 定義 の Dictionary を返す（編成の候補・EXEC_PARTY_MEMBERS.md）。
#
# ⚠ 並び順は characters.json の記述順（Godot 4 の Dictionary は挿入順を保つ）。
#   順が乱れると、編成の候補が押すたびに入れ替わって見える。
# ⚠ get_all_items() と同じ形にしてある。2本目の書き方を作らないこと。
static func get_all_characters() -> Dictionary:
	_ensure_loaded()
	return _cache_characters.duplicate(true)


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


# 召喚ユニットの素データ（段階6）。⚠ get_enemy() と同じ形にしてある。
static func get_summon(id: String) -> Dictionary:
	_ensure_loaded()
	if not _cache_summons.has(id):
		push_error("[MasterDataLoader] summon id not found: " + id)
		return {}
	return (_cache_summons[id] as Dictionary).duplicate(true)


# ⚠ ロード時検証（E100）から呼ぶ。get_summon() を使うと、無いIDのたびに
#   push_error が2本出る（検証の赤と getter の赤）。
static func has_summon(id: String) -> bool:
	_ensure_loaded()
	return _cache_summons.has(id)


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
	# ⚠ _validate_all_skills() より前に読むこと。E100（summon の unit_id が
	#   summons.json に無い）のクロス検証がこのキャッシュを見る。
	_cache_summons = _load_json(PATH_SUMMONS)
	_cache_skills = _load_character_files("skills.json", "スキル")
	# スキルは自由度が高いぶん「書けるが壊れている」組み合わせが増えた。
	# resolver 側だけで防ぐと実戦で撃つまで気づけないので、読んだ直後に全件見る
	# （PLAN_SKILL_TEMPLATE.md 5-4）。characters.json も読み終わっているので、
	# 射程と attack_range のクロス検証もここでできる。
	# ⚠ _cache_characters を読むので、この行は _ensure_loaded() の最終行であること。
	_validate_all_skills()
	# ⚠ 通常攻撃も同じタイミングで見る。スキルと違って「撃てない」が無音なので
	#   （攻撃間隔だけ回って何も起きない）、ロード時に言わないと気づけない。
	_validate_all_basic_attacks()
	# ⚠ 召喚は通常攻撃しか撃たないので、basic_attack の検証と同じ列に並べる。
	_validate_all_summons()
	# ⚠ 素材・アイテムIDのクロス検証（E118）。改名漏れが「加算が黙って消える」形で
	#   出るため、ロード時に言わないと実機でも気づけない。
	_validate_all_item_refs()


# マスターが参照する item_id / material_id が items.json に在るかを見る（E118）。
#
# ⚠ この器は素材を3件から12件へ増やした回（EXEC_MATERIAL_TIERS.md）で足した。
#   それまで items.json への参照は1件も検証されておらず、IDを改名すると
#   「装備は外れないが加算されない」「報酬が黙って落ちる」形で無音に壊れていた
#   （game_manager.gd の get_instance_stats() のコメントが名指ししている問題）。
#
# ⚠ 見るのは stages / shop / research / recipes の4ファイル。
#   initial_state_config.tres は .tres でマスターではないため、ここでは見ない。
#
# ⚠ 同じIDが複数箇所から参照されていれば、その数だけ赤を出す。重複を潰さない。
#   潰すと「どのファイルのどの行で漏れたか」が消える（_validate_all_skills と同じ方針）。
static func _validate_all_item_refs() -> void:
	_ensure_items_loaded()
	_ensure_shop_loaded()
	_ensure_research_loaded()
	_ensure_recipes_loaded()

	var errors: int = 0

	# stages.json … rewards.materials のキー
	for stage_id: Variant in _cache_stages:
		var stage: Variant = _cache_stages[stage_id]
		if not (stage is Dictionary):
			continue
		var rewards: Variant = (stage as Dictionary).get("rewards", {})
		if not (rewards is Dictionary):
			continue
		var materials: Variant = (rewards as Dictionary).get("materials", {})
		if not (materials is Dictionary):
			continue
		for material_id: Variant in (materials as Dictionary):
			errors += _report_missing_item(str(material_id), "stages.json", str(stage_id))

	# shop.json … 各枠の item_id
	for shop_type: Variant in _cache_shop:
		var slots: Variant = _cache_shop[shop_type]
		if not (slots is Array):
			continue
		for slot: Variant in (slots as Array):
			if not (slot is Dictionary):
				continue
			errors += _report_missing_item(
				str((slot as Dictionary).get("item_id", "")),
				"shop.json",
				"%s slot %s" % [str(shop_type), str((slot as Dictionary).get("slot_id", "?"))]
			)

	# research.json … cost_material_id
	for node_id: Variant in _cache_research:
		var node: Variant = _cache_research[node_id]
		if not (node is Dictionary):
			continue
		errors += _report_missing_item(
			str((node as Dictionary).get("cost_material_id", "")),
			"research.json",
			str(node_id)
		)

	# recipes.json … inputs / outputs
	for recipe_id: Variant in _cache_recipes:
		var recipe: Variant = _cache_recipes[recipe_id]
		if not (recipe is Dictionary):
			continue
		for list_key: String in ["inputs", "outputs"]:
			var list: Variant = (recipe as Dictionary).get(list_key, [])
			if not (list is Array):
				continue
			for io: Variant in (list as Array):
				if not (io is Dictionary):
					continue
				errors += _report_missing_item(
					str((io as Dictionary).get("item_id", "")),
					"recipes.json",
					"%s.%s" % [str(recipe_id), list_key]
				)

	print("[MasterDataLoader] items validated: %d entries, %d errors" % [_cache_items.size(), errors])


# E118 … 参照先が items.json に無い。1件につき1本。
# ⚠ 空文字は「欄そのものが無い」であって改名漏れではないため、ここでは見ない
#   （欄の有無はそれぞれの画面が既に弾いている）。
static func _report_missing_item(item_id: String, where: String, context: String) -> int:
	if item_id == "":
		return 0
	if _cache_items.has(item_id):
		return 0
	push_error("[MasterDataLoader] E118 %s (%s): items.json に無いID: %s" % [where, context, item_id])
	return 1


# 召喚ユニットの素データの検証（段階6・E101）。
#
# ⚠ 正常系では1行も出さない（print を増やさない・NEXT_STEPS §5）。
# ⚠ 10軸や basic_attack の中身はここで見ない。前者は BattleUnit.create() が
#   欠けを push_warning で言い、後者は _validate_all_basic_attacks() が見る。
static func _validate_all_summons() -> void:
	for summon_id: Variant in _cache_summons:
		var entry: Variant = _cache_summons[summon_id]
		if not (entry is Dictionary):
			push_error("[MasterDataLoader] summons %s: エントリが Dictionary でない" % str(summon_id))
			continue
		# E101 … 書けてしまうと無音で無視され、「持たせたのに撃たない」を
		#        実機で追うことになる（段階6では召喚はスキルを撃たない）。
		for forbidden: String in ["skills", GameManager.CHARACTER_PASSIVES]:
			if (entry as Dictionary).has(forbidden):
				push_error("[MasterDataLoader] summons %s: '%s' は書けない（段階6では召喚はスキルを撃たない）" % [
					str(summon_id), forbidden
				])


# キャラのフォルダから同じ名前のファイルを集めて1つの辞書にまとめる。
#
# ⚠ スキルもノードもこの1本を通す。同じ形のマージを2本書くと、重複IDの扱いや
#   「無いファイル」の扱いが片方だけ変わる。
# ⚠ 中身の検証はここでやらない。_validate_all_skills() が1箇所で全件見る
#   （マージの都合で検証が2箇所に分かれると、片方だけ直す事故になる）。
static func _load_character_files(file_name: String, what: String) -> Dictionary:
	var merged: Dictionary = {}
	for dir_path: String in CHARACTER_DIRS_REQUIRED:
		_merge_id_map(merged, dir_path + file_name, true, what)
	# ⚠ 検証用キャラは nodes.json を持たない。だから「無い」を正常系にしてある。
	for dir_path: String in CHARACTER_DIRS_OPTIONAL:
		_merge_id_map(merged, dir_path + file_name, false, what)
	# 敵も同じ辞書へ入れる（EXEC_ENEMY_PARITY.md §3-1）。
	# ⚠ 敵用に2本目のマージを書かないこと。味方と敵でスキルIDが重複したときに
	#   赤で弾く挙動が、片方だけ効く形になる。
	# ⚠ 敵は nodes.json を持たないが、任意扱いなので「無い」で警告は出ない。
	for dir_path: String in ENEMY_DIRS_REQUIRED:
		_merge_id_map(merged, dir_path + file_name, true, what)
	for dir_path: String in ENEMY_DIRS_OPTIONAL:
		_merge_id_map(merged, dir_path + file_name, false, what)
	return merged


# 1ファイルぶんを merged へ足す。required が false なら「無い」を正常系として扱う。
#
# ⚠ 重複IDは赤で弾き、先に読んだほうを残す。何もしないと「あとから読んだほうが
#   黙って勝つ」形になり、同じIDを2ファイルに書いた事故が実戦まで表面化しない。
static func _merge_id_map(merged: Dictionary, path: String, required: bool, what: String) -> void:
	# ⚠ 先に存在を見る。_load_json() は無いファイルに対して赤を出すので、
	#   任意のファイルをそのまま渡すと「消したら赤が出る」ことになる。
	# ⚠ load() 方式のときは .import 経由なので ResourceLoader でしか見えない。
	#   FileAccess だけで見ると、書き出し後のビルドで「無い」と誤判定しうる。
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		if required:
			push_error("[MasterDataLoader] %s のファイルが無い: %s" % [what, path])
		return

	var one: Dictionary = _load_json(path)
	for entry_id: Variant in one:
		if merged.has(entry_id):
			push_error("[MasterDataLoader] %s のIDが2つのファイルに重複: '%s'（%s）。先に読んだほうを残す" % [
				what, str(entry_id), path
			])
			continue
		merged[entry_id] = one[entry_id]


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
# characters/<character_id>/nodes.json の形：
#   { node_id: {character_id, stat, tier, cost, value, prerequisites[]} }
# research.json と同じく node_id をキーにした Dictionary。_index_by() は要らない。
#
# ⚠ フォルダで分けたあとも、各エントリは character_id を持ったままにしてある。
#   置き場と中身の二重管理になるが、GameManager 側が character_id で絞っており、
#   消すと呼び出し側の書き換えまで波及する（今回は挙動を変えない）。
#
# ⚠ 数値（tier / cost / value）は float で来る。呼び出し側で int() を付けること。
#
# ⚠ いつ読まれるか（2026-08-16・呼び出し元を全部たどって確認）
#   ・get_all_character_nodes() … stat_node_screen.gd だけ＝割り振り画面を開いたとき
#   ・get_character_node() … GameManager の4箇所。どれも
#     `for node_id in get_stat_nodes(character_id)` の中なので、
#     ⚠ 解放済みノードが0件のセーブでは1回も呼ばれない
#   したがって「つづきから」では出ない（スキルは _ensure_loaded() に
#   組み込んであるので出る。⚠ 2つは別のキャッシュ・別のタイミング）。
#   完了条件にこのログを書くときは「割り振り画面を開く」まで書くこと。
# ========================================================================

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
	# ⚠ スキルと同じマージを通す。件数は合計のまま1本に保つ（完了条件に使えるため）。
	_cache_character_nodes = _load_character_files("nodes.json", "ステータスノード")
	print("[MasterDataLoader] loaded %d character nodes from %s*/nodes.json" % [
		_cache_character_nodes.size(), DIR_CHARACTERS
	])


# ========================================================================
# スキルのロード時検証（EXEC_SKILL_TEMPLATE_PHASE1.md §8）。
# 器が4軸（activation / target / effects[]）になり、「書けるが壊れている」
# 組み合わせが増えた。resolver 側だけの防御にすると実戦で撃つまで分からないので、
# 読んだ直後に全件見る（PLAN_SKILL_TEMPLATE.md 5-4）。
#
# ⚠ 検証が走るのは「最初にマスターデータを引いたとき」であって、ゲームの起動直後
#   ではない。GameManager._ready() は research / shop / recipes の別キャッシュしか
#   触らない。
#
# ⚠ ただし「つづきから」では、その時点で走る（2026-08-16・実機で確認）。
#   経路は GameManager.load_state() → _resync_growth_stats_from_master()
#         → _recalc_stats() → get_character() → _ensure_loaded()。
#   ⚠ 回るのは character_growth のエントリぶんなので、育成データが1件も無い
#     セーブでは呼ばれず、育成画面か戦闘画面に入るまで出ない。
#   完了条件に「ロード時のログ」を書くときは、どちらのセーブで見るかまで書くこと。
# ========================================================================

# スキルのエントリを全件返す（マージ後）。get_all_research_nodes() と同じ形。
static func get_all_skills() -> Dictionary:
	_ensure_loaded()
	return _cache_skills.duplicate(true)


# characters.json と enemies.json の "basic_attack" を全件見る。
#
# ⚠ 味方と敵をまとめて回す。片方だけ検証する形にすると、敵に通常攻撃を
#   書き忘れたときだけ無音になる（敵は殴ってこないだけで、エラーが出ない）。
static func _validate_all_basic_attacks() -> void:
	var error_count: int = 0
	var warning_count: int = 0
	var checked: int = 0

	for source: Dictionary in [_cache_characters, _cache_enemies]:
		for owner_id: Variant in source:
			var entry: Variant = source[owner_id]
			var data: Dictionary = (entry as Dictionary) if entry is Dictionary else {}
			var basic: Variant = data.get("basic_attack", null)
			var basic_data: Dictionary = (basic as Dictionary) if basic is Dictionary else {}
			checked += 1
			for issue: Variant in SkillSchema.validate_basic_attack(str(owner_id), basic_data):
				if not (issue is Dictionary):
					continue
				var message: String = "[MasterDataLoader] basic_attack " + str((issue as Dictionary).get("message", ""))
				if str((issue as Dictionary).get("level", "")) == SkillSchema.LEVEL_ERROR:
					error_count += 1
					push_error(message)
				else:
					warning_count += 1
					push_warning(message)

	print("[MasterDataLoader] basic attacks validated: %d entries, %d errors, %d warnings" % [
		checked, error_count, warning_count
	])


static func _validate_all_skills() -> void:
	var error_count: int = 0
	var warning_count: int = 0
	for skill_id: Variant in _cache_skills:
		var entry: Variant = _cache_skills[skill_id]
		var data: Dictionary = (entry as Dictionary) if entry is Dictionary else {}
		for issue: Variant in SkillSchema.validate(str(skill_id), data):
			if not (issue is Dictionary):
				continue
			# ⚠ ファイル名を出さない。マージ後は「どのファイルから来たか」を持っていない。
			#   skill_id は message に必ず含まれるので、grep でファイルを特定できる。
			var message: String = "[MasterDataLoader] skills " + str((issue as Dictionary).get("message", ""))
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
						push_error("[MasterDataLoader] skills %s: target.range が %s の attack_range (%.1f) より短い" % [
							str(skill_id), cid, attack_range
						])
		# 召喚のクロス検証（段階6・E100）。
		#
		# ⚠ SkillSchema 側に書けない。あちらは1スキルだけを見る静的検証で、
		#   summons.json を知らない（射程 × attack_range と同じ理由でここに置く）。
		# ⚠ 段（phases）の中の効果も見ること。phases が無いスキルでは
		#   phase_of() が data をそのまま返すので、書き方は1本で済む。
		for phase_index: int in range(SkillSchema.phase_count(data)):
			var phase: Dictionary = SkillSchema.phase_of(data, phase_index)
			var raw_effects: Variant = phase.get("effects", null)
			if not (raw_effects is Array):
				continue
			for raw_effect: Variant in (raw_effects as Array):
				if not (raw_effect is Dictionary):
					continue
				if str((raw_effect as Dictionary).get("type", "")) != SkillSchema.EFFECT_SUMMON:
					continue
				var summon_id: String = str((raw_effect as Dictionary).get("unit_id", ""))
				# 空は SkillSchema の E94 が言う。ここで2本目を出さない。
				if summon_id == "" or has_summon(summon_id):
					continue
				error_count += 1
				push_error("[MasterDataLoader] skills %s: summon の unit_id が summons.json に無い: '%s'" % [
					str(skill_id), summon_id
				])

	# _load_json() は成功時に何も出さない。これが唯一の「読めた」の合図。
	print("[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings" % [
		_cache_skills.size(), error_count, warning_count
	])
