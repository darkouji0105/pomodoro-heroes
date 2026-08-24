extends Node

# GameManager: 全画面のSingle Source of Truth。
# 拠点共通データ＋育成・図鑑・ショップ・研究ツリー・製作キュー等の永続データを保持・更新する。
# 他のAutoloadやシーンは直接データを書き換えず、必ず下記関数を経由すること。

var _state: Dictionary = {}

# resource_type には GameStateKeys の定数（GOLD / GEMS / STAMINA）を渡す。
# 文字列リテラルを直接渡さないこと（typoしても実行時まで気づけないため）。
signal resource_changed(resource_type: String, new_value: Variant)
# 素材は種類ごとに表示先が分かれるため、辞書全体ではなく
# 「どの素材がいくつになったか」を個別に通知する専用シグナルを分けている。
signal material_changed(material_id: String, new_amount: int)
signal screen_unlocked(screen_id: String)
signal inventory_changed(item_id: String)
signal pending_chests_changed(pending_count: int)
# 育成データの変化。レベル・ステータス・装備・スキルのいずれかが変わったときに発火する。
# 素材の増減は material_changed 側で通知されるため、こちらには含めない。
signal character_growth_changed(character_id: String)

# 装備の個体が増えた・等級が上がった・素材に戻したときに飛ぶ。
# 着脱では飛ばない（着脱で変わるのは character_growth だけ）。
signal equipment_instances_changed(instance_id: String)
# 研究ノードの解放。素材の増減は material_changed 側で通知されるため、こちらには含めない。
# 実効レベル上限・ステータス上昇は都度計算のため、解放の通知だけで全画面が追従できる。
signal research_node_unlocked(node_id: String)
# ショップのラインナップの変化（購入・リフレッシュの両方）。
# 所持金・素材・アイテムの増減は resource_changed / material_changed / inventory_changed 側で
# 通知されるため、こちらは purchased_count と refresh_at の変化だけを担当する。
signal shop_changed(shop_type: String)
# 製作キューの変化（開始・完了への切り替え・受け取り）。
# 素材・アイテムの増減は material_changed / inventory_changed 側で通知されるため、
# こちらはキューの中身の変化だけを担当する。
signal crafting_queue_changed()

# get_level_up_cost() が返す Dictionary のキー。
# 呼び出し側が文字列リテラルを書かなくて済むようにここで公開する。
const LEVEL_UP_COST_MATERIAL_ID: String = "material_id"
const LEVEL_UP_COST_AMOUNT: String = "amount"

# get_stat_boost_all() が「全ステータス対象」の加算をまとめるキー。
# 既存の get_stat_boost_all() が target_stat 未指定時に使う値と揃える必要がある。
const STAT_BOOST_ALL_KEY: String = "all"

# get_research_unlock_cost() が返す Dictionary のキー。
# get_level_up_cost() と同じ形にそろえてある。
const RESEARCH_COST_MATERIAL_ID: String = "material_id"
const RESEARCH_COST_AMOUNT: String = "amount"

# research.json 側のキー（状態ではなくマスターデータのため GameStateKeys には置かない）。
const RESEARCH_NODE_COST_MATERIAL_ID: String = "cost_material_id"
const RESEARCH_NODE_COST_AMOUNT: String = "cost_amount"

# character_nodes.json 側のキー（同じくマスターデータ。EXEC_LEVEL_ROLE_SHIFT.md §5-1）。
# セーブに残るのはノードIDだけで、これらの値は毎回ここから引き直す。
const STAT_NODE_CHARACTER_ID: String = "character_id"
const STAT_NODE_STAT: String = "stat"
const STAT_NODE_TIER: String = "tier"
const STAT_NODE_COST: String = "cost"
const STAT_NODE_VALUE: String = "value"
const STAT_NODE_PREREQUISITES: String = "prerequisites"

# skills.json 側のキー（マスターデータ。EXEC_SKILL_SELECT.md §4）。
# セーブに残るのはスキルIDだけで、これらの値は毎回ここから引き直す。
#
# characters.json 側の "skills"（そのキャラの候補一覧・並び順つき）も
# ここで名前を持つ。allocatable_stats と同じく、配列の順序が画面の並び順になる。
const SKILL_USER_CHARACTER_ID: String = "user_character_id"
const SKILL_UNLOCK_LEVEL: String = "unlock_level"
const CHARACTER_SKILLS: String = "skills"
# パッシブの候補（characters.json / enemies.json）。⚠ "skills" と別配列にする。
#   同じ配列に入れると、スキルボタンにも敵AIにも混ざる（EXEC_SKILL_PASSIVE_VARS.md §0-1-1）。
const CHARACTER_PASSIVES: String = "passives"

# shop.json 側だけにあるキー（状態には残らないため GameStateKeys には置かない）。
# slot_id / item_id / cost / stock_limit は状態と同じ形のため GameStateKeys 側を使う。
const SHOP_SLOT_PAYOUT_TYPE: String = "payout_type"
const SHOP_SLOT_PAYOUT_COUNT: String = "count"
const SHOP_SLOT_ITEM_TYPE: String = "item_type"

# payout_type に入る値。
# 素材（materials）とアイテム（inventory）は保存先が違うため、渡す関数を切り替える必要がある。
# 「素材IDならadd_material」と推測で分岐させない（IDの綴りだけでは判別できない）。
const PAYOUT_TYPE_MATERIAL: String = "material"
const PAYOUT_TYPE_ITEM: String = "item"

# recipes.json 側だけにあるキー（状態には残らないため GameStateKeys には置かない）。
# 画面側もこの定数を使う（文字列リテラルを2箇所に書かない）。
const RECIPE_ID: String = "recipe_id"
const RECIPE_DURATION_SEC: String = "duration_sec"
const RECIPE_INPUTS: String = "inputs"
const RECIPE_OUTPUTS: String = "outputs"
const RECIPE_IO_ITEM_ID: String = "item_id"
const RECIPE_IO_COUNT: String = "count"
const RECIPE_UNLOCKED_BY_DEFAULT: String = "unlocked_by_default"
const RECIPE_SORT_ORDER: String = "sort_order"

# chests.json 側だけにあるキー（EXEC_CHEST_REGISTRY.md §3-D）。
#
# ⚠ 1エントリは rewards（固定）と draw（抽選）の両方を持てる
#   （GAME_DESIGN.md 4-2 の「固定報酬＋抽選ドロップの二立て」がそのまま形になる）。
const CHEST_NAME_KEY: String = "name_key"
const CHEST_DRAW: String = "draw"
const CHEST_DRAW_ROLLS: String = "rolls"
const CHEST_DRAW_ENTRIES: String = "entries"
const CHEST_DRAW_ITEM_ID: String = "item_id"
const CHEST_DRAW_WEIGHT: String = "weight"
const CHEST_DRAW_COUNT: String = "count"

# items.json 側だけにあるキー。
# 「そのIDが materials に入るのか inventory に入るのか」はここでしか分からない。
# IDの綴りから推測して分岐させないこと（ショップの payout_type と同じ理由）。
const ITEM_MASTER_STORAGE: String = "storage"
const ITEM_MASTER_ITEM_TYPE: String = "item_type"
const ITEM_STORAGE_MATERIAL: String = "material"
const ITEM_STORAGE_INVENTORY: String = "inventory"

# items.json の装備エントリだけが持つキー。
# equipment.json を別に作らないのは、_item_storage() / _grant_item() が既に items.json を
# 引いているため。性能値だけ別ファイルにすると、同期の型がもう1枚要る。
const ITEM_MASTER_EQUIP_SLOT: String = "equip_slot"
const ITEM_MASTER_EQUIP_STATS: String = "equip_stats"

# items.json の装飾エントリだけが持つキー（EXEC_DECORATION.md §3-A）。
#
# ⚠ item_id からは切り出さない。必ずこの欄で引くこと。
#   IDは part_<種類>_<軸>_<段階> の形だが、軸名にも _ が入る（crit_rate / crit_dmg）ため
#   パースは事故る。IDと欄が一致しているかは E119 が検証する。
# stages.json の欄。そのステージをクリアしたときに開く screen_id の配列
# （段階9・EXEC_SCREEN_UNLOCK.md §3-B）。
# ⚠ 知らない screen_id は E125 がロード時に赤で言う。
const STAGE_MASTER_UNLOCKS: String = "unlocks"

const ITEM_MASTER_PART_KIND: String = "part_kind"
const ITEM_MASTER_PART_TIER: String = "part_tier"
const ITEM_MASTER_PART_STAT: String = "part_stat"
const ITEM_MASTER_PART_BASE: String = "part_base"
const ITEM_MASTER_PART_ROLL_MAX: String = "part_roll_max"

# 装飾の種類。
#
# ⚠ part_kind で if を分岐させないこと。種類を足すたびに .gd を触ることになる
#   （EXEC_DECORATION.md §0-4）。使うのは次の2箇所だけ：
#     1. _part_slot_kinds() … どの枠にどの種類が刺さるか
#     2. E119 の検証 … 知らない種類が items.json に入っていないか
const PART_KIND_GEM: String = "gem"
const PART_KIND_CHARM: String = "charm"
const PART_KIND_EMBLEM: String = "emblem"
const PART_KIND_RUNE: String = "rune"

# 装飾のIDの組み立て方（part_<種類>_<軸>_<段階>）。
#
# ⚠ 使うのは「欄 → ID」の向きだけ。逆（IDから欄を切り出す）はしない
#   （軸名にも _ が入る： crit_rate / crit_dmg）。
# ⚠ 組み立てたIDと欄が一致していることは、ロード時に E119 が検証している
#   （MasterDataLoader._validate_all_part_items()）。ここと同じ書式を使うこと。
const PART_ID_FORMAT: String = "part_%s_%s_%d"

# get_part_reject_reason() が返す翻訳キー。"" なら刺せる。
const PART_REJECT_LOCKED: String = "ui_part_reject_locked"
const PART_REJECT_OCCUPIED: String = "ui_part_reject_occupied"
const PART_REJECT_UNKNOWN: String = "ui_part_reject_unknown"
const PART_REJECT_KIND: String = "ui_part_reject_kind"
const PART_REJECT_STOCK: String = "ui_part_reject_stock"

# get_part_upgrade_cost() が返す Dictionary のキー（get_forge_cost() と同じ形）。
# get_rune_merge_reject_reason() が返す翻訳キー。"" なら重ねられる。
# ⚠ PART_REJECT_* と同じ形（刺す判定とは別物なので混ぜない）。
const RUNE_REJECT_KIND: String = "ui_part_reject_rune_kind"
const RUNE_REJECT_MAX: String = "ui_part_reject_rune_max"
const RUNE_REJECT_STOCK: String = "ui_part_reject_rune_stock"

# get_battle_runes() が返す payload 1件のキー。⚠ 状態には入らないのでここ。
const RUNE_PAYLOAD_ITEM_ID: String = "item_id"
const RUNE_PAYLOAD_COOLDOWN: String = "cooldown_sec"
const RUNE_PAYLOAD_MOVE: String = "move"
const RUNE_PAYLOAD_SKILL_DATA: String = "skill_data"

const PART_UPGRADE_MATERIAL_ID: String = "material_id"
const PART_UPGRADE_AMOUNT: String = "amount"

# --- 装備の個体（第2弾） ---

const INSTANCE_ID_PREFIX: String = "eq_"

# ⚠ 等級の上限・鍛冶のコスト・分解の戻りは Balance.equipment（EquipmentConfig）へ移した
#   （EXEC_MATERIAL_TIERS.md 決定C / G。AGENTS.md の数値管理ルール）。
#   ここに定数として残すと二重管理になるため、MAX_EQUIPMENT_GRADE /
#   FORGE_MATERIAL_ID / FORGE_COST_PER_GRADE / DISMANTLE_REFUND_BASE は消してある。
#
# ⚠ 移す前のコメントはこう書いていた：
#     「4〜10の必要素材量はバランスの計算道具ができてから決める
#       （勘で置くと全部やり直しになる）」
#   ⚠ 実測はまだ来ていないので、4〜10は今も勘。ただし数値が
#     equipment_config.gd の forge_cost_by_grade の1行に集まっているので、
#     やり直すときに触るのはその行だけで済む。

# 等級1つにつき、基礎値の何割を「加算」するか。
# 乗算で重ねるとインフレするため加算にしている（PLAN_CHARACTER_GROWTH_LOOP.md 3-1）。
# 等級10でも 1 + 0.25*9 = 3.25倍で止まる。
const GRADE_STAT_RATIO: float = 0.25

# 枠（装飾を刺すところ）。parts は null 込みの長さ固定配列で、位置が枠を表す（PLAN 2-2）。
#
# ⚠ GAME_DESIGN.md 6-4 で「等級を上げると必ず何かが開く」形になった。
#   それまでは PART_SLOT_GRADES = [5, 10] の2枠（等級5で1つ・等級10で2つ）だった。
#   ⚠ 開く等級は PartConfig.part_slot_min_grades（数値なので .tres 側）。
#   ⚠ 位置ごとの「刺さる種類」は _part_slot_kinds()（種類は数値ではないのでここ）。
#
#   0: 等級3 宝石枠1        4: 等級6 護符枠1
#   1: 等級4 宝石枠2        5: 等級7 護符枠2
#   2: 等級5 特別枠1        6: 等級8 紋章枠1
#   3: 等級5 特別枠2        7: 等級9 紋章枠2
#
# ⚠ 特別枠2（位置3）はアクセサリーにしか無い。他の部位では「開かない枠」として
#   位置だけ残す。位置を詰めると部位ごとに添字の意味が変わり、既存セーブの
#   parts が別の枠を指すようになる。
# ⚠ 等級10 では枠が開かない。開くのは「部位固有のパッシブ」で別の仕組み
#   （GAME_DESIGN.md 6-4。この回では実装していない）。
const PART_SLOT_COUNT: int = 8

# get_part_entries() が返す1件分のキー。
const PART_VIEW_INDEX: String = "index"
const PART_VIEW_KINDS: String = "kinds"
const PART_VIEW_ENTRY: String = "entry"
const PART_VIEW_MIN_GRADE: String = "min_grade"

# get_forge_cost() が返す Dictionary のキー。
const FORGE_COST_MATERIAL_ID: String = "material_id"
const FORGE_COST_AMOUNT: String = "amount"

# get_equippable_instances() / get_owned_instances() が返す Dictionary のキー。
const INSTANCE_VIEW_ID: String = "instance_id"
const INSTANCE_VIEW_STATS: String = "stats"
const INSTANCE_VIEW_EQUIPPED_BY: String = "equipped_by"
const INSTANCE_VIEW_SORT_ORDER: String = "sort_order"

# Balance.workshop が読めなかったときの既定値。
const DEFAULT_MAX_QUEUE_SLOTS: int = 1
const DEFAULT_CRAFT_DURATION_SEC: int = 1800

func _ready() -> void:
	_build_new_game_state("_ready()")
	# ⚠ .tres が持つ素材ID・アイテムIDを items.json と突き合わせる（E121）。
	#   ⚠ 起動時に1回だけ。⚠ reset_to_new_game() では呼ばない（マスターは変わらない）。
	_validate_balance_item_refs()


# 「最初から」を押したときに、状態を新規開始の中身に作り直す。
#
# ⚠ なぜ要るか：_state を作るのは _ready()（起動時1回）と load_state() の2つだけで、
#   リセットする口が無かった。そのため
#     つづきから → 遊ぶ → タイトルへ戻る → セーブを削除 → 最初から
#   の順で進むと、⚠ ファイルは消えているのにメモリ上の状態が残り、
#   ⚠ 「セーブを消しても消えない」に見えた（2026-08-24に人間が実機で発見）。
# ⚠ 呼ぶのはタイトル画面の1箇所だけ（title_screen._on_start_pressed）。
#   ⚠ 「新規開始」を決めているのはあそこしかない。2本目を作らないこと。
func reset_to_new_game() -> void:
	_build_new_game_state("reset_to_new_game()")


# 新規開始の状態を組み立てる。⚠ _ready() と reset_to_new_game() の共通部分。
#
# ⚠ 2本に分けて書かないこと。片方だけ直すと「起動直後は正しいが、
#   最初からを押すと壊れている」（またはその逆）になり、どちらもエラーが出ない。
func _build_new_game_state(caller: String) -> void:
	print("[GameManager] %s — initializing from Balance.initial_state" % caller)
	if Balance != null and Balance.initial_state != null:
		_init_from_config(Balance.initial_state)
	else:
		push_warning("[GameManager] Balance.initial_state is null — using empty defaults")
		_state = _empty_state_template()
	# 編成を parties.json から流し込む。_empty_state_template() の party_members は
	# [] のため、これが無いと戦闘にキャラが1人も出ない。
	# ⚠ load_state() 側にも同じ呼び出しが要る。片方だけだと「新規開始で空」か
	#   「ロードで空」のどちらかになり、どちらもエラーが出ない。
	_ensure_party_members_from_master()
	# プリセットの器を作る。_empty_state_template() は空なので、これが無いと
	# 画面に1行も出ない。⚠ load_state() 側にも同じ呼び出しが要る（片方だけだと
	# 「新規開始で空」か「ロードで空」のどちらかになり、どちらもエラーが出ない）。
	_normalize_presets_from_save()
	# 研究ツリーを research.json から流し込む。
	# _empty_state_template() の research_tree は {} のため、これが無いと画面に1つも出ない。
	_sync_research_tree_from_master()
	# ショップのラインナップを shop.json から流し込む。research_tree と同じ理由で、
	# _empty_state_template() の line_up は [] のため、これが無いと画面に1つも出ない。
	_sync_shops_from_master()
	# 流し込んだ「あと」に日付を見る。順序が逆だと、リセットした購入回数を
	# セーブ側の値で上書きしてしまう。
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピを recipes.json から流し込む。research_tree / line_up と同じ理由で、
	# _empty_state_template() の recipes_unlocked は {} のため、これが無いと画面に1つも出ない。
	_sync_recipes_from_master()
	# クリア済みステージから機能の解放を流し込む（GAME_DESIGN.md 9-5）。
	# ⚠ 新規開始では story.stages が空なので何も開かない。
	_sync_unlocked_screens_from_master()
	# 起動した時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
	# materials も出す。initial_state に足した素材が届いているかを、
	# セーブファイルを開かずに確認できるようにするため。
	print("[GameManager] init complete. gold=%d stamina=%s materials=%s unlocked_screens=%s" % [
		int(_state.get(GameStateKeys.GOLD, 0)),
		_state.get(GameStateKeys.STAMINA, {}),
		_state.get(GameStateKeys.MATERIALS, {}),
		_state.get(GameStateKeys.UNLOCKED_SCREENS, {}),
	])

# .tres 側の素材ID・アイテムIDが items.json に在るかを見る（E121）。
#
# ⚠ MasterDataLoader の E118 は .tres を見ない（あちらはマスターデータ専用で、
#   Balance に依存させると層が逆転する）。その穴をここで塞ぐ。
#
# ⚠ なぜ要るか：素材を3件から16件に増やした回で construction_material →
#   construction_material_1 のような改名をしたが、.tres は改名の対象から漏れていた。
#   E118 は .tres を見ないため、2件が無音で壊れたまま残った（2026-08-23 に発覚）：
#     ・pomodoro_config.tres の宝箱4件 … 開けても素材が増えない
#     ・character_config.tres の level_up_material_id … レベルアップが常に失敗する
#   ⚠ どちらも赤も黄も出ず、画面では「押しても何も起きない」としか見えなかった。
#
# ⚠ 空文字は「未設定」であり正常（research_config / shop_config が実際にそう）。飛ばす。
# ⚠ 1件ごとに1本出す。重複を潰さない（E118 / E119 と同じ方針）。
# ⚠ Balance より後に呼ぶこと。GameManager は Autoload の2番目なので _ready() の中なら安全。
func _validate_balance_item_refs() -> void:
	if Balance == null:
		return
	var errors: int = 0

	# character_config.tres … レベルアップの消費素材
	if "character" in Balance and Balance.character != null:
		errors += _report_missing_balance_item(
			str(Balance.character.level_up_material_id), "character_config.tres", "level_up_material_id")

	# ⚠ 宝箱の中身はここで見ない。chests.json へ移したので E118 が見る
	#   （EXEC_CHEST_REGISTRY.md §3-B）。.tres に残っている chest_contents は
	#   誰も読まない死んだ欄で、後半で @export ごと消す。

	# initial_state_config.tres … 開始時の所持素材
	if "initial_state" in Balance and Balance.initial_state != null:
		for material_id: Variant in Balance.initial_state.starting_materials:
			errors += _report_missing_balance_item(
				str(material_id), "initial_state_config.tres", "starting_materials")

	# research_config.tres … 解放の消費素材（未設定なら飛ばす）
	if "research" in Balance and Balance.research != null:
		errors += _report_missing_balance_item(
			str(Balance.research.unlock_material_id), "research_config.tres", "unlock_material_id")

	# shop_config.tres … 抽選の候補（未設定なら飛ばす）
	if "shop" in Balance and Balance.shop != null:
		for item_id: String in Balance.shop.item_pool:
			errors += _report_missing_balance_item(item_id, "shop_config.tres", "item_pool")

	print("[GameManager] balance item refs validated: %d errors" % errors)


func _report_missing_balance_item(item_id: String, where: String, context: String) -> int:
	if item_id == "":
		return 0
	if not MasterDataLoader.get_item(item_id).is_empty():
		return 0
	push_error("[GameManager] E121 %s (%s): items.json に無いID: %s" % [where, context, item_id])
	return 1

# --- 初期化 ---

func _init_from_config(config: InitialStateConfig) -> void:
	_state = _empty_state_template()
	
	var unlocked: Dictionary = {}
	for screen_id: String in config.initially_unlocked_screens:
		unlocked[screen_id] = true
	
	_state[GameStateKeys.GOLD] = config.starting_gold
	_state[GameStateKeys.GEMS] = config.starting_gems
	_state[GameStateKeys.STAMINA] = {
		GameStateKeys.STAMINA_CURRENT: config.starting_stamina_current,
		GameStateKeys.STAMINA_MAX: config.starting_stamina_max
	}
	_state[GameStateKeys.MATERIALS] = config.starting_materials.duplicate(true)
	_state[GameStateKeys.SCENARIO_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.STORY][GameStateKeys.STORY_CURRENT_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.SAVE_VERSION] = config.save_version
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked

func _init_empty() -> void:
	_state = _empty_state_template()

func _empty_state_template() -> Dictionary:
	return {
		GameStateKeys.GOLD: 0,
		GameStateKeys.GEMS: 0,
		GameStateKeys.STAMINA: {GameStateKeys.STAMINA_CURRENT: 0, GameStateKeys.STAMINA_MAX: 0},
		GameStateKeys.MATERIALS: {},
		GameStateKeys.INVENTORY: {},
		GameStateKeys.PENDING_CHESTS: [],
		GameStateKeys.UNLOCKED_SCREENS: {},
		GameStateKeys.SCENARIO_CHAPTER: 1,
		GameStateKeys.BOSS_UNLOCKED: false,
		GameStateKeys.PITY_COUNTERS: {},
		GameStateKeys.TOTAL_POMODORO_COMPLETED: 0,
		GameStateKeys.LAST_POMODORO_END_AT: "",
		# ⚠ save_version の出どころは3箇所ある。上げるときは3つとも上げること。
		#   1. ここ（Balance.initial_state が無いときのフォールバック）
		#   2. save_manager.gd の CURRENT_SAVE_VERSION
		#   3. initial_state_config.tres の save_version（新規開始で実際に効くのはこれ）
		# SaveManager.CURRENT_SAVE_VERSION を参照しないこと。GameManager は Autoload 2番目、
		# SaveManager は3番目で、_ready() の時点でまだ初期化されていない。
		GameStateKeys.SAVE_VERSION: 3,
		GameStateKeys.LAST_SAVED_AT: "",
		GameStateKeys.STORY: {GameStateKeys.STORY_CURRENT_CHAPTER: 1, GameStateKeys.STORY_STAGES: {}},
		GameStateKeys.TRAINING_MODE_UNLOCKED: false,
		GameStateKeys.CODEX: {},
		GameStateKeys.DAILY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.WEEKLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.MONTHLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.CHARACTER_GROWTH: {},
		# 編成。⚠ 空配列で始めること。ここに既定の3体を書くと parties.json と
		#   2箇所に初期値ができる。流し込むのは _ensure_party_members_from_master()。
		GameStateKeys.PARTY_MEMBERS: [],
		# プリセット（2階層）。⚠ ここも空で始める。器を作るのは
		#   _normalize_presets_from_save()（_ready() と load_state() の両方から呼ぶ）。
		GameStateKeys.CHARACTER_PRESETS: {},
		GameStateKeys.PARTY_PRESETS: [],
		GameStateKeys.RESEARCH_TREE: {},
		GameStateKeys.RECIPES_UNLOCKED: {},
		GameStateKeys.CRAFTING_QUEUE: [],
		GameStateKeys.EQUIPMENT_INSTANCES: {},
		GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID: 1,
		GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY: 0,
		GameStateKeys.REACHED_CHEST_THRESHOLDS: [],
		GameStateKeys.UNCLAIMED_CHESTS: [],
		GameStateKeys.LAST_PROTECTION_SELECTED_AT: "",
		GameStateKeys.SELECTED_PROTECTION_TYPE: "",
		GameStateKeys.POTION_FOCUS_REMAINDER: 0,
	}

# --- 内部ヘルパー ---

# _state 内のネストしたDictionary/Arrayを取り出す。
# GDScriptのDictionary・Arrayは参照渡しのため、.get() で取り出したものを直接書き換えると
# _state へ代入し直す前に内部状態が変わってしまう。
# 必ず複製を返し、呼び出し側が明示的に _state へ代入し直す形にする
# （「変更前の値と比較する」処理を後から足しても壊れないようにするため）。
func _copy_dict(key: String) -> Dictionary:
	var value: Variant = _state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate()
	return {}

func _copy_array(key: String) -> Array:
	var value: Variant = _state.get(key, [])
	if value is Array:
		return (value as Array).duplicate()
	return []

# --- 基本リソース ---

func get_state() -> Dictionary:
	# 内部Dictionaryそのものではなく、duplicate(true)した読み取り専用スナップショットを返す。
	# 呼び出し側からの直接書き換えを防ぐため（AGENTS.md「状態アクセスのルール」準拠）。
	return _state.duplicate(true)

func add_gold(amount: int) -> void:
	_state[GameStateKeys.GOLD] = int(_state.get(GameStateKeys.GOLD, 0)) + amount
	print("[GameManager] add_gold(%d) -> %d" % [amount, _state[GameStateKeys.GOLD]])
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])

func add_gems(amount: int) -> void:
	_state[GameStateKeys.GEMS] = int(_state.get(GameStateKeys.GEMS, 0)) + amount
	print("[GameManager] add_gems(%d) -> %d" % [amount, _state[GameStateKeys.GEMS]])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])

func add_stamina(amount: int) -> void:
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	var max_stamina: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	
	current += amount
	if current > max_stamina:
		current = max_stamina
	
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d" % [amount, current])
	resource_changed.emit(GameStateKeys.STAMINA, current)

func spend_stamina(amount: int) -> bool:
	# 足りなければ何もせずfalseを返す
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	if current < amount:
		print("[GameManager] spend_stamina(%d) -> false (have %d)" % [amount, current])
		return false
	stamina[GameStateKeys.STAMINA_CURRENT] = current - amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] spend_stamina(%d) -> true (current=%d)" % [amount, int(stamina[GameStateKeys.STAMINA_CURRENT])])
	resource_changed.emit(GameStateKeys.STAMINA, stamina[GameStateKeys.STAMINA_CURRENT])
	return true

func add_material(material_id: String, amount: int) -> void:
	var materials: Dictionary = _copy_dict(GameStateKeys.MATERIALS)
	var new_amount: int = int(materials.get(material_id, 0)) + amount
	materials[material_id] = new_amount
	_state[GameStateKeys.MATERIALS] = materials
	print("[GameManager] add_material('%s', %d) -> %d" % [material_id, amount, new_amount])
	# 辞書全体ではなく「どの素材がいくつになったか」を通知する。
	# 拠点画面は素材の種類ごとにラベルを持つため、種類が特定できないと差分更新できない。
	material_changed.emit(material_id, new_amount)

func get_material_count(material_id: String) -> int:
	var materials: Dictionary = _state.get(GameStateKeys.MATERIALS, {})
	return int(materials.get(material_id, 0))

# item_type を省略した場合は "" （種別不明）として登録する。
# 勝手に "equipment" 等を推測すると、消費アイテムまで装備扱いになるため。
# 種別が分かる呼び出し元（ショップ・作業場・宝箱など）は必ず明示的に渡すこと。
#
# 装備だけは inventory に入れず、1個につき個体（eq_N）を1つ作る。
# 装備の入口は宝箱（open_chest）・ショップ（purchase_shop_item）・作業場（collect_craft）の
# 3つあるが、どれも最後はこの関数を通るため、個体の生成をここに1箇所だけ置いている。
# 判定に item_type 引数を使わないのは、open_chest() が第3引数を渡さないため。
func add_to_inventory(item_id: String, count: int, item_type: String = GameStateKeys.ITEM_TYPE_UNKNOWN) -> void:
	if _is_equipment_item(item_id):
		var newly: bool = _mark_codex_discovered(item_id)
		var last_instance_id: String = ""
		for i: int in range(count):
			last_instance_id = _create_equipment_instance(item_id)
		print("[GameManager] add_to_inventory('%s', %d) -> equipment instances (last=%s newly_discovered=%s)" % [
			item_id, count, last_instance_id, newly
		])
		# 1回の受け取りで何個来ても、飛ばすシグナルは1本にする（再描画を並走させない）。
		equipment_instances_changed.emit(last_instance_id)
		return

	# 初出のitem_idであれば、図鑑（codex）のdiscoveredも自動でtrueにする
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = {}
	if inventory.has(item_id) and inventory[item_id] is Dictionary:
		entry = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_COUNT] = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) + count
	if item_type != GameStateKeys.ITEM_TYPE_UNKNOWN:
		entry[GameStateKeys.ITEM_TYPE] = item_type
	elif not entry.has(GameStateKeys.ITEM_TYPE):
		entry[GameStateKeys.ITEM_TYPE] = GameStateKeys.ITEM_TYPE_UNKNOWN
	if not entry.has(GameStateKeys.ITEM_SLOT_POSITION):
		entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: 0, GameStateKeys.POS_Y: 0}
	if not entry.has(GameStateKeys.ITEM_PROPERTIES):
		entry[GameStateKeys.ITEM_PROPERTIES] = {}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory

	var newly_discovered: bool = _mark_codex_discovered(item_id)
	print("[GameManager] add_to_inventory('%s', %d, type='%s') -> count=%d newly_discovered=%s" % [
		item_id, count, str(entry[GameStateKeys.ITEM_TYPE]), int(entry[GameStateKeys.ITEM_COUNT]), newly_discovered])
	inventory_changed.emit(item_id)

