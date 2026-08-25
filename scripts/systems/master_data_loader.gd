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
#   characters/char_swordsman/passives.json  … そのキャラのパッシブ（段階3・2026-08-25）
#
# ⚠ passives.json は skills.json と同じ辞書（_cache_skills）へマージされる。
#   戦闘は _restore_passives() → MasterDataLoader.get_skill(passive_id) を通るので、
#   別の辞書に分けると戦闘側に「パッシブ用の引き先」を足すことになる。
#   ファイルだけ分け、引き口は1本のままにする。
# ⚠ そのぶん skills.json と passives.json でIDが重複したら赤（_merge_id_map）。
# ⚠ passives.json は「無くてよい」。検証用キャラと敵は持たない。
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
	# ⚠ パッシブも同じ辞書へ入れる（EXEC_CHARACTER_PASSIVES.md §4-1）。
	#   引き口を1本に保つため、passives.json を skills.json の続きとしてマージする。
	# ⚠ 2本目のマージ関数を書かないこと。IDの重複を弾く枝が片方だけ効く形になる。
	_cache_skills = _load_character_files("skills.json", "スキル")
	# ⚠ required は false。敵と検証用キャラは passives.json を持たない。
	#   本番キャラで欠けた場合は E126 が拾う（characters.json の passives に
	#   書いてあるIDが定義されていない、という形で必ず赤になる）。
	_merge_character_files(_cache_skills, "passives.json", "パッシブ", false)
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
	# ⚠ ルーン（E123 / E124）。⚠ items.json を読み終わっている必要がある
	#   （_validate_all_item_refs() が _ensure_items_loaded() を通している）。
	#   ⚠ 刺しても何も起きないルーンは無音なので、ロード時に言うしかない。
	_validate_all_runes()


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

	# stages.json … unlocks の screen_id が存在するか（E125・段階9）。
	#
	# ⚠ 知らない screen_id を書くと「クリアしても開かない」形で無音に壊れる。
	#   ⚠ 画面IDの一覧は GameManager が持つ1本を通す（定数の並びを2箇所に書かない）。
	# ⚠ rewards の枝とは別のループにしてある。あちらは rewards を持たないステージで
	#   continue するので、相乗りすると unlocks を見落とす。
	var known_screens: Array[String] = GameManager.get_all_screen_ids()
	for stage_id: Variant in _cache_stages:
		var stage_entry: Variant = _cache_stages[stage_id]
		if not (stage_entry is Dictionary):
			continue
		if not (stage_entry as Dictionary).has(GameManager.STAGE_MASTER_UNLOCKS):
			continue
		var raw_unlocks: Variant = (stage_entry as Dictionary)[GameManager.STAGE_MASTER_UNLOCKS]
		if not (raw_unlocks is Array):
			push_error("[MasterDataLoader] E125 stages.json (%s): unlocks が Array でない" % str(stage_id))
			errors += 1
			continue
		for raw_screen_id: Variant in (raw_unlocks as Array):
			if not (str(raw_screen_id) in known_screens):
				push_error("[MasterDataLoader] E125 stages.json (%s): 知らない screen_id: '%s'" % [
					str(stage_id), str(raw_screen_id)
				])
				errors += 1

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

		# stages.json … rewards.inventory のキー（EXEC_DECORATION.md §3-G）。
		#
		# ⚠ この枝は装飾をステージから落とせるようにした回で足した。
		#   apply_battle_rewards() が rewards.inventory を読むようになったのも同じ回で、
		#   それまでは「書いても落ちない」欄だった（EXEC_DECORATION.md §1-4）。
		var inventory: Variant = (rewards as Dictionary).get("inventory", {})
		if inventory is Dictionary:
			for item_id: Variant in (inventory as Dictionary):
				errors += _report_missing_item(str(item_id), "stages.json", str(stage_id))

		# stages.json … rewards.chest_id が chests.json に在るか（E122）。
		#
		# ⚠ 抽選テーブルそのものは chests.json へ移した（EXEC_CHEST_REGISTRY.md §3-E）。
		#   ここに残るのは「どの宝箱を落とすか」の1行だけ。
		# ⚠ 指し先が無いと、勝っても宝箱が積まれない形で無音に壊れる。
		var chest_id: String = str((rewards as Dictionary).get("chest_id", ""))
		if chest_id != "" and get_chest(chest_id).is_empty():
			push_error("[MasterDataLoader] E122 stages.json (%s): chests.json に無い chest_id: %s" % [
				str(stage_id), chest_id
			])
			errors += 1

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

	# research.json … cost_material_id ＋ ボードと前提の整合（E128・段階10）。
	#
	# ⚠ E128 が見るのは「押せないノードが1件出るだけ」で赤も黄も出ずに詰む形。
	#   ⚠ GameManager._prerequisites_met() の push_warning は、解放を試した瞬間にしか出ない
	#     （＝画面に並んでいるだけでは誰も気づけない）。
	# ⚠ ループを2本に分けない。cost_material_id と同じ1本の中で見る。
	for node_id: Variant in _cache_research:
		var node: Variant = _cache_research[node_id]
		if not (node is Dictionary):
			continue
		errors += _report_missing_item(
			str((node as Dictionary).get("cost_material_id", "")),
			"research.json",
			str(node_id)
		)

		# JSON の数値は float で来る。int() を外すと比較がずれる。
		var board: int = int((node as Dictionary).get(GameManager.RESEARCH_NODE_BOARD, GameManager.RESEARCH_DEFAULT_BOARD))
		if board < 1:
			push_error("[MasterDataLoader] E128 research.json (%s): board は1以上でなければならない: %d" % [
				str(node_id), board
			])
			errors += 1

		var raw_prerequisites: Variant = (node as Dictionary).get("prerequisites", [])
		if not (raw_prerequisites is Array):
			push_error("[MasterDataLoader] E128 research.json (%s): prerequisites が Array でない" % str(node_id))
			errors += 1
			continue
		for raw_prerequisite: Variant in (raw_prerequisites as Array):
			var prerequisite_id: String = str(raw_prerequisite)
			if not _cache_research.has(prerequisite_id):
				push_error("[MasterDataLoader] E128 research.json (%s): 知らない prerequisite: '%s'" % [
					str(node_id), prerequisite_id
				])
				errors += 1
				continue
			var prerequisite: Variant = _cache_research[prerequisite_id]
			if not (prerequisite is Dictionary):
				continue
			# ⚠ 後のボードを前提にすると、そのノードは永久に解放できない
			#   （前のボードを全部解放しないと次のボードが開かないため）。
			var prerequisite_board: int = int((prerequisite as Dictionary).get(
				GameManager.RESEARCH_NODE_BOARD, GameManager.RESEARCH_DEFAULT_BOARD))
			if prerequisite_board > board:
				push_error("[MasterDataLoader] E128 research.json (%s): 前提 '%s' が後のボードにある（board %d → %d）" % [
					str(node_id), prerequisite_id, board, prerequisite_board
				])
				errors += 1

	# recipes.json … inputs / outputs（E118）＋ draw の形（E129・段階11）
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
		errors += _validate_recipe_draw(str(recipe_id), recipe as Dictionary)

	# chests.json … rewards の中身と draw の抽選テーブル（E118 / E120 / W20）。
	_ensure_chests_loaded()
	for chest_id: Variant in _cache_chests:
		var chest: Variant = _cache_chests[chest_id]
		if not (chest is Dictionary):
			continue
		errors += _validate_chest(str(chest_id), chest as Dictionary)

	# 装飾の欄そのものの検証（E119）。行を増やさず同じ1本に合流させる。
	errors += _validate_all_part_items()

	print("[MasterDataLoader] items validated: %d entries, %d errors" % [_cache_items.size(), errors])


# E119 … items.json の装飾（item_type: "part"）の欄が欠けている／不正。
#
# ⚠ 装飾は欄が5つあり、1つでも欠けると「刺さるが加算されない」形で無音に壊れる。
#   E118 を足したときと同じ判断（EXEC_DECORATION.md §0-3 の9）。
#
# ⚠ item_id と欄の綴りが一致しているかも見る。ずれると「刺さるが別の軸が上がる」になる。
#   ⚠ これは検証であって、実行時に item_id から欄を切り出すという意味ではない。
#     引くのは必ず欄のほう（EXEC_DECORATION.md §3-A）。
#
# ⚠ part_tier の上限（Balance.part.max_part_tier）はここでは見ない。
#   PartConfig はこの検証より後に用意されるため（実装を前半・後半に割っている）。
#   上限は upgrade_part() 側が持つ。
#
# ⚠ 1件ごとに1本出す。重複を潰さない（E118 と同じ方針）。
static func _validate_all_part_items() -> int:
	var errors: int = 0
	var valid_kinds: Array[String] = [
		GameManager.PART_KIND_GEM,
		GameManager.PART_KIND_CHARM,
		GameManager.PART_KIND_EMBLEM,
		GameManager.PART_KIND_RUNE,
	]
	var valid_stats: Array[String] = GameManager.get_stat_keys()

	for item_id: Variant in _cache_items:
		var entry: Variant = _cache_items[item_id]
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		if str(item.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_PART:
			continue

		var kind: String = str(item.get(GameManager.ITEM_MASTER_PART_KIND, ""))
		if not (kind in valid_kinds):
			errors += _report_part_error(str(item_id), "part_kind が不正: '%s'" % kind)

		# ⚠ ルーンはステータスを1つも足さない（GAME_DESIGN.md 7-7）。加算の欄は
		#   「空・0・0」を必ず書かせる。欄ごと省くと「欄が欠けている」と言えなくなる。
		# ⚠ 種類で分岐してよいのはここと _part_slot_kinds() の2箇所だけ
		#   （game_manager.gd:2039 の注記）。実行時のコードでは分岐しないこと。
		var is_rune: bool = (kind == GameManager.PART_KIND_RUNE)

		# MasterDataLoader は JSON をそのまま返すため float で来る（CLAUDE.md 3番）。
		var tier: int = int(item.get(GameManager.ITEM_MASTER_PART_TIER, 0))
		if tier < 1:
			errors += _report_part_error(str(item_id), "part_tier が1未満: %d" % tier)

		var stat: String = str(item.get(GameManager.ITEM_MASTER_PART_STAT, ""))
		var base: int = int(item.get(GameManager.ITEM_MASTER_PART_BASE, 0))

		if is_rune:
			if stat != "":
				errors += _report_part_error(str(item_id), "ルーンの part_stat は空であること: '%s'" % stat)
			if base != 0:
				errors += _report_part_error(str(item_id), "ルーンの part_base は0であること: %d" % base)
			if int(item.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, -1)) != 0:
				errors += _report_part_error(str(item_id), "ルーンの part_roll_max は0であること")
		else:
			if not (stat in valid_stats):
				errors += _report_part_error(str(item_id), "part_stat が10軸に無い: '%s'" % stat)
			if base < 1:
				errors += _report_part_error(str(item_id), "part_base が1未満: %d" % base)
			# ロールは 0 〜 part_roll_max。0（振れ幅なし）は許す。
			if not item.has(GameManager.ITEM_MASTER_PART_ROLL_MAX):
				errors += _report_part_error(str(item_id), "part_roll_max の欄が無い")
			elif int(item[GameManager.ITEM_MASTER_PART_ROLL_MAX]) < 0:
				errors += _report_part_error(str(item_id), "part_roll_max が負")

		# IDと欄の綴りの一致。上でどれかが不正なら比較しても意味が無いので飛ばす。
		# ⚠ ルーンには当てない。軸が無いので欄からIDを組み立てられない。
		#   代わりに E124 が runes.json と1:1で突き合わせる（EXEC_RUNES.md §3-D）。
		if not is_rune and kind in valid_kinds and stat in valid_stats and tier >= 1:
			# ⚠ 書式は GameManager と共有する。2箇所に書くと、片方だけ直して
			#   「検証は通るのに段階を上げられない」になる。
			var expected: String = GameManager.PART_ID_FORMAT % [kind, stat, tier]
			if str(item_id) != expected:
				errors += _report_part_error(
					str(item_id), "IDと欄の綴りが一致しない（欄から組むと '%s'）" % expected
				)

	return errors