# 図鑑の discovered を立てる。初出なら true。
# 装備は inventory を通らないため、切り出して両方から呼ぶ。
func _mark_codex_discovered(item_id: String) -> bool:
	var codex: Dictionary = _copy_dict(GameStateKeys.CODEX)
	if codex.has(item_id):
		return false
	codex[item_id] = {
		GameStateKeys.CODEX_DISCOVERED: true,
		GameStateKeys.CODEX_OBTAINED_AT: str(Time.get_unix_time_from_system()),
	}
	_state[GameStateKeys.CODEX] = codex
	return true

# --- 画面アンロック ---

func unlock_screen(screen_id: String) -> void:
	var unlocked: Dictionary = _copy_dict(GameStateKeys.UNLOCKED_SCREENS)
	unlocked[screen_id] = true
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked
	print("[GameManager] unlock_screen('%s')" % screen_id)
	screen_unlocked.emit(screen_id)

func is_screen_unlocked(screen_id: String) -> bool:
	var unlocked: Dictionary = _state.get(GameStateKeys.UNLOCKED_SCREENS, {})
	return bool(unlocked.get(screen_id, false))

# 存在する画面ID（機能IDを含む）の一覧。並び順は GAME_DESIGN.md 9-5 の解放順。
#
# ⚠ 定数の並びを2箇所に書かない。ロード時検証（E125）も F4 もここを通す。
# ⚠ decoration / rune は遷移先が無い「機能ID」。装備画面の中の行を出し分けるだけ
#   （EXEC_SCREEN_UNLOCK.md 決定5）。
func get_all_screen_ids() -> Array[String]:
	return [
		GameStateKeys.SCREEN_ADVENTURE_SELECT,
		GameStateKeys.SCREEN_GUILD,
		GameStateKeys.SCREEN_EQUIPMENT,
		GameStateKeys.SCREEN_TRAINING,
		GameStateKeys.SCREEN_WAREHOUSE,
		GameStateKeys.SCREEN_POMODORO,
		GameStateKeys.SCREEN_DECORATION,
		GameStateKeys.SCREEN_RESEARCH,
		GameStateKeys.SCREEN_SHOP,
		GameStateKeys.SCREEN_WORKSHOP,
		GameStateKeys.SCREEN_RUNE,
		GameStateKeys.SCREEN_SETTINGS,
		GameStateKeys.SCREEN_SCENARIO,
	]

# そのステージをクリアしたときに開くもの（stages.json の unlocks）。
#
# ⚠ 引き金（ステージ）と対象（機能）を同じ行に置く。.gd に表を書かないこと
#   （ステージが増えたら unlocks を分けるだけで刻める）。
func get_stage_unlocks(stage_id: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = MasterDataLoader.get_stage(stage_id).get(STAGE_MASTER_UNLOCKS, null)
	if not (raw is Array):
		return result
	for entry: Variant in (raw as Array):
		result.append(str(entry))
	return result

# クリア済みステージの unlocks を、状態へ流し込み直す
# （AGENTS.md「マスターデータと状態を同期する型」。研究ツリーと同じ形）。
#
# ⚠ 一度開いたものは閉じない。unlocked_screens から消す枝を書かないこと。
#   ⚠ 完全な都度計算にすると、既存セーブで開いていた画面が次の起動で消える。
# ⚠ 書き込みは unlock_screen() を通す。screen_unlocked が飛ぶのはあの1本だけで、
#   直接 _state を書くと拠点が追従しない。
# ⚠ 起動時・ロード時・クリアした瞬間の3箇所から呼ぶ。
func _sync_unlocked_screens_from_master() -> void:
	var opened: int = 0
	var story: Dictionary = _state.get(GameStateKeys.STORY, {})
	var stages: Dictionary = story.get(GameStateKeys.STORY_STAGES, {})
	for raw_stage_id: Variant in stages:
		var entry: Variant = stages[raw_stage_id]
		if not (entry is Dictionary):
			continue
		if not bool((entry as Dictionary).get(GameStateKeys.STAGE_CLEARED, false)):
			continue
		for screen_id: String in get_stage_unlocks(str(raw_stage_id)):
			if is_screen_unlocked(screen_id):
				continue
			unlock_screen(screen_id)
			opened += 1
	print("[GameManager] _sync_unlocked_screens_from_master() -> %d opened (now %s)" % [
		opened, str(_state.get(GameStateKeys.UNLOCKED_SCREENS, {}).keys())
	])

# その種類の装飾が解放されているか（EXEC_SCREEN_UNLOCK.md 決定5）。
#
# ⚠ 種類ごとの挙動の分岐ではなく「種類 → 機能ID」の表。_part_slot_kinds() と同じ立場。
#   ⚠ 種類を足したときに触るのはこの表の1語だけ。
func is_part_kind_unlocked(part_kind: String) -> bool:
	var screen_id: String = GameStateKeys.SCREEN_RUNE if part_kind == PART_KIND_RUNE 		else GameStateKeys.SCREEN_DECORATION
	return is_screen_unlocked(screen_id)

# --- 宝箱 ---

func add_pending_chest(chest_data: Dictionary) -> void:
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	chests.append(chest_data.duplicate(true))
	_state[GameStateKeys.PENDING_CHESTS] = chests
	print("[GameManager] add_pending_chest() -> pending_count=%d" % get_pending_chest_count())
	pending_chests_changed.emit(get_pending_chest_count())

func open_chest(instance_id: String) -> bool:
	# 存在しなければ何もせずfalse。存在すればopened=trueにしてrewardsを反映
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	for i: int in range(chests.size()):
		if not (chests[i] is Dictionary):
			continue
		var chest: Dictionary = (chests[i] as Dictionary).duplicate(true)
		if str(chest.get(GameStateKeys.CHEST_INSTANCE_ID, "")) != instance_id:
			continue
		if bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			print("[GameManager] open_chest('%s') -> false (already opened)" % instance_id)
			return false
		chest[GameStateKeys.CHEST_OPENED] = true
		chests[i] = chest
		_state[GameStateKeys.PENDING_CHESTS] = chests
		# rewards を反映（既存の add_* 関数を使い回し、重複実装を避ける）
		var rewards: Dictionary = chest.get(GameStateKeys.CHEST_REWARDS, {})
		if rewards.has(GameStateKeys.REWARD_GOLD):
			add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
		if rewards.has(GameStateKeys.REWARD_GEMS):
			add_gems(int(rewards[GameStateKeys.REWARD_GEMS]))
		if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
			var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
			for mat_id: String in mats:
				add_material(mat_id, int(mats[mat_id]))
		if rewards.has(GameStateKeys.REWARD_INVENTORY) and rewards[GameStateKeys.REWARD_INVENTORY] is Dictionary:
			var items: Dictionary = rewards[GameStateKeys.REWARD_INVENTORY]
			for item_id: String in items:
				add_to_inventory(item_id, int(items[item_id]))
		print("[GameManager] open_chest('%s') -> true" % instance_id)
		pending_chests_changed.emit(get_pending_chest_count())
		return true
	print("[GameManager] open_chest('%s') -> false (not found)" % instance_id)
	return false

func get_pending_chest_count() -> int:
	# opened == false の件数
	var chests: Array = _state.get(GameStateKeys.PENDING_CHESTS, [])
	var count: int = 0
	for chest: Dictionary in chests:
		if not bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			count += 1
	return count

# --- ポモドーロ報酬 ---

func apply_pomodoro_rewards(reward_data: Dictionary) -> void:
	# gold/stamina/materialsの反映、total_pomodoro_completedの加算、
	# last_pomodoro_end_atの更新、SignalBus.pomodoro_session_completedの発火までを一括で行う
	print("[GameManager] apply_pomodoro_rewards(%s)" % reward_data)
	if reward_data.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(reward_data[GameStateKeys.REWARD_GOLD]))
	if reward_data.has(GameStateKeys.REWARD_STAMINA):
		add_stamina(int(reward_data[GameStateKeys.REWARD_STAMINA]))
	if reward_data.has(GameStateKeys.REWARD_MATERIALS) and reward_data[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = reward_data[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# total_pomodoro_completed +1
	_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(_state.get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)) + 1
	# last_pomodoro_end_at 更新
	_state[GameStateKeys.LAST_POMODORO_END_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] total_pomodoro_completed -> %d" % _state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	# 発火元をGameManagerに一本化（呼び出し元のポモドーロ画面側では発火させない・二重発火防止）
	SignalBus.pomodoro_session_completed.emit(reward_data)

# --- ポモドーロ：しきい値と宝箱 ---

# その日の累計作業分を加算する。振り返りが確定したセットのみ呼ばれる想定。
func add_focus_minutes(minutes: int) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	
	var current: int = int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))
	var new_total: int = current + minutes
	_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = new_total
	print("[GameManager] add_focus_minutes(%d) -> total=%d" % [minutes, new_total])
	# ここでしきい値判定を自動で行わず、PomodoroController 側で明示的に跨ぎを制御できるように口を開けておく
	# (指示書 7-6 は PomodoroController 側で判定する手順になっている)

# その日の累計作業分を取得する
func get_cumulative_focus_minutes() -> int:
	_refresh_daily_pomodoro_stats_if_needed()
	return int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))

# しきい値に到達済みか（同じしきい値で二重に宝箱を発生させないため）
func has_reached_threshold(threshold_min: int) -> bool:
	var reached: Array = _state.get(GameStateKeys.REACHED_CHEST_THRESHOLDS, [])
	return int(threshold_min) in reached

# しきい値到達を記録し、受け取り待ちの宝箱を積む。
# この時点では add_pending_chest() を呼ばない（受け取りは拠点帰還時）。
func record_reached_threshold(threshold_min: int, chest_type: String) -> void:
	var reached: Array = _copy_array(GameStateKeys.REACHED_CHEST_THRESHOLDS)
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	
	if not (int(threshold_min) in reached):
		reached.append(int(threshold_min))
		unclaimed.append(chest_type)
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = reached
		_state[GameStateKeys.UNCLAIMED_CHESTS] = unclaimed
		print("[GameManager] recorded threshold: %d min -> %s" % [threshold_min, chest_type])

# 受け取り待ちの宝箱の一覧を取得する
func get_unclaimed_chests() -> Array:
	return _state.get(GameStateKeys.UNCLAIMED_CHESTS, []).duplicate(true)

# 受け取り待ちの宝箱をすべて pending_chests へ移し、unclaimed_chests を空にする。
# 付与した件数を返す。
func claim_pending_chests() -> int:
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	if unclaimed.is_empty():
		return 0
	
	# ⚠ 中身は chests.json（EXEC_CHEST_REGISTRY.md §3-A）。もとは
	#   Balance.pomodoro.chest_contents（.tres）から引いていたが、.tres は E118 が
	#   見られず、素材IDの改名から漏れて無音で壊れた（EXEC_STAGE_DROPS.md §11）。
	# ⚠ unclaimed の要素は chest_id。ChestScheduleEntry.chest_type が入れている
	#   （あちらの @export 名は変えていない。改名すると .tres の値が黙って空になる）。
	var count: int = 0
	for chest_id: String in unclaimed:
		if grant_chest(chest_id, GameStateKeys.CHEST_SOURCE_POMODORO):
			count += 1

	_state[GameStateKeys.UNCLAIMED_CHESTS] = []
	print("[GameManager] claimed %d chests" % count)
	return count

# 加護の選択を記録する（選択時刻も記録し、翌日の再表示判定に使う）
func set_protection_type(protection_id: String) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = protection_id
	_state[GameStateKeys.LAST_PROTECTION_SELECTED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] set_protection_type('%s')" % protection_id)

# 今日すでに加護を選んでいるか（毎朝4:00基準）
func has_selected_protection_today() -> bool:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at == "":
		return false
	return GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system())

# 日付が変わっていれば当日データをリセットする。
func reset_daily_pomodoro_state_if_needed() -> void:
	_refresh_daily_pomodoro_stats_if_needed()

# 日付が変わっていたら累計作業分としきい値をリセットする内部関数
func _refresh_daily_pomodoro_stats_if_needed() -> void:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at != "" and not GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system()):
		print("[GameManager] new day detected - resetting daily pomodoro stats")
		_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = 0
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = []
		_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = ""
		# UNCLAIMED_CHESTS はリセットしない

func _check_chest_thresholds(_old_total: int, new_total: int) -> void:
	pass # PomodoroController 側で呼ぶため不要になったが互換性のために残すか、削除する

func add_cumulative_focus_minutes(minutes: int) -> void:
	add_focus_minutes(minutes)

func claim_unclaimed_chests() -> void:
	var _cnt = claim_pending_chests()

func is_protection_selected_today() -> bool:
	return has_selected_protection_today()

func get_cumulative_focus_minutes_today() -> int:
	return get_cumulative_focus_minutes()

# --- 戦闘報酬 ---

func apply_battle_rewards(result_data: Dictionary) -> void:
	# gold/materialsの反映、SignalBus.battle_finishedの発火までを一括で行う
	# ※ expは扱わない（レベル上げは専用素材消費型。DATA_SCHEMA.md 4-3準拠）
	# ⚠ 抽選テーブルは chests.json へ移したので、rewards には chest_id の1行しか
	#   残っていない（EXEC_CHEST_REGISTRY.md §3-E）。そのまま出して読める長さになった。
	print("[GameManager] apply_battle_rewards(%s)" % result_data)
	var rewards: Dictionary = result_data.get(GameStateKeys.BATTLE_REWARDS, {})
	if rewards.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
	if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# ⚠ rewards.inventory（EXEC_DECORATION.md §0-3 の4）。
	#   AGENTS.md の報酬 Dictionary の共通形は {gold, gems, stamina, materials, inventory} だが、
	#   ここは長いあいだ gold と materials しか読んでいなかった。ステージ報酬から
	#   アイテムも装備も1件も出せない「無音の穴」だった（stages.json に書いても落ちない）。
	#   ⚠ add_to_inventory() を通すので、装備なら個体（eq_N）になる（CLAUDE.md 8番）。
	#   ⚠ gems と stamina は今も読んでいない。使う予定が無いため（宿題に残してある）。
	if rewards.has(GameStateKeys.REWARD_INVENTORY) and rewards[GameStateKeys.REWARD_INVENTORY] is Dictionary:
		var inv: Dictionary = rewards[GameStateKeys.REWARD_INVENTORY]
		for item_id: String in inv:
			var count: int = int(inv[item_id])
			if count <= 0:
				continue
			add_to_inventory(item_id, count, str(
				MasterDataLoader.get_item(item_id).get(ITEM_MASTER_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)
			))
	# ⚠ 抽選ドロップ（EXEC_STAGE_DROPS.md §3-C）。固定報酬を全部配り終えてから引く。
	#   ⚠ battle_finished より前に呼ぶ。宝箱の件数が確定していないと、
	#     購読側が古い pending_count を読む。
	_grant_stage_chest(rewards)
	# 発火元をGameManagerに一本化（呼び出し元の戦闘画面側では発火させない・二重発火防止）
	SignalBus.battle_finished.emit(result_data)

# rewards.chest_id を読み、その宝箱を1個積む。
#
# ⚠ chest_id を持たないステージでは何もしない（黄も出さない）。書いていないのは正常。
func _grant_stage_chest(rewards: Dictionary) -> void:
	var chest_id: String = str(rewards.get(GameStateKeys.CHEST_ID, ""))
	if chest_id == "":
		return
	var _granted: bool = grant_chest(chest_id, GameStateKeys.CHEST_SOURCE_BATTLE)


# 宝箱を1個積む。chests.json の定義を引き、固定（rewards）と抽選（draw）を合流させる。
#
# ⚠ 宝箱を積む唯一の口。ポモドーロ（claim_pending_chests）も戦闘（_grant_stage_chest）も
#   ここを通す。積む形が2つあると、片方だけ直す事故が起きる（NEXT_STEPS §2-4）。
# ⚠ 中身が空なら積まない（EXEC_STAGE_DROPS.md §0-1 の3）。空の宝箱を積むと
#   「開けたのに何も出ない」になる。抽選のハズレ枠の weight が、そのまま
#   「宝箱が出ない確率」になる。
# ⚠ 状態を触るのは最後の add_pending_chest() の1回だけ（CLAUDE.md 6番）。
# ⚠ 抽選の結果は個体に焼き込む（人間の決定C・積むときに振る）。開けるときには振らない。
func grant_chest(chest_id: String, source: String) -> bool:
	var chest: Dictionary = MasterDataLoader.get_chest(chest_id)
	if chest.is_empty():
		push_warning("[GameManager] grant_chest: chests.json に無い chest_id: " + chest_id)
		return false

	# 固定ぶん。複製してから触る（マスターのキャッシュを汚さない）。
	var rewards: Dictionary = {}
	var fixed: Variant = chest.get(GameStateKeys.CHEST_REWARDS, null)
	if fixed is Dictionary:
		rewards = (fixed as Dictionary).duplicate(true)

	# 抽選ぶん。inventory に合流させる（固定で同じIDが入っていれば足す）。
	var draw_def: Variant = chest.get(CHEST_DRAW, null)
	if draw_def is Dictionary:
		var drawn: Dictionary = _roll_chest_draw(draw_def as Dictionary)
		if not drawn.is_empty():
			var inv: Dictionary = rewards.get(GameStateKeys.REWARD_INVENTORY, {})
			for item_id: String in drawn:
				inv[item_id] = int(inv.get(item_id, 0)) + int(drawn[item_id])
			rewards[GameStateKeys.REWARD_INVENTORY] = inv

	if _is_rewards_empty(rewards):
		# ⚠ 抽選のハズレは正常系。print を出さない（NEXT_STEPS §4）。
		#   70%の戦闘で出るので、出すと godot.log がこの1行で埋まる。
		return false

	add_pending_chest({
		GameStateKeys.CHEST_INSTANCE_ID: str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		GameStateKeys.CHEST_ID: chest_id,
		GameStateKeys.CHEST_SOURCE: source,
		GameStateKeys.CHEST_OBTAINED_AT: str(Time.get_unix_time_from_system()),
		GameStateKeys.CHEST_OPENED: false,
		GameStateKeys.CHEST_REWARDS: rewards,
	})
	return true


# 宝箱の中身が実質空か。gold/gems/stamina は0、materials/inventory は空なら空とみなす。
func _is_rewards_empty(rewards: Dictionary) -> bool:
	for key: String in [GameStateKeys.REWARD_GOLD, GameStateKeys.REWARD_GEMS, GameStateKeys.REWARD_STAMINA]:
		if int(rewards.get(key, 0)) > 0:
			return false
	for key: String in [GameStateKeys.REWARD_MATERIALS, GameStateKeys.REWARD_INVENTORY]:
		var table: Variant = rewards.get(key, {})
		if table is Dictionary and not (table as Dictionary).is_empty():
			return false
	return true

# 重み付きテーブルを rolls 回引く。戻りは {item_id: count}（rewards.inventory と同じ形）。
#
# ⚠ 抽選はこの1本だけ。同じ形の判定を散らさない（NEXT_STEPS §2-4）。
# ⚠ item_id が "" の枠はハズレ。当たっても何も足さない。
# ⚠ weight の合計が0以下なら空を返す。randi_range(1, 0) を踏まないため。
# ⚠ MasterDataLoader が返す数値は float なので、rolls も weight も count も int() で包む
#   （CLAUDE.md 3番）。包み忘れると randi_range に float が渡って黙って壊れる。
# ⚠ 乱数は固定しない（装飾のロールと同じ）。検証は分布で見る。
func _roll_chest_draw(draw_def: Dictionary) -> Dictionary:
	var drawn: Dictionary = {}
	var rows: Variant = draw_def.get(CHEST_DRAW_ENTRIES, [])
	if not (rows is Array):
		return drawn
	var list: Array = rows as Array

	var total_weight: int = 0
	for row: Variant in list:
		if not (row is Dictionary):
			continue
		total_weight += maxi(0, int((row as Dictionary).get(CHEST_DRAW_WEIGHT, 0)))
	if total_weight <= 0:
		return drawn

	var rolls: int = int(draw_def.get(CHEST_DRAW_ROLLS, 1))
	for _i: int in range(rolls):
		var pick: int = randi_range(1, total_weight)
		var cursor: int = 0
		for row: Variant in list:
			if not (row is Dictionary):
				continue
			var entry: Dictionary = row as Dictionary
			cursor += maxi(0, int(entry.get(CHEST_DRAW_WEIGHT, 0)))
			if pick > cursor:
				continue
			var item_id: String = str(entry.get(CHEST_DRAW_ITEM_ID, ""))
			if item_id != "":
				var count: int = maxi(1, int(entry.get(CHEST_DRAW_COUNT, 1)))
				drawn[item_id] = int(drawn.get(item_id, 0)) + count
			break
	return drawn

# --- 倉庫：図鑑・インベントリ整理 ---

func get_codex_entry(item_id: String) -> Dictionary:
	var codex: Dictionary = _state.get(GameStateKeys.CODEX, {})
	var entry: Dictionary = codex.get(item_id, {})
	return entry.duplicate(true)

func update_inventory_slot_position(item_id: String, position: Vector2i) -> void:
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	if not inventory.has(item_id):
		print("[GameManager] update_inventory_slot_position('%s') -> item not in inventory" % item_id)
		return
	var entry: Dictionary = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: position.x, GameStateKeys.POS_Y: position.y}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	print("[GameManager] update_inventory_slot_position('%s', %s)" % [item_id, position])
	inventory_changed.emit(item_id)

# --- ショップ ---

func _shop_key(shop_type: String) -> String:
	match shop_type:
		GameStateKeys.SHOP_TYPE_DAILY:
			return GameStateKeys.DAILY_SHOP
		GameStateKeys.SHOP_TYPE_WEEKLY:
			return GameStateKeys.WEEKLY_SHOP
		GameStateKeys.SHOP_TYPE_MONTHLY:
			return GameStateKeys.MONTHLY_SHOP
	return ""

func get_shop_lineup(shop_type: String) -> Array:
	var key: String = _shop_key(shop_type)
	if key == "":
		print("[GameManager] get_shop_lineup('%s') -> unknown shop_type" % shop_type)
		return []
	var shop: Dictionary = _state.get(key, {})
	var line_up: Variant = shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if line_up is Array:
		return (line_up as Array).duplicate(true)
	return []

# 商品を1つ購入する。
# 不明な shop_type・存在しない slot_id・売り切れ・残高不足のときは
# 何もせず false を返す。成功時は通貨を減らし、素材またはアイテムを増やして
# shop_changed を発火する。
#
# 判定の順番は unlock_research_node() と揃える：
#   存在 → 在庫 → 残高 → （ここから状態を変える）
# add_gold() / add_gems() は残高を確認しないため、減算する前に必ずここで確認する。
func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] purchase_shop_item: unknown shop_type: " + shop_type)
		return false

	var shop: Dictionary = _state.get(key, {})
	var line_up: Variant = shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if not (line_up is Array):
		push_warning("[GameManager] purchase_shop_item: line_up is not Array: " + shop_type)
		return false

	var index: int = _find_shop_slot_index(line_up as Array, slot_id)
	if index < 0:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (slot not found)" % [shop_type, slot_id])
		return false

	var slot: Dictionary = (line_up as Array)[index]

	# 在庫。stock_limit が 0 以下のスロットは「無制限」ではなく「買えない」として扱う。
	# 0 を無制限にすると、shop.json の書き忘れがそのまま無限購入になる。
	var stock_limit: int = int(slot.get(GameStateKeys.SHOP_STOCK_LIMIT, 0))
	var purchased_count: int = int(slot.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0))
	if stock_limit <= 0 or purchased_count >= stock_limit:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (sold out: %d/%d)" % [
			shop_type, slot_id, purchased_count, stock_limit
		])
		return false

	# 受け取るもの。状態を変える前に不正な定義を弾いておく
	# （通貨を減らしたあとで「渡せません」が起きないようにするため）。
	var item_id: String = str(slot.get(GameStateKeys.SHOP_ITEM_ID, ""))
	var payout_type: String = str(slot.get(SHOP_SLOT_PAYOUT_TYPE, PAYOUT_TYPE_ITEM))
	var payout_count: int = int(slot.get(SHOP_SLOT_PAYOUT_COUNT, 1))
	if item_id == "":
		push_warning("[GameManager] purchase_shop_item: item_id が未設定（shop.json）: slot %d" % slot_id)
		return false
	if payout_count <= 0:
		push_warning("[GameManager] purchase_shop_item: count が 0 以下（shop.json）: slot %d" % slot_id)
		return false
	if payout_type != PAYOUT_TYPE_MATERIAL and payout_type != PAYOUT_TYPE_ITEM:
		push_warning("[GameManager] purchase_shop_item: 未知の payout_type: " + payout_type)
		return false

	# 残高
	var cost: Dictionary = slot.get(GameStateKeys.SHOP_COST, {})
	var currency_type: String = str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, ""))
	var amount: int = int(cost.get(GameStateKeys.COST_AMOUNT, 0))
	if amount < 0:
		push_warning("[GameManager] purchase_shop_item: cost.amount が負（shop.json）: slot %d" % slot_id)
		return false
	var balance: int = _get_currency_balance(currency_type)
	if balance < 0:
		push_warning("[GameManager] purchase_shop_item: 未知の currency_type: " + currency_type)
		return false
	if balance < amount:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (%s: %d < %d)" % [
			shop_type, slot_id, currency_type, balance, amount
		])
		return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# _copy_dict() は浅いコピーのため、line_up の配列と各スロットを
	# duplicate(true) してから書き換える。これを飛ばすと _state 内の実体を直接触る。
	var new_shop: Dictionary = _copy_dict(key)
	var new_line_up: Array = (line_up as Array).duplicate(true)
	var new_slot: Dictionary = new_line_up[index]
	new_slot[GameStateKeys.SHOP_PURCHASED_COUNT] = purchased_count + 1
	new_line_up[index] = new_slot
	new_shop[GameStateKeys.SHOP_LINE_UP] = new_line_up
	_state[key] = new_shop

	# 通貨の減算・受け取りはラインナップを更新したあとに行う。
	# resource_changed / material_changed を受けて再描画する画面が、
	# 購入済み回数が増えた状態を見られるようにするため。
	if amount > 0:
		_spend_currency(currency_type, amount)

	if payout_type == PAYOUT_TYPE_MATERIAL:
		add_material(item_id, payout_count)
	else:
		add_to_inventory(item_id, payout_count, str(slot.get(SHOP_SLOT_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)))

	print("[GameManager] purchase_shop_item('%s', %d) -> true (%s x%d for %s %d, stock %d/%d)" % [
		shop_type, slot_id, item_id, payout_count, currency_type, amount,
		purchased_count + 1, stock_limit
	])
	shop_changed.emit(shop_type)
	return true

# ゲーム内の日付が変わっていれば購入回数を戻す。
#
# 第1弾はラインナップが固定のため、リフレッシュ＝「purchased_count を 0 に戻す」だけ。
# 抽選を入れる場合も、この関数の中でラインナップを組み直せば呼び出し側は変わらない。
#
# 日付の判定は必ず GameDate を経由する。ここで Time を直接使うと、
# ポモドーロの加護選択・ストリークと 4:00 の基準がずれる。
func refresh_shop_if_needed(shop_type: String) -> void:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] refresh_shop_if_needed: unknown shop_type: " + shop_type)
		return

	# 週替わり・月替わりは第1弾では未実装（週・月の区切りが未確定のため）。
	# 誤って日単位でリセットしないよう、ここで明示的に何もせず返す。
	if shop_type != GameStateKeys.SHOP_TYPE_DAILY:
		print("[GameManager] refresh_shop_if_needed('%s') -> skip (第1弾は daily のみ)" % shop_type)
		return

	var shop: Dictionary = _state.get(key, {})
	var last_refreshed: String = str(shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))
	var today: String = GameDate.get_game_date_string()
	if last_refreshed == today:
		print("[GameManager] refresh_shop_if_needed('%s') -> no refresh (%s)" % [shop_type, today])
		return

	var new_shop: Dictionary = _copy_dict(key)
	var line_up: Variant = new_shop.get(GameStateKeys.SHOP_LINE_UP, [])
	var new_line_up: Array = []
	if line_up is Array:
		new_line_up = (line_up as Array).duplicate(true)
	for i: int in range(new_line_up.size()):
		if not (new_line_up[i] is Dictionary):
			continue
		var slot: Dictionary = new_line_up[i]
		slot[GameStateKeys.SHOP_PURCHASED_COUNT] = 0
		new_line_up[i] = slot
	new_shop[GameStateKeys.SHOP_LINE_UP] = new_line_up
	new_shop[GameStateKeys.SHOP_REFRESH_AT] = today
	_state[key] = new_shop

	print("[GameManager] refresh_shop_if_needed('%s') -> refreshed (%s -> %s, %d slots)" % [
		shop_type, last_refreshed, today, new_line_up.size()
	])
	shop_changed.emit(shop_type)

# --- ショップ：内部ヘルパー ---

# line_up の中から slot_id が一致する要素の位置を返す。見つからなければ -1。
# 配列の添字と slot_id は一致するとは限らない（shop.json で歯抜けの番号を振れるため）。
func _find_shop_slot_index(line_up: Array, slot_id: int) -> int:
	for i: int in range(line_up.size()):
		if not (line_up[i] is Dictionary):
			continue
		if int((line_up[i] as Dictionary).get(GameStateKeys.SHOP_SLOT_ID, -1)) == slot_id:
			return i
	return -1

# 通貨の所持数。未知の currency_type では -1 を返す（0 と区別するため）。
func _get_currency_balance(currency_type: String) -> int:
	match currency_type:
		GameStateKeys.GOLD:
			return int(_state.get(GameStateKeys.GOLD, 0))
		GameStateKeys.GEMS:
			return int(_state.get(GameStateKeys.GEMS, 0))
	return -1