static func _report_part_error(item_id: String, reason: String) -> int:
	push_error("[MasterDataLoader] E119 items.json (%s): %s" % [item_id, reason])
	return 1


# chests.json のエントリ1件を見る（E118 の枝 ＋ E120 ＋ W20）。
#
# | 記号 | 何を見るか                                                          | 色 |
# | E118 | rewards.materials / rewards.inventory / draw.entries[].item_id が
#          items.json に無い（"" はハズレ枠なので飛ばす）                     | 赤 |
# | E120 | draw の形が不正：rolls < 1 ／ entries が空 ／ weight が負 ／ 合計が0以下 | 赤 |
# | W19  | draw はあるが当たり枠（item_id != ""）が1件も無い                     | 黄 |
# | W20  | rewards も draw も持たない＝開けても何も出ない宝箱                    | 黄 |
#
# ⚠ W19 / W20 を赤にしないのは、「今は何も出さない」と意図的に書く余地を残すため。
#   ただし黙らせない。書いたのに永久に出ない形は無音の穴になる。
# ⚠ メッセージに chest_id を必ず入れる。どの宝箱か分からないと直せない。
static func _validate_chest(chest_id: String, chest: Dictionary) -> int:
	var errors: int = 0
	var has_rewards: bool = false
	var has_draw: bool = false

	# 固定報酬（rewards）… materials と inventory のキーが items.json に在るか。
	var rewards: Variant = chest.get("rewards", null)
	if rewards is Dictionary:
		for list_key: String in ["materials", "inventory"]:
			var table: Variant = (rewards as Dictionary).get(list_key, {})
			if not (table is Dictionary):
				continue
			for item_id: Variant in (table as Dictionary):
				has_rewards = true
				errors += _report_missing_item(
					str(item_id), "chests.json", "%s.rewards.%s" % [chest_id, list_key])

	# 抽選（draw）
	var draw: Variant = chest.get("draw", null)
	if draw is Dictionary:
		has_draw = true
		errors += _validate_chest_draw(chest_id, draw as Dictionary)
	elif draw != null:
		push_error("[MasterDataLoader] E120 chests.json (%s): draw が Dictionary でない" % chest_id)
		errors += 1

	if not has_rewards and not has_draw:
		push_warning("[MasterDataLoader] W20 chests.json (%s): rewards も draw も無い。開けても何も出ない" % chest_id)

	return errors