# 残高の確認は呼び出し側で済ませてあること。この関数は確認しない。
func _spend_currency(currency_type: String, amount: int) -> void:
	match currency_type:
		GameStateKeys.GOLD:
			add_gold(-amount)
		GameStateKeys.GEMS:
			add_gems(-amount)

# shop.json の定義を各ショップの line_up へ流し込む。
#
# purchased_count だけは既存の値を残し、それ以外（item_id / cost / stock_limit /
# payout_type / count / item_type）は毎回マスターデータで上書きする。
# これで shop.json の価格を変えると、既存セーブにも次の起動で反映される。
# 研究の _sync_research_tree_from_master() と同じ型（AGENTS.md「マスターデータと状態を同期する型」）。
#
# refresh_at には触らない。ここで消すと、起動するたびに購入回数が戻る。
#
# shop.json から消えた slot_id はラインナップからも消える。
# slot_id を振り直すと購入回数が別の商品に付け替わるため、番号は使い回さないこと。
func _sync_shops_from_master() -> void:
	for shop_type: String in MasterDataLoader.get_all_shop_types():
		_sync_shop_from_master(shop_type)

func _sync_shop_from_master(shop_type: String) -> void:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] _sync_shop_from_master: shop.json に未知の shop_type: " + shop_type)
		return

	var slots: Array = MasterDataLoader.get_shop_slots(shop_type)
	if slots.is_empty():
		push_warning("[GameManager] _sync_shop_from_master: shop.json の '%s' が空か読み込めない" % shop_type)
		return

	# 既存の購入回数を slot_id で引けるようにしておく
	var current_shop: Dictionary = _state.get(key, {})
	var current_counts: Dictionary = {}
	var current_line_up: Variant = current_shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if current_line_up is Array:
		for entry: Variant in (current_line_up as Array):
			if not (entry is Dictionary):
				continue
			var existing: Dictionary = entry
			var existing_slot_id: int = int(existing.get(GameStateKeys.SHOP_SLOT_ID, -1))
			current_counts[existing_slot_id] = int(existing.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0))

	var synced: Array = []
	for entry: Variant in slots:
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = entry
		var slot_id: int = int(definition.get(GameStateKeys.SHOP_SLOT_ID, -1))
		if slot_id < 0:
			push_warning("[GameManager] _sync_shop_from_master: slot_id が無いスロットを飛ばした")
			continue

		# MasterDataLoader は JSON をそのまま返すため数値は float で来る。int() 必須。
		# 包み忘れるとセーブに 100.0 と書かれる。
		var stock_limit: int = int(definition.get(GameStateKeys.SHOP_STOCK_LIMIT, 0))
		var purchased_count: int = int(current_counts.get(slot_id, 0))
		# stock_limit を下げたとき、購入回数が上限を超えたまま残らないようにする
		if purchased_count > stock_limit:
			purchased_count = stock_limit

		var cost_definition: Dictionary = definition.get(GameStateKeys.SHOP_COST, {})
		synced.append({
			GameStateKeys.SHOP_SLOT_ID: slot_id,
			GameStateKeys.SHOP_ITEM_ID: str(definition.get(GameStateKeys.SHOP_ITEM_ID, "")),
			GameStateKeys.SHOP_COST: {
				GameStateKeys.COST_CURRENCY_TYPE: str(cost_definition.get(GameStateKeys.COST_CURRENCY_TYPE, GameStateKeys.GOLD)),
				GameStateKeys.COST_AMOUNT: int(cost_definition.get(GameStateKeys.COST_AMOUNT, 0)),
			},
			GameStateKeys.SHOP_STOCK_LIMIT: stock_limit,
			GameStateKeys.SHOP_PURCHASED_COUNT: purchased_count,
			SHOP_SLOT_PAYOUT_TYPE: str(definition.get(SHOP_SLOT_PAYOUT_TYPE, PAYOUT_TYPE_ITEM)),
			SHOP_SLOT_PAYOUT_COUNT: int(definition.get(SHOP_SLOT_PAYOUT_COUNT, 1)),
			SHOP_SLOT_ITEM_TYPE: str(definition.get(SHOP_SLOT_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)),
		})

	var new_shop: Dictionary = _copy_dict(key)
	new_shop[GameStateKeys.SHOP_LINE_UP] = synced
	if not new_shop.has(GameStateKeys.SHOP_REFRESH_AT):
		new_shop[GameStateKeys.SHOP_REFRESH_AT] = ""
	_state[key] = new_shop

	print("[GameManager] _sync_shop_from_master('%s') -> %d slots (refresh_at='%s')" % [
		shop_type, synced.size(), str(new_shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))
	])

# --- 育成 ---

# 育成データを返す。エントリが無ければ characters.json から既定値（レベル1）を組み立てて返す。
#
# 既定値は _state に書き込まない。理由：
#  - レベル1のキャラはセーブデータに現れず、キャラクターを追加しても移行処理が要らない
#  - 「読んだだけで状態が変わる」getter を作らない
func get_character_growth(character_id: String) -> Dictionary:
	var growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var entry: Dictionary = growth.get(character_id, {})
	if entry.is_empty():
		return _default_growth_for(character_id)
	return entry.duplicate(true)

# 保存されている素の値に、研究と装備のボーナスを合成した最終値を返す。
# 表示と戦闘の両方がこちらを使う。
#
# stats そのものに研究・装備の効果を混ぜないのは、研究ノードの効果値や装備の性能値を
# 変えたときに、既存セーブの stats が実態とずれるのを避けるため。
# 状態が持つのは「どのレベルか」「どの item_id を装備しているか」だけ。
func get_effective_stats(character_id: String) -> Dictionary:
	var growth: Dictionary = get_character_growth(character_id)
	var raw: Dictionary = growth.get(GameStateKeys.GROWTH_STATS, {})
	var boosts: Dictionary = get_stat_boost_all()
	var boost_all: int = int(boosts.get(STAT_BOOST_ALL_KEY, 0))
	var equip: Dictionary = get_equipment_bonus(character_id)
	# 割り振り（ステータスノード）。5項目めとして足す。
	# これを忘れると「ノードを押しても戦闘にも育成画面にも出ない」になる。
	var nodes: Dictionary = get_stat_node_bonus(character_id)

	var result: Dictionary = {}
	var percent_keys: Array[String] = _percent_stat_keys()
	for stat_key: String in _stat_keys():
		# 研究の「全ステータス+N」は実数軸だけに乗せる。
		# ％軸に乗せると1ノードで会心率とCD短縮が同時に上がる（_percent_stat_keys()）。
		var all_bonus: int = 0 if stat_key in percent_keys else boost_all
		result[stat_key] = (
			int(raw.get(stat_key, 0))
			+ int(boosts.get(stat_key, 0))
			+ all_bonus
			+ int(equip.get(stat_key, 0))
			+ int(nodes.get(stat_key, 0))
		)
	return result

# 現在のレベルから1つ上げるのに必要な素材を返す。
# 戻り値: {material_id: String, amount: int}
func get_level_up_cost(character_id: String) -> Dictionary:
	var empty: Dictionary = {LEVEL_UP_COST_MATERIAL_ID: "", LEVEL_UP_COST_AMOUNT: 0}
	if Balance == null or Balance.character == null:
		push_warning("[GameManager] get_level_up_cost: Balance.character is null")
		return empty

	var config: CharacterConfig = Balance.character
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var base: float = float(config.base_level_up_cost)
	var growth: float = config.cost_growth_per_level
	var fallback: float = base + growth * float(level - 1)

	var amount: int = GrowthFormula.evaluate_int(
		config.level_up_cost_formula,
		{"base": base, "growth": growth, "level": float(level)},
		fallback
	)
	if amount < 0:
		amount = 0

	return {
		LEVEL_UP_COST_MATERIAL_ID: config.level_up_material_id,
		LEVEL_UP_COST_AMOUNT: amount,
	}

# レベルを1つ上げる。上限到達・素材不足のときは何もせず false を返す。
# 成功時は素材を消費し、stats を再計算して character_growth_changed を発火する。
func level_up_character(character_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		push_warning("[GameManager] level_up_character: unknown character_id: " + character_id)
		return false

	var level: int = int(growth.get(GameStateKeys.GROWTH_LEVEL, 1))
	var cap: int = get_effective_level_cap(character_id)
	if level >= cap:
		print("[GameManager] level_up_character('%s') -> false (level %d >= cap %d)" % [character_id, level, cap])
		return false

	var cost: Dictionary = get_level_up_cost(character_id)
	var material_id: String = str(cost.get(LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(LEVEL_UP_COST_AMOUNT, 0))
	if material_id == "":
		push_warning("[GameManager] level_up_character: level_up_material_id が未設定（character_config.tres）")
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	var owned: int = get_material_count(material_id)
	if owned < amount:
		print("[GameManager] level_up_character('%s') -> false (material %s: %d < %d)" % [
			character_id, material_id, owned, amount
		])
		return false

	if amount > 0:
		add_material(material_id, -amount)

	var new_level: int = level + 1
	# growth は get_character_growth() が返した複製なので、直接書き換えてよい。
	growth[GameStateKeys.GROWTH_LEVEL] = new_level
	growth[GameStateKeys.GROWTH_STATS] = _recalc_stats(character_id, new_level)

	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	all_growth[character_id] = growth
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth

	print("[GameManager] level_up_character('%s') -> true (level=%d stats=%s)" % [
		character_id, new_level, growth[GameStateKeys.GROWTH_STATS]
	])
	character_growth_changed.emit(character_id)
	return true

# --- 育成：内部ヘルパー ---

# stats のキー10本（GAME_DESIGN.md 8-1）。並びは 8-1 の表と同じ順。
# 順序を固定したいので配列で持つ。
#
# ここに足すと追従するもの：
#   get_effective_stats() / get_instance_stats() / get_equipment_bonus()
#   _default_growth_for() / _recalc_stats() / load_state() の int() 正規化
#
# 戦闘も追従する（EXEC_STATS_10_AXES_FORMULA.md）：
#   BattleUnit.create() が get_stat_keys() を回して 10軸を取り込む。
#   ただし式（どの軸をどう使うか）は BattleFormula と BattleUnit.get_power() /
#   get_defense() にあるので、新しい軸を「効かせる」にはそちらも直すこと。
func _stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_HP,
		GameStateKeys.STAT_ATK,
		GameStateKeys.STAT_MAG,
		GameStateKeys.STAT_DEF,
		GameStateKeys.STAT_MDEF,
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
		GameStateKeys.STAT_SPD,
	]

# 画面がステータスをこの順で並べるために公開する（get_equip_slots() と同じ形）。
# 画面側に軸の配列を複製させないこと。以前 equipment_screen.gd に
# _stat_labels() という2本目の4軸配列があり、片方だけ直す事故の元になっていた。
func get_stat_keys() -> Array[String]:
	return _stat_keys()

# ％で持つ軸（GAME_DESIGN.md 8-1）。実数軸と同じ stats 辞書に入るが、扱いが2箇所だけ違う。
#
#  1. 研究の「全ステータス+N」（stat_boost_all の target_stat = "all"）の対象にしない
#  2. 画面に "%" を付けて出す
#
# 1 を守らないと、研究ノード1つで crit_rate と haste が同時に上がる。
# ％系は装備と装飾だけで動かす前提（PLAN_STATS_AND_FORMULAS.md 4章）なので、
# 研究で上がると装飾を刺す理由が消える。
#
# なお target_stat で名指しされた加算（boosts.get(stat_key)）は％軸にも効かせる。
# 「会心率を上げる研究ノード」を将来置けるようにするため。
func _percent_stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
	]

# 画面が "%" を付けるかどうかの判定に使う。
func is_percent_stat(stat_key: String) -> bool:
	return stat_key in _percent_stat_keys()

# characters.json からレベル1の既定値を組み立てる。存在しないIDなら空を返す。
#
# MasterDataLoader は JSON をそのまま返すため、数値は float で来る。
# int() で包まないと、セーブに "hp": 120.0 と書かれる。
func _default_growth_for(character_id: String) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		stats[stat_key] = int(char_data.get(stat_key, 0))

	return {
		GameStateKeys.GROWTH_LEVEL: 1,
		GameStateKeys.GROWTH_STATS: stats,
		# 解放済みステータスノードのID配列。レベル1では空。
		# 効果値はここに複製せず、character_nodes.json から毎回引く。
		GameStateKeys.GROWTH_NODES: [],
		# 選択したスキルIDの2枠（EXEC_SKILL_SELECT.md §5）。レベル1では両方 ""。
		# 空の枠は戦闘時に候補の先頭で埋めるため、ここでマスターを複製しない。
		GameStateKeys.GROWTH_SKILLS: {
			GameStateKeys.GROWTH_SKILL_SLOTS: _empty_slots(SLOT_KIND_SKILL),
		},
		# パッシブ枠（EXEC_SKILL_PASSIVE_VARS.md §3-4）。⚠ スキル枠とは別枠。
		# ⚠ 空の枠は戦闘時に埋めない（埋めると外したつもりのものが勝手に付く）。
		GameStateKeys.GROWTH_PASSIVES: {
			GameStateKeys.GROWTH_SKILL_SLOTS: _empty_slots(SLOT_KIND_PASSIVE),
		},
		GameStateKeys.GROWTH_EQUIPMENT: {
			GameStateKeys.EQUIP_HEAD: null,
			GameStateKeys.EQUIP_ARMOR: null,
			GameStateKeys.EQUIP_LEGS: null,
			GameStateKeys.EQUIP_WEAPON: null,
			GameStateKeys.EQUIP_ACCESSORY: null,
		},
	}

# 指定レベルにおける stats を、stat_growth_formula で計算し直す。
# 差分を足し込むのではなく毎回レベルから計算するため、式を変えても既存データが追従する。
func _recalc_stats(character_id: String, level: int) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var growth_table: Dictionary = char_data.get("growth_per_level", {})
	var formula: String = ""
	if Balance != null and Balance.character != null:
		formula = Balance.character.stat_growth_formula

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		var base: float = float(char_data.get(stat_key, 0))
		# growth_per_level を持たないキャラは 0 として扱う（伸びないだけで、エラーにしない）。
		var growth: float = float(growth_table.get(stat_key, 0))
		var fallback: float = base + growth * float(level - 1)
		stats[stat_key] = GrowthFormula.evaluate_int(
			formula,
			{"base": base, "growth": growth, "level": float(level)},
			fallback
		)
	return stats

# セーブから戻した stats を、現在の stat_growth_formula で全キャラ計算し直す。
# load_state() から呼ぶ（_sync_research_tree_from_master() と同じ位置づけ）。
#
# これが無いと、式や characters.json の基礎値を変えたときに
# 「新規開始では効くが、ロードすると古い値のまま」になる。
# PLAN_IMPLEMENTATION.md 1章の未チェック項目「ロード時に _recalc_stats() を通る経路がある」はこれ。
#
# _state を直接触る。load_state() が _state へ代入したあとにしか呼ばれない。
func _resync_growth_stats_from_master() -> void:
	var growth_all: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	for character_id: String in growth_all:
		if not (growth_all[character_id] is Dictionary):
			continue
		var entry: Dictionary = growth_all[character_id]
		var level: int = int(entry.get(GameStateKeys.GROWTH_LEVEL, 1))
		var recalculated: Dictionary = _recalc_stats(character_id, level)
		# characters.json から消えたキャラは _recalc_stats() が {} を返す。
		# 空で上書きすると全ステータスが 0 になるため、そのまま残す。
		if recalculated.is_empty():
			continue
		entry[GameStateKeys.GROWTH_STATS] = recalculated

# --- 装備：スロット ---

# 装備できるスロット名。順序を固定したいので配列で持つ（_stat_keys() と同じ形）。
# 画面もこの順で並ぶ：頭・上半身・下半身・武器・アクセサリー。
# armor は「上半身」の内部キー。改名しない（既存セーブのキーが変わるため）。
func _equip_slots() -> Array[String]:
	return [
		GameStateKeys.EQUIP_HEAD,
		GameStateKeys.EQUIP_ARMOR,
		GameStateKeys.EQUIP_LEGS,
		GameStateKeys.EQUIP_WEAPON,
		GameStateKeys.EQUIP_ACCESSORY,
	]

# 画面が「頭・上半身・…」の順でスロットを並べるために公開する。
func get_equip_slots() -> Array[String]:
	return _equip_slots()

# --- 装備：個体 ---

# item_id が装備品かどうか。items.json だけで判定する。
func _is_equipment_item(item_id: String) -> bool:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return false
	return str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_EQUIPMENT

# 個体1つ分。存在しなければ空。
func get_equipment_instance(instance_id: String) -> Dictionary:
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	var entry: Variant = instances.get(instance_id, null)
	if not (entry is Dictionary):
		return {}
	return (entry as Dictionary).duplicate(true)

# 個体を1つ作る。戻り値は新しい instance_id。
# 呼ぶのは add_to_inventory() だけ（シグナルもそちらが1本だけ飛ばす）。
func _create_equipment_instance(item_id: String) -> String:
	var next_id: int = int(_state.get(GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID, 1))
	var instance_id: String = INSTANCE_ID_PREFIX + str(next_id)

	# parts は null 込みの長さ固定配列。位置が枠を表す。
	# 「刺さっているものだけ入れる」形にすると、どちらの枠か分からなくなる。
	var parts: Array = []
	for i: int in range(PART_SLOT_COUNT):
		parts.append(null)

	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances[instance_id] = {
		GameStateKeys.INSTANCE_ITEM_ID: item_id,
		GameStateKeys.INSTANCE_GRADE: 1,
		GameStateKeys.INSTANCE_PARTS: parts,
	}
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances
	_state[GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID] = next_id + 1

	print("[GameManager] _create_equipment_instance('%s') -> %s" % [item_id, instance_id])
	return instance_id

# 個体1つ分を _state へ書き戻す（_write_growth() と同じ形）。
func _write_instance(instance_id: String, instance: Dictionary) -> void:
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances[instance_id] = instance
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

# その個体を装備しているキャラのID。どこにも装備していなければ ""。
# 在庫から出し入れせず「どこかのスロットに入っているか」で絞る（PLAN 2-2）。
func _equipped_owner(instance_id: String) -> String:
	if instance_id == "":
		return ""
	var all_growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	for character_id: String in all_growth:
		if not (all_growth[character_id] is Dictionary):
			continue
		var equipment: Variant = (all_growth[character_id] as Dictionary).get(GameStateKeys.GROWTH_EQUIPMENT, {})
		if not (equipment is Dictionary):
			continue
		for slot: String in _equip_slots():
			var value: Variant = (equipment as Dictionary).get(slot, null)
			if value != null and str(value) == instance_id:
				return character_id
	return ""

# 部位と等級から、開いている枠の数を数える。状態には持たない（PLAN 2-2）。
#
# ⚠ 部位を引数に取るのは、特別枠2（位置3）がアクセサリーにしか無いため。
#   等級だけでは数が決まらない（GAME_DESIGN.md 6-4）。
func get_open_part_slot_count(equip_slot: String, grade: int) -> int:
	var count: int = 0
	for def: Variant in get_part_slot_defs(equip_slot):
		if _is_slot_open(def, grade):
			count += 1
	return count

func _is_slot_open(def: Variant, grade: int) -> bool:
	if not (def is Dictionary):
		return false
	var kinds: Variant = (def as Dictionary).get(PART_VIEW_KINDS, [])
	# 刺さる種類が1つも無い枠は「この部位には無い枠」。等級をいくら上げても開かない。
	if not (kinds is Array) or (kinds as Array).is_empty():
		return false
	return grade >= int((def as Dictionary).get(PART_VIEW_MIN_GRADE, 0))

# --- 装備：性能 ---

# 個体1つ分のステータス加算。{hp, atk, def, spd} を必ず4つ返す。
#
# 性能値は状態に持たない。equip_stats × 等級係数で毎回計算する。
# こうすると items.json を調整したときに既存の個体へも次の起動で反映される。
#
# 等級1が素の値。1つ上がるごとに基礎値の GRADE_STAT_RATIO 倍を加算する（乗算にしない）。
# MasterDataLoader は JSON をそのまま返すため、必ず int() で包む。
func get_instance_stats(instance_id: String) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in _stat_keys():
		result[stat_key] = 0

	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return result

	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		# items.json から消えたIDを装備したまま。装備は外れないが加算されない。
		# リリース後にアイテムIDを改名しないこと（レシピIDと同じ制約）。
		push_warning("[GameManager] get_instance_stats: items.json に無いID: " + item_id)
		return result

	var equip_stats: Variant = definition.get(ITEM_MASTER_EQUIP_STATS, {})
	if not (equip_stats is Dictionary):
		return result

	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	for stat_key: String in _stat_keys():
		var base: int = int((equip_stats as Dictionary).get(stat_key, 0))
		result[stat_key] = base + int(floor(float(base) * GRADE_STAT_RATIO * float(grade - 1)))

	# 刺さっている装飾の加算（EXEC_DECORATION.md §1-2）。
	# ⚠ 装飾がステータスに乗る合流点はここ1箇所だけ。この先は
	#   get_equipment_bonus() → get_effective_stats() → 戦闘・画面 と既存の経路で流れる。
	# ⚠ 何も刺していなければ1つも足さない（装飾を使わないプレイヤーの数値は変わらない）。
	_add_part_stats(instance_id, instance, result)
	return result

# 刺さっている装飾の加算を result に足す。
#
# ⚠ W18：加算できない装飾は「足さないが、parts からは消さない」。
#   push_warning を1本出して残す（PLAN_CHARACTER_GROWTH_LOOP.md 3-2 の [x] が
#   名指しで要求している形。黙って倉庫に返すと「無くなった」に見える）。
#
# ⚠ 枠を減らす変更（part_slot_min_grades を伸ばす・特別枠を消す等）をしたときに、
#   あふれた装飾がここに来る。_is_slot_open() が false になる枝がそれ。
func _add_part_stats(instance_id: String, instance: Dictionary, result: Dictionary) -> void:
	var raw_parts: Variant = instance.get(GameStateKeys.INSTANCE_PARTS, [])
	if not (raw_parts is Array):
		return
	var parts: Array = raw_parts
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	var defs: Array = get_part_slot_defs(_instance_equip_slot(instance_id))

	for i: int in range(parts.size()):
		var entry: Variant = parts[i]
		if not (entry is Dictionary):
			continue
		var part_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))

		if i >= defs.size() or not _is_slot_open(defs[i], grade):
			push_warning("[GameManager] W18 %s: 枠%d は開いていないのに '%s' が刺さっている（加算しないが消さない）" % [
				instance_id, i, part_id
			])
			continue

		var definition: Dictionary = get_part_definition(part_id)
		if definition.is_empty():
			push_warning("[GameManager] W18 %s: items.json に無い装飾 '%s' が刺さっている（加算しないが消さない）" % [
				instance_id, part_id
			])
			continue

		var kind: String = str(definition.get(ITEM_MASTER_PART_KIND, ""))
		if not (kind in (defs[i] as Dictionary).get(PART_VIEW_KINDS, [])):
			push_warning("[GameManager] W18 %s: 枠%d に刺さらない装飾 '%s'（種類 %s）が刺さっている（加算しないが消さない）" % [
				instance_id, i, part_id, kind
			])
			continue

		var stat_key: String = str(definition.get(ITEM_MASTER_PART_STAT, ""))

		# ステータスを足さない装飾（ルーン）。加算の欄を持たないものは黙って飛ばす。
		# ⚠ part_kind で分岐しないこと（下の _part_slot_kinds() の注記）。
		#   「加算の欄があるか」だけを見れば、種類を足しても効く。
		# ⚠ W18 より上に置くこと。下に置くと黄を出してから飛ばすことになり、
		#   ルーンを刺しているだけで戦闘のたびに黄が並ぶ。
		if stat_key == "":
			continue

		if not result.has(stat_key):
			push_warning("[GameManager] W18 %s: 装飾 '%s' の part_stat '%s' が10軸に無い（加算しないが消さない）" % [
				instance_id, part_id, stat_key
			])
			continue

		result[stat_key] = int(result[stat_key]) + get_part_stat_value(entry)

# 装備している個体のステータス加算の合計。{hp, atk, def, spd} を必ず4つ返す。
func get_equipment_bonus(character_id: String) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in _stat_keys():
		result[stat_key] = 0

	for slot: String in _equip_slots():
		var instance_id: String = get_equipped_instance_id(character_id, slot)
		if instance_id == "":
			continue
		var stats: Dictionary = get_instance_stats(instance_id)
		for stat_key: String in _stat_keys():
			result[stat_key] = int(result[stat_key]) + int(stats.get(stat_key, 0))
	return result

# --- 装備：一覧 ---

# 指定スロットに装備している個体ID。何も装備していなければ ""。
func get_equipped_instance_id(character_id: String, slot: String) -> String:
	var growth: Dictionary = get_character_growth(character_id)
	var equipment: Dictionary = growth.get(GameStateKeys.GROWTH_EQUIPMENT, {})
	var value: Variant = equipment.get(slot, null)
	if value == null:
		return ""
	return str(value)

# 持っている装備の個体を全部返す。倉庫が一覧を描くために使う。
# 戻り値: [{instance_id, item_id, grade, parts, stats, equipped_by, sort_order}]
# sort_order の昇順 → 等級の降順。
func get_owned_instances() -> Array:
	var result: Array = []
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	for instance_id: String in instances:
		var instance: Dictionary = get_equipment_instance(instance_id)
		if instance.is_empty():
			continue
		var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		var definition: Dictionary = MasterDataLoader.get_item(item_id)
		result.append({
			INSTANCE_VIEW_ID: instance_id,
			GameStateKeys.INSTANCE_ITEM_ID: item_id,
			GameStateKeys.INSTANCE_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
			GameStateKeys.INSTANCE_PARTS: instance.get(GameStateKeys.INSTANCE_PARTS, []),
			INSTANCE_VIEW_STATS: get_instance_stats(instance_id),
			INSTANCE_VIEW_EQUIPPED_BY: _equipped_owner(instance_id),
			INSTANCE_VIEW_SORT_ORDER: int(definition.get(RECIPE_SORT_ORDER, 0)),
		})
	_sort_instance_view(result)
	return result

# 指定スロットに着けられる、どこにも装備していない個体。装備画面の一覧はこれを使う。
func get_equippable_instances(slot: String) -> Array:
	var result: Array = []
	for entry: Variant in get_owned_instances():
		if not (entry is Dictionary):
			continue
		var view: Dictionary = entry
		if str(view.get(INSTANCE_VIEW_EQUIPPED_BY, "")) != "":
			continue
		var definition: Dictionary = MasterDataLoader.get_item(str(view.get(GameStateKeys.INSTANCE_ITEM_ID, "")))
		if definition.is_empty():
			continue
		if str(definition.get(ITEM_MASTER_EQUIP_SLOT, "")) != slot:
			continue
		result.append(view)
	return result

func _sort_instance_view(list: Array) -> void:
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sort_a: int = int(a.get(INSTANCE_VIEW_SORT_ORDER, 0))
		var sort_b: int = int(b.get(INSTANCE_VIEW_SORT_ORDER, 0))
		if sort_a != sort_b:
			return sort_a < sort_b
		return int(a.get(GameStateKeys.INSTANCE_GRADE, 1)) > int(b.get(GameStateKeys.INSTANCE_GRADE, 1)))

# --- 装備：着脱 ---

# 着けられない理由。着けられるなら ""（get_part_reject_reason() と同じ形）。
#
# ⚠ 戻り値は翻訳キーではなくログ用の英文。装備の可否は画面が
#   get_equippable_instances() で先に絞っているので、理由を画面に出す口が無い。
#   ⚠ 画面に出す必要が出たら、PART_REJECT_* と同じく翻訳キーに変えること。
#
# ⚠ ignore_owner は「これから外すので、今の持ち主は見なくてよい」ための逃げ道。
#   apply_party_preset() が、状態を触る前に「着けられるか」を数えるときだけ true にする
#   （持ち主を見てしまうと、奪う予定のものが全部弾かれる）。
#   ⚠ equip_instance() からは絶対に true で呼ばないこと。二重装備ができる。
func get_equip_reject_reason(
	character_id: String, slot: String, instance_id: String, ignore_owner: bool = false
) -> String:
	if get_character_growth(character_id).is_empty():
		return "unknown character"

	if not _equip_slots().has(slot):
		return "unknown slot: " + slot

	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return "unknown instance: " + instance_id

	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return "item not in items.json: " + item_id

	if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_EQUIPMENT:
		return "not equipment: " + item_id

	var item_slot: String = str(definition.get(ITEM_MASTER_EQUIP_SLOT, ""))
	if item_slot != slot:
		return "slot mismatch: item=%s requested=%s" % [item_slot, slot]

	if not ignore_owner:
		var owner: String = _equipped_owner(instance_id)
		if owner != "" and owner != character_id:
			return "equipped by " + owner

	return ""

# 装備する。成功したら true。
#
# 判定の順番は start_craft() / purchase_shop_item() と揃える。
# 状態を変える前に全部の判定を終える：
#   キャラ存在 → スロット妥当 → 個体が存在 → items.json に存在 → 装備品である
#   → スロット一致 → 他のキャラが装備していない
#
# 在庫を触らないため、飛ぶシグナルは character_growth_changed の1本だけ。
# 前に着けていた個体は equipment_instances に残ったまま「どこにも装備していない」に戻る。
func equip_instance(character_id: String, slot: String, instance_id: String) -> bool:
	var reason: String = get_equip_reject_reason(character_id, slot, instance_id)
	if reason != "":
		print("[GameManager] equip_instance('%s', '%s', '%s') -> false (%s)" % [
			character_id, slot, instance_id, reason
		])
		return false

	# --- ここから状態を変える ---

	var growth: Dictionary = get_character_growth(character_id)
	var instance: Dictionary = get_equipment_instance(instance_id)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var previous: String = get_equipped_instance_id(character_id, slot)
	var equipment: Dictionary = (growth.get(GameStateKeys.GROWTH_EQUIPMENT, {}) as Dictionary).duplicate(true)
	equipment[slot] = instance_id
	growth[GameStateKeys.GROWTH_EQUIPMENT] = equipment
	_write_growth(character_id, growth)

	print("[GameManager] equip_instance('%s', '%s', '%s') -> true (item=%s previous=%s bonus=%s)" % [
		character_id, slot, instance_id, item_id, previous, get_equipment_bonus(character_id)
	])
	character_growth_changed.emit(character_id)
	return true

# 外す。何も装備していなければ false。個体は equipment_instances に残る。
func unequip_instance(character_id: String, slot: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		print("[GameManager] unequip_instance('%s') -> false (unknown character)" % character_id)
		return false

	if not _equip_slots().has(slot):
		print("[GameManager] unequip_instance('%s') -> false (unknown slot: %s)" % [character_id, slot])
		return false

	var current: String = get_equipped_instance_id(character_id, slot)
	if current == "":
		print("[GameManager] unequip_instance('%s', '%s') -> false (nothing equipped)" % [character_id, slot])
		return false

	# --- ここから状態を変える ---

	var equipment: Dictionary = (growth.get(GameStateKeys.GROWTH_EQUIPMENT, {}) as Dictionary).duplicate(true)
	equipment[slot] = null
	growth[GameStateKeys.GROWTH_EQUIPMENT] = equipment
	_write_growth(character_id, growth)

	print("[GameManager] unequip_instance('%s', '%s') -> true (removed=%s bonus=%s)" % [
		character_id, slot, current, get_equipment_bonus(character_id)
	])
	character_growth_changed.emit(character_id)
	return true

# --- 装備：鍛冶 ---

# 等級を1つ上げるのに必要な素材。{material_id, amount}。上限に達していれば amount = 0。
# --- 装備：等級と段階 ---

# Balance.equipment を1本の口から引く。
#
# ⚠ 枠に equipment_config.tres を割り当て忘れると null になり、
#   そのままだと「等級の上限が0」「鍛冶ができない」という静かな壊れ方をする
#   （実際に踏んだ。EXEC_MATERIAL_TIERS.md §11-3）。
#   何が起きたかと直し方をその場で言う。
var _equipment_config_warned: bool = false

func _equipment() -> EquipmentConfig:
	if Balance.equipment == null:
		if not _equipment_config_warned:
			_equipment_config_warned = true
			push_error("[GameManager] Balance.equipment が null。balance.tscn の Equipment の枠に resources/balance/equipment_config.tres を割り当てること（等級・鍛冶・分解が全部止まる）")
		return null
	return Balance.equipment

#
# ⚠ 「等級から段階を出す」判定はこの1本だけ。鍛冶・分解・（将来の）装飾が全部ここを通る。
#   同じ形の判定を2本目に書かないこと（この器で3回踏んでいる形）。
#
# forge_material_tier_min_grades = [1, 4, 7, 10] なら
#   2〜3 → 段階1 / 4〜6 → 段階2 / 7〜9 → 段階3 / 10 → 段階4。
func get_forge_material_tier(grade: int) -> int:
	var tier: int = 1
	var config: EquipmentConfig = _equipment()
	if config == null:
		return tier
	var mins: Array[int] = config.forge_material_tier_min_grades
	for i: int in range(mins.size()):
		if grade >= mins[i]:
			tier = i + 1
	return tier


# 等級から、その等級へ上げるのに要る鍛冶素材のIDを返す。
func get_forge_material_id(grade: int) -> String:
	return GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + str(get_forge_material_tier(grade))


func get_max_equipment_grade() -> int:
	var config: EquipmentConfig = _equipment()
	if config == null:
		return 1
	return int(config.max_equipment_grade)


# 鍛冶素材が何段階あるか。画面が「段階の数」を決め打ちしないための1本。
func get_forge_material_tier_count() -> int:
	var config: EquipmentConfig = _equipment()
	if config == null:
		return 1
	return config.forge_material_tier_min_grades.size()


# 等級 grade へ上げるのに要る数。
#
# ⚠ forge_cost_by_grade の添字0が「等級2へ上げる数」。長さが足りないときは
#   末尾の値で埋めるが、黙って埋めると「等級9から上がらない」が無音になるため赤を出す。
func get_forge_cost_amount(grade: int) -> int:
	var config: EquipmentConfig = _equipment()
	if config == null:
		return 0
	var costs: Array[int] = config.forge_cost_by_grade
	if costs.is_empty():
		push_error("[GameManager] forge_cost_by_grade が空。鍛冶ができない")
		return 0
	var index: int = grade - 2
	if index < 0:
		return 0
	if index >= costs.size():
		push_error("[GameManager] forge_cost_by_grade が短い（等級%d ぶんが無い。長さ=%d・上限=%d）。末尾の値で埋める" % [
			grade, costs.size(), get_max_equipment_grade()
		])
		return int(costs[costs.size() - 1])
	return int(costs[index])


func get_forge_cost(instance_id: String) -> Dictionary:
	var empty: Dictionary = {
		FORGE_COST_MATERIAL_ID: GameStateKeys.ITEM_FORGING_MATERIAL_1,
		FORGE_COST_AMOUNT: 0,
	}
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return empty
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	if grade >= get_max_equipment_grade():
		return empty
	var next_grade: int = grade + 1
	return {
		FORGE_COST_MATERIAL_ID: get_forge_material_id(next_grade),
		FORGE_COST_AMOUNT: get_forge_cost_amount(next_grade),
	}

func can_forge(instance_id: String) -> bool:
	var cost: Dictionary = get_forge_cost(instance_id)
	var amount: int = int(cost.get(FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return false
	return get_material_count(str(cost.get(FORGE_COST_MATERIAL_ID, ""))) >= amount

# 等級を1つ上げる。失敗しない（素材と判定を通れば必ず上がる）。
#
# 待ち時間は持たせていない。時間を入れるならキューがもう1本要り、作業場の Tick を
# 装備画面にもう1つ作ることになるため、あとで個体に grade_up_at を足す形にする。
#
# add_material() が material_changed を飛ばすが、装備画面はそれを購読しない
# （equipment_instances_changed だけを見て再描画する。2本飛ぶと行が二重に並ぶ）。
func forge_equipment(instance_id: String) -> bool:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] forge_equipment('%s') -> false (unknown instance)" % instance_id)
		return false

	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	if grade >= get_max_equipment_grade():
		print("[GameManager] forge_equipment('%s') -> false (grade %d >= max %d)" % [
			instance_id, grade, get_max_equipment_grade()
		])
		return false

	var cost: Dictionary = get_forge_cost(instance_id)
	var material_id: String = str(cost.get(FORGE_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(FORGE_COST_AMOUNT, 0))
	var owned: int = get_material_count(material_id)
	if owned < amount:
		print("[GameManager] forge_equipment('%s') -> false (material %s: %d < %d)" % [
			instance_id, material_id, owned, amount
		])
		return false

	# --- ここから状態を変える ---

	if amount > 0:
		add_material(material_id, -amount)

	var new_grade: int = grade + 1
	instance[GameStateKeys.INSTANCE_GRADE] = new_grade
	_write_instance(instance_id, instance)

	print("[GameManager] forge_equipment('%s') -> true (grade %d -> %d cost=%d stats=%s slots=%d)" % [
		instance_id, grade, new_grade, amount, get_instance_stats(instance_id),
		get_open_part_slot_count(_instance_equip_slot(instance_id), new_grade)
	])
	equipment_instances_changed.emit(instance_id)
	return true

# 素材に戻したときの戻り量。{material_id: count} を返す。
#
# ⚠ 戻り型は int ではない（EXEC_MATERIAL_TIERS.md 決定F / §0-2 の6）。
#   等級10まで伸ばすと、払う素材が4段階にまたがる。段階①だけに返すと
#   払った上位素材が消えるため、払った段階ごとに返す。
#
# ⚠ 返すのは払った量の dismantle_refund_ratio 倍（切り捨て）。
#   この回より前は全額戻していた＝「上げて分解して付け替える」が無損失だった。
#   ⚠ 切り上げにしないこと。1つ上げてすぐ分解すると素材が増える経路ができる。
#
# ⚠ 基礎ぶん（等級1の素の価値）は段階①へ返す。こちらにも率を掛ける。
func get_dismantle_refund(instance_id: String) -> Dictionary:
	var result: Dictionary = {}
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return result

	var config: EquipmentConfig = _equipment()
	if config == null:
		return result
	var ratio: float = float(config.dismantle_refund_ratio)
	var base_amount: int = int(floor(float(config.dismantle_refund_base) * ratio))
	if base_amount > 0:
		result[GameStateKeys.ITEM_FORGING_MATERIAL_1] = base_amount

	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	for g: int in range(2, grade + 1):
		var material_id: String = get_forge_material_id(g)
		var amount: int = int(floor(float(get_forge_cost_amount(g)) * ratio))
		if amount <= 0:
			continue
		result[material_id] = int(result.get(material_id, 0)) + amount
	return result


# 分解の戻りの合計。ボタンの表示のように「1つの数」で足りる側が使う。
func get_dismantle_refund_total(instance_id: String) -> int:
	var total: int = 0
	for amount: Variant in get_dismantle_refund(instance_id).values():
		total += int(amount)
	return total

# 重複した装備を鍛冶の素材に戻す。装備中のものは戻せない。
#
# 自動変換にしていないのは、「同じ装備を2本持って2人に着ける」がこのタスクの目玉のため。
# 2本目を勝手に溶かすと、個体管理が効いているかを確認できなくなる。
func dismantle_equipment(instance_id: String) -> bool:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] dismantle_equipment('%s') -> false (unknown instance)" % instance_id)
		return false

	var owner: String = _equipped_owner(instance_id)
	if owner != "":
		print("[GameManager] dismantle_equipment('%s') -> false (equipped by %s)" % [instance_id, owner])
		return false

	# --- ここから状態を変える ---

	var refund: Dictionary = get_dismantle_refund(instance_id)
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances.erase(instance_id)
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

	# ⚠ 段階ごとに add_material() を呼ぶので material_changed が段階の数だけ飛ぶ。
	#   装備画面は equipment_instances_changed だけを見ているので二重描画にならない
	#   （forge_equipment() のコメントと同じ理由）。
	for material_id: Variant in refund:
		add_material(str(material_id), int(refund[material_id]))

	print("[GameManager] dismantle_equipment('%s') -> true (item=%s grade=%d refund=%s)" % [
		instance_id, str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
		int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)), str(refund)
	])
	equipment_instances_changed.emit(instance_id)
	return true

# ============================================================
# 装飾（宝石・護符・紋章）— EXEC_DECORATION.md
# ============================================================
#
# ⚠ 状態が持つのは equipment_instances.<id>.parts の {item_id, roll} だけ。
#   性能（part_base / part_roll_max）は items.json から毎回引く（CLAUDE.md 4番）。
#   GAME_DESIGN.md 7-6 は「{装飾ID, 等級, 出目}」と書いているが、等級は落としている
#   （マスターから引ける＝複製になるため）。
#
# ⚠ part_kind で if を分岐させないこと。種類を足すたびに .gd を触ることになる。
#   種類を見るのは _part_slot_kinds() と E119 の2箇所だけ。
#
# ⚠ 段階の数を 4 と直書きしないこと。get_max_part_tier() と配列の長さから引く。

var _part_config_warned: bool = false

# Balance.part の唯一の口。null のときは1回だけ赤で直し方を言い、以降は黙る
# （_equipment() と同じ形。割り当て忘れが「静かな壊れ方」をした前回への対処）。
func _part() -> PartConfig:
	if Balance.part == null:
		if not _part_config_warned:
			_part_config_warned = true
			push_error("[GameManager] Balance.part が null。balance.tscn の Part の枠に resources/balance/part_config.tres を割り当てること（装飾の段階上げと壊す処理が全部止まる）")
		return null
	return Balance.part

# 装飾の段階の上限。画面もここから引く（4 と直書きしない）。
func get_max_part_tier() -> int:
	var config: PartConfig = _part()
	if config == null:
		return 1
	return int(config.max_part_tier)

# 段階 → 装飾素材のID（get_forge_material_id() と同じ形）。
func get_decor_material_id(tier: int) -> String:
	return GameStateKeys.ITEM_DECOR_MATERIAL_PREFIX + str(tier)

# 枠の位置ごとに、そこへ刺さる装飾の種類（GAME_DESIGN.md 6-4）。
#
# ⚠ 種類が決まるのは「部位」ではなく「枠」。部位が効くのは等級5の特別枠だけ。
# ⚠ ワイルド枠は宝石・護符・紋章のどれでも受ける（GAME_DESIGN.md 7-1）。ルーンは受けない。
# ⚠ 種類を足すときに触るのはこの表だけ。part_kind で if を分岐させないこと。
func _part_slot_kinds(equip_slot: String) -> Array:
	var wild: Array[String] = [PART_KIND_GEM, PART_KIND_CHARM, PART_KIND_EMBLEM]
	var special_a: Array[String] = []
	var special_b: Array[String] = []
	if equip_slot == GameStateKeys.EQUIP_WEAPON:
		special_a = [PART_KIND_RUNE]
	elif equip_slot == GameStateKeys.EQUIP_ACCESSORY:
		special_a = [PART_KIND_RUNE]
		special_b = [PART_KIND_RUNE]
	elif equip_slot in [GameStateKeys.EQUIP_HEAD, GameStateKeys.EQUIP_ARMOR, GameStateKeys.EQUIP_LEGS]:
		special_a = wild
	else:
		# 装備でないIDが来た。枠を1つも作らない。
		return []
	return [
		[PART_KIND_GEM], [PART_KIND_GEM],
		special_a, special_b,
		[PART_KIND_CHARM], [PART_KIND_CHARM],
		[PART_KIND_EMBLEM], [PART_KIND_EMBLEM],
	]

# 部位ごとの枠の定義。長さは PART_SLOT_COUNT。
# 戻り値の1件: {index, min_grade, kinds}
#
# ⚠ 開く等級（数値）は PartConfig、刺さる種類は _part_slot_kinds()。
#   2本の長さが合わないと「等級9の枠が開かない」が無音になるので赤を出す。
func get_part_slot_defs(equip_slot: String) -> Array:
	var kinds_table: Array = _part_slot_kinds(equip_slot)
	if kinds_table.is_empty():
		return []

	var config: PartConfig = _part()
	var min_grades: Array[int] = []
	if config != null:
		min_grades = config.part_slot_min_grades
	if min_grades.size() != kinds_table.size():
		push_error("[GameManager] part_slot_min_grades の長さが %d。枠の種類の表は %d 件（PART_SLOT_COUNT=%d）。part_config.tres を直すこと" % [
			min_grades.size(), kinds_table.size(), PART_SLOT_COUNT
		])

	var result: Array = []
	for i: int in range(kinds_table.size()):
		# 長さが足りないぶんは「開かない枠」として置く（黙って詰めない）。
		var min_grade: int = int(min_grades[i]) if i < min_grades.size() else 9999
		result.append({
			PART_VIEW_INDEX: i,
			PART_VIEW_MIN_GRADE: min_grade,
			PART_VIEW_KINDS: kinds_table[i],
		})
	return result

# その枠に刺さる種類。開いているかどうかは見ない。
func get_part_kinds_for_slot_index(equip_slot: String, slot_index: int) -> Array:
	var defs: Array = get_part_slot_defs(equip_slot)
	if slot_index < 0 or slot_index >= defs.size():
		return []
	return (defs[slot_index] as Dictionary).get(PART_VIEW_KINDS, [])

# 個体が入る部位（items.json の equip_slot）。装備していなくても決まる。
func _instance_equip_slot(instance_id: String) -> String:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return ""
	var definition: Dictionary = MasterDataLoader.get_item(str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")))
	return str(definition.get(ITEM_MASTER_EQUIP_SLOT, ""))

# 装飾1件の定義。装飾でなければ空を返す。
# MasterDataLoader は JSON をそのまま返すため、数値は int() で包む（CLAUDE.md 3番）。
func get_part_definition(item_id: String) -> Dictionary:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return {}
	if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_PART:
		return {}
	return {
		ITEM_MASTER_PART_KIND: str(definition.get(ITEM_MASTER_PART_KIND, "")),
		ITEM_MASTER_PART_TIER: int(definition.get(ITEM_MASTER_PART_TIER, 0)),
		ITEM_MASTER_PART_STAT: str(definition.get(ITEM_MASTER_PART_STAT, "")),
		ITEM_MASTER_PART_BASE: int(definition.get(ITEM_MASTER_PART_BASE, 0)),
		ITEM_MASTER_PART_ROLL_MAX: int(definition.get(ITEM_MASTER_PART_ROLL_MAX, 0)),
	}

# 刺さっている装飾1つ分の加算量。{item_id, roll} → part_base + roll。
#
# ⚠ 表示も加算もこの1本を通す。2本目を書かないこと（EXEC_DECORATION.md §2-7）。
func get_part_stat_value(part_entry: Variant) -> int:
	if not (part_entry is Dictionary):
		return 0
	var entry: Dictionary = part_entry
	var definition: Dictionary = get_part_definition(str(entry.get(GameStateKeys.PART_ITEM_ID, "")))
	if definition.is_empty():
		return 0
	# items.json の part_roll_max を後から縮めたときに、保存済みの出目がはみ出す。
	# 黙って大きいままにしないよう必ず丸める。
	var roll: int = clampi(
		int(entry.get(GameStateKeys.PART_ROLL, 0)), 0, int(definition.get(ITEM_MASTER_PART_ROLL_MAX, 0))
	)
	return int(definition.get(ITEM_MASTER_PART_BASE, 0)) + roll

# instance の parts を長さ PART_SLOT_COUNT に揃えて返す（null 込み）。
# get_equipment_instance() は duplicate(true) を返すので、ここで得た配列は
# そのまま書き換えて _write_instance() で戻してよい。
func _parts_array(instance: Dictionary) -> Array:
	var raw: Variant = instance.get(GameStateKeys.INSTANCE_PARTS, [])
	var parts: Array = raw if raw is Array else []
	while parts.size() < PART_SLOT_COUNT:
		parts.append(null)
	return parts

# 開いている枠の一覧。画面はこれだけを見る。
# 戻り値の1件: {index, min_grade, kinds, entry}（entry は {item_id, roll} または null）
#
# ⚠ 開いていない枠は返さない。位置（index）は詰めずにそのまま入れる。
#   画面が「何番目の枠か」で attach_part() を呼ぶので、詰めると別の枠に刺さる。
func get_part_entries(instance_id: String) -> Array:
	var result: Array = []
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return result
	var parts: Array = _parts_array(instance)
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	for def: Variant in get_part_slot_defs(_instance_equip_slot(instance_id)):
		if not _is_slot_open(def, grade):
			continue
		var i: int = int((def as Dictionary).get(PART_VIEW_INDEX, 0))
		var view: Dictionary = (def as Dictionary).duplicate(true)
		view[PART_VIEW_ENTRY] = parts[i] if i < parts.size() and parts[i] is Dictionary else null
		result.append(view)
	return result

# 刺せない理由の翻訳キー。"" なら刺せる。
#
# ⚠ 刺せるかどうかの判定はこの1本だけ。画面のボタンの活性も attach_part() の
#   判定もここを通す（同じ形の判定を2本書かない）。
# ⚠ 段階の判定は無い。下位段階も上位の枠に刺さる（PLAN 3-2 の [x]）。
func get_part_reject_reason(instance_id: String, slot_index: int, item_id: String) -> String:
	# 1. 個体が在るか
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return PART_REJECT_UNKNOWN

	# 2. その枠が開いているか（部位と等級の両方で決まる。GAME_DESIGN.md 6-4）
	var equip_slot: String = _instance_equip_slot(instance_id)
	var defs: Array = get_part_slot_defs(equip_slot)
	if slot_index < 0 or slot_index >= defs.size():
		return PART_REJECT_LOCKED
	if not _is_slot_open(defs[slot_index], int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))):
		return PART_REJECT_LOCKED

	# 3. その枠が空か（上書きで黙って壊さない）
	var parts: Array = _parts_array(instance)
	if slot_index < parts.size() and parts[slot_index] is Dictionary:
		return PART_REJECT_OCCUPIED

	# 4. 装飾として引けるか
	var definition: Dictionary = get_part_definition(item_id)
	if definition.is_empty():
		return PART_REJECT_UNKNOWN

	# 5. その「枠」が受け付ける種類か（部位ではなく枠で決まる）
	if not (str(definition.get(ITEM_MASTER_PART_KIND, "")) in (defs[slot_index] as Dictionary).get(PART_VIEW_KINDS, [])):
		return PART_REJECT_KIND

	# 6. 在庫を持っているか
	if get_item_count(item_id) <= 0:
		return PART_REJECT_STOCK

	return ""

# 枠に装飾を刺す。ロールはここで振る（GAME_DESIGN.md 7-6・人間の決定C）。
#
# ⚠ 判定は get_part_reject_reason() に全部任せる。ここに2本目を書かない。
# ⚠ 状態を触るのは判定を全部通したあと（CLAUDE.md 6番）。
#
# ⚠ シグナルは2本飛ぶ（_remove_from_inventory() の inventory_changed と、
#   ここの equipment_instances_changed）。倉庫は両方購読しているので再描画が
#   2回走るが、_rebuild_inventory() は await を持たないので行は二重にならない。
func attach_part(instance_id: String, slot_index: int, item_id: String) -> bool:
	var reason: String = get_part_reject_reason(instance_id, slot_index, item_id)
	if reason != "":
		print("[GameManager] attach_part('%s', %d, '%s') -> false (%s)" % [
			instance_id, slot_index, item_id, reason
		])
		return false

	var roll_max: int = int(get_part_definition(item_id).get(ITEM_MASTER_PART_ROLL_MAX, 0))

	# --- ここから状態を変える ---

	_remove_from_inventory(item_id, 1)

	# 出目は 0 〜 part_roll_max。マイナスは作らない（PLAN 4-2 の [x]）。
	var roll: int = randi_range(0, roll_max) if roll_max > 0 else 0

	var instance: Dictionary = get_equipment_instance(instance_id)
	var parts: Array = _parts_array(instance)
	parts[slot_index] = {
		GameStateKeys.PART_ITEM_ID: item_id,
		GameStateKeys.PART_ROLL: roll,
	}
	instance[GameStateKeys.INSTANCE_PARTS] = parts
	_write_instance(instance_id, instance)

	print("[GameManager] attach_part('%s', %d, '%s') -> true (roll=%d/%d value=%d stats=%s)" % [
		instance_id, slot_index, item_id, roll, roll_max,
		get_part_stat_value(parts[slot_index]), get_instance_stats(instance_id)
	])
	equipment_instances_changed.emit(instance_id)
	return true