static func _validate_chest_draw(chest_id: String, draw: Dictionary) -> int:
	var errors: int = 0

	var rolls: int = int(draw.get("rolls", 1))
	if rolls < 1:
		push_error("[MasterDataLoader] E120 chests.json (%s): rolls は1以上でなければならない: %d" % [chest_id, rolls])
		errors += 1

	var rows: Variant = draw.get("entries", [])
	if not (rows is Array) or (rows as Array).is_empty():
		push_error("[MasterDataLoader] E120 chests.json (%s): entries が空、または Array でない" % chest_id)
		return errors + 1

	var total_weight: int = 0
	var hit_rows: int = 0
	for row: Variant in (rows as Array):
		if not (row is Dictionary):
			push_error("[MasterDataLoader] E120 chests.json (%s): entries の要素が Dictionary でない" % chest_id)
			errors += 1
			continue
		var entry: Dictionary = row as Dictionary
		var weight: int = int(entry.get("weight", 0))
		if weight < 0:
			push_error("[MasterDataLoader] E120 chests.json (%s): weight が負: %d" % [chest_id, weight])
			errors += 1
			continue
		total_weight += weight
		var item_id: String = str(entry.get("item_id", ""))
		if item_id != "":
			hit_rows += 1
		errors += _report_missing_item(item_id, "chests.json", "%s.draw" % chest_id)

	if total_weight <= 0:
		push_error("[MasterDataLoader] E120 chests.json (%s): weight の合計が0以下: %d" % [chest_id, total_weight])
		errors += 1
	elif hit_rows == 0:
		push_warning("[MasterDataLoader] W19 chests.json (%s): draw に当たり枠が1件も無い。この宝箱は永久に何も出さない" % chest_id)

	return errors


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


# E129 … recipes.json のレシピ1件を見る（段階11・EXEC_WORKSHOP_REVIVE.md 決め8）。
#
# | 見るもの | なぜ |
# |---|---|
# | outputs も draw も無い | 素材だけ減って何も貰えない |
# | draw.entries が空 / weight の合計が0以下 | 抽選が必ず空を返す＝同上 |
# | draw.entries[].item_id が "" | ⚠ 宝箱と違い、作業場に「ハズレ」を作らない（決め3） |
#
# ⚠ item_id が items.json に在るかは E118 が見る（ここでは重ねない）。
# ⚠ draw.entries の item_id は "" を弾くため、E118 の枝もここから1本ずつ通す。
static func _validate_recipe_draw(recipe_id: String, recipe: Dictionary) -> int:
	var errors: int = 0
	var outputs: Variant = recipe.get("outputs", [])
	var has_outputs: bool = outputs is Array and not (outputs as Array).is_empty()
	var draw_def: Variant = recipe.get("draw", null)
	var has_draw: bool = draw_def is Dictionary and not (draw_def as Dictionary).is_empty()

	if not has_outputs and not has_draw:
		push_error("[MasterDataLoader] E129 recipes.json (%s): outputs も draw も無い" % recipe_id)
		return errors + 1
	if not has_draw:
		return errors

	var rows: Variant = (draw_def as Dictionary).get("entries", [])
	if not (rows is Array) or (rows as Array).is_empty():
		push_error("[MasterDataLoader] E129 recipes.json (%s): draw.entries が空" % recipe_id)
		return errors + 1

	var total_weight: int = 0
	for row: Variant in (rows as Array):
		if not (row is Dictionary):
			push_error("[MasterDataLoader] E129 recipes.json (%s): draw.entries に Dictionary でない要素" % recipe_id)
			errors += 1
			continue
		var entry: Dictionary = row
		var item_id: String = str(entry.get("item_id", ""))
		if item_id == "":
			push_error("[MasterDataLoader] E129 recipes.json (%s): draw.entries に item_id が空の枠がある（作業場にハズレは作らない）" % recipe_id)
			errors += 1
		else:
			errors += _report_missing_item(item_id, "recipes.json", "%s.draw" % recipe_id)
		total_weight += maxi(0, int(entry.get("weight", 0)))

	if total_weight <= 0:
		push_error("[MasterDataLoader] E129 recipes.json (%s): draw.entries の weight の合計が 0 以下" % recipe_id)
		errors += 1
	return errors


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
	_merge_character_files(merged, file_name, what)
	return merged


# 既にある辞書へ、全キャラ・全敵ぶんの同名ファイルを足す。
#
# ⚠ 走査する順番が _load_character_files() と1文字も違わないこと。
#   ここを別に書くと、passives.json だけ「無いファイル」の扱いがズレる。
# ⚠ required_in_main = false にすると、本番キャラと敵のフォルダでも「無い」を
#   正常系として扱う。passives.json がこれ（敵と検証用キャラは持たない）。
#   欠けたことは E126 が別の形で拾うので、ここで赤にしなくてよい。
static func _merge_character_files(
		merged: Dictionary, file_name: String, what: String,
		required_in_main: bool = true
) -> void:
	for dir_path: String in CHARACTER_DIRS_REQUIRED:
		_merge_id_map(merged, dir_path + file_name, required_in_main, what)
	# ⚠ 検証用キャラは nodes.json を持たない。だから「無い」を正常系にしてある。
	for dir_path: String in CHARACTER_DIRS_OPTIONAL:
		_merge_id_map(merged, dir_path + file_name, false, what)
	# 敵も同じ辞書へ入れる（EXEC_ENEMY_PARITY.md §3-1）。
	# ⚠ 敵用に2本目のマージを書かないこと。味方と敵でスキルIDが重複したときに
	#   赤で弾く挙動が、片方だけ効く形になる。
	# ⚠ 敵は nodes.json を持たないが、任意扱いなので「無い」で警告は出ない。
	for dir_path: String in ENEMY_DIRS_REQUIRED:
		_merge_id_map(merged, dir_path + file_name, required_in_main, what)
	for dir_path: String in ENEMY_DIRS_OPTIONAL:
		_merge_id_map(merged, dir_path + file_name, false, what)


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
# chests.json … 宝箱の種類ごとの定義（EXEC_CHEST_REGISTRY.md §3-A）。
#
# ⚠ もとはポモドーロ分が pomodoro_config.tres、戦闘分が stages.json の
#   rewards.chest_table と2箇所に分かれていた。前者は .tres なので E118 が見られず、
#   素材IDの改名から漏れて無音で壊れた（EXEC_STAGE_DROPS.md §11）。
#   ⚠ JSON に寄せたのは、この検証の網に入れるため。
const PATH_CHESTS: String = DIR_PATH + "chests.json"
# runes.json … ルーン1件ごとの挙動（EXEC_RUNES.md §3-A。人間の決定・2026-08-24）。
#
# ⚠ items.json には ID と part_kind しか無い。挙動（CD・効果・移動量）はこちら。
# ⚠ 効果の語彙はスキルとまったく同じ。検証も SkillSchema.validate() を流用する
#   （E123）。効果の検証を2本目に書かないこと。
const PATH_RUNES: String = DIR_PATH + "runes.json"