# 枠から装飾を外す。⚠ 外すと壊れる（GAME_DESIGN.md 7-6・人間の決定D）。
# 在庫には戻らない。装飾素材が返る。
#
# ⚠ 確認モーダルは画面側の担当。ここは確認しない（GameManager は await を持たない）。
#   壊れる量を先に見せたいときは get_part_dismantle_refund() を呼ぶこと。
func detach_part(instance_id: String, slot_index: int) -> bool:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] detach_part('%s', %d) -> false (unknown instance)" % [instance_id, slot_index])
		return false

	var open_count: int = get_open_part_slot_count(
		_instance_equip_slot(instance_id), int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	)
	var parts: Array = _parts_array(instance)
	# ⚠ 開いていない枠のぶんも外せるようにしてある。枠を減らす変更をしたときに、
	#   あふれた装飾を取り出す手段が無くなるため（W18 は「消さない」なので残り続ける）。
	if slot_index < 0 or slot_index >= parts.size():
		print("[GameManager] detach_part('%s', %d) -> false (枠の範囲外・開いている枠=%d)" % [
			instance_id, slot_index, open_count
		])
		return false
	if not (parts[slot_index] is Dictionary):
		print("[GameManager] detach_part('%s', %d) -> false (空の枠)" % [instance_id, slot_index])
		return false

	var part_id: String = str((parts[slot_index] as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
	var refund: Dictionary = get_part_dismantle_refund(part_id, 1)

	# --- ここから状態を変える ---

	parts[slot_index] = null
	instance[GameStateKeys.INSTANCE_PARTS] = parts
	_write_instance(instance_id, instance)

	for material_id: Variant in refund:
		add_material(str(material_id), int(refund[material_id]))

	print("[GameManager] detach_part('%s', %d) -> true (壊した '%s' refund=%s stats=%s)" % [
		instance_id, slot_index, part_id, str(refund), get_instance_stats(instance_id)
	])
	equipment_instances_changed.emit(instance_id)
	return true

# 段階を1つ上げた装飾のID。上げられなければ ""。
#
# ⚠ 欄からIDを組み立てる。逆（IDから欄を切り出す）はしない。
#   組み立てたIDと欄が一致していることは E119 がロード時に検証している。
func get_upgraded_part_id(item_id: String) -> String:
	var definition: Dictionary = get_part_definition(item_id)
	if definition.is_empty():
		return ""
	# ⚠ ルーンは分解方式で上がらない。重ねる（merge_runes()）が別系統として在る
	#   （GAME_DESIGN.md 7-7 の表）。⚠ ここで弾かないと part_rune__2 を組み立てて
	#   赤が出る（ルーンには軸が無いため）。
	# ⚠ part_kind ではなく「runes.json にエントリが在るか」で分ける。
	if not MasterDataLoader.get_rune(item_id).is_empty():
		return ""
	var tier: int = int(definition.get(ITEM_MASTER_PART_TIER, 0))
	if tier < 1 or tier >= get_max_part_tier():
		return ""
	var next_id: String = PART_ID_FORMAT % [
		str(definition.get(ITEM_MASTER_PART_KIND, "")),
		str(definition.get(ITEM_MASTER_PART_STAT, "")),
		tier + 1,
	]
	if get_part_definition(next_id).is_empty():
		# 段階の上限だけ伸ばして items.json に行を足し忘れた形。黙ると
		# 「上げるボタンが出るのに押しても何も起きない」になる。
		push_error("[GameManager] 段階%d の装飾 '%s' が items.json に無い（'%s' から上げられない）" % [
			tier + 1, next_id, item_id
		])
		return ""
	return next_id

# 段階を1つ上げるのに要るもの。{material_id, amount}。上げられなければ amount = 0。
#
# ⚠ 払うのは「いま持っている段階」の装飾素材（decor_material_<tier>）。
#   装備の鍛冶は「上げた先の等級」で引くので、向きが逆である点に注意。
func get_part_upgrade_cost(item_id: String) -> Dictionary:
	var empty: Dictionary = {PART_UPGRADE_MATERIAL_ID: "", PART_UPGRADE_AMOUNT: 0}
	var definition: Dictionary = get_part_definition(item_id)
	if definition.is_empty():
		return empty
	var config: PartConfig = _part()
	if config == null:
		return empty
	var tier: int = int(definition.get(ITEM_MASTER_PART_TIER, 0))
	if tier < 1 or tier >= get_max_part_tier():
		return empty

	var costs: Array[int] = config.upgrade_cost_by_tier
	if costs.is_empty():
		push_error("[GameManager] upgrade_cost_by_tier が空。装飾の段階を上げられない")
		return empty
	var index: int = tier - 1
	var amount: int = 0
	if index >= costs.size():
		# 黙って落とすと「段階3から上がらない」が無音になる
		# （get_forge_cost_amount() と同じ形）。
		push_error("[GameManager] upgrade_cost_by_tier が短い（段階%d ぶんが無い。長さ=%d・上限=%d）。末尾の値で埋める" % [
			tier, costs.size(), get_max_part_tier()
		])
		amount = int(costs[costs.size() - 1])
	else:
		amount = int(costs[index])
	return {PART_UPGRADE_MATERIAL_ID: get_decor_material_id(tier), PART_UPGRADE_AMOUNT: amount}

func can_upgrade_part(item_id: String) -> bool:
	if get_upgraded_part_id(item_id) == "":
		return false
	if get_item_count(item_id) <= 0:
		return false
	var cost: Dictionary = get_part_upgrade_cost(item_id)
	var amount: int = int(cost.get(PART_UPGRADE_AMOUNT, 0))
	if amount <= 0:
		return false
	return get_material_count(str(cost.get(PART_UPGRADE_MATERIAL_ID, ""))) >= amount

# 装飾の段階を1つ上げる（分解方式・GAME_DESIGN.md 7-1）。
# 在庫の装飾1つと装飾素材を払い、1つ上の段階の装飾を1つ在庫へ入れる。
#
# ⚠ 刺さっている装飾は上げられない。parts の中身は在庫ではないため
#   （上げたいなら先に外す＝壊れる）。
func upgrade_part(item_id: String) -> bool:
	var next_id: String = get_upgraded_part_id(item_id)
	if next_id == "":
		print("[GameManager] upgrade_part('%s') -> false (上げ先が無い)" % item_id)
		return false

	var owned: int = get_item_count(item_id)
	if owned <= 0:
		print("[GameManager] upgrade_part('%s') -> false (持っていない)" % item_id)
		return false

	var cost: Dictionary = get_part_upgrade_cost(item_id)
	var material_id: String = str(cost.get(PART_UPGRADE_MATERIAL_ID, ""))
	var amount: int = int(cost.get(PART_UPGRADE_AMOUNT, 0))
	if amount <= 0:
		print("[GameManager] upgrade_part('%s') -> false (コストが引けない)" % item_id)
		return false

	var owned_material: int = get_material_count(material_id)
	if owned_material < amount:
		print("[GameManager] upgrade_part('%s') -> false (material %s: %d < %d)" % [
			item_id, material_id, owned_material, amount
		])
		return false

	# --- ここから状態を変える ---

	add_material(material_id, -amount)
	_remove_from_inventory(item_id, 1)
	add_to_inventory(next_id, 1, GameStateKeys.ITEM_TYPE_PART)

	print("[GameManager] upgrade_part('%s') -> true (-> %s cost=%s x%d)" % [
		item_id, next_id, material_id, amount
	])
	return true

# 装飾を壊したときに返る素材。{material_id: count}
# （get_dismantle_refund() と同じ形。外したとき・在庫で壊したときの両方が使う）。
func get_part_dismantle_refund(item_id: String, count: int) -> Dictionary:
	var result: Dictionary = {}
	if count <= 0:
		return result
	var definition: Dictionary = get_part_definition(item_id)
	if definition.is_empty():
		return result
	# ルーンは壊しても装飾素材にならない（GAME_DESIGN.md 7-7：余りは「かけら」に
	# なる。かけらは今回作っていない＝人間の決定3）。
	# ⚠ ここで止めないと decor_material_5 という存在しないIDが返り、段階5で赤が出る。
	# ⚠ part_kind ではなく「runes.json にエントリが在るか」で分ける。
	if not MasterDataLoader.get_rune(item_id).is_empty():
		return result
	var config: PartConfig = _part()
	if config == null:
		return result
	var tier: int = int(definition.get(ITEM_MASTER_PART_TIER, 0))
	if tier < 1:
		return result

	var table: Array[int] = config.dismantle_by_tier
	if table.is_empty():
		push_error("[GameManager] dismantle_by_tier が空。装飾を壊しても何も返らない")
		return result
	var index: int = tier - 1
	var per_one: int = 0
	if index >= table.size():
		push_error("[GameManager] dismantle_by_tier が短い（段階%d ぶんが無い。長さ=%d）。末尾の値で埋める" % [
			tier, table.size()
		])
		per_one = int(table[table.size() - 1])
	else:
		per_one = int(table[index])
	if per_one <= 0:
		return result

	result[get_decor_material_id(tier)] = per_one * count
	return result

# 在庫の装飾を壊して装飾素材に戻す。戻りは {material_id: count}。空なら何もしていない。
#
# ⚠ 外して壊れる側（detach_part）とは別。こちらは在庫の余りを整理するためのもの。
# ⚠ 確認モーダルは出さない（装備の「素材にする」も出していない。刺さっているものは
#   減らないので、押し間違いの被害が在庫の余りに限られる）。
func dismantle_part(item_id: String, count: int) -> Dictionary:
	if count <= 0:
		return {}
	var owned: int = get_item_count(item_id)
	if owned < count:
		print("[GameManager] dismantle_part('%s', %d) -> {} (持っているのは %d)" % [item_id, count, owned])
		return {}

	var refund: Dictionary = get_part_dismantle_refund(item_id, count)
	if refund.is_empty():
		# 戻りが引けないなら在庫も減らさない（払っただけになるのを避ける）。
		print("[GameManager] dismantle_part('%s', %d) -> {} (戻りが引けない)" % [item_id, count])
		return {}

	# --- ここから状態を変える ---

	_remove_from_inventory(item_id, count)
	for material_id: Variant in refund:
		add_material(str(material_id), int(refund[material_id]))

	print("[GameManager] dismantle_part('%s', %d) -> %s" % [item_id, count, str(refund)])
	return refund


# ============================================================
# ルーン（GAME_DESIGN.md 7-5 / 7-7・EXEC_RUNES.md）
#
# ⚠ ルーンは装飾の4種類目。刺す・外すは装飾とまったく同じ口を通る
#   （attach_part / detach_part / get_part_reject_reason）。ここに在るのは
#   「ルーンだけが持つもの」＝挙動・重ねる・移動量の3つだけ。
#
# ⚠ ステータスを1つも足さない。加算の合流点（_add_part_stats）は part_stat が
#   空の装飾を飛ばす。⚠ ここに加算を書かないこと。
# ============================================================

# ルーン1件の挙動。ルーンでなければ空。
#
# ⚠ 「これはルーンか」の判定はこれを通す。part_kind で分岐しないこと
#   （_part_slot_kinds() の注記）。
# ⚠ 数値は int() / float() で包む。MasterDataLoader は float を返す（CLAUDE.md 3番）。
func get_rune_definition(item_id: String) -> Dictionary:
	return MasterDataLoader.get_rune(item_id)


func get_max_rune_tier() -> int:
	var config: PartConfig = _part()
	return 5 if config == null else config.max_rune_tier


func get_rune_merge_count() -> int:
	var config: PartConfig = _part()
	return 2 if config == null else maxi(config.rune_merge_count, 2)


func get_rune_move_lock_sec() -> float:
	var config: PartConfig = _part()
	return 1.2 if config == null else maxf(config.rune_move_lock_sec, 0.0)


# 選べる移動量。移動系でなければ空。⚠ 符号つき（正が前進・負が後退）。
func get_rune_move_choices(item_id: String) -> Array[int]:
	var result: Array[int] = []
	var rune: Dictionary = get_rune_definition(item_id)
	var raw_move: Variant = rune.get(MasterDataLoader.RUNE_MOVE, null)
	if not (raw_move is Dictionary):
		return result
	var raw_choices: Variant = (raw_move as Dictionary).get(MasterDataLoader.RUNE_MOVE_CHOICES, null)
	if not (raw_choices is Array):
		return result
	for raw_distance: Variant in (raw_choices as Array):
		result.append(int(raw_distance))
	return result


# そのキャラが選んである移動量。
#
# ⚠ 未設定なら choices の先頭を返す。「選んでいないと動かない」を作らない
#   （刺した直後に何も起きないと、壊れているのか未設定なのか画面から読めない）。
func get_rune_move(character_id: String, item_id: String) -> int:
	var choices: Array[int] = get_rune_move_choices(item_id)
	if choices.is_empty():
		return 0
	var stored: Variant = get_character_growth(character_id).get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	if stored is Dictionary and (stored as Dictionary).has(item_id):
		var distance: int = int((stored as Dictionary)[item_id])
		if distance in choices:
			return distance
	return choices[0]


# 移動量を選ぶ。choices に無い値は弾く。
#
# ⚠ 状態を変える前に判定を全部終える（CLAUDE.md 6番）。
func set_rune_move(character_id: String, item_id: String, distance: int) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		print("[GameManager] set_rune_move('%s') -> false (知らない character_id)" % character_id)
		return false
	var choices: Array[int] = get_rune_move_choices(item_id)
	if not (distance in choices):
		print("[GameManager] set_rune_move('%s', '%s', %d) -> false (選べる値は %s)" % [
			character_id, item_id, distance, str(choices)
		])
		return false

	# --- ここから状態を変える ---

	var raw_stored: Variant = growth.get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	var stored: Dictionary = (raw_stored as Dictionary).duplicate(true) if raw_stored is Dictionary else {}
	stored[item_id] = distance
	growth[GameStateKeys.GROWTH_RUNE_MOVE] = stored
	_write_growth(character_id, growth)
	character_growth_changed.emit(character_id)

	print("[GameManager] set_rune_move('%s', '%s', %d) -> true" % [character_id, item_id, distance])
	return true


# 戦闘に渡すルーンの確定版。{skill_id: [payload, ...]}。
#
# ⚠ 戦闘が読む唯一の口（get_battle_skills() と同じ形）。画面でも戦闘でも
#   紐付けを2本目に書かないこと。
# ⚠ 紐付けは GAME_DESIGN.md 7-5：武器のルーン枠 → スキル1、アクセサリーの
#   ルーン枠（2つ）→ スキル2。⚠ スキル枠が足りないぶんは黙って落とす（正常系）。
# ⚠ payload の skill_data は MasterDataLoader が組み立てたもの。ここでも
#   battle_controller でも組み立て直さないこと。
func get_battle_runes(character_id: String) -> Dictionary:
	var result: Dictionary = {}
	var skills: Array = get_battle_skills(character_id)
	# 添字が「スキル枠の番号」。武器＝枠1（添字0）／アクセサリー＝枠2（添字1）。
	var slot_for_equip: Dictionary = {
		GameStateKeys.EQUIP_WEAPON: 0,
		GameStateKeys.EQUIP_ACCESSORY: 1,
	}

	for equip_slot: Variant in slot_for_equip:
		var skill_index: int = int(slot_for_equip[equip_slot])
		if skill_index >= skills.size():
			continue
		var skill_id: String = str(skills[skill_index])
		var instance_id: String = get_equipped_instance_id(character_id, str(equip_slot))
		if instance_id == "":
			continue

		# ⚠ 開いている枠だけを返す1本を通す。判定を2本目に書かない。
		for raw_view: Variant in get_part_entries(instance_id):
			if not (raw_view is Dictionary):
				continue
			var entry: Variant = (raw_view as Dictionary).get(PART_VIEW_ENTRY, null)
			if not (entry is Dictionary):
				continue
			var item_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
			var rune: Dictionary = get_rune_definition(item_id)
			if rune.is_empty():
				continue
			if not result.has(skill_id):
				result[skill_id] = []
			(result[skill_id] as Array).append({
				RUNE_PAYLOAD_ITEM_ID: item_id,
				RUNE_PAYLOAD_COOLDOWN: float(rune.get(MasterDataLoader.RUNE_COOLDOWN_SEC, 0.0)),
				RUNE_PAYLOAD_MOVE: get_rune_move(character_id, item_id),
				RUNE_PAYLOAD_SKILL_DATA: MasterDataLoader.rune_skill_data(item_id),
			})
	return result


# 重ねられない理由の翻訳キー。"" なら重ねられる。
#
# ⚠ 判定はこの1本だけ。画面のボタンの活性も merge_runes() もここを通す。
func get_rune_merge_reject_reason(item_id: String) -> String:
	var rune: Dictionary = get_rune_definition(item_id)
	if rune.is_empty():
		return RUNE_REJECT_KIND
	# 段階の上限。⚠ かけらは今回作っていない（人間の決定3・2026-08-24）。
	if not rune.has(MasterDataLoader.RUNE_NEXT_ID):
		return RUNE_REJECT_MAX
	if get_item_count(item_id) < get_rune_merge_count():
		return RUNE_REJECT_STOCK
	return ""


# 同じルーンを rune_merge_count 個消して、1つ上の段階を1個作る
# （GAME_DESIGN.md 7-7「同じものを重ねる」）。
#
# ⚠ upgrade_part()（分解方式）に相乗りしないこと。素材を1つも払わない。
# ⚠ 状態を変える前に判定を全部終える（CLAUDE.md 6番）。
func merge_runes(item_id: String) -> bool:
	var reason: String = get_rune_merge_reject_reason(item_id)
	if reason != "":
		print("[GameManager] merge_runes('%s') -> false (%s)" % [item_id, reason])
		return false
	var next_id: String = str(get_rune_definition(item_id).get(MasterDataLoader.RUNE_NEXT_ID, ""))
	# 上げ先が items.json に無いと、消えるだけになる。黙って通さない。
	if get_part_definition(next_id).is_empty():
		push_error("[GameManager] merge_runes: 上げ先 '%s' が items.json に無い（'%s' から重ねられない）" % [
			next_id, item_id
		])
		return false

	# --- ここから状態を変える ---

	var cost: int = get_rune_merge_count()
	_remove_from_inventory(item_id, cost)
	add_to_inventory(next_id, 1, GameStateKeys.ITEM_TYPE_PART)

	print("[GameManager] merge_runes('%s') -> true (-%d -> %s)" % [item_id, cost, next_id])
	return true

# 1キャラ分の育成データを _state へ書き戻す。
# level_up_character() が直接書いていた3行と同じ処理。装備でも同じ形が要るため関数にした。
# Dictionary は参照渡しのため、_copy_dict() で複製してから差し替える。
func _write_growth(character_id: String, growth: Dictionary) -> void:
	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	all_growth[character_id] = growth
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth


# --- 育成：ステータスノード（EXEC_LEVEL_ROLE_SHIFT.md） ---
#
# 割り振りポイントはノードを解放するのに使う。セーブが持つのは
# character_growth.<id>.nodes（解放済みノードIDの配列）だけ。
# 総ポイントも効果値も保存せず、level と character_nodes.json から毎回引く。
#
# character_nodes.json の1件：
#   {character_id, stat, tier, cost, value, prerequisites[]}
# MasterDataLoader は JSON をそのまま返すため、数値は float で来る。int() 必須。

# 現在のレベルで得られる総ポイント（GAME_DESIGN.md 5-2）。
# 1レベルにつき1点。最大レベル到達時のみ追加で1点（Lv100 でちょうど100点）。
func get_stat_node_total_points(character_id: String) -> int:
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var points: int = level - 1
	if points < 0:
		points = 0
	var max_level: int = 100
	if Balance != null and Balance.character != null:
		max_level = Balance.character.max_character_level
	if level >= max_level:
		points += 1
	return points


# 解放済みノードのIDを返す（順序は解放した順）。
func get_stat_nodes(character_id: String) -> Array:
	var growth: Dictionary = get_character_growth(character_id)
	var nodes: Variant = growth.get(GameStateKeys.GROWTH_NODES, [])
	if not (nodes is Array):
		return []
	return (nodes as Array).duplicate(true)


# 解放済みノードが使っているポイントの合計。
func get_stat_node_spent_points(character_id: String) -> int:
	var spent: int = 0
	for node_id: Variant in get_stat_nodes(character_id):
		var definition: Dictionary = MasterDataLoader.get_character_node(str(node_id))
		# character_nodes.json から消えたIDがセーブに残っていても落とさない。
		# push_error は MasterDataLoader 側で出ている。
		if definition.is_empty():
			continue
		spent += int(definition.get(STAT_NODE_COST, 0))
	return spent


# 残ポイント。画面が出す数字はこれ。
func get_stat_node_remaining_points(character_id: String) -> int:
	return get_stat_node_total_points(character_id) - get_stat_node_spent_points(character_id)


# 解放済みノードのステータス合計。get_effective_stats() の5項目め。
# 戻り値は stat_key -> int。振っていない軸はキーごと入れない。
func get_stat_node_bonus(character_id: String) -> Dictionary:
	var bonus: Dictionary = {}
	for node_id: Variant in get_stat_nodes(character_id):
		var definition: Dictionary = MasterDataLoader.get_character_node(str(node_id))
		if definition.is_empty():
			continue
		var stat_key: String = str(definition.get(STAT_NODE_STAT, ""))
		if stat_key == "":
			continue
		bonus[stat_key] = int(bonus.get(stat_key, 0)) + int(definition.get(STAT_NODE_VALUE, 0))
	return bonus


# 前提条件を満たしているか（ポイントは見ない）。
# 画面が「前提未解放」と「ポイント不足」を区別して出すために分ける
# （can_unlock_research_node() と同じ形）。
func can_unlock_stat_node(character_id: String, node_id: String) -> bool:
	var definition: Dictionary = MasterDataLoader.get_character_node(node_id)
	if definition.is_empty():
		return false
	if str(definition.get(STAT_NODE_CHARACTER_ID, "")) != character_id:
		return false
	var unlocked: Array = get_stat_nodes(character_id)
	if node_id in unlocked:
		return false
	var prerequisites: Variant = definition.get(STAT_NODE_PREREQUISITES, [])
	if not (prerequisites is Array):
		return true
	for required: Variant in (prerequisites as Array):
		if not (str(required) in unlocked):
			return false
	return true


# ノードを1つ解放する。
#
# ⚠ 状態を変える前に全部の判定を終える（CLAUDE.md 6番）。
# 途中で nodes に append してから弾くと、ポイントだけ減った状態が残る。
func unlock_stat_node(character_id: String, node_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		push_warning("[GameManager] unlock_stat_node: unknown character_id: " + character_id)
		return false

	var definition: Dictionary = MasterDataLoader.get_character_node(node_id)
	if definition.is_empty():
		# 存在しないIDぶんの push_error は MasterDataLoader 側で出ている。
		print("[GameManager] unlock_stat_node('%s', '%s') -> false (unknown node)" % [character_id, node_id])
		return false

	if str(definition.get(STAT_NODE_CHARACTER_ID, "")) != character_id:
		print("[GameManager] unlock_stat_node('%s', '%s') -> false (node belongs to '%s')" % [
			character_id, node_id, str(definition.get(STAT_NODE_CHARACTER_ID, ""))
		])
		return false

	var unlocked: Array = get_stat_nodes(character_id)
	if node_id in unlocked:
		print("[GameManager] unlock_stat_node('%s', '%s') -> false (already unlocked)" % [character_id, node_id])
		return false

	if not can_unlock_stat_node(character_id, node_id):
		print("[GameManager] unlock_stat_node('%s', '%s') -> false (prerequisite not met)" % [character_id, node_id])
		return false

	var cost: int = int(definition.get(STAT_NODE_COST, 0))
	var remaining: int = get_stat_node_remaining_points(character_id)
	if remaining < cost:
		print("[GameManager] unlock_stat_node('%s', '%s') -> false (points %d < %d)" % [
			character_id, node_id, remaining, cost
		])
		return false

	# ここから状態を変える。
	unlocked.append(node_id)
	growth[GameStateKeys.GROWTH_NODES] = unlocked
	_write_growth(character_id, growth)

	print("[GameManager] unlock_stat_node('%s', '%s') -> true (spent=%d remaining=%d)" % [
		character_id, node_id, get_stat_node_spent_points(character_id),
		get_stat_node_remaining_points(character_id)
	])
	character_growth_changed.emit(character_id)
	return true


# 全解除。無料（GAME_DESIGN.md 5-3「いつでも無料で振り直せる」）。
# nodes を空にするだけ。ポイントは level から引いているので自動で戻る。
func reset_stat_nodes(character_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		push_warning("[GameManager] reset_stat_nodes: unknown character_id: " + character_id)
		return false

	var cleared: int = get_stat_nodes(character_id).size()
	if cleared == 0:
		print("[GameManager] reset_stat_nodes('%s') -> false (nothing to clear)" % character_id)
		return false

	growth[GameStateKeys.GROWTH_NODES] = []
	_write_growth(character_id, growth)

	print("[GameManager] reset_stat_nodes('%s') -> true (cleared %d nodes)" % [character_id, cleared])
	character_growth_changed.emit(character_id)
	return true


# --- 育成：スキル選択（EXEC_SKILL_SELECT.md） ---
#
# 候補6個から2枠を選んで戦闘に持ち込む（GAME_DESIGN.md 3-2）。
# セーブが持つのは character_growth.<id>.skills.slots（選んだスキルIDの配列）だけ。
# 倍率・CD・解放レベルは skills.json から毎回引く。
#
# 候補の一覧と並び順は characters.json の "skills" が決める
# （allocatable_stats と同じ思想。ここで候補を決め打ちしない）。

# 戦闘に持ち込める枠の数。
#
# ⚠ 枠は装備スロットに対応しない。スキルはそのまま持ち込むだけで、
# 武器・アクセサリーとの紐づきはルーン側だけの話（2026-08-15に確認）。
# ここに EQUIP_WEAPON / EQUIP_ACCESSORY を持ち込まないこと。
#
# .tres に置かないのは、これがバランス数値ではなく構造だから
# （_equip_slots() と同じ扱い）。枠を増やすときはここだけ直せば、
# 正規化・画面・戦闘への受け渡しは追従する。
const SKILL_SLOT_COUNT: int = 2

# パッシブの枠数（PLAN 7-2・段階3の後半④）。
# ⚠ スキル枠とは別枠（人間の決定・2026-08-17）。パッシブはスキル枠を消費しない。
const PASSIVE_SLOT_COUNT: int = 1

# 枠の種類。⚠ 枠の仕組みを複製しないための識別子（EXEC_SKILL_PASSIVE_VARS.md §3-4）。
#   3種類目を足すときも、関数をもう一式作らず _slot_spec() に1行足すこと。
const SLOT_KIND_SKILL: String = "skill"
const SLOT_KIND_PASSIVE: String = "passive"

# 枠の種類ごとに違うのは、この4つだけ。
#
# state_key   … growth の中のどのキーに入るか
# count       … 枠数
# master_key  … characters.json のどの配列が候補か
# fill_empty  … 未選択の枠を候補の先頭で埋めるか
#               ⚠ スキルは埋める（セーブに初期2個を書かないための仕組み）。
#                 パッシブは埋めない。埋めると「外したつもりのパッシブが勝手に付く」。
func _slot_spec(kind: String) -> Dictionary:
	if kind == SLOT_KIND_PASSIVE:
		return {
			"state_key": GameStateKeys.GROWTH_PASSIVES,
			"count": PASSIVE_SLOT_COUNT,
			"master_key": CHARACTER_PASSIVES,
			"fill_empty": false,
		}
	return {
		"state_key": GameStateKeys.GROWTH_SKILLS,
		"count": SKILL_SLOT_COUNT,
		"master_key": CHARACTER_SKILLS,
		"fill_empty": true,
	}

# 画面が枠を並べるために公開する。枠に名前は無いので、番号で並べる。
func get_skill_slot_count() -> int:
	return SKILL_SLOT_COUNT

func get_passive_slot_count() -> int:
	return PASSIVE_SLOT_COUNT

# 未選択の枠だけの配列。_default_growth_for() と正規化の両方から使う。
func _empty_slots(kind: String = SLOT_KIND_SKILL) -> Array:
	var slots: Array = []
	for _i: int in range(int(_slot_spec(kind)["count"])):
		slots.append("")
	return slots

# growth の枠を必ず {"slots": [長さ=枠数の文字列配列]} の形に直す。
# 渡された growth を直接書き換える。戻り値は「直したかどうか」。
#
# 旧セーブ（欄が無い／{}）と、将来枠数を変えたあとのセーブを、ここで吸収する。
# これがあるおかげで save_version を上げなくてよい（EXEC_SKILL_SELECT.md §9）。
#
# ⚠ 種類ごとに2本目を書かないこと。パッシブ枠を足したときに書き分けると、
#   片方だけ正規化されるセーブができる。
func _normalize_slots(growth: Dictionary, kind: String = SLOT_KIND_SKILL) -> bool:
	var spec: Dictionary = _slot_spec(kind)
	var state_key: String = str(spec["state_key"])
	var count: int = int(spec["count"])
	var changed: bool = false

	var holder_raw: Variant = growth.get(state_key, null)
	if not (holder_raw is Dictionary):
		holder_raw = {}
		changed = true
	var holder: Dictionary = holder_raw

	var slots_raw: Variant = holder.get(GameStateKeys.GROWTH_SKILL_SLOTS, null)
	if not (slots_raw is Array):
		slots_raw = []
		changed = true
	var slots: Array = (slots_raw as Array).duplicate()

	# 長さを枠数に合わせる。足りなければ "" で埋め、多ければ切る。
	while slots.size() < count:
		slots.append("")
		changed = true
	if slots.size() > count:
		slots.resize(count)
		changed = true

	# 中身は必ず String にする。JSON から戻すと null が混ざりうる。
	for i: int in range(slots.size()):
		var normalized: String = "" if slots[i] == null else str(slots[i])
		if slots[i] != normalized:
			changed = true
		slots[i] = normalized

	holder[GameStateKeys.GROWTH_SKILL_SLOTS] = slots
	growth[state_key] = holder
	return changed

# 全種類の枠をまとめて正規化する。⚠ 呼ぶ側は種類を数えないこと。
func _normalize_all_slots(growth: Dictionary) -> bool:
	var changed: bool = _normalize_slots(growth, SLOT_KIND_SKILL)
	if _normalize_slots(growth, SLOT_KIND_PASSIVE):
		changed = true
	return changed

# ロード時に全キャラの skills を正規化する。
# _resync_growth_stats_from_master() と同じ位置から呼ぶ。
# ============================================================
# パーティの編成（EXEC_PARTY_MEMBERS.md）
# ============================================================

# 編成が空／壊れているときに流し込む既定。⚠ parties.json の唯一のエントリ。
const DEFAULT_PARTY_ID: String = "party_default"


# 編成の3枠。⚠ 複製を返す（get_state() と同じ理由。参照を返すと呼び出し側から
#   _state を直接書き換えられ、「必ず関数経由」が構造的に破れる）。
func get_party_members() -> Array:
	var members: Variant = _state.get(GameStateKeys.PARTY_MEMBERS, [])
	if not (members is Array):
		return []
	return (members as Array).duplicate(true)


# 枠 index のキャラを差し替える。差し替えた（または既に同じだった）なら true。
#
# ⚠ 状態を変える前に全部の判定を終える（CLAUDE.md 6番）。途中で1枠だけ書いてから
#   弾くと、重複した編成が残る。
# ⚠ そのキャラが別の枠に居るときは「交換」する。片方を空にしない
#   （空き枠を作らないのが不変条件。作ると「2人で挑む」が書けてしまう）。
func set_party_member(index: int, character_id: String) -> bool:
	if index < 0 or index >= GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[GameManager] set_party_member: index が範囲外: %d" % index)
		return false
	# ⚠ get_character() を使わないこと。見つからないと push_error を出す口なので、
	#   「候補にあるか確かめる」用途に使うと正常系で赤が出る。
	if not MasterDataLoader.get_all_characters().has(character_id):
		push_error("[GameManager] set_party_member: 知らない character_id: " + character_id)
		return false

	var members: Array = get_party_members()
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[GameManager] set_party_member: 編成の件数が %d（%d のはず）" % [
			members.size(), GameStateKeys.PARTY_SLOT_COUNT
		])
		return false

	# 変わらないのも成功（画面が同じ項目を選び直しただけ）。
	if str(members[index]) == character_id:
		return true

	# ここまで判定だけ。ここから状態を作る。
	var other: int = members.find(character_id)
	if other >= 0:
		members[other] = members[index]
	members[index] = character_id

	_state[GameStateKeys.PARTY_MEMBERS] = members.duplicate(true)
	# ⚠ シグナルを飛ばさない。購読者は冒険選択の1画面だけで、押したハンドラの中で
	#   描き直すほうが安い。character_growth_changed を流用しないこと（あれは
	#   レベル・ステータス・装備・スキルの変化で、ギルドの4画面が聞いている）。
	# ⚠ パーティ選択画面ができて購読者が2つになったら party_changed を足す。
	#   そのとき AGENTS.md のシグナル表にも1行足すこと。
	return true


# セーブに編成が無い／壊れているときだけ、parties.json から流し込む。
#
# ⚠ research_tree / shop / recipes の「毎回マスターで上書き」とは逆（AGENTS.md
#   「マスターデータと状態を同期する型」を真似ないこと）。編成は進捗ではなく
#   プレイヤーの選択なので、毎回上書きすると入れ替えが起動のたびに巻き戻る。
#   しかもエラーは1つも出ない。
# ⚠ _normalize_skill_slots_from_save() と同じ位置づけ。旧セーブでもここで生えるので
#   save_version は 3 のままでよい。
# ⚠ 呼ぶ場所は _ready() と load_state() の2箇所。片方だけだと「新規開始で空」か
#   「ロードで空」のどちらかになり、どちらもエラーが出ない。
# ⚠ マスターに無いIDが1つでも混ざっていたら、その枠だけ直さず全体を既定に戻す。
#   半端に埋めると「知らないキャラが1人だけ居る」状態が残る。
func _ensure_party_members_from_master() -> void:
	if _is_party_members_valid():
		return

	var party_data: Dictionary = MasterDataLoader.get_party(DEFAULT_PARTY_ID)
	var raw: Variant = party_data.get("members", null)
	if not (raw is Array) or (raw as Array).size() != GameStateKeys.PARTY_SLOT_COUNT:
		# ⚠ 黙って既定を捏造しない。空のままにすると戦闘側が赤を出して気づける。
		push_error("[GameManager] _ensure_party_members_from_master: parties.json の '%s' が %d 人でない" % [
			DEFAULT_PARTY_ID, GameStateKeys.PARTY_SLOT_COUNT
		])
		return

	var members: Array = []
	for entry: Variant in (raw as Array):
		members.append(str(entry))
	_state[GameStateKeys.PARTY_MEMBERS] = members
	print("[GameManager] _ensure_party_members_from_master() -> %s" % str(members))


# 3枠ちょうどで、全部マスターに居て、重複が無いか。
func _is_party_members_valid() -> bool:
	var raw: Variant = _state.get(GameStateKeys.PARTY_MEMBERS, null)
	if not (raw is Array):
		return false
	var members: Array = raw as Array
	if members.size() != GameStateKeys.PARTY_SLOT_COUNT:
		return false
	var all_characters: Dictionary = MasterDataLoader.get_all_characters()
	var seen: Dictionary = {}
	for entry: Variant in members:
		var character_id: String = str(entry)
		if not all_characters.has(character_id):
			return false
		if seen.has(character_id):
			return false
		seen[character_id] = true
	return true


# 編成に出せるキャラ（character_id の配列）。並び順は characters.json の記述順。
#
# ⚠ 冒険選択とパーティ選択画面の2画面が同じ一覧を要るので、ここに1本だけ置く
#   （もとは adventure_select._collect_party_candidates() にあった）。
# ⚠ 検証用の3体はデバッグビルドでだけ出す。⚠ リリース前にこの分岐を消す（宿題16）。
# ⚠ 「所持しているキャラだけ」の概念はまだ無い。将来ここで絞る。
func get_party_candidates() -> Array[String]:
	var result: Array[String] = []
	var show_debug: bool = OS.is_debug_build()
	for character_id: Variant in MasterDataLoader.get_all_characters():
		var id: String = str(character_id)
		if not show_debug and id.begins_with("char_debug_"):
			continue
		result.append(id)
	return result


# ============================================================
# プリセット（2階層。GAME_DESIGN.md 5-5 / EXEC_PARTY_PRESETS.md）
# ============================================================
#
# キャラプリセット … 1キャラの「ビルド」。nodes / skills / passives / equipment。
# 編成プリセット   … 3人ぶんの「誰の、どの番号か」を参照で持つ。
#
# ⚠ 参照方式なので、キャラ側のビルドを直すと、それを参照している全編成に反映される
#   （DEMO_CHECKLIST.md 180）。⚠ 編成側にキャラの中身を複製しないこと。
# ⚠ 中身はIDだけ（CLAUDE.md 4番）。効果値はマスターから毎回引く。
# ⚠ 保存は「現在の状態を焼く」形（人間の決定・2026-08-23）。画面から中身を
#   1項目ずつ編集する機能は作らない（それはギルドの育成・装備画面の役）。

# 編成プリセットの本数（人間の決定・2026-08-23。固定本数。増やす仕組みは作らない）。
# ⚠ .tres に置かない。バランス数値ではなく構造（SKILL_SLOT_COUNT と同じ扱い）。
const PARTY_PRESET_COUNT: int = 10

# 1キャラあたりのキャラプリセットの枠数。
# ⚠ 3 は設計役が置いた数（GAME_DESIGN 5-5 は「キャラごとに複数」としか書いていない）。
const CHARACTER_PRESET_COUNT: int = 3

# プリセットが装備も持つか。
#
# ⚠ 2026-08-23に2回動いた欄：
#     1. 「装備プリセットはいったんやめる」で false にした
#     2. 実機で一通り触ったあと「装備にも適用がいる」で true に戻した
#   ⚠ いまは GAME_DESIGN 5-5（「キャラプリセットは装備一式を持つ」）と一致している。
# ⚠ false のあいだに焼いたビルドは equipment が5部位とも null で残る。
#   ⚠ true に戻したあと、それを適用すると裸になる。⚠ 焼き直しが要る
#     （「装備を焼かなかった」と「何も装備していない」を区別する術が無いため、
#       コード側では直せない。⚠ 人間に焼き直してもらうしかない）。
# ⚠ 常に true なら、この定数と分岐は消してよい（宿題）。
#   ⚠ 残してあるのは、1セッションで2回動いた欄だから。
const PRESET_EQUIPMENT_ENABLED: bool = true

# apply_party_preset() / get_party_preset_apply_report() の戻り値のキー。
# ⚠ 状態には入らないので GameStateKeys ではなくここに置く（INSTANCE_VIEW_* と同じ扱い）。
const APPLY_OK: String = "ok"
const APPLY_REASON: String = "reason"
const APPLY_MEMBERS: String = "members"
const APPLY_CONFLICTS: String = "conflicts"
const APPLY_MISSING: String = "missing"
const APPLY_NODES_SKIPPED: String = "nodes_skipped"
const APPLY_PLAN: String = "plan"
const APPLY_CHARACTER_ID: String = "character_id"
const APPLY_FROM_CHARACTER_ID: String = "from_character_id"
const APPLY_SLOT: String = "slot"
const APPLY_INSTANCE_ID: String = "instance_id"

# reason に入る翻訳キー。⚠ 画面がそのまま tr() に渡す。
const PRESET_REJECT_UNSAVED: String = "ui_party_preset_unsaved"
const PRESET_REJECT_REF_UNSAVED: String = "ui_party_preset_ref_unsaved"
const PRESET_REJECT_BROKEN: String = "ui_party_preset_broken"


func get_party_preset_count() -> int:
	return PARTY_PRESET_COUNT


func get_character_preset_count() -> int:
	return CHARACTER_PRESET_COUNT


# 空のキャラプリセット1件。⚠ saved が false の枠が「空き」。
func _empty_character_preset() -> Dictionary:
	return {
		GameStateKeys.PRESET_SAVED: false,
		GameStateKeys.GROWTH_NODES: [],
		GameStateKeys.GROWTH_SKILLS: {GameStateKeys.GROWTH_SKILL_SLOTS: _empty_slots(SLOT_KIND_SKILL)},
		GameStateKeys.GROWTH_PASSIVES: {GameStateKeys.GROWTH_SKILL_SLOTS: _empty_slots(SLOT_KIND_PASSIVE)},
		GameStateKeys.GROWTH_EQUIPMENT: _empty_equipment(),
		# ⚠ 5つ目のキー（GAME_DESIGN.md 7-7・段階8）。移動系ルーンを1つも
		#   刺していないキャラでは空のまま。
		GameStateKeys.GROWTH_RUNE_MOVE: {},
	}


# 空の編成プリセット1件。
func _empty_party_preset() -> Dictionary:
	return {
		GameStateKeys.PRESET_SAVED: false,
		GameStateKeys.PRESET_SLOTS: [],
	}


# 5部位ぶんの null。⚠ 装備の「無し」は null（_normalize_equipment_from_save() と揃える）。
func _empty_equipment() -> Dictionary:
	var equipment: Dictionary = {}
	for slot: String in _equip_slots():
		equipment[slot] = null
	return equipment


# 編成プリセット10件。⚠ 複製を返す。
func get_party_presets() -> Array:
	var presets: Variant = _state.get(GameStateKeys.PARTY_PRESETS, [])
	if not (presets is Array):
		return []
	return (presets as Array).duplicate(true)


# そのキャラのビルド3件。⚠ 無ければ空の器を返す（画面が件数を数えられるように）。
func get_character_presets(character_id: String) -> Array:
	var all_presets: Dictionary = _state.get(GameStateKeys.CHARACTER_PRESETS, {})
	var entry: Variant = all_presets.get(character_id, null)
	if not (entry is Array) or (entry as Array).size() != CHARACTER_PRESET_COUNT:
		var fallback: Array = []
		for _i: int in range(CHARACTER_PRESET_COUNT):
			fallback.append(_empty_character_preset())
		return fallback
	return (entry as Array).duplicate(true)


# ビルド1件。範囲外なら空の器。
func get_character_preset(character_id: String, index: int) -> Dictionary:
	if index < 0 or index >= CHARACTER_PRESET_COUNT:
		return _empty_character_preset()
	var presets: Array = get_character_presets(character_id)
	var entry: Variant = presets[index]
	if not (entry is Dictionary):
		return _empty_character_preset()
	return entry as Dictionary


func _write_character_presets(character_id: String, presets: Array) -> void:
	var all_presets: Dictionary = _copy_dict(GameStateKeys.CHARACTER_PRESETS)
	all_presets[character_id] = presets
	_state[GameStateKeys.CHARACTER_PRESETS] = all_presets


# 現在の状態をビルドへ焼く（人間の決定8）。
#
# ⚠ get_battle_skills() を焼かないこと。あれは未選択の枠を候補の先頭で埋めた確定版で、
#   焼くと「選んでいないものが選んだことになる」。プリセットは未選択もそのまま持つ。
func save_character_preset(character_id: String, index: int) -> bool:
	if index < 0 or index >= CHARACTER_PRESET_COUNT:
		push_error("[GameManager] save_character_preset: index が範囲外: %d" % index)
		return false
	if get_character_growth(character_id).is_empty():
		push_error("[GameManager] save_character_preset: 知らない character_id: " + character_id)
		return false

	# ここまで判定だけ。ここから状態を作る。
	var equipment: Dictionary = _empty_equipment()
	# ⚠ 装備はいったん焼かない（PRESET_EQUIPMENT_ENABLED）。欄は空のまま残す。
	if PRESET_EQUIPMENT_ENABLED:
		for slot: String in _equip_slots():
			var instance_id: String = get_equipped_instance_id(character_id, slot)
			equipment[slot] = null if instance_id == "" else instance_id

	var preset: Dictionary = {
		GameStateKeys.PRESET_SAVED: true,
		GameStateKeys.GROWTH_NODES: get_stat_nodes(character_id),
		GameStateKeys.GROWTH_SKILLS: {
			GameStateKeys.GROWTH_SKILL_SLOTS: get_selected_skills(character_id),
		},
		GameStateKeys.GROWTH_PASSIVES: {
			GameStateKeys.GROWTH_SKILL_SLOTS: get_selected_passives(character_id),
		},
		GameStateKeys.GROWTH_EQUIPMENT: equipment,
		# ⚠ 移動系ルーンの移動量（GAME_DESIGN.md 7-7）。装備と違って取り合いが
		#   起きないので、そのまま複製して焼く。
		GameStateKeys.GROWTH_RUNE_MOVE: _current_rune_move(character_id),
	}

	var presets: Array = get_character_presets(character_id)
	presets[index] = preset
	_write_character_presets(character_id, presets)

	print("[GameManager] save_character_preset('%s', %d) -> true (nodes=%d skills=%s equipment=%s)" % [
		character_id, index, (preset[GameStateKeys.GROWTH_NODES] as Array).size(),
		str(preset[GameStateKeys.GROWTH_SKILLS]), str(equipment),
	])
	return true


# 編成プリセットを焼く。slots は [{character_id, preset_index} × PARTY_SLOT_COUNT]。
#
# ⚠ 中身を複製せず、参照だけ持つ（GAME_DESIGN 5-5）。
# ⚠ 状態を変える前に全部の判定を終える（CLAUDE.md 6番）。
func save_party_preset(index: int, slots: Array) -> bool:
	if index < 0 or index >= PARTY_PRESET_COUNT:
		push_error("[GameManager] save_party_preset: index が範囲外: %d" % index)
		return false
	if slots.size() != GameStateKeys.PARTY_SLOT_COUNT:
		push_error("[GameManager] save_party_preset: 枠が %d 件（%d のはず）" % [
			slots.size(), GameStateKeys.PARTY_SLOT_COUNT
		])
		return false

	var all_characters: Dictionary = MasterDataLoader.get_all_characters()
	var seen: Dictionary = {}
	var normalized: Array = []
	for entry: Variant in slots:
		if not (entry is Dictionary):
			push_error("[GameManager] save_party_preset: 枠が Dictionary でない")
			return false
		var slot: Dictionary = entry
		var character_id: String = str(slot.get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var preset_index: int = int(slot.get(GameStateKeys.PRESET_INDEX, -1))
		if not all_characters.has(character_id):
			push_error("[GameManager] save_party_preset: 知らない character_id: " + character_id)
			return false
		if seen.has(character_id):
			push_error("[GameManager] save_party_preset: 同じキャラが2枠に居る: " + character_id)
			return false
		if preset_index < 0 or preset_index >= CHARACTER_PRESET_COUNT:
			push_error("[GameManager] save_party_preset: preset_index が範囲外: %d" % preset_index)
			return false
		seen[character_id] = true
		normalized.append({
			GameStateKeys.PRESET_CHARACTER_ID: character_id,
			GameStateKeys.PRESET_INDEX: preset_index,
		})

	# ここまで判定だけ。ここから状態を作る。

	# ⚠ 参照先のビルドが空なら、その場で焼く（人間の決定・2026-08-23）。
	#
	# ⚠ これが無いと行き止まりになる：「編成を保存 → 適用」を押しても
	#   ui_party_preset_ref_unsaved で弾かれ続け、⚠ 画面のどこにも
	#   「先にビルドを焼け」と書いていないので抜け出せない（実際に踏んだ）。
	# ⚠ 既に保存済みのビルドは触らない。⚠ 他の編成プリセットが参照しているものを
	#   黙って上書きすると、参照方式の利点（1つ直せば全編成に反映）が
	#   「1つ壊せば全編成が壊れる」に反転する。
	# ⚠ 意図的な焼き直しは、育成画面かこの画面の「焼く」でやる。
	var burned: Array[String] = []
	for entry: Variant in normalized:
		var slot: Dictionary = entry
		var character_id: String = str(slot[GameStateKeys.PRESET_CHARACTER_ID])
		var preset_index: int = int(slot[GameStateKeys.PRESET_INDEX])
		if bool(get_character_preset(character_id, preset_index).get(GameStateKeys.PRESET_SAVED, false)):
			continue
		if save_character_preset(character_id, preset_index):
			burned.append("%s[%d]" % [character_id, preset_index])

	var presets: Array = get_party_presets()
	presets[index] = {
		GameStateKeys.PRESET_SAVED: true,
		GameStateKeys.PRESET_SLOTS: normalized,
	}
	_state[GameStateKeys.PARTY_PRESETS] = presets

	print("[GameManager] save_party_preset(%d) -> true (%s / 空だったので焼いたビルド=%s)" % [
		index, str(normalized), str(burned)
	])
	return true


# 編成プリセットを空きに戻す。⚠ キャラ側のビルドは消さない（参照が宙に浮くため）。
func clear_party_preset(index: int) -> bool:
	if index < 0 or index >= PARTY_PRESET_COUNT:
		push_error("[GameManager] clear_party_preset: index が範囲外: %d" % index)
		return false
	var presets: Array = get_party_presets()
	var entry: Variant = presets[index]
	if entry is Dictionary and not bool((entry as Dictionary).get(GameStateKeys.PRESET_SAVED, false)):
		return false
	presets[index] = _empty_party_preset()
	_state[GameStateKeys.PARTY_PRESETS] = presets
	print("[GameManager] clear_party_preset(%d) -> true" % index)
	return true


# その nodes の集合を当てられない理由。当てられるなら ""。
#
# ⚠ 呼ぶ順で結果が変わらないよう、集合として見る（unlock_stat_node() を1件ずつ
#   呼ぶと、前提条件の順で通ったり通らなかったりする）。
func _nodes_reject_reason(character_id: String, nodes: Array) -> String:
	var wanted: Dictionary = {}
	for node_id: Variant in nodes:
		wanted[str(node_id)] = true

	var total_cost: int = 0
	for node_id: Variant in nodes:
		var id: String = str(node_id)
		var definition: Dictionary = MasterDataLoader.get_character_node(id)
		if definition.is_empty():
			return "unknown node: " + id
		if str(definition.get(STAT_NODE_CHARACTER_ID, "")) != character_id:
			return "node belongs to another character: " + id
		var prerequisites: Variant = definition.get(STAT_NODE_PREREQUISITES, [])
		if prerequisites is Array:
			for required: Variant in (prerequisites as Array):
				if not wanted.has(str(required)):
					return "prerequisite missing: %s needs %s" % [id, str(required)]
		total_cost += int(definition.get(STAT_NODE_COST, 0))

	var available: int = get_stat_node_total_points(character_id)
	if total_cost > available:
		return "points %d < %d" % [available, total_cost]
	return ""


# 適用できるか／何が起きるかを数える。⚠ 状態を1つも触らない
#   （can_unlock_stat_node() と同じ形。apply_party_preset() はこれを呼んでから動く）。
#
# 戻り値：
#   ok             … 適用できるか
#   reason         … ok が false のときだけ。翻訳キー
#   members        … 適用後の3人（character_id）
#   conflicts      … [{from_character_id, character_id, slot, instance_id}] 奪うもの
#   missing        … [{character_id, slot, instance_id}] 個体が消えていて空にするもの
#   nodes_skipped  … [{character_id, reason}] nodes を当てないキャラ
#   plan           … {character_id: {slot: instance_id or ""}} ⚠ 画面は読まない
func get_party_preset_apply_report(index: int) -> Dictionary:
	var report: Dictionary = {
		APPLY_OK: false,
		APPLY_REASON: PRESET_REJECT_BROKEN,
		APPLY_MEMBERS: [],
		APPLY_CONFLICTS: [],
		APPLY_MISSING: [],
		APPLY_NODES_SKIPPED: [],
		APPLY_PLAN: {},
	}
	if index < 0 or index >= PARTY_PRESET_COUNT:
		push_error("[GameManager] get_party_preset_apply_report: index が範囲外: %d" % index)
		return report

	var presets: Array = get_party_presets()
	var entry: Variant = presets[index] if index < presets.size() else null
	if not (entry is Dictionary) or not bool((entry as Dictionary).get(GameStateKeys.PRESET_SAVED, false)):
		report[APPLY_REASON] = PRESET_REJECT_UNSAVED
		return report

	var slots: Variant = (entry as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
	if not (slots is Array) or (slots as Array).size() != GameStateKeys.PARTY_SLOT_COUNT:
		report[APPLY_REASON] = PRESET_REJECT_BROKEN
		return report

	# --- 参照先を引く ---
	var members: Array = []
	var builds: Array = []
	var all_characters: Dictionary = MasterDataLoader.get_all_characters()
	var seen: Dictionary = {}
	for slot_entry: Variant in (slots as Array):
		if not (slot_entry is Dictionary):
			report[APPLY_REASON] = PRESET_REJECT_BROKEN
			return report
		var slot_data: Dictionary = slot_entry
		var character_id: String = str(slot_data.get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var preset_index: int = int(slot_data.get(GameStateKeys.PRESET_INDEX, -1))
		if not all_characters.has(character_id) or seen.has(character_id):
			report[APPLY_REASON] = PRESET_REJECT_BROKEN
			return report
		if preset_index < 0 or preset_index >= CHARACTER_PRESET_COUNT:
			report[APPLY_REASON] = PRESET_REJECT_BROKEN
			return report
		var build: Dictionary = get_character_preset(character_id, preset_index)
		if not bool(build.get(GameStateKeys.PRESET_SAVED, false)):
			report[APPLY_REASON] = PRESET_REJECT_REF_UNSAVED
			return report
		seen[character_id] = true
		members.append(character_id)
		builds.append(build)

	# --- ここから「当てられるものを数える」。状態は触らない ---
	var conflicts: Array = []
	var missing: Array = []
	var nodes_skipped: Array = []
	var plan: Dictionary = {}
	# 同じ個体を2人が要求したときに、先に取ったほうを覚えておく（枠の若いほうが勝つ）。
	var claimed: Dictionary = {}

	for i: int in range(members.size()):
		_plan_build(
			str(members[i]), builds[i], members, claimed,
			conflicts, missing, nodes_skipped, plan
		)

	report[APPLY_OK] = true
	report[APPLY_REASON] = ""
	report[APPLY_MEMBERS] = members
	report[APPLY_CONFLICTS] = conflicts
	report[APPLY_MISSING] = missing
	report[APPLY_NODES_SKIPPED] = nodes_skipped
	report[APPLY_PLAN] = plan
	return report


# ビルド1つぶんを「当てられるか」数える。⚠ 状態を1つも触らない。
#
# ⚠ 編成プリセット（3人）と、キャラ単体の適用の両方がここを通る。
#   ⚠ 2本目を書かないこと。片方だけ直る形になる。
# ⚠ together は「同じ適用で一緒に組み替えるキャラ」。編成プリセットなら3人、
#   キャラ単体ならその1人。⚠ この中で装備が移るぶんは conflicts に積まない
#   （どちらも同じ適用でビルドを当て直すので、焼いたときの意図どおり）。
# ⚠ claimed は「同じ個体を2人が要求したときに、先に取ったほうを覚える」表。
#   ⚠ 枠の若いほうが勝つ（決めておかないと Dictionary の順に依存する）。
func _plan_build(
	character_id: String, build_raw: Variant, together: Array, claimed: Dictionary,
	conflicts: Array, missing: Array, nodes_skipped: Array, plan: Dictionary
) -> void:
	var build: Dictionary = build_raw if build_raw is Dictionary else {}

	var nodes: Variant = build.get(GameStateKeys.GROWTH_NODES, [])
	var nodes_reason: String = _nodes_reject_reason(
		character_id, (nodes as Array) if nodes is Array else []
	)
	if nodes_reason != "":
		nodes_skipped.append({APPLY_CHARACTER_ID: character_id, APPLY_REASON: nodes_reason})

	# ⚠ 装備を止めているとき（PRESET_EQUIPMENT_ENABLED）は plan を空のままにする。
	#   ⚠ apply 側が装備に触らなくなる（空にするのではない）。
	if not PRESET_EQUIPMENT_ENABLED:
		plan[character_id] = {}
		return

	var wanted_equipment: Variant = build.get(GameStateKeys.GROWTH_EQUIPMENT, {})
	var slot_plan: Dictionary = {}
	for slot: String in _equip_slots():
		slot_plan[slot] = ""
		var value: Variant = (wanted_equipment as Dictionary).get(slot, null) if wanted_equipment is Dictionary else null
		if value == null:
			continue
		var instance_id: String = str(value)

		# 個体が消えている（分解された）。⚠ その枠だけ空にして続ける。赤も黄も出さない。
		var equip_reason: String = get_equip_reject_reason(character_id, slot, instance_id, true)
		if equip_reason != "":
			missing.append({
				APPLY_CHARACTER_ID: character_id,
				APPLY_SLOT: slot,
				APPLY_INSTANCE_ID: instance_id,
			})
			continue

		# 同じ個体を2人が要求した。負けたほうは奪われた側として積む。
		if claimed.has(instance_id):
			conflicts.append({
				APPLY_FROM_CHARACTER_ID: str(claimed[instance_id]),
				APPLY_CHARACTER_ID: character_id,
				APPLY_SLOT: slot,
				APPLY_INSTANCE_ID: instance_id,
			})
			continue

		var owner: String = _equipped_owner(instance_id)
		if owner != "" and owner != character_id and not (owner in together):
			conflicts.append({
				APPLY_FROM_CHARACTER_ID: owner,
				APPLY_CHARACTER_ID: character_id,
				APPLY_SLOT: slot,
				APPLY_INSTANCE_ID: instance_id,
			})
		claimed[instance_id] = character_id
		slot_plan[slot] = instance_id
	plan[character_id] = slot_plan


# 編成プリセットを適用する。戻り値は get_party_preset_apply_report() と同じ形。
#
# ⚠ 判定は1本（上の関数）。ここに2本目を書かないこと。
# ⚠ 状態を変えるのは「--- ここから ---」より下だけ（CLAUDE.md 6番）。
# ⚠ character_growth_changed は1キャラにつき1回にまとめる。部位ごとに飛ばすと
#   5本飛び、await を持つ倉庫画面が二重に並ぶ（AGENTS.md）。
func apply_party_preset(index: int) -> Dictionary:
	var report: Dictionary = get_party_preset_apply_report(index)
	if not bool(report.get(APPLY_OK, false)):
		print("[GameManager] apply_party_preset(%d) -> false (%s)" % [
			index, str(report.get(APPLY_REASON, ""))
		])
		return report

	var members: Array = report[APPLY_MEMBERS]
	var plan: Dictionary = report[APPLY_PLAN]
	var skipped: Dictionary = {}
	for entry: Variant in (report[APPLY_NODES_SKIPPED] as Array):
		skipped[str((entry as Dictionary).get(APPLY_CHARACTER_ID, ""))] = true

	# --- ここから状態を変える ---

	# 1. 奪う側を先に外す。
	_unequip_conflicts(report)

	# 2. 編成を書く。⚠ set_party_member() が唯一の口。_state を直接書かない。
	#    ⚠ 3人が互いに違えば、枠0→1→2 の順に呼ぶと必ず目標どおりになる
	#      （枠0を確定させると、以降の交換は枠1以上しか触らないため）。
	for i: int in range(members.size()):
		set_party_member(i, str(members[i]))

	# 3. 各キャラの中身を当てる。⚠ 書き込みは1キャラ1回。
	for i: int in range(members.size()):
		var character_id: String = str(members[i])
		_write_build(
			character_id,
			get_character_preset(character_id, _referenced_preset_index(index, character_id)),
			plan.get(character_id, {}),
			skipped.has(character_id)
		)

	print("[GameManager] apply_party_preset(%d) -> true (members=%s conflicts=%d missing=%d nodes_skipped=%d)" % [
		index, str(members), (report[APPLY_CONFLICTS] as Array).size(),
		(report[APPLY_MISSING] as Array).size(), (report[APPLY_NODES_SKIPPED] as Array).size(),
	])
	return report


# 奪う側を先に外す。⚠ 外す前に着けると _equipped_owner() が別人を返して
#   get_equip_reject_reason() が弾く。
func _unequip_conflicts(report: Dictionary) -> void:
	for entry: Variant in (report.get(APPLY_CONFLICTS, []) as Array):
		var instance_id: String = str((entry as Dictionary).get(APPLY_INSTANCE_ID, ""))
		var owner: String = _equipped_owner(instance_id)
		if owner == "":
			continue
		for slot: String in _equip_slots():
			if get_equipped_instance_id(owner, slot) == instance_id:
				unequip_instance(owner, slot)
				break


# ビルド1つぶんを growth へ書き込む。⚠ 書き込みは1キャラ1回・シグナルも1本。
#
# ⚠ 部位ごとに _write_growth() を呼ぶと5本飛び、await を持つ倉庫画面が
#   二重に並ぶ（AGENTS.md「再描画は await を持たせない」）。
# ⚠ 判定は _plan_build() で済んでいる。ここで弾かないこと。
func _write_build(
	character_id: String, build_raw: Variant, slot_plan: Dictionary, skip_nodes: bool
) -> void:
	var build: Dictionary = build_raw if build_raw is Dictionary else {}
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		return

	# nodes … ⚠ unlock_stat_node() を1件ずつ呼ばない（呼ぶ順で前提条件に
	#   引っかかる）。検証を通した配列をそのまま書く。
	if not skip_nodes:
		var nodes: Variant = build.get(GameStateKeys.GROWTH_NODES, [])
		growth[GameStateKeys.GROWTH_NODES] = (nodes as Array).duplicate(true) if nodes is Array else []

	# skills / passives … ⚠ select_skill() を呼ばない（あれは「別の枠に居たら
	#   交換」をするので、配列をそのまま当てるのと結果が変わる）。
	for kind: String in [SLOT_KIND_SKILL, SLOT_KIND_PASSIVE]:
		var state_key: String = str(_slot_spec(kind)["state_key"])
		var holder: Variant = build.get(state_key, null)
		if holder is Dictionary:
			growth[state_key] = (holder as Dictionary).duplicate(true)
	_normalize_all_slots(growth)

	# equipment … 計画どおりに置き換える。
	# ⚠ 装備を止めているとき（PRESET_EQUIPMENT_ENABLED = false）は計画が空。
	#   ⚠ そのときは growth の equipment に一切触らない。空の計画で上書きすると、
	#     プリセットを当てるたびに裸になる。
	if PRESET_EQUIPMENT_ENABLED:
		var equipment: Dictionary = _empty_equipment()
		for slot: String in _equip_slots():
			var instance_id: String = str(slot_plan.get(slot, ""))
			equipment[slot] = null if instance_id == "" else instance_id
		growth[GameStateKeys.GROWTH_EQUIPMENT] = equipment

	# rune_move … ⚠ 装備の有無（PRESET_EQUIPMENT_ENABLED）とは無関係に当てる。
	#   ⚠ 欄が無い古いビルドでは触らない（当てるたびに移動量が消えるのを避ける）。
	var raw_rune_move: Variant = build.get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	if raw_rune_move is Dictionary:
		growth[GameStateKeys.GROWTH_RUNE_MOVE] = _valid_rune_move(
			character_id, raw_rune_move as Dictionary
		)

	_write_growth(character_id, growth)
	character_growth_changed.emit(character_id)


# いま選んである移動量をそのまま取り出す（焼くときに使う）。
func _current_rune_move(character_id: String) -> Dictionary:
	var raw: Variant = get_character_growth(character_id).get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	return _valid_rune_move(character_id, raw as Dictionary) if raw is Dictionary else {}


# 移動量の表から「いま成り立つもの」だけを残す。
#
# ⚠ 正規化（セーブ・プリセット）と適用の両方がここを通る。判定を2本目に書かない。
# ⚠ 落とすのは3通り：ルーンでないキー／移動系でないルーン／choices に無い値。
#   ⚠ どれも「ルーンを重ねて段階が上がった」「JSONの選択肢を狭めた」で普通に起きる。
#     正常系なので黄を出さない。
func _valid_rune_move(character_id: String, stored: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_item_id: Variant in stored:
		var item_id: String = str(raw_item_id)
		var choices: Array[int] = get_rune_move_choices(item_id)
		if choices.is_empty():
			continue
		var distance: int = int(stored[raw_item_id])
		if not (distance in choices):
			continue
		result[item_id] = distance
	return result


# --- キャラ単体の適用（育成画面・装備画面の「適用」ボタン） ---
#
# ⚠ 編成プリセットは3人まとめて当てる口。⚠ 1人だけ当て直したいときの口がこれ。
#   ⚠ 判定も書き込みも編成プリセットと同じ部品（_plan_build / _write_build）を通る。
#   ⚠ 2本目を書かないこと。
# ⚠ 編成は触らない。⚠ 当てるのはそのキャラの中身だけ（set_party_member() を呼ばない）。

# 当てられるか／何が起きるかを数える。⚠ 状態を1つも触らない。
func get_character_preset_apply_report(character_id: String, index: int) -> Dictionary:
	var report: Dictionary = {
		APPLY_OK: false,
		APPLY_REASON: PRESET_REJECT_BROKEN,
		APPLY_MEMBERS: [],
		APPLY_CONFLICTS: [],
		APPLY_MISSING: [],
		APPLY_NODES_SKIPPED: [],
		APPLY_PLAN: {},
	}
	if index < 0 or index >= CHARACTER_PRESET_COUNT:
		push_error("[GameManager] get_character_preset_apply_report: index が範囲外: %d" % index)
		return report
	if get_character_growth(character_id).is_empty():
		push_error("[GameManager] get_character_preset_apply_report: 知らない character_id: " + character_id)
		return report

	var build: Dictionary = get_character_preset(character_id, index)
	if not bool(build.get(GameStateKeys.PRESET_SAVED, false)):
		# ⚠ 「空きのビルドを当てようとした」は正常系。赤を出さない。
		report[APPLY_REASON] = PRESET_REJECT_UNSAVED
		return report

	var conflicts: Array = []
	var missing: Array = []
	var nodes_skipped: Array = []
	var plan: Dictionary = {}
	# ⚠ together はこの1人だけ。⚠ 他のキャラが持っている装備は全部「奪う」対象になる。
	_plan_build(character_id, build, [character_id], {}, conflicts, missing, nodes_skipped, plan)

	report[APPLY_OK] = true
	report[APPLY_REASON] = ""
	report[APPLY_MEMBERS] = [character_id]
	report[APPLY_CONFLICTS] = conflicts
	report[APPLY_MISSING] = missing
	report[APPLY_NODES_SKIPPED] = nodes_skipped
	report[APPLY_PLAN] = plan
	return report


# 当てる。戻り値は get_character_preset_apply_report() と同じ形。
func apply_character_preset(character_id: String, index: int) -> Dictionary:
	var report: Dictionary = get_character_preset_apply_report(character_id, index)
	if not bool(report.get(APPLY_OK, false)):
		print("[GameManager] apply_character_preset('%s', %d) -> false (%s)" % [
			character_id, index, str(report.get(APPLY_REASON, ""))
		])
		return report

	# --- ここから状態を変える ---
	_unequip_conflicts(report)

	var skipped: bool = not (report[APPLY_NODES_SKIPPED] as Array).is_empty()
	_write_build(
		character_id, get_character_preset(character_id, index),
		(report[APPLY_PLAN] as Dictionary).get(character_id, {}), skipped
	)

	print("[GameManager] apply_character_preset('%s', %d) -> true (conflicts=%d missing=%d nodes_skipped=%d)" % [
		character_id, index, (report[APPLY_CONFLICTS] as Array).size(),
		(report[APPLY_MISSING] as Array).size(), (report[APPLY_NODES_SKIPPED] as Array).size(),
	])
	return report


# 適用の結果を、画面にそのまま出せる1つの文にする。
#
# ⚠ ここに置いたのは、⚠ 適用の口が3つ（パーティ選択・育成・装備）に増えたため。
#   ⚠ 文面を画面ごとに書くと、⚠ 「奪った」の言い回しが3通りになる。
# ⚠ 本来 GameManager は表示を持たない層だが、⚠ report が返す reason は
#   もともと翻訳キーなので、⚠ ここは既にその境目にある。
# ⚠ 黙って強くなったり弱くなったりさせない（人間の決定）。奪ったもの・
#   消えていたものを1件1行で出す。
func format_apply_report(report: Dictionary) -> String:
	if not bool(report.get(APPLY_OK, false)):
		return tr(str(report.get(APPLY_REASON, "")))

	var lines: Array[String] = []
	for entry: Variant in (report.get(APPLY_CONFLICTS, []) as Array):
		var conflict: Dictionary = entry
		lines.append(tr("ui_party_preset_taken") % [
			_character_name(str(conflict.get(APPLY_FROM_CHARACTER_ID, ""))),
			_instance_name(str(conflict.get(APPLY_INSTANCE_ID, ""))),
		])
	for entry: Variant in (report.get(APPLY_MISSING, []) as Array):
		var missing: Dictionary = entry
		lines.append(tr("ui_party_preset_missing") % [
			_character_name(str(missing.get(APPLY_CHARACTER_ID, ""))),
			tr("ui_equipment_slot_" + str(missing.get(APPLY_SLOT, ""))),
		])
	for entry: Variant in (report.get(APPLY_NODES_SKIPPED, []) as Array):
		var skipped: Dictionary = entry
		lines.append(tr("ui_party_preset_nodes_skipped") % _character_name(
			str(skipped.get(APPLY_CHARACTER_ID, ""))
		))
	if lines.is_empty():
		return tr("ui_party_preset_applied")
	return "\n".join(lines)


func _character_name(character_id: String) -> String:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	return tr(str(char_data.get("name_key", character_id)))


# 個体の表示名。⚠ 個体は item_id を持つので、名前はマスターから引く。
func _instance_name(instance_id: String) -> String:
	var instance: Dictionary = get_equipment_instance(instance_id)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	if item_id == "":
		return instance_id
	return tr(str(MasterDataLoader.get_item(item_id).get("name_key", item_id)))


# 編成プリセット index が、そのキャラのどの番号を参照しているか。
# ⚠ get_party_preset_apply_report() が通ったあとにだけ呼ぶ（範囲は検証済み）。
func _referenced_preset_index(index: int, character_id: String) -> int:
	var presets: Array = get_party_presets()
	var entry: Variant = presets[index] if index < presets.size() else null
	if not (entry is Dictionary):
		return -1
	var slots: Variant = (entry as Dictionary).get(GameStateKeys.PRESET_SLOTS, [])
	if not (slots is Array):
		return -1
	for slot_entry: Variant in (slots as Array):
		if not (slot_entry is Dictionary):
			continue
		if str((slot_entry as Dictionary).get(GameStateKeys.PRESET_CHARACTER_ID, "")) == character_id:
			return int((slot_entry as Dictionary).get(GameStateKeys.PRESET_INDEX, -1))
	return -1


# プリセットの形を揃え、指し先が消えたものを落とす。
#
# ⚠ _sync_*_from_master() の「毎回マスターで上書き」は真似ないこと。編成と同じく、
#   プリセットは進捗ではなくプレイヤーの選択で、上書きすると起動のたびに巻き戻る。
# ⚠ 知らないキーを消さないこと。段階8（ルーン）の移動量がここに5つ目のキーとして入る。
# ⚠ push_warning を出さないこと。装備を分解して参照が切れるのは正常系
#   （確率でも操作でも普通に起きる。ログが埋まる）。
# ⚠ 呼ぶ場所は _ready() と load_state() の2箇所。片方だけだと「新規開始で空」か
#   「ロードで空」のどちらかになり、どちらもエラーが出ない。
# ⚠ load_state() では _normalize_equipment_from_save() より後に呼ぶこと
#   （消えた個体の判定に、正規化済みの equipment_instances が要る）。
func _normalize_presets_from_save() -> void:
	var fixed: int = 0
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	var all_characters: Dictionary = MasterDataLoader.get_all_characters()

	# --- キャラプリセット ---
	var raw_characters: Variant = _state.get(GameStateKeys.CHARACTER_PRESETS, {})
	var all_presets: Dictionary = (raw_characters as Dictionary).duplicate(true) if raw_characters is Dictionary else {}
	for character_id: String in all_presets.keys():
		# マスターに無いキャラのぶんは、エントリごと落とす。
		if not all_characters.has(character_id):
			all_presets.erase(character_id)
			fixed += 1
			continue

		var raw_list: Variant = all_presets[character_id]
		var list: Array = (raw_list as Array).duplicate(true) if raw_list is Array else []
		if not (raw_list is Array):
			fixed += 1
		while list.size() < CHARACTER_PRESET_COUNT:
			list.append(_empty_character_preset())
			fixed += 1
		if list.size() > CHARACTER_PRESET_COUNT:
			list.resize(CHARACTER_PRESET_COUNT)
			fixed += 1

		for i: int in range(list.size()):
			if _normalize_character_preset(list, i, character_id, instances):
				fixed += 1
		all_presets[character_id] = list
	_state[GameStateKeys.CHARACTER_PRESETS] = all_presets

	# --- 編成プリセット ---
	var raw_party: Variant = _state.get(GameStateKeys.PARTY_PRESETS, [])
	var party_presets: Array = (raw_party as Array).duplicate(true) if raw_party is Array else []
	if not (raw_party is Array):
		fixed += 1
	while party_presets.size() < PARTY_PRESET_COUNT:
		party_presets.append(_empty_party_preset())
		fixed += 1
	if party_presets.size() > PARTY_PRESET_COUNT:
		party_presets.resize(PARTY_PRESET_COUNT)
		fixed += 1

	for i: int in range(party_presets.size()):
		if _normalize_party_preset(party_presets, i, all_characters):
			fixed += 1
	_state[GameStateKeys.PARTY_PRESETS] = party_presets

	print("[GameManager] _normalize_presets_from_save() -> %d fixed (%d characters, %d party presets)" % [
		fixed, all_presets.size(), party_presets.size()
	])


# キャラプリセット1件を直す。直したら true。
# ⚠ 知らないキーは残す（entry を作り直さず、足りないものだけ足す）。
func _normalize_character_preset(
	list: Array, index: int, character_id: String, instances: Dictionary
) -> bool:
	var changed: bool = false
	var raw: Variant = list[index]
	if not (raw is Dictionary):
		list[index] = _empty_character_preset()
		return true
	var preset: Dictionary = raw

	if not (preset.get(GameStateKeys.PRESET_SAVED, null) is bool):
		preset[GameStateKeys.PRESET_SAVED] = false
		changed = true

	# nodes … マスターに無いノードと、他のキャラのノードを落とす。
	var raw_nodes: Variant = preset.get(GameStateKeys.GROWTH_NODES, null)
	var nodes: Array = []
	if raw_nodes is Array:
		for node_id: Variant in (raw_nodes as Array):
			var definition: Dictionary = MasterDataLoader.get_character_node(str(node_id))
			if definition.is_empty():
				changed = true
				continue
			if str(definition.get(STAT_NODE_CHARACTER_ID, "")) != character_id:
				changed = true
				continue
			nodes.append(str(node_id))
	else:
		changed = true
	preset[GameStateKeys.GROWTH_NODES] = nodes

	# skills / passives … ⚠ growth と同じ形なので _normalize_slots() をそのまま当てる。
	if _normalize_all_slots(preset):
		changed = true

	# equipment … 消えた個体を null に戻す（_normalize_equipment_from_save() と同じ扱い）。
	var raw_equipment: Variant = preset.get(GameStateKeys.GROWTH_EQUIPMENT, null)
	var equipment: Dictionary = _empty_equipment()
	for slot: String in _equip_slots():
		var value: Variant = (raw_equipment as Dictionary).get(slot, null) if raw_equipment is Dictionary else null
		if value == null:
			continue
		var instance_id: String = str(value)
		if instances.has(instance_id):
			equipment[slot] = instance_id
		else:
			changed = true
	if not (raw_equipment is Dictionary):
		changed = true
	preset[GameStateKeys.GROWTH_EQUIPMENT] = equipment

	# rune_move … ⚠ 段階8で足した5つ目のキー。器が無い古いセーブでは空で作る。
	#   ⚠ 中身は _valid_rune_move() が1本で洗う（正規化と適用で2本目を書かない）。
	var raw_rune_move: Variant = preset.get(GameStateKeys.GROWTH_RUNE_MOVE, null)
	var rune_move: Dictionary = _valid_rune_move(
		character_id, (raw_rune_move as Dictionary) if raw_rune_move is Dictionary else {}
	)
	if not (raw_rune_move is Dictionary) or rune_move.size() != (raw_rune_move as Dictionary).size():
		changed = true
	preset[GameStateKeys.GROWTH_RUNE_MOVE] = rune_move

	list[index] = preset
	return changed


# 編成プリセット1件を直す。直したら true。
# ⚠ 半端に埋めないこと。1箇所でも壊れていたら空きに戻す
#   （_ensure_party_members_from_master() と同じ流儀）。
func _normalize_party_preset(presets: Array, index: int, all_characters: Dictionary) -> bool:
	var raw: Variant = presets[index]
	if not (raw is Dictionary):
		presets[index] = _empty_party_preset()
		return true
	var preset: Dictionary = raw

	if not bool(preset.get(GameStateKeys.PRESET_SAVED, false)):
		if preset.get(GameStateKeys.PRESET_SLOTS, null) is Array and (preset[GameStateKeys.PRESET_SLOTS] as Array).is_empty():
			return false
		presets[index] = _empty_party_preset()
		return true

	var raw_slots: Variant = preset.get(GameStateKeys.PRESET_SLOTS, null)
	if not (raw_slots is Array) or (raw_slots as Array).size() != GameStateKeys.PARTY_SLOT_COUNT:
		presets[index] = _empty_party_preset()
		return true

	var seen: Dictionary = {}
	var slots: Array = []
	for entry: Variant in (raw_slots as Array):
		if not (entry is Dictionary):
			presets[index] = _empty_party_preset()
			return true
		var slot: Dictionary = entry
		var character_id: String = str(slot.get(GameStateKeys.PRESET_CHARACTER_ID, ""))
		var preset_index: int = int(slot.get(GameStateKeys.PRESET_INDEX, -1))
		if not all_characters.has(character_id) or seen.has(character_id):
			presets[index] = _empty_party_preset()
			return true
		if preset_index < 0 or preset_index >= CHARACTER_PRESET_COUNT:
			presets[index] = _empty_party_preset()
			return true
		seen[character_id] = true
		# ⚠ JSON から戻すと preset_index が float になる。int() で包み直す（CLAUDE.md 3番）。
		slots.append({
			GameStateKeys.PRESET_CHARACTER_ID: character_id,
			GameStateKeys.PRESET_INDEX: preset_index,
		})

	var changed: bool = str(slots) != str(raw_slots)
	preset[GameStateKeys.PRESET_SLOTS] = slots
	presets[index] = preset
	return changed


func _normalize_skill_slots_from_save() -> void:
	var growth_all: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var fixed: int = 0
	for character_id: String in growth_all:
		if not (growth_all[character_id] is Dictionary):
			continue
		# ⚠ スキル枠とパッシブ枠の両方をここで直す。片方だけ直す形にしないこと
		#   （旧セーブでパッシブ枠だけ生えないまま画面へ行く）。
		var growth: Dictionary = growth_all[character_id]
		var changed: bool = _normalize_all_slots(growth)
		# ⚠ rune_move は growth 側にも在る（プリセットは growth の切り出し）。
		#   ⚠ 片方だけ洗うと、本体が壊れたまま残る。
		var raw_rune_move: Variant = growth.get(GameStateKeys.GROWTH_RUNE_MOVE, null)
		if raw_rune_move is Dictionary:
			var cleaned: Dictionary = _valid_rune_move(character_id, raw_rune_move as Dictionary)
			if cleaned.size() != (raw_rune_move as Dictionary).size():
				growth[GameStateKeys.GROWTH_RUNE_MOVE] = cleaned
				changed = true
		if changed:
			fixed += 1
	print("[GameManager] _normalize_skill_slots_from_save() -> %d / %d entries normalized" % [
		fixed, growth_all.size()
	])

# そのキャラの候補を全部返す（レベルで絞らない）。並び順は characters.json のまま。
# 画面が「まだ解放されていない候補」を灰色で見せるために要る。
func get_all_skill_candidates(character_id: String, kind: String = SLOT_KIND_SKILL) -> Array:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	var master_key: String = str(_slot_spec(kind)["master_key"])
	# ⚠ パッシブは欄そのものが無いキャラが普通にいる。無いのは正常系なので
	#   警告を出さない（正常系に警告を付けない）。
	if not char_data.has(master_key):
		return []
	var raw: Variant = char_data.get(master_key, [])
	if not (raw is Array):
		push_warning("[GameManager] get_all_skill_candidates: %s が配列ではない: %s" % [
			master_key, character_id
		])
		return []
	var result: Array = []
	for entry: Variant in (raw as Array):
		result.append(str(entry))
	return result

# 現在のレベルで解放済みの候補だけを返す。
# skills.json に無いIDは落とす（characters.json 側だけ書き換えたときの保険）。
# ⚠ パッシブも定義は skills.json にある（activation: "passive"）。読み先は同じ。
func get_skill_candidates(character_id: String, kind: String = SLOT_KIND_SKILL) -> Array:
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var result: Array = []
	for skill_id: String in get_all_skill_candidates(character_id, kind):
		var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
		if skill_data.is_empty():
			continue
		if int(skill_data.get(SKILL_UNLOCK_LEVEL, 1)) <= level:
			result.append(skill_id)
	return result

# skills.json の unlock_level。画面が「Lv5 で解放」と出すために公開する。
# MasterDataLoader は float を返すため int() で包む（CLAUDE.md 3番）。
# 欄が無いスキルは 1（初期解放）として扱う。
func get_skill_unlock_level(skill_id: String) -> int:
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if skill_data.is_empty():
		return 0
	return int(skill_data.get(SKILL_UNLOCK_LEVEL, 1))

# 保存されている選択をそのまま返す。長さは必ず枠数。未選択は ""。
# 空欄を埋めないので、画面はこちらを使う（「未選択」と表示できる）。
func get_selected_skills(character_id: String, kind: String = SLOT_KIND_SKILL) -> Array:
	var growth: Dictionary = get_character_growth(character_id)
	# growth は get_character_growth() が複製したものなので、直接直してよい。
	_normalize_slots(growth, kind)
	var holder: Dictionary = growth.get(str(_slot_spec(kind)["state_key"]), {})
	return (holder.get(GameStateKeys.GROWTH_SKILL_SLOTS, []) as Array).duplicate()


# 画面用。パッシブ枠の選択をそのまま返す（未選択は ""）。
func get_selected_passives(character_id: String) -> Array:
	return get_selected_skills(character_id, SLOT_KIND_PASSIVE)

# 戦闘に渡す確定版。空の枠を候補の先頭で埋め、"" を落として返す。
#
# battle_controller.gd はこれだけを見る。characters.json の "skills" を
# 直接読まないこと（選択が反映されなくなる。EXEC_SKILL_SELECT.md §7）。
#
# 状態にマスターを複製しないための仕組みでもある。未選択のまま戦闘に出ても
# スキルが空にならないので、初期2個をセーブに書き込む必要がない。
func get_battle_skills(character_id: String, kind: String = SLOT_KIND_SKILL) -> Array:
	var selected: Array = get_selected_skills(character_id, kind)
	var candidates: Array = get_skill_candidates(character_id, kind)

	# 先に選択済みを確定させる。マスターから消えたIDと未解放のIDはここで落ちる。
	var slots: Array = []
	for entry: Variant in selected:
		var skill_id: String = str(entry)
		if skill_id != "" and skill_id in candidates and not (skill_id in slots):
			slots.append(skill_id)
		else:
			slots.append("")

	# 空の枠を、まだ使っていない候補の先頭で埋める。
	# ⚠ パッシブは埋めない（fill_empty が偽）。埋めると「外したつもりの
	#   パッシブが勝手に付く」。スキルと挙動が違う唯一の点。
	if bool(_slot_spec(kind)["fill_empty"]):
		for i: int in range(slots.size()):
			if str(slots[i]) != "":
				continue
			for candidate: Variant in candidates:
				var candidate_id: String = str(candidate)
				if not (candidate_id in slots):
					slots[i] = candidate_id
					break

	# 候補が枠数に足りないときは "" が残るため、ここで落とす。
	var result: Array = []
	for entry: Variant in slots:
		if str(entry) != "":
			result.append(str(entry))
	return result


# 戦闘に渡すパッシブの確定版。⚠ BattleUnit.passive_ids に入る。
# ⚠ 空の枠は埋めない（上の fill_empty）。
func get_battle_passives(character_id: String) -> Array:
	return get_battle_skills(character_id, SLOT_KIND_PASSIVE)

# 選べない理由を返す。選べるなら "" を返す。
#
# 判定はすべてここに集める。状態を変える前に全部の判定を終えるため
# （CLAUDE.md 6番）、select_skill() は先頭でこれを1回呼ぶだけでよい。
func _skill_select_error(
		character_id: String, slot_index: int, skill_id: String,
		kind: String = SLOT_KIND_SKILL
) -> String:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		return "character not found: " + character_id
	if slot_index < 0 or slot_index >= int(_slot_spec(kind)["count"]):
		return "slot_index out of range: %d" % slot_index
	if skill_id == "":
		return "skill_id is empty"

	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if skill_data.is_empty():
		return "skill not found: " + skill_id

	var owner_id: String = str(skill_data.get(SKILL_USER_CHARACTER_ID, ""))
	if owner_id != character_id:
		return "skill '%s' belongs to '%s'" % [skill_id, owner_id]
	# user_character_id が合っていても、characters.json の候補一覧に無ければ選ばせない。
	# 候補一覧が正（get_battle_skills() もそちらで絞るため、ここを緩めると
	# 「選べたのに戦闘に出ない」になる）。
	if not (skill_id in get_all_skill_candidates(character_id, kind)):
		return "skill '%s' is not a candidate of '%s'" % [skill_id, character_id]

	var level: int = int(growth.get(GameStateKeys.GROWTH_LEVEL, 1))
	var unlock_level: int = int(skill_data.get(SKILL_UNLOCK_LEVEL, 1))
	if unlock_level > level:
		return "unlock_level %d > level %d" % [unlock_level, level]

	return ""

# 判定のみ。状態を触らない（can_unlock_stat_node() と同じ形）。
func can_select_skill(
		character_id: String, slot_index: int, skill_id: String,
		kind: String = SLOT_KIND_SKILL
) -> bool:
	return _skill_select_error(character_id, slot_index, skill_id, kind) == ""

# 枠にスキルを入れる。
#
# 選んだスキルが既に別の枠に入っている場合は、2つの枠を入れ替える。弾かない。
# 枠の順番に意味がある（GAME_DESIGN.md 3-2）ため、「Bを1番に置きたい」という
# 操作がそのまま入れ替えになる。swap 専用の関数は作らない。
func select_skill(
		character_id: String, slot_index: int, skill_id: String,
		kind: String = SLOT_KIND_SKILL
) -> bool:
	var error: String = _skill_select_error(character_id, slot_index, skill_id, kind)
	if error != "":
		print("[GameManager] select_skill('%s', %d, '%s') -> false (%s)" % [
			character_id, slot_index, skill_id, error
		])
		return false

	var state_key: String = str(_slot_spec(kind)["state_key"])
	var growth: Dictionary = get_character_growth(character_id)
	_normalize_slots(growth, kind)
	var skills: Dictionary = growth[state_key]
	var slots: Array = (skills[GameStateKeys.GROWTH_SKILL_SLOTS] as Array).duplicate()

	if str(slots[slot_index]) == skill_id:
		print("[GameManager] select_skill('%s', %d, '%s') -> false (already in this slot)" % [
			character_id, slot_index, skill_id
		])
		return false

	var existing: int = slots.find(skill_id)
	if existing >= 0:
		# 入れ替え。押した枠に入っていたものを、元の枠へ移す。
		slots[existing] = slots[slot_index]
	slots[slot_index] = skill_id

	skills[GameStateKeys.GROWTH_SKILL_SLOTS] = slots
	growth[state_key] = skills
	_write_growth(character_id, growth)

	print("[GameManager] select_skill('%s', %d, '%s') -> true (slots=%s)" % [
		character_id, slot_index, skill_id, str(slots)
	])
	character_growth_changed.emit(character_id)
	return true

# 枠を未選択に戻す。空にしても戦闘には候補の先頭が入る（get_battle_skills()）。
func clear_skill_slot(
		character_id: String, slot_index: int, kind: String = SLOT_KIND_SKILL
) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		print("[GameManager] clear_skill_slot('%s', %d) -> false (character not found)" % [
			character_id, slot_index
		])
		return false
	if slot_index < 0 or slot_index >= int(_slot_spec(kind)["count"]):
		print("[GameManager] clear_skill_slot('%s', %d) -> false (slot_index out of range)" % [
			character_id, slot_index
		])
		return false

	var state_key: String = str(_slot_spec(kind)["state_key"])
	_normalize_slots(growth, kind)
	var skills: Dictionary = growth[state_key]
	var slots: Array = (skills[GameStateKeys.GROWTH_SKILL_SLOTS] as Array).duplicate()

	if str(slots[slot_index]) == "":
		print("[GameManager] clear_skill_slot('%s', %d) -> false (already empty)" % [
			character_id, slot_index
		])
		return false

	slots[slot_index] = ""
	skills[GameStateKeys.GROWTH_SKILL_SLOTS] = slots
	growth[state_key] = skills
	_write_growth(character_id, growth)

	print("[GameManager] clear_skill_slot('%s', %d) -> true (slots=%s)" % [
		character_id, slot_index, str(slots)
	])
	character_growth_changed.emit(character_id)
	return true

# --- 研究 ---

func get_research_tree() -> Dictionary:
	return _state.get(GameStateKeys.RESEARCH_TREE, {}).duplicate(true)

# 解放に必要な素材を返す。戻り値: {material_id: String, amount: int}
# コストは research.json 側に持つ（ノードごとに違うため .tres の単一値では表せない）。
func get_research_unlock_cost(node_id: String) -> Dictionary:
	var empty: Dictionary = {RESEARCH_COST_MATERIAL_ID: "", RESEARCH_COST_AMOUNT: 0}
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	if definition.is_empty():
		return empty
	# MasterDataLoader は JSON をそのまま返すため cost_amount は float で来る。int() 必須。
	return {
		RESEARCH_COST_MATERIAL_ID: str(definition.get(RESEARCH_NODE_COST_MATERIAL_ID, "")),
		RESEARCH_COST_AMOUNT: int(definition.get(RESEARCH_NODE_COST_AMOUNT, 0)),
	}

# 前提条件を満たしているか（素材は見ない）。
# 画面が「前提未解放」と「素材不足」を区別して表示するために分けてある。
func can_unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		return false
	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		return false
	return _prerequisites_met(node)

# 研究ノードを解放する。存在しない・解放済み・前提未達・素材不足のときは
# 何もせず false を返す。成功時は素材を消費して research_node_unlocked を発火する。
func unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		push_warning("[GameManager] unlock_research_node: unknown node_id: " + node_id)
		return false

	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		print("[GameManager] unlock_research_node('%s') -> false (already unlocked)" % node_id)
		return false

	# 前提の判定を素材の判定より先に行う。順序を入れ替えると、
	# 前提未解放のノードで「素材不足」と表示されて画面の説明と食い違う。
	if not _prerequisites_met(node):
		print("[GameManager] unlock_research_node('%s') -> false (prerequisites not met: %s)" % [
			node_id, node.get(GameStateKeys.NODE_PREREQUISITES, [])
		])
		return false

	var cost: Dictionary = get_research_unlock_cost(node_id)
	var material_id: String = str(cost.get(RESEARCH_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(RESEARCH_COST_AMOUNT, 0))
	if amount > 0 and material_id == "":
		push_warning("[GameManager] unlock_research_node: cost_material_id が未設定（research.json）: " + node_id)
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	if amount > 0:
		var owned: int = get_material_count(material_id)
		if owned < amount:
			print("[GameManager] unlock_research_node('%s') -> false (material %s: %d < %d)" % [
				node_id, material_id, owned, amount
			])
			return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# _copy_dict() は浅いコピーのため、ノードのDictionaryをもう一段複製してから書き換える。
	# これを飛ばすと _state 内の実体を直接書き換えることになる。
	var new_tree: Dictionary = _copy_dict(GameStateKeys.RESEARCH_TREE)
	var new_node: Dictionary = (new_tree[node_id] as Dictionary).duplicate(true)
	new_node[GameStateKeys.NODE_UNLOCKED] = true
	new_tree[node_id] = new_node
	_state[GameStateKeys.RESEARCH_TREE] = new_tree

	# 素材の減算はツリーを更新したあとに行う。
	# material_changed を受けて再描画する画面が、解放済みの状態を見られるようにするため。
	if amount > 0:
		add_material(material_id, -amount)

	print("[GameManager] unlock_research_node('%s') -> true (cost %s x%d, effect %s +%d)" % [
		node_id, material_id, amount,
		str(new_node.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
		int(new_node.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
	])
	research_node_unlocked.emit(node_id)
	return true

# --- 研究：内部ヘルパー ---

# prerequisites に並ぶノードが全て unlocked か。空配列なら true。
func _prerequisites_met(node: Dictionary) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var prerequisites: Variant = node.get(GameStateKeys.NODE_PREREQUISITES, [])
	if not (prerequisites is Array):
		return true
	for prerequisite_id: Variant in (prerequisites as Array):
		var required: Variant = tree.get(str(prerequisite_id), null)
		if not (required is Dictionary):
			# research.json に存在しないIDが前提に書かれている。
			# 解放できてしまうより、解放できないほうが安全。
			push_warning("[GameManager] _prerequisites_met: unknown prerequisite: " + str(prerequisite_id))
			return false
		if not bool((required as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			return false
	return true

# research.json の定義を research_tree へ流し込む。
#
# unlocked だけは既存の値を残し、それ以外（effect_type / effect_value /
# target_stat / prerequisites）は毎回マスターデータで上書きする。
# これにより research.json の効果値を調整すると、既存セーブにも次の起動で反映される。
# （initial_state_config.tres がセーブ済みだと反映されない罠を、研究では踏まない形にする）
#
# research.json から消えたノードは research_tree からも消える。
# ノードIDを改名するとその解放状態は失われるため、リリース後は改名しないこと。
func _sync_research_tree_from_master() -> void:
	var master: Dictionary = MasterDataLoader.get_all_research_nodes()
	if master.is_empty():
		push_warning("[GameManager] _sync_research_tree_from_master: research.json が空か読み込めない")
		return

	var current: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var synced: Dictionary = {}
	for node_id: String in master:
		if not (master[node_id] is Dictionary):
			continue
		var definition: Dictionary = master[node_id]

		var was_unlocked: bool = false
		if current.has(node_id) and current[node_id] is Dictionary:
			was_unlocked = bool((current[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false))

		# JSON の配列要素は Variant で来るため str() で包み直す。
		var prerequisites: Array = []
		var raw_prerequisites: Variant = definition.get(GameStateKeys.NODE_PREREQUISITES, [])
		if raw_prerequisites is Array:
			for prerequisite_id: Variant in (raw_prerequisites as Array):
				prerequisites.append(str(prerequisite_id))

		# effect_value は必ず int() で包む。包み忘れるとセーブに 5.0 と書かれ、
		# get_effective_level_cap() の戻り値が 15.0 になる。
		synced[node_id] = {
			GameStateKeys.NODE_UNLOCKED: was_unlocked,
			GameStateKeys.NODE_EFFECT_TYPE: str(definition.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
			GameStateKeys.NODE_EFFECT_VALUE: int(definition.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
			GameStateKeys.NODE_TARGET_STAT: str(definition.get(GameStateKeys.NODE_TARGET_STAT, STAT_BOOST_ALL_KEY)),
			GameStateKeys.NODE_PREREQUISITES: prerequisites,
		}

	_state[GameStateKeys.RESEARCH_TREE] = synced

	var unlocked_count: int = 0
	for node_id: String in synced:
		if bool((synced[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			unlocked_count += 1
	print("[GameManager] _sync_research_tree_from_master() -> %d nodes (unlocked=%d)" % [synced.size(), unlocked_count])

func get_effective_level_cap(_character_id: String) -> int:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	#
	# 研究ツリーは未実装で常に空のため、走査結果だけだと 0 が返り、
	# レベル1のキャラが即座に上限扱いになって育成画面が操作不能になる。
	# base_level_cap を下駄として先に置く（EXEC_GUILD_TRAINING §5-3）。
	# 研究が入っても、解放ノードの effect_value が加算されるだけで呼び出し側は変わらない。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var cap: int = 0
	if Balance != null and Balance.character != null:
		cap = int(Balance.character.base_level_cap)
	else:
		push_warning("[GameManager] get_effective_level_cap: Balance.character is null — base_level_cap を 0 として扱う")
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			cap += int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return cap

func get_stat_boost_all() -> Dictionary:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	# 返り値の形は { "hp": 10, "atk": 5, ... }。target_stat未指定のノードは "all" に集約する。
	# TODO: 実際にどのステータスへどう加算するかは PLAN_GUILD_RESEARCH.md 側で未確定。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var boosts: Dictionary = {}
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_STAT_BOOST_ALL:
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, "all"))
			boosts[stat] = int(boosts.get(stat, 0)) + int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return boosts

# --- 作業場 ---

# 製作キューのスナップショットを返す。
func get_crafting_queue() -> Array:
	return _state.get(GameStateKeys.CRAFTING_QUEUE, []).duplicate(true)

# 同時に進行できる製作の本数。Balance から読めなければ既定値。
#
# balance.gd に workshop プロパティが実在するかは未確認のため、"in" で存在を確かめてから読む。
# 名前が違っていた場合はここで push_warning が出る（画面は既定値1で動く）。
func get_max_queue_slots() -> int:
	if Balance != null and "workshop" in Balance and Balance.workshop != null:
		var slots: int = int(Balance.workshop.max_queue_slots)
		if slots > 0:
			return slots
	push_warning("[GameManager] get_max_queue_slots: Balance.workshop が読めない — %d を使う" % DEFAULT_MAX_QUEUE_SLOTS)
	return DEFAULT_MAX_QUEUE_SLOTS

# 解放済みで、かつ定義が妥当なレシピの一覧を返す（画面がレシピ一覧を描くために使う）。
# sort_order の昇順。
func get_available_recipes() -> Array:
	var unlocked: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	var result: Array = []
	for recipe_id: String in MasterDataLoader.get_all_recipes():
		if not bool(unlocked.get(recipe_id, false)):
			continue
		var definition: Dictionary = _normalized_recipe(recipe_id)
		if definition.is_empty():
			continue
		result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get(RECIPE_SORT_ORDER, 0)) < int(b.get(RECIPE_SORT_ORDER, 0)))
	return result

# アイテムの所持数。items.json に無いIDでは -1 を返す（0 と区別するため）。
# materials と inventory のどちらに入っているかは items.json の storage で決まる。
func get_item_count(item_id: String) -> int:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		return get_material_count(item_id)
	if storage == ITEM_STORAGE_INVENTORY:
		var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
		if not inventory.has(item_id):
			return 0
		var entry: Variant = inventory[item_id]
		if not (entry is Dictionary):
			return 0
		return int((entry as Dictionary).get(GameStateKeys.ITEM_COUNT, 0))
	return -1

# 製作を開始する。
#
# 判定の順番は purchase_shop_item() と揃える：
#   レシピ存在 → 解放済み → キューの空き → 定義の妥当性 → 素材 → （ここから状態を変える）
# 定義の妥当性を素材より先に見る。素材だけ減って何も貰えない、を起こさないため。
func start_craft(recipe_id: String) -> bool:
	if MasterDataLoader.get_recipe(recipe_id).is_empty():
		print("[GameManager] start_craft('%s') -> false (recipe not found)" % recipe_id)
		return false

	var unlocked: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	if not bool(unlocked.get(recipe_id, false)):
		print("[GameManager] start_craft('%s') -> false (recipe not unlocked)" % recipe_id)
		return false

	var queue: Array = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	var max_slots: int = get_max_queue_slots()
	if queue.size() >= max_slots:
		print("[GameManager] start_craft('%s') -> false (queue full: %d/%d)" % [recipe_id, queue.size(), max_slots])
		return false

	# 定義の妥当性。ここで弾かれるのは items.json に無いIDや count<=0 を書いたとき。
	var definition: Dictionary = _normalized_recipe(recipe_id)
	if definition.is_empty():
		print("[GameManager] start_craft('%s') -> false (invalid recipe definition)" % recipe_id)
		return false

	var inputs: Array = definition.get(RECIPE_INPUTS, [])
	for entry: Variant in inputs:
		var input: Dictionary = entry
		var item_id: String = str(input.get(RECIPE_IO_ITEM_ID, ""))
		var need: int = int(input.get(RECIPE_IO_COUNT, 0))
		var have: int = get_item_count(item_id)
		if have < need:
			print("[GameManager] start_craft('%s') -> false (%s: %d < %d)" % [recipe_id, item_id, have, need])
			return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	for entry: Variant in inputs:
		var input: Dictionary = entry
		_consume_item(str(input.get(RECIPE_IO_ITEM_ID, "")), int(input.get(RECIPE_IO_COUNT, 0)))

	var started_at: int = int(Time.get_unix_time_from_system())
	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, DEFAULT_CRAFT_DURATION_SEC))
	# outputs の先頭は表示・スキーマ互換のために持たせるだけ。
	# 実際に配るものは受け取り時に recipes.json から引き直す（EXEC_GUILD_WORKSHOP.md §2-5）。
	var first_output: Dictionary = (definition.get(RECIPE_OUTPUTS, []) as Array)[0]
	var output_item_id: String = str(first_output.get(RECIPE_IO_ITEM_ID, ""))

	var new_queue: Array = _copy_array(GameStateKeys.CRAFTING_QUEUE)
	new_queue.append({
		GameStateKeys.CRAFT_QUEUE_ID: "%d_%s" % [started_at, recipe_id],
		GameStateKeys.CRAFT_RECIPE_ID: recipe_id,
		GameStateKeys.CRAFT_RECIPE_TYPE: str(MasterDataLoader.get_item(output_item_id).get(ITEM_MASTER_ITEM_TYPE, "")),
		GameStateKeys.CRAFT_STARTED_AT: started_at,
		# 開始時点の所要時間をコピーして持つ。recipes.json を変えても走行中の残り時間が飛ばない。
		GameStateKeys.CRAFT_DURATION_SEC: duration_sec,
		GameStateKeys.CRAFT_STATUS: GameStateKeys.CRAFT_STATUS_IN_PROGRESS,
		GameStateKeys.CRAFT_OUTPUT_ITEM_ID: output_item_id,
	})
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue

	print("[GameManager] start_craft('%s') -> true (duration=%ds, queue=%d/%d)" % [
		recipe_id, duration_sec, new_queue.size(), max_slots
	])
	crafting_queue_changed.emit()
	return true

# 完成した製作物を受け取る。完了前・存在しない queue_id なら何もせず false。
func collect_craft(queue_id: String) -> bool:
	# 受け取る前に完了判定を回す。画面を経由せずに呼ばれても正しく判定できるようにするため。
	refresh_crafting_queue_if_needed()

	var queue: Array = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	var index: int = _find_craft_index(queue, queue_id)
	if index < 0:
		print("[GameManager] collect_craft('%s') -> false (not found)" % queue_id)
		return false

	var entry: Dictionary = queue[index]
	if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) != GameStateKeys.CRAFT_STATUS_COMPLETED:
		print("[GameManager] collect_craft('%s') -> false (not completed)" % queue_id)
		return false

	var recipe_id: String = str(entry.get(GameStateKeys.CRAFT_RECIPE_ID, ""))
	var definition: Dictionary = _normalized_recipe(recipe_id)
	if definition.is_empty():
		# _sync_recipes_from_master() が消し損ねた場合の保険。
		push_warning("[GameManager] collect_craft: レシピ定義が無効: " + recipe_id)
		return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# キューから先に消してから配る。inventory_changed を受けて再描画する画面が、
	# 受け取り済みのキューを見られるようにするため（purchase_shop_item と同じ順番）。
	var new_queue: Array = _copy_array(GameStateKeys.CRAFTING_QUEUE)
	new_queue.remove_at(index)
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue

	var granted: Array[String] = []
	for output: Variant in (definition.get(RECIPE_OUTPUTS, []) as Array):
		var item: Dictionary = output
		var item_id: String = str(item.get(RECIPE_IO_ITEM_ID, ""))
		var count: int = int(item.get(RECIPE_IO_COUNT, 0))
		_grant_item(item_id, count)
		granted.append("%s x%d" % [item_id, count])

	print("[GameManager] collect_craft('%s') -> true (%s, queue=%d)" % [
		queue_id, ", ".join(granted), new_queue.size()
	])
	crafting_queue_changed.emit()
	return true

# 完了時刻を過ぎている in_progress のエントリを completed に切り替える。
#
# 日付ではなく経過時間で判定するため、GameDate は使わない。
# 変化があったときだけ crafting_queue_changed を発火する。毎秒呼ばれるため、
# ここで無条件に emit すると画面が毎秒作り直される。
func refresh_crafting_queue_if_needed() -> void:
	var queue: Variant = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	if not (queue is Array) or (queue as Array).is_empty():
		return

	var now: int = int(Time.get_unix_time_from_system())
	var new_queue: Array = (queue as Array).duplicate(true)
	var changed: bool = false
	for i: int in range(new_queue.size()):
		if not (new_queue[i] is Dictionary):
			continue
		var entry: Dictionary = new_queue[i]
		if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) != GameStateKeys.CRAFT_STATUS_IN_PROGRESS:
			continue
		var finish_at: int = int(entry.get(GameStateKeys.CRAFT_STARTED_AT, 0)) + int(entry.get(GameStateKeys.CRAFT_DURATION_SEC, 0))
		if now < finish_at:
			continue
		entry[GameStateKeys.CRAFT_STATUS] = GameStateKeys.CRAFT_STATUS_COMPLETED
		new_queue[i] = entry
		changed = true
		print("[GameManager] refresh_crafting_queue_if_needed: '%s' -> completed" % str(entry.get(GameStateKeys.CRAFT_QUEUE_ID, "")))

	if not changed:
		return
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue
	crafting_queue_changed.emit()

# --- 作業場：内部ヘルパー ---

# queue_id が一致する要素の位置を返す。見つからなければ -1。
func _find_craft_index(queue: Array, queue_id: String) -> int:
	for i: int in range(queue.size()):
		if not (queue[i] is Dictionary):
			continue
		if str((queue[i] as Dictionary).get(GameStateKeys.CRAFT_QUEUE_ID, "")) == queue_id:
			return i
	return -1

# items.json の storage を返す。未登録・未知の値なら ""。
func _item_storage(item_id: String) -> String:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return ""
	var storage: String = str(definition.get(ITEM_MASTER_STORAGE, ""))
	if storage != ITEM_STORAGE_MATERIAL and storage != ITEM_STORAGE_INVENTORY:
		return ""
	return storage

# 残高の確認は呼び出し側で済ませてあること。この関数は確認しない
# （_spend_currency() と同じ約束）。
func _consume_item(item_id: String, count: int) -> void:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		add_material(item_id, -count)
		return
	if storage == ITEM_STORAGE_INVENTORY:
		_remove_from_inventory(item_id, count)
		return
	push_warning("[GameManager] _consume_item: items.json に無いID: " + item_id)

func _grant_item(item_id: String, count: int) -> void:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		add_material(item_id, count)
		return
	if storage == ITEM_STORAGE_INVENTORY:
		add_to_inventory(item_id, count, str(MasterDataLoader.get_item(item_id).get(ITEM_MASTER_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)))
		return
	push_warning("[GameManager] _grant_item: items.json に無いID: " + item_id)

# inventory から減らす。0 になったエントリは消す（use_stamina_potion() と同じ扱い）。
func _remove_from_inventory(item_id: String, count: int) -> void:
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	if not inventory.has(item_id) or not (inventory[item_id] is Dictionary):
		push_warning("[GameManager] _remove_from_inventory: 所持していない: " + item_id)
		return
	var entry: Dictionary = (inventory[item_id] as Dictionary).duplicate(true)
	var remaining: int = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) - count
	if remaining > 0:
		entry[GameStateKeys.ITEM_COUNT] = remaining
		inventory[item_id] = entry
	else:
		inventory.erase(item_id)
	_state[GameStateKeys.INVENTORY] = inventory
	print("[GameManager] _remove_from_inventory('%s', %d) -> %d" % [item_id, count, maxi(remaining, 0)])
	inventory_changed.emit(item_id)

# recipes.json のレシピを検証して正規化した Dictionary を返す。妥当でなければ空。
#
# ここで弾くもの：inputs/outputs が空、items.json に無いID、count <= 0。
# MasterDataLoader が返す数値は float のため int() で包む。包み忘れると
# セーブに 1800.0 と書かれる。
func _normalized_recipe(recipe_id: String) -> Dictionary:
	var definition: Dictionary = MasterDataLoader.get_recipe(recipe_id)
	if definition.is_empty():
		return {}

	var inputs: Array = _normalized_io(definition.get(RECIPE_INPUTS, []), recipe_id, RECIPE_INPUTS)
	var outputs: Array = _normalized_io(definition.get(RECIPE_OUTPUTS, []), recipe_id, RECIPE_OUTPUTS)
	if inputs.is_empty() or outputs.is_empty():
		return {}

	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, 0))
	if duration_sec <= 0:
		duration_sec = _default_craft_duration_sec()

	return {
		RECIPE_ID: recipe_id,
		RECIPE_DURATION_SEC: duration_sec,
		RECIPE_INPUTS: inputs,
		RECIPE_OUTPUTS: outputs,
		RECIPE_SORT_ORDER: int(definition.get(RECIPE_SORT_ORDER, 0)),
	}

func _normalized_io(list: Variant, recipe_id: String, label: String) -> Array:
	if not (list is Array) or (list as Array).is_empty():
		push_warning("[GameManager] recipes.json: '%s' の %s が空" % [recipe_id, label])
		return []
	var result: Array = []
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			push_warning("[GameManager] recipes.json: '%s' の %s に Dictionary でない要素" % [recipe_id, label])
			return []
		var item: Dictionary = entry
		var item_id: String = str(item.get(RECIPE_IO_ITEM_ID, ""))
		var count: int = int(item.get(RECIPE_IO_COUNT, 0))
		if _item_storage(item_id) == "":
			push_warning("[GameManager] recipes.json: '%s' の %s に items.json へ無いID: '%s'" % [recipe_id, label, item_id])
			return []
		if count <= 0:
			push_warning("[GameManager] recipes.json: '%s' の %s の count が 0 以下: '%s'" % [recipe_id, label, item_id])
			return []
		result.append({RECIPE_IO_ITEM_ID: item_id, RECIPE_IO_COUNT: count})
	return result

func _default_craft_duration_sec() -> int:
	if Balance != null and "workshop" in Balance and Balance.workshop != null:
		var value: int = int(Balance.workshop.base_craft_duration_sec)
		if value > 0:
			return value
	return DEFAULT_CRAFT_DURATION_SEC

# recipes.json の定義を recipes_unlocked へ流し込む。
#
# 状態側だけが持つのは「解放済みかどうか」と crafting_queue のみ。
# 消費・産出・所要時間は毎回マスターデータが正（_sync_shop_from_master() と同じ型）。
#
# recipes.json から消えたレシピIDは recipes_unlocked からもキューからも消える。
# レシピIDを改名すると走行中の製作が消えるため、リリース後に改名しないこと。
func _sync_recipes_from_master() -> void:
	# ⚠ 空でもそのまま流す（EXEC_WORKSHOP_RETIRE.md 決め1）。
	#   作業場の廃止で recipes.json は 0 件になった。ここで早期 return すると
	#   recipes_unlocked に消えたレシピIDが残り、_normalize_crafting_queue() にも
	#   到達しないため、走行中のキューが落ちない。
	# ⚠ 「ファイルが読めない」の保険は MasterDataLoader._index_by() が持っている
	#   （root が空なら push_error("empty or unreadable")）。ここでは重ねない。
	var master: Dictionary = MasterDataLoader.get_all_recipes()

	var current: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	var synced: Dictionary = {}
	var skipped: int = 0
	for recipe_id: String in master:
		# 定義が壊れているレシピはここで落とす。実行時に気づくと
		# 「素材だけ減って何も貰えない」が起きる。
		if _normalized_recipe(recipe_id).is_empty():
			skipped += 1
			continue
		if current.has(recipe_id):
			synced[recipe_id] = bool(current[recipe_id])
		else:
			var definition: Dictionary = master[recipe_id]
			synced[recipe_id] = bool(definition.get(RECIPE_UNLOCKED_BY_DEFAULT, false))
	_state[GameStateKeys.RECIPES_UNLOCKED] = synced

	_normalize_crafting_queue(synced)

	var unlocked_count: int = 0
	for recipe_id: String in synced:
		if bool(synced[recipe_id]):
			unlocked_count += 1
	print("[GameManager] _sync_recipes_from_master() -> %d recipes (unlocked=%d, skipped=%d)" % [
		synced.size(), unlocked_count, skipped
	])

# キューの数値を int に戻し、消えたレシピのエントリを捨てる。
#
# JSON から復元すると started_at / duration_sec が float になる。時刻の比較は
# float でも動いてしまうが、セーブに 1.7628e+09 と書かれると読めなくなる。
func _normalize_crafting_queue(valid_recipes: Dictionary) -> void:
	var queue: Variant = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	if not (queue is Array):
		_state[GameStateKeys.CRAFTING_QUEUE] = []
		return

	var normalized: Array = []
	for entry: Variant in (queue as Array):
		if not (entry is Dictionary):
			continue
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var recipe_id: String = str(item.get(GameStateKeys.CRAFT_RECIPE_ID, ""))
		if not valid_recipes.has(recipe_id):
			push_warning("[GameManager] _normalize_crafting_queue: レシピが無いキューを捨てた: " + recipe_id)
			continue
		item[GameStateKeys.CRAFT_STARTED_AT] = int(item.get(GameStateKeys.CRAFT_STARTED_AT, 0))
		item[GameStateKeys.CRAFT_DURATION_SEC] = int(item.get(GameStateKeys.CRAFT_DURATION_SEC, 0))
		var status: String = str(item.get(GameStateKeys.CRAFT_STATUS, ""))
		if status != GameStateKeys.CRAFT_STATUS_IN_PROGRESS and status != GameStateKeys.CRAFT_STATUS_COMPLETED:
			item[GameStateKeys.CRAFT_STATUS] = GameStateKeys.CRAFT_STATUS_IN_PROGRESS
		normalized.append(item)
	_state[GameStateKeys.CRAFTING_QUEUE] = normalized

# --- セーブ・ロード ---

# セーブデータから状態を復元する。
# SaveManagerからのみ呼ばれることを想定。
# セーブから戻した装備を正規化する。load_state() からのみ呼ぶ。
#
# 1. grade を int に戻す（JSON復元で 3.0 になる）
# 2. parts を長さ PART_SLOT_COUNT に揃える。足りなければ null で埋める。
#    枠を減らす変更をしたときも配列から消さない（あふれた部品を黙って消さないため）
# 3. character_growth.equipment を5部位に揃え、個体でない値を捨てる
#
# 第1弾は equipment に item_id の文字列（"weapon_iron_sword" 等）が直接入っていた。
# 移行処理は書かず捨てると決めた（まだ自分しか遊んでいないため）。
func _normalize_equipment_from_save() -> void:
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	var max_id: int = 0
	for instance_id: String in instances:
		if not (instances[instance_id] is Dictionary):
			continue
		var instance: Dictionary = (instances[instance_id] as Dictionary).duplicate(true)
		instance[GameStateKeys.INSTANCE_GRADE] = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))

		var raw_parts: Variant = instance.get(GameStateKeys.INSTANCE_PARTS, [])
		var parts: Array = (raw_parts as Array).duplicate() if raw_parts is Array else []
		while parts.size() < PART_SLOT_COUNT:
			parts.append(null)
		instance[GameStateKeys.INSTANCE_PARTS] = parts

		instances[instance_id] = instance

		# 採番が巻き戻らないよう、既存のIDから最大値を拾っておく。
		if instance_id.begins_with(INSTANCE_ID_PREFIX):
			max_id = maxi(max_id, int(instance_id.substr(INSTANCE_ID_PREFIX.length())))
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

	var next_id: int = int(_state.get(GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID, 1))
	_state[GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID] = maxi(next_id, max_id + 1)

	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	for character_id: String in all_growth:
		if not (all_growth[character_id] is Dictionary):
			continue
		var entry: Dictionary = (all_growth[character_id] as Dictionary).duplicate(true)
		var saved: Variant = entry.get(GameStateKeys.GROWTH_EQUIPMENT, {})
		var equipment: Dictionary = {}
		for slot: String in _equip_slots():
			var value: Variant = (saved as Dictionary).get(slot, null) if saved is Dictionary else null
			if value == null:
				equipment[slot] = null
				continue
			var equipped_id: String = str(value)
			if instances.has(equipped_id):
				equipment[slot] = equipped_id
			else:
				push_warning("[GameManager] load_state: 個体でない装備を捨てた（%s の %s = %s）" % [
					character_id, slot, equipped_id
				])
				equipment[slot] = null
		entry[GameStateKeys.GROWTH_EQUIPMENT] = equipment
		all_growth[character_id] = entry
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth


func load_state(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false
	
	if not data.has(GameStateKeys.SAVE_VERSION):
		push_warning("[GameManager] load_state: missing save_version")
		return false
	
	# テンプレで初期化してから上書き（将来のキー追加対策）
	var new_state: Dictionary = _empty_state_template()
	for key: String in data:
		if new_state.has(key):
			new_state[key] = data[key]
	
	# 数値の int() キャスト（JSON復元時は float になるため）
	# §6-2 の決定事項に従い、対象を限定する。
	if new_state.has(GameStateKeys.GOLD):
		new_state[GameStateKeys.GOLD] = int(new_state[GameStateKeys.GOLD])
	if new_state.has(GameStateKeys.GEMS):
		new_state[GameStateKeys.GEMS] = int(new_state[GameStateKeys.GEMS])
	if new_state.has(GameStateKeys.STAMINA) and new_state[GameStateKeys.STAMINA] is Dictionary:
		var stamina: Dictionary = new_state[GameStateKeys.STAMINA]
		if stamina.has(GameStateKeys.STAMINA_CURRENT):
			stamina[GameStateKeys.STAMINA_CURRENT] = int(stamina[GameStateKeys.STAMINA_CURRENT])
		if stamina.has(GameStateKeys.STAMINA_MAX):
			stamina[GameStateKeys.STAMINA_MAX] = int(stamina[GameStateKeys.STAMINA_MAX])
	if new_state.has(GameStateKeys.TOTAL_POMODORO_COMPLETED):
		new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	if new_state.has(GameStateKeys.SCENARIO_CHAPTER):
		new_state[GameStateKeys.SCENARIO_CHAPTER] = int(new_state[GameStateKeys.SCENARIO_CHAPTER])
	if new_state.has(GameStateKeys.SAVE_VERSION):
		new_state[GameStateKeys.SAVE_VERSION] = int(new_state[GameStateKeys.SAVE_VERSION])
	if new_state.has(GameStateKeys.MATERIALS) and new_state[GameStateKeys.MATERIALS] is Dictionary:
		var mats: Dictionary = new_state[GameStateKeys.MATERIALS]
		for mat_id: String in mats:
			mats[mat_id] = int(mats[mat_id])
	# 育成データ。JSONから戻すと level も stats も float になるため int に戻す。
	# これを飛ばすと、セーブ→ロード後に hp が 128.0 と表示され、レベル比較もずれる。
	if new_state.has(GameStateKeys.CHARACTER_GROWTH) and new_state[GameStateKeys.CHARACTER_GROWTH] is Dictionary:
		var growth_all: Dictionary = new_state[GameStateKeys.CHARACTER_GROWTH]
		for character_id: String in growth_all:
			if not (growth_all[character_id] is Dictionary):
				continue
			var entry: Dictionary = growth_all[character_id]
			if entry.has(GameStateKeys.GROWTH_LEVEL):
				entry[GameStateKeys.GROWTH_LEVEL] = int(entry[GameStateKeys.GROWTH_LEVEL])
			if entry.has(GameStateKeys.GROWTH_STATS) and entry[GameStateKeys.GROWTH_STATS] is Dictionary:
				var entry_stats: Dictionary = entry[GameStateKeys.GROWTH_STATS]
				for stat_key: String in _stat_keys():
					if entry_stats.has(stat_key):
						entry_stats[stat_key] = int(entry_stats[stat_key])
			# 解放済みステータスノード。中身は文字列なので int() 正規化は要らないが、
			# 型だけ見る。配列でなければ捨てて空に戻す（不正なセーブで落とさない）。
			if not (entry.get(GameStateKeys.GROWTH_NODES, []) is Array):
				push_warning("[GameManager] load_state: %s.nodes is not Array - resetting" % character_id)
				entry[GameStateKeys.GROWTH_NODES] = []
	
	# 状態反映（外部参照を断つため duplicate）
	_state = new_state.duplicate(true)
	# セーブに入っている stats を、現在の stat_growth_formula で計算し直す。
	# _sync_research_tree_from_master() と同じ考え方で、マスター＋式を正とする。
	_resync_growth_stats_from_master()
	# skills を {"slots": ["", ""]} の形に揃える。
	# 旧セーブは skills が {} のため、ここで枠が生える（EXEC_SKILL_SELECT.md §6-1）。
	# これがあるので save_version は 3 のままでよい。
	_normalize_skill_slots_from_save()
	# 編成を確かめる。旧セーブは party_members を持たないため、ここで生える
	# （skills の枠と同じ理由で save_version は 3 のままでよい）。
	# ⚠ 毎回 parties.json で上書きしないこと。上書きすると、入れ替えが
	#   起動のたびに巻き戻る（EXEC_PARTY_MEMBERS.md §4-2）。
	_ensure_party_members_from_master()
	# 装備の個体を正規化する。JSONから戻すと grade が float になる。
	# 第1弾の装備（equipment に item_id の文字列が入っている）はここで捨てる。
	_normalize_equipment_from_save()
	# プリセットの形を揃え、分解された個体への参照を null に戻す。
	# ⚠ _normalize_equipment_from_save() より後であること（消えた個体の判定に、
	#   正規化済みの equipment_instances が要る）。
	# ⚠ 旧セーブは character_presets / party_presets を持たないため、ここで生える
	#   （skills の枠と同じ理由で save_version は 3 のままでよい）。
	_normalize_presets_from_save()
	# セーブから戻した research_tree を research.json と同期する。
	# unlocked は残り、効果値・前提条件はマスターデータで上書きされる。
	# JSON復元で float になった effect_value も、ここで int() に戻る。
	_sync_research_tree_from_master()
	# ショップも同様。価格・在庫は shop.json で上書きし、purchased_count だけ残る。
	# JSON復元で float になった purchased_count も、ここで int() に戻る。
	_sync_shops_from_master()
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピも同様。解放状態と crafting_queue だけが残る。
	# JSON復元で float になった started_at / duration_sec も、ここで int() に戻る。
	_sync_recipes_from_master()
	# 解放も同期する。⚠ 既に true のものは触らない（一度開いたものは閉じない）。
	#   ⚠ 段階9より前のセーブには新しい画面IDが1つも入っていないので、ここで生える。
	_sync_unlocked_screens_from_master()
	# ロードした時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
	print("[GameManager] load_state success. version=%d" % int(_state[GameStateKeys.SAVE_VERSION]))
	
	# 主要なシグナルを発火（再描画用）
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])
	var stamina_dict: Dictionary = _state[GameStateKeys.STAMINA]
	resource_changed.emit(GameStateKeys.STAMINA, int(stamina_dict.get(GameStateKeys.STAMINA_CURRENT, 0)))
	
	var materials: Dictionary = _state[GameStateKeys.MATERIALS]
	for mat_id: String in materials:
		material_changed.emit(mat_id, int(materials[mat_id]))
	
	pending_chests_changed.emit(get_pending_chest_count())
	
	return true

# 保存直前に呼ばれ、last_saved_atを更新する
func mark_saved() -> void:
	_state[GameStateKeys.LAST_SAVED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] mark_saved -> last_saved_at=%s" % _state[GameStateKeys.LAST_SAVED_AT])

func grant_stamina_potions(focus_minutes: int) -> int:
	var unit_per_min: int = int(Balance.pomodoro.potion_focus_minutes_per_unit)
	if unit_per_min <= 0:
		push_warning("[GameManager] invalid potion rate")
		return 0
	var remainder: int = int(_state.get(GameStateKeys.POTION_FOCUS_REMAINDER, 0))
	var total_min: int = focus_minutes + remainder
	var count: int = total_min / unit_per_min
	_state[GameStateKeys.POTION_FOCUS_REMAINDER] = total_min % unit_per_min
	if count > 0:
		add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, count, GameStateKeys.ITEM_TYPE_CONSUMABLE)
	return count

func get_stamina_potion_count() -> int:
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	if not inventory.has(GameStateKeys.ITEM_STAMINA_POTION):
		return 0
	var entry: Dictionary = inventory[GameStateKeys.ITEM_STAMINA_POTION]
	return int(entry.get(GameStateKeys.ITEM_COUNT, 0))

func use_stamina_potion() -> bool:
	var count: int = get_stamina_potion_count()
	if count <= 0:
		return false
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = (inventory[GameStateKeys.ITEM_STAMINA_POTION] as Dictionary).duplicate(true)
	if count == 1:
		inventory.erase(GameStateKeys.ITEM_STAMINA_POTION)
	else:
		entry[GameStateKeys.ITEM_COUNT] = count - 1
		inventory[GameStateKeys.ITEM_STAMINA_POTION] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	inventory_changed.emit(GameStateKeys.ITEM_STAMINA_POTION)
	_add_stamina_uncapped(int(Balance.pomodoro.stamina_potion_recovery))
	return true

# --- ストーリーステージ ---

# 戦闘勝利時にステージのクリア状態を記録する。
# stars は判定基準が未確定のため、当面は常に 0 が渡される。
# 既存の stars より小さい値で上書きしないよう maxi で比較する。
func mark_stage_cleared(stage_id: String, stars: int = 0) -> void:
	var story: Dictionary = _copy_dict(GameStateKeys.STORY)
	var stages: Dictionary = (story.get(GameStateKeys.STORY_STAGES, {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (stages.get(stage_id, {}) as Dictionary).duplicate(true)
	entry[GameStateKeys.STAGE_CLEARED] = true
	entry[GameStateKeys.STAGE_STARS] = maxi(int(entry.get(GameStateKeys.STAGE_STARS, 0)), stars)
	stages[stage_id] = entry
	story[GameStateKeys.STORY_STAGES] = stages
	_state[GameStateKeys.STORY] = story
	print("[GameManager] mark_stage_cleared('%s', %d)" % [stage_id, stars])
	# ⚠ クリアした瞬間に開く。拠点へ戻る前に screen_unlocked が飛ぶので、
	#   拠点は _ready() の時点で正しい状態を読む。
	_sync_unlocked_screens_from_master()

func is_stage_cleared(stage_id: String) -> bool:
	var story: Dictionary = _state.get(GameStateKeys.STORY, {})
	var stages: Dictionary = story.get(GameStateKeys.STORY_STAGES, {})
	var entry: Dictionary = stages.get(stage_id, {})
	return bool(entry.get(GameStateKeys.STAGE_CLEARED, false))


# --- 上限を超えられるスタミナ加算 ---

# max で切り捨てずにスタミナを増やす。
#
# 通常の add_stamina() は max で切り捨てる。上限の意味は
# 「放っておいても max までしか溜まらない」ことであり、
# 自然回復・宝箱・ポモドーロ報酬はすべてそちらを通す。
#
# 上限を超えてよいのは「プレイヤーが能動的に使ったぶん」だけ。
# 現状はスタミナポーションと、戦闘敗北時の返却の2つ。
func _add_stamina_uncapped(amount: int) -> int:
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)) + amount
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	resource_changed.emit(GameStateKeys.STAMINA, current)
	return current

# 戦闘に敗北したときのスタミナ返却。
# ポーションで上限を超えている状態から払った場合、add_stamina() では
# max で切り捨てられて戻らないため、上限を超えられる経路を使う。
func refund_stamina(amount: int) -> void:
	if amount <= 0:
		return
	var current: int = _add_stamina_uncapped(amount)
	print("[GameManager] refund_stamina(%d) -> current=%d" % [amount, current])