# runes.json の欄。⚠ 状態のキーではないのでここに置く（GameStateKeys ではない）。
const RUNE_NEXT_ID: String = "next_id"
const RUNE_COOLDOWN_SEC: String = "cooldown_sec"
const RUNE_TARGET: String = "target"
const RUNE_EFFECTS: String = "effects"
const RUNE_MOVE: String = "move"
const RUNE_MOVE_CHOICES: String = "choices"
const RUNE_FIELDS_KNOWN: Array[String] = [
	"rune_id", RUNE_NEXT_ID, RUNE_COOLDOWN_SEC, RUNE_TARGET, RUNE_EFFECTS, RUNE_MOVE,
]

static var _cache_items: Dictionary = {}
static var _items_loaded: bool = false
static var _cache_recipes: Dictionary = {}
static var _recipes_loaded: bool = false
static var _cache_chests: Dictionary = {}
static var _chests_loaded: bool = false
static var _cache_runes: Dictionary = {}
static var _runes_loaded: bool = false


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


# 宝箱の定義を返す。未登録なら空 Dictionary。
# 中身は rewards（固定）と draw（抽選）の両方を持てる（GAME_DESIGN.md 4-2 の二立て）。
static func get_chest(chest_id: String) -> Dictionary:
	_ensure_chests_loaded()
	if not _cache_chests.has(chest_id):
		return {}
	return (_cache_chests[chest_id] as Dictionary).duplicate(true)


# chest_id -> 定義 の Dictionary を返す。
static func get_all_chests() -> Dictionary:
	_ensure_chests_loaded()
	return _cache_chests.duplicate(true)


static func _ensure_chests_loaded() -> void:
	if _chests_loaded:
		return
	_chests_loaded = true
	_cache_chests = _index_by(_load_json(PATH_CHESTS), "chests", "chest_id", PATH_CHESTS)


# ルーン1件の挙動。未登録なら空 Dictionary（＝そのIDはルーンではない）。
#
# ⚠ 「これはルーンか」の判定にこれを使う。part_kind で分岐しないこと
#   （game_manager.gd:2039 の注記。EXEC_RUNES.md §2-2）。
static func get_rune(rune_id: String) -> Dictionary:
	_ensure_runes_loaded()
	if not _cache_runes.has(rune_id):
		return {}
	return (_cache_runes[rune_id] as Dictionary).duplicate(true)


# rune_id -> 定義 の Dictionary を返す。
static func get_all_runes() -> Dictionary:
	_ensure_runes_loaded()
	return _cache_runes.duplicate(true)


static func _ensure_runes_loaded() -> void:
	if _runes_loaded:
		return
	_runes_loaded = true
	_cache_runes = _index_by(_load_json(PATH_RUNES), "runes", "rune_id", PATH_RUNES)


# ルーン1件を「スキル1件ぶんの辞書」に組み立てる。空なら組み立てられない。
#
# ⚠ 撃つときも検証するときも、この1本が作ったものを使う（EXEC_RUNES.md §0-3 の12）。
#   2箇所で組み立てると、片方だけ直して「検証は通るのに撃つと赤」になる。
# ⚠ name_key / user_character_id / unlock_level / activation は SkillSchema が
#   必須にしている足場。runes.json には書かせない（知らない欄は E123 が弾く）。
# ⚠ SkillRuntime.cast() は skill_data を引数で受け、MasterDataLoader を引き直さない
#   （skill_runtime.gd:109）。だから _cache_skills に登録しなくてよい。
static func rune_skill_data(rune_id: String) -> Dictionary:
	var entry: Dictionary = get_rune(rune_id)
	if entry.is_empty() or not (entry.get(RUNE_EFFECTS, null) is Array):
		return {}
	return {
		"name_key": "ui_res_" + rune_id,
		"user_character_id": rune_id,
		"unlock_level": 1,
		# ⚠ float() で包む。JSON は数値を float で返す（CLAUDE.md 3番）。
		"cooldown_sec": float(entry.get(RUNE_COOLDOWN_SEC, 0.0)),
		"activation": SkillSchema.ACTIVATION_INSTANT,
		"target": entry.get(RUNE_TARGET, {}),
		"effects": entry.get(RUNE_EFFECTS, []),
	}


# E123 … runes.json の形が不正。
# E124 … items.json のルーンと runes.json が1:1で対応していない。
#
# ⚠ 効果の中身は SkillSchema.validate() に任せる。効果の検証を2本目に書かない
#   （EXEC_RUNES.md §0-3 の12）。
# ⚠ 1件ごとに1本出す。重複を潰さない（E118 / E119 と同じ方針）。
static func _validate_all_runes() -> void:
	_ensure_runes_loaded()
	_ensure_items_loaded()
	var errors: int = 0

	for raw_id: Variant in _cache_runes:
		var rune_id: String = str(raw_id)
		var entry: Variant = _cache_runes[raw_id]
		if not (entry is Dictionary):
			errors += _report_rune_error(rune_id, "定義が Dictionary でない")
			continue
		var rune: Dictionary = entry

		for key: Variant in rune:
			if not (str(key) in RUNE_FIELDS_KNOWN):
				errors += _report_rune_error(rune_id, "知らない欄がある: '%s'" % str(key))

		if float(rune.get(RUNE_COOLDOWN_SEC, 0.0)) <= 0.0:
			errors += _report_rune_error(rune_id, "cooldown_sec が正の数値でない")

		var has_effects: bool = rune.get(RUNE_EFFECTS, null) is Array
		var has_move: bool = rune.get(RUNE_MOVE, null) is Dictionary
		if not has_effects and not has_move:
			errors += _report_rune_error(rune_id, "effects も move も無い（撃っても何も起きない）")

		# --- 移動系 ---
		if has_move:
			var raw_choices: Variant = (rune[RUNE_MOVE] as Dictionary).get(RUNE_MOVE_CHOICES, null)
			if not (raw_choices is Array) or (raw_choices as Array).is_empty():
				errors += _report_rune_error(rune_id, "move.choices が空、または配列でない")
			else:
				for raw_distance: Variant in (raw_choices as Array):
					# ⚠ 0 を許すと「選べるのに動かない」選択肢ができる。
					if not (raw_distance is float or raw_distance is int) or int(raw_distance) == 0:
						errors += _report_rune_error(
							rune_id, "move.choices に 0 か数値でないものがある: %s" % str(raw_distance)
						)

		# --- 効果（スキルとまったく同じ語彙）---
		if has_effects:
			var probe: Dictionary = rune_skill_data(rune_id)
			for raw_issue: Variant in SkillSchema.validate(rune_id, probe):
				if not (raw_issue is Dictionary):
					continue
				var issue: Dictionary = raw_issue
				var message: String = "[MasterDataLoader] E123 runes.json " + str(issue.get("message", ""))
				if str(issue.get("level", "")) == "error":
					push_error(message)
					errors += 1
				else:
					push_warning(message)

		# --- 上げ先（E124 の枝）---
		if rune.has(RUNE_NEXT_ID):
			var next_id: String = str(rune[RUNE_NEXT_ID])
			if not _cache_runes.has(next_id):
				errors += _report_rune_error(rune_id, "next_id が runes.json に無い: '%s'" % next_id)
			else:
				var tier: int = int((_cache_items.get(rune_id, {}) as Dictionary).get(
					GameManager.ITEM_MASTER_PART_TIER, 0))
				var next_tier: int = int((_cache_items.get(next_id, {}) as Dictionary).get(
					GameManager.ITEM_MASTER_PART_TIER, 0))
				if next_tier != tier + 1:
					errors += _report_rune_error(rune_id, "next_id '%s' の段階が+1でない（%d -> %d）" % [
						next_id, tier, next_tier
					])

		# --- items.json 側に在るか（E124）---
		var item: Variant = _cache_items.get(rune_id, null)
		if not (item is Dictionary):
			errors += _report_rune_ref_error(rune_id, "runes.json に在るが items.json に無い")
		elif str((item as Dictionary).get(GameManager.ITEM_MASTER_PART_KIND, "")) != GameManager.PART_KIND_RUNE:
			errors += _report_rune_ref_error(rune_id, "items.json 側が part_kind: 'rune' でない")

	# --- 逆向き（E124）---
	for raw_item_id: Variant in _cache_items:
		var item_entry: Variant = _cache_items[raw_item_id]
		if not (item_entry is Dictionary):
			continue
		if str((item_entry as Dictionary).get(GameManager.ITEM_MASTER_PART_KIND, "")) != GameManager.PART_KIND_RUNE:
			continue
		if not _cache_runes.has(str(raw_item_id)):
			errors += _report_rune_ref_error(str(raw_item_id), "items.json に在るが runes.json に無い（刺しても何も起きない）")

	print("[MasterDataLoader] runes validated: %d entries, %d errors" % [_cache_runes.size(), errors])


static func _report_rune_error(rune_id: String, reason: String) -> int:
	push_error("[MasterDataLoader] E123 runes.json (%s): %s" % [rune_id, reason])
	return 1


static func _report_rune_ref_error(rune_id: String, reason: String) -> int:
	push_error("[MasterDataLoader] E124 (%s): %s" % [rune_id, reason])
	return 1


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

	# E126 … characters.json の passives と、passives.json の中身のクロス検証。
	#
	# ⚠ SkillSchema 側に書けない。あちらは1スキルだけを見る静的検証で、
	#   characters.json を知らない（E100 と同じ理由でここに置く）。
	# ⚠ なぜ要るか：get_skill_candidates() は定義の無いIDを黙って落とす。
	#   characters.json の欄と passives.json のどちらか片方だけ書いた事故が、
	#   「そのパッシブが一生付かない」という無音の形で実戦まで残る
	#   （EXEC_CHARACTER_PASSIVES.md §4-1）。
	# ⚠ スキル（skills の欄）はここで見ない。あちらは未選択の枠を候補の先頭で
	#   埋めるので、欠けると戦闘のボタンが減って気づける。
	error_count += _validate_character_passives()

	# _load_json() は成功時に何も出さない。これが唯一の「読めた」の合図。
	print("[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings" % [
		_cache_skills.size(), error_count, warning_count
	])


# characters.json の passives に並んでいるIDが、本当にパッシブとして定義されて
# いるかを見る。戻り値は赤の件数（E126）。
static func _validate_character_passives() -> int:
	var errors: int = 0
	for character_id: Variant in _cache_characters:
		var entry: Variant = _cache_characters[character_id]
		if not (entry is Dictionary):
			continue
		var raw: Variant = (entry as Dictionary).get("passives", null)
		# ⚠ 欄が無いのは正常系。持たないキャラが居てよい（get_all_skill_candidates
		#   と同じ扱いにする。ここだけ厳しくすると敵と検証用キャラが赤になる）。
		if raw == null:
			continue
		if not (raw is Array):
			errors += 1
			push_error("[MasterDataLoader] characters %s: passives が配列ではない" % str(character_id))
			continue
		for raw_id: Variant in (raw as Array):
			var passive_id: String = str(raw_id)
			if not _cache_skills.has(passive_id):
				errors += 1
				push_error("[MasterDataLoader] characters %s: passives の '%s' が定義されていない（passives.json に無い）" % [
					str(character_id), passive_id
				])
				continue
			var data: Variant = _cache_skills[passive_id]
			var activation: String = str((data as Dictionary).get("activation", "")) if data is Dictionary else ""
			if activation != SkillSchema.ACTIVATION_PASSIVE:
				errors += 1
				push_error("[MasterDataLoader] characters %s: passives の '%s' は activation が '%s'（'passive' でなければ一生付かない）" % [
					str(character_id), passive_id, activation
				])
				continue
			# 誰のものかが食い違うと、_skill_select_error() と同じ理由で
			# 「候補には出るが持ち主が違う」状態になる。
			var owner_id: String = str((data as Dictionary).get("user_character_id", ""))
			if owner_id != str(character_id):
				errors += 1
				push_error("[MasterDataLoader] characters %s: passives の '%s' の user_character_id が '%s'" % [
					str(character_id), passive_id, owner_id
				])
	return errors
