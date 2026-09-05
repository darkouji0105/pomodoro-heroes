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

# フロア探索の状態が変わった（段階14-a）。開始・移動・中断のいずれでも飛ぶ。
# ⚠ 14-a の時点で購読者はゼロ。マップ画面（14-c）が繋ぐ。
# ⚠ floor_id は「変わったあとの値」。中断したときは "" が飛ぶ。
signal floor_run_changed(floor_id: String)

# 移動で宝箱が出た（段階14-g）。⚠ 積まれたときだけ飛ぶ（中身が空なら飛ばない）。
# ⚠ rarity を一緒に渡す。⚠ 受け取る側が chest_id から綴りを切り出さないため
#   （IDから切り出さない＝ITEM_MASTER_PART_KIND のコメントと同じ理由）。
# ⚠ 周回（run_floor_auto）でも飛ぶ。購読しているのはマップ画面だけなので実害は無い。
signal floor_chest_found(chest_id: String, rarity: String)

# 難ダンジョンのランの状態が変わった（段階17-a）。開始・移動・ボス撃破・
# 潜行・撤退・全ロストのいずれでも飛ぶ。
# ⚠ floor_run_changed と1本にまとめない。器が別（PLAN_HARD_DUNGEON.md §7）で、
#   購読する画面も別になる（17-d）。1本にすると、どちらの器が変わったのかを
#   受け取り側が状態を読んで判定することになる。
# ⚠ dungeon_id は「変わったあとの値」。ランが終わったときは "" が飛ぶ。
signal dungeon_run_changed(dungeon_id: String)

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
# ⚠ ボード・カテゴリ・区切りの印（段階10・EXEC_GUILD_RESEARCH_V2.md §5-C）。
# ⚠ この3つは状態に持たせない。「今どのボードか」は get_current_research_board() が
#   毎回マスターと進捗から計算する（＝セーブの移行が要らない）。
const RESEARCH_NODE_BOARD: String = "board"
const RESEARCH_NODE_CATEGORY: String = "category"
const RESEARCH_NODE_MILESTONE: String = "milestone"
# milestone に入る値（"" は印なし）。
const RESEARCH_MILESTONE_MID: String = "mid"
const RESEARCH_MILESTONE_FINAL: String = "final"
# board を持たないノードの扱い。1枚目のボードに置く。
const RESEARCH_DEFAULT_BOARD: int = 1

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
# ⚠ 装飾のランダム製作（段階11・EXEC_WORKSHOP_REVIVE.md 決め1）。
#   ⚠ 中身の形は chests.json の draw と同じ（rolls / entries[{item_id, weight, count}]）ので、
#     ⚠ 読む定数は CHEST_DRAW_* を使い回す。新しい綴りを増やさない。
#   ⚠ レシピは outputs と draw の「どちらかが非空」なら妥当。両方空は E129 が赤で言う。
const RECIPE_DRAW: String = "draw"

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

# stages.json のフロア形式の欄（段階14-a・PLAN_SCENARIO_MAP.md §3）。
#
# ⚠ stages.json には2つの形式が同居する。
#     フロア形式  … layers を持つ（floor_1..5・本番）
#     ウェーブ形式 … waves を持つ（stage_dbg_* 5本・検証用。リリース前に消す）
# ⚠ 見分ける口は is_floor_stage() の1本だけ。2箇所で判定しないこと。
const STAGE_MASTER_LAYERS: String = "layers"
const STAGE_MASTER_BATTLE_POOL: String = "battle_pool"
const STAGE_MASTER_BOSS: String = "boss"
# フロアが使う宝箱のID（段階14-b）。{rarity: chest_id} の4件。
#
# ⚠ floor_id から "floor_%d_%s" を組み立てないこと。必ずこの欄で引く。
#   IDから切り出す形は装飾で事故っている（ITEM_MASTER_PART_KIND のコメント）。
const STAGE_MASTER_CHEST_IDS: String = "chest_ids"

# 道中の戦闘ノード1回ぶんの報酬（段階14-i・宿題63）。
#
# ⚠ rewards（ボス）とは別の欄。⚠ 中身の形は同じ {gold, materials, inventory}。
# ⚠ 道中に報酬が無かったころ、戦闘ノードは純粋なコストで「避けるのが常に最適」だった。
#   ⚠ 宝箱は移動に紐づくのでどのルートでも同じ数＝戦闘を踏む理由が1つも無かった。
# ⚠ 総量は据え置き（人間の決定：Lv100×3 の集中時間は実質16時間のまま）。
#   ⚠ ボスの gold を半分にして、⚠ 残り半分を道中へ配り直しただけ。
#   ⚠ 期待戦闘回数（無作為ルートで 3.5回）で掛けると元の合計に戻る。
# ⚠ 素材はここに入れない。⚠ 1周ぶんを整数で割ると端数が出て、⚠ フロアごとの
#   配り方（stages.json の materials）と二重管理になる。⚠ ゴールドだけにする。
const STAGE_MASTER_NODE_REWARDS: String = "node_rewards"

# レアリティの綴り。⚠ chests.json の chest_id の後半と stages.json の chest_ids の
#   キーが、この4つで揃っていること。
const CHEST_RARITY_COMMON: String = "common"
const CHEST_RARITY_RARE: String = "rare"
const CHEST_RARITY_EPIC: String = "epic"
const CHEST_RARITY_LEGENDARY: String = "legendary"
# layers の各要素。
const LAYER_NODE_COUNT: String = "node_count"
const LAYER_WEIGHTS: String = "weights"

const ITEM_MASTER_PART_KIND: String = "part_kind"
const ITEM_MASTER_PART_TIER: String = "part_tier"
const ITEM_MASTER_PART_STAT: String = "part_stat"
const ITEM_MASTER_PART_BASE: String = "part_base"
const ITEM_MASTER_PART_ROLL_MAX: String = "part_roll_max"
# 素材の段階（1〜4）。items.json の material 16件だけが持つ。
#
# ⚠ IDの末尾（"_1".."_4"）から切り出さないこと（ITEM_MASTER_PART_KIND のコメントと
#   同じ理由）。仮アセットのアイコンが「右下の数字」と「色」に使う。
const ITEM_MASTER_MATERIAL_TIER: String = "material_tier"

# ランの中で使うものが「何をするか」（段階17-c・item_type: dungeon の品だけが持つ）。
#
# ⚠ ID の綴りで見分けないこと（ITEM_MASTER_PART_KIND と同じ理由）。
# ⚠ 効き方の数値はここに書かない。DungeonConfig のつまみが持つ（AGENTS.md の判定表）。
const ITEM_MASTER_DUNGEON_EFFECT: String = "dungeon_effect"
# ⚠ 増やすときは use_dungeon_item() の分岐と E134 の検証も一緒に足すこと
#   （欄だけ足して実装しない＝AGENTS.md）。
const DUNGEON_EFFECT_HEAL: String = "heal"
const DUNGEON_EFFECT_REVIVE: String = "revive"

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
	# ⚠ 上限の合計が max_character_level と一致しているかを見る（E127・段階10）。
	#   ⚠ ずれるとパッシブの Lv100 が永久に解放されないが、赤も黄も出ない。
	_validate_level_cap_total()
	# ⚠ FloorConfig の割り当てと層の重みを見る（E131・段階14-i）。
	#   ⚠ 割り当て漏れは「起動は通るがフロアに入った瞬間に落ちる」形で出る。
	_validate_floor_config()
	_validate_icon_config()
	# ⚠ 難ダンジョン（段階17-a・E133 / W22）。⚠ Balance.dungeon の割り当て漏れは
	#   「ランに入った瞬間に落ちる」形で出るので、起動時に言わないと気づけない。
	_validate_dungeon_config()
	# ⚠ 持ち物のマス目（段階18-b・E135）。⚠ 割り当て漏れは 9999 マスで動き続けるので、
	#   ⚠ ここで言わないと「容量が効いていないこと」に誰も気づけない。
	_validate_inventory_config()
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
		# マス目の並び（段階18-f）。⚠ 空なら「まだ並べていない」＝持ち物の順で作り直す。
		GameStateKeys.INVENTORY_ORDER: [],
		# 買った拡張ぶんのマス数（段階18-e）。
		GameStateKeys.INVENTORY_EXTRA_SLOTS: 0,
		GameStateKeys.PENDING_CHESTS: [],
		# フロア探索（段階14-a）。floor_id が "" なら入っていない。
		# ⚠ 9つの欄を最初から全部持たせる。14-b〜14-e が埋める欄も空で置く。
		GameStateKeys.FLOOR_RUN: _empty_floor_run(),
		# 難ダンジョンのラン（段階17-a）。dungeon_id が "" なら入っていない。
		# ⚠ FLOOR_RUN とは別の器（PLAN_HARD_DUNGEON.md §7）。⚠ 使い回さないこと。
		# ⚠ 14 の欄を最初から全部持たせる。17-b〜17-e が埋める欄も空で置く。
		GameStateKeys.DUNGEON_RUN: _empty_dungeon_run(),
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
# ⚠⚠ 段階18-b：戻り値を「実際に入った数」に変えた（前は void）。
#   ⚠ 満杯なら 0 が返る。⚠ 呼び元は戻り値を見て、⚠ 払ったものを取り消すのではなく
#     「払う前に弾く」こと（CLAUDE.md 6番）。⚠ ここは最後の砦であって、判定の場所ではない。
#   ⚠ 素材（add_material）はマスを使わないので、ここを通らない（人間の決定5）。
func add_to_inventory(item_id: String, count: int, item_type: String = GameStateKeys.ITEM_TYPE_UNKNOWN) -> int:
	if count <= 0:
		return 0
	# ⚠ 入る数まで削る。⚠ 溢れたぶんは入らない（＝拾えない）。⚠ 何かを勝手に捨てて空けない。
	var accepted: int = mini(count, get_inventory_free_slots())
	if accepted <= 0:
		push_warning("[GameManager] W25 add_to_inventory('%s', %d) -> 0（倉庫が満杯 %d/%d）" % [
			item_id, count, get_inventory_slots_used(), get_inventory_slot_max()
		])
		return 0
	if accepted < count:
		push_warning("[GameManager] W25 add_to_inventory('%s', %d) -> %d だけ入った（倉庫 %d/%d）" % [
			item_id, count, accepted, get_inventory_slots_used(), get_inventory_slot_max()
		])
	count = accepted

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
		return count

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
	# ⚠ slot_position はもう書かない（段階18-f）。⚠ item_id ごとに1つしか持てないので、
	#   ⚠ 「1マス＝1個」の並びを表現できない。⚠ 並びは INVENTORY_ORDER が持つ。
	if not entry.has(GameStateKeys.ITEM_PROPERTIES):
		entry[GameStateKeys.ITEM_PROPERTIES] = {}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory

	var newly_discovered: bool = _mark_codex_discovered(item_id)
	print("[GameManager] add_to_inventory('%s', %d, type='%s') -> count=%d newly_discovered=%s" % [
		item_id, count, str(entry[GameStateKeys.ITEM_TYPE]), int(entry[GameStateKeys.ITEM_COUNT]), newly_discovered])
	inventory_changed.emit(item_id)
	return count

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
		# ⚠ 段階18-b：倉庫に入らないなら開けさせない（PLAN_INVENTORY.md §4-1）。
		#   ⚠ 開けてから溢れると中身が消える。⚠ 未開封のまま残せば取り返しがつく。
		#   ⚠ 判定は「開けた」と書く前（CLAUDE.md 6番）。
		var chest_needs: int = _inventory_slots_needed(
			chest.get(GameStateKeys.CHEST_REWARDS, {}).get(GameStateKeys.REWARD_INVENTORY, {})
		)
		if not can_accept_inventory(chest_needs):
			print("[GameManager] open_chest('%s') -> false (倉庫が満杯 %d/%d・要る %d マス)" % [
				instance_id, get_inventory_slots_used(), get_inventory_slot_max(), chest_needs
			])
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

# chests.json の draw を引く。戻りは {item_id: count}（rewards.inventory と同じ形）。
func _roll_chest_draw(draw_def: Dictionary) -> Dictionary:
	# ⚠ 研究の chest_draw_bonus はここ1箇所だけに乗る（段階10）。
	#   ⚠ weight（ドロップ率・高等級の確率）には乗せない。抽選の本体は変えない。
	return _roll_weighted_table(
		draw_def.get(CHEST_DRAW_ENTRIES, []),
		int(draw_def.get(CHEST_DRAW_ROLLS, 1)) + get_research_chest_draw_bonus()
	)


# recipes.json の draw を引く（作業場の装飾のくじ・段階11）。
#
# ⚠ _roll_chest_draw() を呼んではいけない。あちらには研究の「宝箱」枝が乗っており、
#   ⚠ そのまま使うと宝箱の研究が作業場のくじにも黙って効く（EXEC_WORKSHOP_REVIVE.md 決め2）。
# ⚠ 作業場の枝は rolls ではなく duration_sec と本数に乗る。ここには何も足さない。
func _roll_recipe_draw(draw_def: Dictionary) -> Dictionary:
	return _roll_weighted_table(
		draw_def.get(CHEST_DRAW_ENTRIES, []),
		int(draw_def.get(CHEST_DRAW_ROLLS, 1))
	)


# 重み付きテーブルを rolls 回引く。戻りは {item_id: count}（rewards.inventory と同じ形）。
#
# ⚠ 抽選の本体はこの1本だけ。同じ形の判定を散らさない（NEXT_STEPS §2-6）。
#   ⚠ 宝箱もレシピもここを通る。⚠ ボーナスの類は一切見ない。足すのは呼び出し側の rolls。
# ⚠ item_id が "" の枠はハズレ。当たっても何も足さない
#   （⚠ 宝箱だけの仕様。レシピ側は E129 が "" を赤で弾く）。
# ⚠ weight の合計が0以下なら空を返す。randi_range(1, 0) を踏まないため。
# ⚠ MasterDataLoader が返す数値は float なので、rolls も weight も count も int() で包む
#   （CLAUDE.md 3番）。包み忘れると randi_range に float が渡って黙って壊れる。
# ⚠ 乱数は固定しない（装飾のロールと同じ）。検証は分布で見る。
func _roll_weighted_table(rows: Variant, rolls: int) -> Dictionary:
	var drawn: Dictionary = {}
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

# --- マス目（段階18-a・PLAN_INVENTORY.md） -----------------------------
#
# ⚠⚠ 「何がマスを1つ占めるか」を決める口はここ1本（§5-1・人間の決定5）。
#   ⚠ 画面側（倉庫・ダンジョンの鞄）で item_type を見て並べ直さないこと。
#   ⚠ 判定が2箇所になると、片方だけ直したときに「倉庫では見えるのに数が合わない」になる。
#
# マスに並ぶもの：
#   ⚠ 持ち物（INVENTORY）… 消耗品・装飾。⚠ 1個＝1マス（重ねない＝人間の決定3）
#   ⚠ 装備の個体（EQUIPMENT_INSTANCES）… 1個＝1マス（数えられないので当然そうなる）
# マスに並ばないもの：
#   ⚠ 汎用素材（MATERIALS）… 人間の決定5。⚠ 数千個になるので入れると即破綻する
#   ⚠ ランの鞄（DUNGEON_RUN_BAG）… 器が別（PLAN_HARD_DUNGEON.md §7）。⚠ 18-d で別の口を作る

# マス1つぶんの中身のキー。⚠ 文字列リテラルを散らさない。
const SLOT_ENTRY_KIND: String = "kind"
const SLOT_ENTRY_ITEM_ID: String = "item_id"
const SLOT_ENTRY_INSTANCE_ID: String = "instance_id"
const SLOT_ENTRY_GRADE: String = "grade"
const SLOT_ENTRY_EQUIPPED_BY: String = "equipped_by"
# ⚠ 何個持っているか（⚠ 鞄のマスだけが入れる。⚠ 倉庫は拠点の所持数を引けるので入れない）。
const SLOT_ENTRY_COUNT: String = "count"
# ⚠ 種類は2つだけ。⚠ 増やすときは ItemSlot の描き分けも同じ回に足すこと。
const SLOT_KIND_ITEM: String = "item"
const SLOT_KIND_INSTANCE: String = "instance"
# ⚠ レリック（段階17-e-3）。⚠ items.json の品ではないが、⚠ マスと詳細の部品を共有するために
#   同じ形で包む（⚠ アイコンは ItemIcon が relic_id から引ける）。
#   ⚠ 個数を持たない。⚠ 拠点の倉庫にも入らない。
const SLOT_KIND_RELIC: String = "relic"
# キャラの装備マス（get_equipment_slot_entries の1要素）のキー。
const SLOT_ENTRY_EQUIP_SLOT: String = "equip_slot"
const SLOT_ENTRY_ENTRY: String = "entry"


# マスに並ぶものを、並び順のまま返す（⚠ 空きマスは含まない＝数を数えるのはこちら）。
#
# ⚠ 1マス＝1個。⚠ count が 3 なら同じ item_id が3要素になる（重ねない）。
# ⚠ 並びは INVENTORY_ORDER（段階18-f）。⚠ 動かした順がそのまま出る。
func get_inventory_slot_entries() -> Array:
	var result: Array = []
	for entry: Variant in get_inventory_slot_layout():
		if not (entry as Dictionary).is_empty():
			result.append(entry)
	return result


# マス目そのもの（⚠ 長さは倉庫のマス数。⚠ 空きマスは空の Dictionary）。
#
# ⚠⚠ 画面はこちらを使う。⚠ 穴（途中の空きマス）が要るため
#   （⚠ 動かして空けた場所が、⚠ 次に描いたとき詰まってしまうと「動かせない」のと同じ）。
func get_inventory_slot_layout() -> Array:
	var order: Array = _reconciled_inventory_order()
	var result: Array = []
	for key: Variant in order:
		result.append(_slot_entry_of_key(str(key)))
	return result


# 並びの1マスぶんの鍵から、マスの中身を組み立てる。
#
# ⚠ 鍵は「持ち物なら item_id」「装備の個体なら instance_id」。
# ⚠ 見分けは equipment_instances に在るかどうか。⚠ 綴りで見分けない。
func _slot_entry_of_key(key: String) -> Dictionary:
	if key == "":
		return {}
	var instance: Dictionary = get_equipment_instance(key)
	if not instance.is_empty():
		return {
			SLOT_ENTRY_KIND: SLOT_KIND_INSTANCE,
			SLOT_ENTRY_ITEM_ID: str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
			SLOT_ENTRY_INSTANCE_ID: key,
			SLOT_ENTRY_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
			SLOT_ENTRY_EQUIPPED_BY: _equipped_owner(key),
		}
	return {
		SLOT_ENTRY_KIND: SLOT_KIND_ITEM,
		SLOT_ENTRY_ITEM_ID: key,
		SLOT_ENTRY_INSTANCE_ID: "",
		SLOT_ENTRY_GRADE: 0,
		SLOT_ENTRY_EQUIPPED_BY: "",
	}


# いま持っているものの「鍵の必要数」。{鍵: 何マス要るか}。
#
# ⚠ 持ち物は個数ぶん。⚠ 装備の個体は1つにつき1マス。
# ⚠⚠ 装備中の個体は数えない（人間の決定7。⚠ キャラの装備マスへ移っている）。
func _inventory_required_keys() -> Dictionary:
	var required: Dictionary = {}
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	for entry: Variant in inventory:
		var item_id: String = str(entry)
		var row: Variant = inventory[item_id]
		if not (row is Dictionary):
			continue
		var count: int = int((row as Dictionary).get(GameStateKeys.ITEM_COUNT, 0))
		if count > 0:
			required[item_id] = count
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	for entry: Variant in instances:
		var instance_id: String = str(entry)
		if _equipped_owner(instance_id) != "":
			continue
		required[instance_id] = 1
	return required


# 並びを持ち物と突き合わせて作り直す（段階18-f）。
#
# ⚠⚠ 並びは「飾り」であって正ではない。⚠ ずれたら並びのほうを直す。
#   ⚠ 拾ったもの（並びに無いもの）は前から空きマスへ入れる。
#   ⚠ 無くなったもの（壊した・装備した・売った）はマスを空ける。
#   ⚠ 穴は詰めない（⚠ 詰めると自分で空けた場所が消える）。
# ⚠ 状態は書き換えない。⚠ 読むたびに作り直すだけ（⚠ セーブに書くのは動かしたときだけ）。
func _reconciled_inventory_order() -> Array:
	var slot_max: int = get_inventory_slot_max()
	var required: Dictionary = _inventory_required_keys()
	var raw: Variant = _state.get(GameStateKeys.INVENTORY_ORDER, [])
	var order: Array = []
	var used: Dictionary = {}

	if raw is Array:
		for entry: Variant in (raw as Array):
			if order.size() >= slot_max:
				break
			var key: String = str(entry)
			if key == "":
				order.append("")
				continue
			var have: int = int(used.get(key, 0))
			if have >= int(required.get(key, 0)):
				# もう持っていない（⚠ 壊した・装備した）。⚠ マスは空ける。
				order.append("")
				continue
			used[key] = have + 1
			order.append(key)

	while order.size() < slot_max:
		order.append("")

	# 並びに入っていないもの（⚠ 拾ったばかり）を前から詰める。
	var keys: Array = required.keys()
	keys.sort()
	var cursor: int = 0
	for entry: Variant in keys:
		var key: String = str(entry)
		var missing: int = int(required[key]) - int(used.get(key, 0))
		while missing > 0:
			while cursor < order.size() and str(order[cursor]) != "":
				cursor += 1
			if cursor >= order.size():
				# ⚠ ここへ来るのは容量より持ち物が多いとき（⚠ 上限を下げた直後など）。
				#   ⚠ 黙って消さずに言う。⚠ 中身は INVENTORY に残っている。
				push_warning("[GameManager] W27 マス目に収まらない持ち物がある（%d マス / 必要 %d）" % [
					slot_max, _required_total(required)
				])
				return order
			order[cursor] = key
			missing -= 1
	return order


func _required_total(required: Dictionary) -> int:
	var total: int = 0
	for key: Variant in required:
		total += int(required[key])
	return total


# マスを入れ替える（段階18-f・ドラッグ＆ドロップ）。
#
# ⚠ 中身は動かさない。⚠ 動くのは並びだけ（⚠ 持ち物そのものは INVENTORY が正）。
# ⚠ 空きマスへ動かすのも、⚠ 中身どうしの入れ替えも、⚠ どちらも同じ「交換」。
#   ⚠ 挿入（あいだに割り込んで後ろをずらす）にしないこと。⚠ 1回の操作で何マスも動くと、
#     ⚠ 何が起きたか画面から読めない（マインクラフトも交換）。
# ⚠ 状態を触る前に判定を終える（CLAUDE.md 6番）。
func move_inventory_slot(from_index: int, to_index: int) -> bool:
	var order: Array = _reconciled_inventory_order()
	if from_index < 0 or to_index < 0 or from_index >= order.size() or to_index >= order.size():
		print("[GameManager] move_inventory_slot(%d -> %d) -> false (マスの外)" % [from_index, to_index])
		return false
	if from_index == to_index:
		return false
	if str(order[from_index]) == "" and str(order[to_index]) == "":
		return false

	var moved: String = str(order[from_index])
	order[from_index] = order[to_index]
	order[to_index] = moved
	_state[GameStateKeys.INVENTORY_ORDER] = order
	print("[GameManager] move_inventory_slot(%d -> %d) -> true ('%s' と '%s' を入れ替えた)" % [
		from_index, to_index, moved, str(order[from_index])
	])
	inventory_changed.emit(moved)
	return true


# レリック1件をマスの形に包む（段階17-e-3）。
#
# ⚠ 共有部品（ItemSlot / ItemDetail）へ渡すためだけの形。⚠ 状態には入らない。
func make_relic_slot_entry(relic_id: String, character_id: String = "") -> Dictionary:
	return {
		SLOT_ENTRY_KIND: SLOT_KIND_RELIC,
		SLOT_ENTRY_ITEM_ID: relic_id,
		SLOT_ENTRY_INSTANCE_ID: "",
		SLOT_ENTRY_GRADE: 0,
		SLOT_ENTRY_EQUIPPED_BY: character_id,
	}


# ランの鞄のマス目（段階18-d・PLAN_INVENTORY.md 未決6）。
#
# ⚠⚠ 倉庫の口（get_inventory_slot_layout）を借りない。⚠ 器が別（PLAN_HARD_DUNGEON.md §7）。
#   ⚠ 借りると鞄に拠点の持ち物が並ぶ。⚠ 部品（ItemSlot / ItemGrid / ItemDetail）だけ共有する。
# ⚠ 長さは鞄の枠。⚠ 空きマスは空の Dictionary（⚠ 「あと何個入るか」が見えること）。
# ⚠ 並べ替えは保存しない。⚠ 鞄は item_id と個数しか持たない（台帳 §7）。
#   ⚠ 並びが要るなら DUNGEON_RUN に欄を1本足すことになる。⚠ INVENTORY_ORDER を借りない。
func get_dungeon_bag_slot_layout() -> Array:
	var result: Array = []
	var bag: Dictionary = get_dungeon_bag()
	var item_ids: Array = bag.keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		var count: int = int(bag[item_id])
		for _i: int in range(maxi(0, count)):
			result.append({
				SLOT_ENTRY_KIND: SLOT_KIND_ITEM,
				SLOT_ENTRY_ITEM_ID: item_id,
				SLOT_ENTRY_INSTANCE_ID: "",
				SLOT_ENTRY_GRADE: 0,
				SLOT_ENTRY_EQUIPPED_BY: "",
				# ⚠ 鞄の個数。⚠ 拠点の所持数ではない（⚠ ラン専用の品は拠点に1個も無い）。
				SLOT_ENTRY_COUNT: count,
			})
	while result.size() < get_dungeon_bag_slots():
		result.append({})
	return result


# キャラの装備マス（人間の決定7・2026-09-03）。
#
# ⚠ 並びは get_equip_slots()（頭・上半身・脚・武器・アクセサリー）。⚠ 2本目の並びを作らない。
# ⚠ 何も着けていない枠は entry が空の Dictionary。⚠ 行ごと飛ばさないこと
#   （⚠ 空きマスが見えることがマス目にする理由そのもの）。
# ⚠ ここに出るものは get_inventory_slot_entries() には出ない（同じ個体が2マスを占めない）。
func get_equipment_slot_entries(character_id: String) -> Array:
	var result: Array = []
	for slot: String in get_equip_slots():
		var instance_id: String = get_equipped_instance_id(character_id, slot)
		var entry: Dictionary = {}
		if instance_id != "":
			var instance: Dictionary = get_equipment_instance(instance_id)
			entry = {
				SLOT_ENTRY_KIND: SLOT_KIND_INSTANCE,
				SLOT_ENTRY_ITEM_ID: str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
				SLOT_ENTRY_INSTANCE_ID: instance_id,
				SLOT_ENTRY_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
				SLOT_ENTRY_EQUIPPED_BY: character_id,
			}
		result.append({SLOT_ENTRY_EQUIP_SLOT: slot, SLOT_ENTRY_ENTRY: entry})
	return result


# いま何マス使っているか。⚠ 数える口はここ1本（get_inventory_slot_entries と必ず一致する）。
func get_inventory_slots_used() -> int:
	return get_inventory_slot_entries().size()


var _inventory_config_warned: bool = false


# ⚠ Balance.inventory を読む唯一の口（_dungeon() と同じ形）。
func _inventory_config() -> InventoryConfig:
	if Balance == null or Balance.inventory == null:
		if not _inventory_config_warned:
			_inventory_config_warned = true
			push_error("[GameManager] E135 balance.tscn: Balance.inventory が null。inventory_config.tres を Balance ノードの inventory 欄に割り当てること")
		return null
	return Balance.inventory


# 倉庫のマス数（段階18-b）。
#
# ⚠ 拡張ぶんは 18-e で状態に足す。⚠ そのときもここ1本を通すこと
#   （画面や入口が「初期値＋拡張」を自分で足し算しない）。
# ⚠ Config が無いときは 0 ではなく大きい数を返す。⚠ 0 を返すと、割り当て漏れの
#   その日から「何も拾えないゲーム」になり、⚠ 原因が容量だと気づけない。
func get_inventory_slot_max() -> int:
	var config: InventoryConfig = _inventory_config()
	if config == null:
		return 9999
	# ⚠ 足し算をするのはここ1本（段階18-e）。⚠ 画面や入口が「初期＋拡張」を組み立てないこと。
	return maxi(0, int(config.initial_slots) + get_inventory_extra_slots())


# 買った拡張ぶんのマス数（段階18-e）。
func get_inventory_extra_slots() -> int:
	return int(_state.get(GameStateKeys.INVENTORY_EXTRA_SLOTS, 0))


# 次の拡張の値段（ゴールド）。⚠ 上限まで買っていれば 0。
#
# ⚠ 値段の式を画面に書かないこと。⚠ 押せるかの判定も get_inventory_expand_reject_reason()。
func get_inventory_expand_cost() -> int:
	var config: InventoryConfig = _inventory_config()
	if config == null:
		return 0
	if get_inventory_page_count() >= int(config.max_pages):
		return 0
	var per_page: int = get_inventory_slots_per_page()
	var bought: int = get_inventory_extra_slots() / maxi(1, per_page * int(config.expand_pages_per_purchase))
	return maxi(0, int(config.expand_cost_gold_base) + int(config.expand_cost_gold_step) * bought)


# 拡張を断る理由（"" なら買える）。⚠ 画面はこの1本に聞く。
const INVENTORY_EXPAND_REJECT_MAX: String = "max"
const INVENTORY_EXPAND_REJECT_GOLD: String = "gold"


func get_inventory_expand_reject_reason() -> String:
	var config: InventoryConfig = _inventory_config()
	if config == null:
		return INVENTORY_EXPAND_REJECT_MAX
	if get_inventory_page_count() >= int(config.max_pages):
		return INVENTORY_EXPAND_REJECT_MAX
	if int(_state.get(GameStateKeys.GOLD, 0)) < get_inventory_expand_cost():
		return INVENTORY_EXPAND_REJECT_GOLD
	return ""


# 枠を1ページぶん買う（段階18-e）。
#
# ⚠ 状態を触る前に判定を終える（CLAUDE.md 6番）。⚠ 払ってから増やすのではなく、
#   ⚠ 断る理由が無いことを先に確かめる。
# ⚠ 並び（INVENTORY_ORDER）は触らない。⚠ 長さは _reconciled_inventory_order() が
#   毎回そろえるので、⚠ ここで後ろに "" を足さないこと（2箇所で長さを決めない）。
func expand_inventory() -> bool:
	var reason: String = get_inventory_expand_reject_reason()
	if reason != "":
		print("[GameManager] expand_inventory() -> false (%s)" % reason)
		return false
	var config: InventoryConfig = _inventory_config()
	var added: int = get_inventory_slots_per_page() * maxi(1, int(config.expand_pages_per_purchase))
	var cost: int = get_inventory_expand_cost()

	# --- ここから状態を変える ---
	_spend_currency(GameStateKeys.GOLD, cost)
	_state[GameStateKeys.INVENTORY_EXTRA_SLOTS] = get_inventory_extra_slots() + added
	print("[GameManager] expand_inventory() -> true (%d G / +%d マス / 合計 %d マス・%d ページ)" % [
		cost, added, get_inventory_slot_max(), get_inventory_page_count()
	])
	inventory_changed.emit("")
	return true


# マスの中身を1つ捨てる（段階18-e）。
#
# ⚠⚠ 満杯で拡張も買えないと閉じ込められるので、⚠ 逃げ道は必ず要る（台帳 §4-2）。
# ⚠ 戻りは無い。⚠ 装備は「素材にする」（dismantle_equipment）のほうが素材が戻るので、
#   ⚠ 画面はそちらを勧めること。⚠ ただしここで装備を弾かない（⚠ 逃げ道は塞がない）。
# ⚠ 1マス＝1個なので、⚠ 捨てるのも1個（⚠ 「全部捨てる」を作らない）。
# ⚠ 装備中の個体はマス目に出てこないので、⚠ ここへは来ない（人間の決定7）。
func discard_inventory_slot(index: int) -> bool:
	var layout: Array = get_inventory_slot_layout()
	if index < 0 or index >= layout.size():
		print("[GameManager] discard_inventory_slot(%d) -> false (マスの外)" % index)
		return false
	var entry: Dictionary = layout[index]
	if entry.is_empty():
		print("[GameManager] discard_inventory_slot(%d) -> false (空のマス)" % index)
		return false

	# --- ここから状態を変える ---
	if str(entry.get(SLOT_ENTRY_KIND, "")) == SLOT_KIND_INSTANCE:
		var instance_id: String = str(entry.get(SLOT_ENTRY_INSTANCE_ID, ""))
		var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
		instances.erase(instance_id)
		_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances
		print("[GameManager] discard_inventory_slot(%d) -> true (装備の個体 %s を捨てた・戻りは無し)" % [
			index, instance_id
		])
		equipment_instances_changed.emit("")
		return true

	var item_id: String = str(entry.get(SLOT_ENTRY_ITEM_ID, ""))
	_remove_from_inventory(item_id, 1)
	print("[GameManager] discard_inventory_slot(%d) -> true ('%s' を1個捨てた・戻りは無し)" % [index, item_id])
	return true


# --- ページ（人間の決定8・2026-09-03） ---
#
# ⚠ 500 マスを 100 マス（20列 × 5行）× 5 ページで見せる。
# ⚠ 掛け算をするのはここ1本。⚠ 画面で columns × rows を計算し直さないこと
#   （⚠ Config を変えたときに画面だけ古い数のまま並ぶ）。

# 1行に並べるマスの数。
func get_inventory_columns() -> int:
	var config: InventoryConfig = _inventory_config()
	if config == null:
		return 1
	return maxi(1, int(config.columns))


# 1ページのマス数。
func get_inventory_slots_per_page() -> int:
	var config: InventoryConfig = _inventory_config()
	if config == null:
		return get_inventory_slot_max()
	return maxi(1, int(config.columns) * int(config.rows_per_page))


# ページ数。⚠ 端数が出たら1ページ多く数える（⚠ 最後のページが半端でもマスは在る）。
func get_inventory_page_count() -> int:
	var per_page: int = get_inventory_slots_per_page()
	return maxi(1, int(ceil(float(get_inventory_slot_max()) / float(per_page))))


# そのページに並ぶもの（⚠ 空きマスは空の Dictionary。⚠ 長さは1ページのマス数）。
#
# ⚠ ページ番号は 0 から。⚠ 範囲の外なら空の配列。
# ⚠ 並びは INVENTORY_ORDER（段階18-f）。⚠ ドラッグで動かした順がそのまま出る。
func get_inventory_page_entries(page: int) -> Array:
	var per_page: int = get_inventory_slots_per_page()
	# ⚠ 穴つきの並び（layout）から切る。⚠ 詰めた配列（entries）から切らないこと。
	#   ⚠ 詰めると、⚠ 自分で空けたマスが次に描いたとき消える（＝動かせない）。
	var layout: Array = get_inventory_slot_layout()
	var from: int = page * per_page
	if page < 0 or from >= layout.size():
		return []
	return layout.slice(from, mini(from + per_page, layout.size()))


# 空きマス。
func get_inventory_free_slots() -> int:
	return maxi(0, get_inventory_slot_max() - get_inventory_slots_used())


# 報酬の {item_id: 個数} が何マス要るか。⚠ 素材は 0（マスを使わない＝人間の決定5）。
func _inventory_slots_needed(items: Variant) -> int:
	if not (items is Dictionary):
		return 0
	var total: int = 0
	for item_id: Variant in (items as Dictionary):
		total += _inventory_slots_needed_for_item(str(item_id), int((items as Dictionary)[item_id]))
	return total


# 1件ぶん。⚠ 素材かどうかの判定は _item_storage() の1本に聞く（綴りで見分けない）。
func _inventory_slots_needed_for_item(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	if _item_storage(item_id) == ITEM_STORAGE_MATERIAL:
		return 0
	return count


# その数だけ入るか。⚠ 物が増える口は「状態を触る前に」これを聞く（CLAUDE.md 6番）。
#
# ⚠ 聞かずに add_to_inventory() へ流すと、⚠ 払ったあとで入らないことが分かる
#   （ゴールドを払った・材料を消した・宝箱を開けた あとでは取り返せない）。
func can_accept_inventory(count: int) -> bool:
	if count <= 0:
		return true
	return get_inventory_free_slots() >= count


# 倉庫の容量を見る（E135）。
func _validate_inventory_config() -> void:
	if Balance == null or Balance.inventory == null:
		push_error("[GameManager] E135 balance.tscn: Balance.inventory が null。inventory_config.tres を Balance ノードの inventory 欄に割り当てること")
		return
	if int(Balance.inventory.initial_slots) <= 0:
		push_error("[GameManager] E135 inventory_config.gd: initial_slots が 0。何も拾えないゲームになる")
		return
	# 段階18-e。⚠ 拡張が「買えるのに増えない」「無限に買える」を止める。
	if int(Balance.inventory.expand_pages_per_purchase) <= 0:
		push_error("[GameManager] E135 inventory_config.gd: expand_pages_per_purchase が 0。買っても増えない")
		return
	if int(Balance.inventory.max_pages) <= 0:
		push_error("[GameManager] E135 inventory_config.gd: max_pages が 0。1ページも持てない")
		return
	if int(Balance.inventory.expand_cost_gold_base) <= 0:
		push_warning("[GameManager] W28 inventory_config.gd: expand_cost_gold_base が 0。枠がタダで増える")
	if int(Balance.inventory.columns) <= 0 or int(Balance.inventory.rows_per_page) <= 0:
		push_error("[GameManager] E135 inventory_config.gd: columns / rows_per_page が 0。1ページに1マスも並ばない")
		return
	# ⚠ 割り切れないと最後のページだけ半端になる。⚠ 壊れはしないので黄。
	var per_page: int = get_inventory_slots_per_page()
	if int(Balance.inventory.initial_slots) % per_page != 0:
		push_warning("[GameManager] W26 inventory_config.gd: initial_slots %d が 1ページ %d マスで割り切れない（最後のページが半端になる）" % [
			int(Balance.inventory.initial_slots), per_page
		])
	print("[GameManager] inventory config validated: %d マス ＝ %d マス（%d列 × %d行）× %d ページ, 0 errors" % [
		int(Balance.inventory.initial_slots), per_page,
		int(Balance.inventory.columns), int(Balance.inventory.rows_per_page),
		get_inventory_page_count(),
	])


# ⚠ update_inventory_slot_position() は段階18-f で消した。
#   ⚠ 呼び出し元が0件のまま残っていた欄（slot_position）の書き込み口で、
#     ⚠ item_id ごとに1つしか位置を持てず「1マス＝1個」を表現できなかった。
#   ⚠ 並びを動かす口は move_inventory_slot()。

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

	# ⚠ 段階18-b：倉庫に入らないなら買わせない（PLAN_INVENTORY.md §4-1）。
	#   ⚠ ゴールドを払ってから「渡せません」になるのが最悪。⚠ 判定はここまでに終える。
	#   ⚠ 素材で受け取るぶん（payout_type=material）はマスを使わない（人間の決定5）。
	if payout_type == PAYOUT_TYPE_ITEM and not can_accept_inventory(payout_count):
		print("[GameManager] purchase_shop_item('%s', %d) -> false (倉庫が満杯 %d/%d・要る %d マス)" % [
			shop_type, slot_id, get_inventory_slots_used(), get_inventory_slot_max(), payout_count
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

	# ⚠⚠ 外すとインベントリのマスへ戻る（人間の決定7）。⚠ 満杯なら外させない。
	#   ⚠ 外してから「置く場所が無い」になると、⚠ 個体が宙に浮く（どのマスにも出ない）。
	#   ⚠ 判定は状態を触る前（CLAUDE.md 6番）。
	#   ⚠ 着けるほうは判定が要らない（⚠ 着ける個体がマスから出て、⚠ 前のものが戻る＝差し引き 0 以下）。
	if not can_accept_inventory(1):
		print("[GameManager] unequip_instance('%s', '%s') -> false (倉庫が満杯 %d/%d)" % [
			character_id, slot, get_inventory_slots_used(), get_inventory_slot_max()
		])
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
# 素材の段階（1〜4）。素材でない、または欄が無ければ 0。
#
# ⚠ 段階を引く口はここ1本。画面がIDの末尾を切り出さないこと。
func get_material_tier(item_id: String) -> int:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return 0
	if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_MATERIAL:
		return 0
	return int(definition.get(ITEM_MASTER_MATERIAL_TIER, 0))


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
#
# ⚠ パッシブは選ばない。レベルで解放されたものが全部効く
#   （人間の決定・2026-08-25。GAME_DESIGN.md 5-2 の表「20レベルごとに1つ解放（計5個）」
#   と 5-4「1キャラ5個」。EXEC_CHARACTER_PASSIVES.md §2 の決定1）。
#
# ⚠ get_battle_skills() を通さないこと。あちらは「枠に選んだもの」を確定させる
#   関数で、パッシブには枠が無い。通すと選択済みの1件しか戦闘に出ない。
# ⚠ get_skill_candidates() が unlock_level <= level で絞り、skills.json /
#   passives.json に無いIDも落とす。ここに2本目の絞り込みを書かない。
# ⚠ PASSIVE_SLOT_COUNT / _slot_spec() のパッシブの枝 / GROWTH_PASSIVES（状態）は
#   残してある。セーブとキャラプリセットの正規化がそこを通るため（消すと移行が要る）。
#   誰も読まない欄になったことは PROJECT_STATUS.md の宿題に書いてある。
func get_battle_passives(character_id: String) -> Array:
	return get_skill_candidates(character_id, SLOT_KIND_PASSIVE)

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
	# ⚠ ボードが開いていなければ前提の話まで行かない（unlock_research_node() と同じ順）。
	if not is_research_board_open(get_research_board_of(node_id)):
		return false
	return _prerequisites_met(node)


# --- 研究：ボード（段階10・GAME_DESIGN.md 9-1「1周クリアで次のボードに切り替わる」）---

# そのノードが属するボード番号。⚠ マスターだけが持つ欄で、状態には無い。
func get_research_board_of(node_id: String) -> int:
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	if definition.is_empty():
		return RESEARCH_DEFAULT_BOARD
	# JSON の数値は float で来る。int() を外すと比較がずれる（CLAUDE.md 3番）。
	return int(definition.get(RESEARCH_NODE_BOARD, RESEARCH_DEFAULT_BOARD))


# 今のボード＝未解放ノードを持つ最小のボード。全部解放済みなら最大のボード。
#
# ⚠ 状態に「今どのボードか」を持たない。持つとセーブの移行が要るうえ、
#   research.json にボードを足したときに状態と食い違う（_sync_research_tree_from_master()
#   がマスターを正とするのと同じ考え方）。
func get_current_research_board() -> int:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var lowest_open: int = -1
	var highest: int = RESEARCH_DEFAULT_BOARD
	for node_id: String in tree:
		var board: int = get_research_board_of(node_id)
		highest = maxi(highest, board)
		if bool((tree[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			continue
		if lowest_open < 0 or board < lowest_open:
			lowest_open = board
	return highest if lowest_open < 0 else lowest_open


func is_research_board_open(board: int) -> bool:
	return board <= get_current_research_board()


# そのボードの {全件, 解放済み}。画面のヘッダと scenario=research が使う。
func get_research_board_progress(board: int) -> Dictionary:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var total: int = 0
	var unlocked: int = 0
	for node_id: String in tree:
		if get_research_board_of(node_id) != board:
			continue
		total += 1
		if bool((tree[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			unlocked += 1
	return {"total": total, "unlocked": unlocked}


# 研究で解放した「宝箱の抽選回数 +N」の合計。_roll_chest_draw() の rolls に乗る。
func get_research_chest_draw_bonus() -> int:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var bonus: int = 0
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if not bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
			continue
		if str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) != GameStateKeys.EFFECT_CHEST_DRAW_BONUS:
			continue
		bonus += int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return bonus


# 研究で解放した「同時製作 +N」の合計。get_max_queue_slots() に乗る。
func get_research_craft_slot_bonus() -> int:
	return _research_effect_total(GameStateKeys.EFFECT_CRAFT_SLOT_BONUS)


# 研究で解放した「製作時間 -N%」の合計。start_craft() の duration_sec に乗る。
#
# ⚠ 100% 以上にならないよう頭を押さえる。押さえないと duration_sec が 0 か負になり、
#   ⚠ 押した瞬間に完成する製作ができてしまう（床は start_craft() 側の maxi(1, ...)）。
func get_research_craft_speed_percent() -> int:
	return clampi(_research_effect_total(GameStateKeys.EFFECT_CRAFT_SPEED_BONUS), 0, 99)


# 解放済みノードのうち、effect_type が一致するものの effect_value の合計。
# ⚠ 同じ形の走査を effect_type ごとに増やさないための1本
#   （get_research_chest_draw_bonus() も将来ここへ寄せてよい）。
func _research_effect_total(effect_type: String) -> int:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var total: int = 0
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if not bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
			continue
		if str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) != effect_type:
			continue
		total += int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return total

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

	# ⚠ ボードの判定は前提より先。前のボードを全部解放するまでは、前提を満たしていても
	#   解放させない（GAME_DESIGN.md 9-1）。順序を入れ替えると理由の表示が食い違う。
	var board: int = get_research_board_of(node_id)
	if not is_research_board_open(board):
		print("[GameManager] unlock_research_node('%s') -> false (board %d not open, current=%d)" % [
			node_id, board, get_current_research_board()
		])
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

# E127 … base_level_cap ＋ 全 level_cap_unlock の合計が max_character_level と一致するか。
#
# ⚠ ずれても赤も黄も出ず、「Lv100 のパッシブが永久に解放されない」形で無音に壊れる
#   （2026-08-25 に実際に踏んだ穴。NEXT_STEPS §1-3 が「一番重い」と言っている項目）。
# ⚠ 見るのはマスターの全ノードであって、解放済みのぶんではない。
#   ⚠ 「全部解放したときに 100 に届くか」を見張るのがこの検証。
func _validate_level_cap_total() -> void:
	if Balance == null or Balance.character == null:
		push_warning("[GameManager] E127: Balance.character が読めないため上限の合計を検証できない")
		return

	var base_cap: int = int(Balance.character.base_level_cap)
	var max_level: int = int(Balance.character.max_character_level)
	var nodes: Dictionary = MasterDataLoader.get_all_research_nodes()
	var sum_unlocks: int = 0
	var cap_nodes: int = 0
	for node_id: Variant in nodes:
		var definition: Variant = nodes[node_id]
		if not (definition is Dictionary):
			continue
		if str((definition as Dictionary).get(GameStateKeys.NODE_EFFECT_TYPE, "")) != GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			continue
		cap_nodes += 1
		sum_unlocks += int((definition as Dictionary).get(GameStateKeys.NODE_EFFECT_VALUE, 0))

	if base_cap + sum_unlocks != max_level:
		push_error("[GameManager] E127 research.json / character_config.gd: base_level_cap %d + level_cap_unlock %d件の合計 %d = %d だが max_character_level は %d" % [
			base_cap, cap_nodes, sum_unlocks, base_cap + sum_unlocks, max_level
		])
		return
	print("[GameManager] level cap validated: %d + %d (%d nodes) = %d, 0 errors" % [
		base_cap, sum_unlocks, cap_nodes, max_level
	])


# E131 … FloorConfig が割り当てられ、層の重みの4本が噛み合っているか（段階14-i）。
#
# ⚠ 新しい Config なので、balance.tscn の floor 欄が空だと Balance.floor が null になる。
#   ⚠ 起動は通り、フロアに入った瞬間に落ちる。ここで先に鳴らす。
# ⚠ 4本の長さが揃っていないと、短い配列だけ clampi で末尾が使われ、
#   「層6だけ重みが層5のまま」という無音のずれになる。
# ⚠ ショップの合流点（重みが shop だけの層）が1つも無いと、
#   「ショップは在るのに行けない周」が戻る（PLAN_SCENARIO_MAP.md §10-2-C）。
#   ⚠ これは仕様の選択なので赤ではなく黄（W21）にする。
func _validate_floor_config() -> void:
	if Balance == null or Balance.floor == null:
		push_error("[GameManager] E131 balance.tscn: Balance.floor が null。floor_config.tres を Balance ノードの floor 欄に割り当てること")
		return

	var rows: Dictionary = {
		"layer_weight_battle": Balance.floor.layer_weight_battle,
		"layer_weight_relic": Balance.floor.layer_weight_relic,
		"layer_weight_rest": Balance.floor.layer_weight_rest,
		"layer_weight_shop": Balance.floor.layer_weight_shop,
	}
	var expected: int = (rows["layer_weight_battle"] as Array).size()
	var errors: int = 0
	for name: String in rows:
		var size: int = (rows[name] as Array).size()
		if size != expected:
			push_error("[GameManager] E131 floor_config.gd: %s の長さ %d が layer_weight_battle の %d と違う（層ごとの重みがずれる）" % [
				name, size, expected
			])
			errors += 1
	if expected <= 0:
		push_error("[GameManager] E131 floor_config.gd: 層の重みが空。層が1つも作れない")
		errors += 1

	# ⚠ 各層の合計が 0 だと _roll_node_kind() が battle を返す（あちらの保険）。
	#   ⚠ 保険が効くので落ちないが、意図しない全戦闘フロアになる。
	var forced_shop_layers: int = 0
	for layer: int in range(1, expected + 1):
		var weights: Dictionary = get_floor_layer_weights(layer)
		if weights.is_empty():
			push_error("[GameManager] E131 floor_config.gd: 層 %d の重みが全部 0（battle に落ちる）" % layer)
			errors += 1
			continue
		if weights.size() == 1 and weights.has(GameStateKeys.FLOOR_NODE_KIND_SHOP):
			forced_shop_layers += 1
	if forced_shop_layers <= 0:
		push_warning("[GameManager] W21 floor_config.gd: 必ず通るショップの層が無い。たいまつを買えない周が出る（PLAN_SCENARIO_MAP.md §10-2-C）")

	if errors > 0:
		return
	print("[GameManager] floor config validated: %d 層 / 必ず通るショップの層 %d, 0 errors" % [
		expected, forced_shop_layers
	])


# 仮アセットのアイコンの色（E132）。
#
# ⚠ 見るのは3つだけ：割り当て漏れ ／ 色の数が等級の数と違う ／ 段階を写す表が
#   等級の範囲を出ている。⚠ どれも「静かに間違った色が出る」種類なので赤で鳴らす。
func _validate_icon_config() -> void:
	if Balance == null or Balance.icon == null:
		push_error("[GameManager] E132 balance.tscn: Balance.icon が null。icon_config.tres を Balance ノードの icon 欄に割り当てること")
		return

	var errors: int = 0
	var max_grade: int = get_max_equipment_grade()
	var colors: int = Balance.icon.grade_colors.size()
	if colors != max_grade:
		push_error("[GameManager] E132 icon_config.gd: grade_colors が %d 色。装備の等級は %d 段（端の色に丸められる）" % [
			colors, max_grade
		])
		errors += 1

	var tables: Dictionary = {
		"tier_grades": Balance.icon.tier_grades,
		"rune_tier_grades": Balance.icon.rune_tier_grades,
	}
	for table_name: String in tables:
		var table: Array = tables[table_name]
		if table.is_empty():
			push_error("[GameManager] E132 icon_config.gd: %s が空。段階を色に写せない" % table_name)
			errors += 1
			continue
		for grade: Variant in table:
			if int(grade) < 1 or int(grade) > colors:
				push_error("[GameManager] E132 icon_config.gd: %s に等級 %d が入っている（1〜%d の外）" % [
					table_name, int(grade), colors
				])
				errors += 1

	# 段数そのものは PartConfig が持つ。写す表の長さが足りないと、
	# 上の段階が全部同じ色になる（黙って起きる）。
	if Balance.part != null:
		if Balance.icon.tier_grades.size() != Balance.part.max_part_tier:
			push_error("[GameManager] E132 icon_config.gd: tier_grades の長さ %d が max_part_tier %d と違う" % [
				Balance.icon.tier_grades.size(), Balance.part.max_part_tier
			])
			errors += 1
		if Balance.icon.rune_tier_grades.size() != Balance.part.max_rune_tier:
			push_error("[GameManager] E132 icon_config.gd: rune_tier_grades の長さ %d が max_rune_tier %d と違う" % [
				Balance.icon.rune_tier_grades.size(), Balance.part.max_rune_tier
			])
			errors += 1

	if errors > 0:
		return
	print("[GameManager] icon config validated: %d 色 / 段階 %d / ルーン段階 %d, 0 errors" % [
		colors, Balance.icon.tier_grades.size(), Balance.icon.rune_tier_grades.size()
	])


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
#
# ⚠ 研究の craft_slot_bonus が乗るのはここ1箇所だけ（段階11）。
func get_max_queue_slots() -> int:
	var base: int = DEFAULT_MAX_QUEUE_SLOTS
	if Balance != null and "workshop" in Balance and Balance.workshop != null:
		var slots: int = int(Balance.workshop.max_queue_slots)
		if slots > 0:
			base = slots
		else:
			push_warning("[GameManager] get_max_queue_slots: Balance.workshop.max_queue_slots が 0 以下 — %d を使う" % DEFAULT_MAX_QUEUE_SLOTS)
	else:
		push_warning("[GameManager] get_max_queue_slots: Balance.workshop が読めない — %d を使う" % DEFAULT_MAX_QUEUE_SLOTS)
	return base + get_research_craft_slot_bonus()

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
	# ⚠ 研究の craft_speed_bonus が乗るのはここ1箇所だけ（段階11）。
	#   ⚠ 開始のときに確定する。走行中のものには効かない（下の「開始時点をコピー」と同じ考え方）。
	#   ⚠ 床の 1 はバランス数値ではなく「0秒や負を作らない」ための下限。
	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, DEFAULT_CRAFT_DURATION_SEC))
	duration_sec = maxi(1, int(round(float(duration_sec) * float(100 - get_research_craft_speed_percent()) / 100.0)))
	# outputs の先頭は表示・スキーマ互換のために持たせるだけ。
	# 実際に配るものは受け取り時に recipes.json から引き直す（EXEC_GUILD_WORKSHOP.md §2-5）。
	# ⚠ draw だけのレシピ（装飾のくじ）は出るものが決まっていないので "" になる。
	#   ⚠ output_item_id / recipe_type は誰も読んでいない欄（段階11で確認）。
	var outputs_list: Array = definition.get(RECIPE_OUTPUTS, [])
	var output_item_id: String = ""
	if not outputs_list.is_empty():
		output_item_id = str((outputs_list[0] as Dictionary).get(RECIPE_IO_ITEM_ID, ""))

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

	# ⚠ 段階18-b：倉庫に入らないなら受け取らせない（PLAN_INVENTORY.md §4-1）。
	#   ⚠ キューから消してから溢れると、作ったものが消える。⚠ 完成済みのまま残す。
	#   ⚠ 抽選（draw）は引く前に中身が分からないので、⚠ rolls の数だけマスを要求する
	#     （⚠ 多めに見積もる側へ倒す。⚠ 足りないより安全）。
	var craft_needs: int = 0
	for output_check: Variant in (definition.get(RECIPE_OUTPUTS, []) as Array):
		if output_check is Dictionary:
			craft_needs += _inventory_slots_needed_for_item(
				str((output_check as Dictionary).get(RECIPE_IO_ITEM_ID, "")),
				int((output_check as Dictionary).get(RECIPE_IO_COUNT, 0))
			)
	var draw_check: Variant = definition.get(RECIPE_DRAW, {})
	if draw_check is Dictionary and not (draw_check as Dictionary).is_empty():
		craft_needs += maxi(1, int((draw_check as Dictionary).get(CHEST_DRAW_ROLLS, 1)))
	if not can_accept_inventory(craft_needs):
		print("[GameManager] collect_craft('%s') -> false (倉庫が満杯 %d/%d・要る %d マス)" % [
			queue_id, get_inventory_slots_used(), get_inventory_slot_max(), craft_needs
		])
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

	# ⚠ 抽選は「受け取るとき」に引く（開始のときではない・決め1）。
	#   ⚠ 装飾は _grant_item() → add_to_inventory() を通る。inventory を直接書かない。
	var draw_def: Variant = definition.get(RECIPE_DRAW, {})
	if draw_def is Dictionary and not (draw_def as Dictionary).is_empty():
		var drawn: Dictionary = _roll_recipe_draw(draw_def as Dictionary)
		for drawn_id: String in drawn:
			var drawn_count: int = int(drawn[drawn_id])
			_grant_item(drawn_id, drawn_count)
			granted.append("%s x%d (draw)" % [drawn_id, drawn_count])

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
# ここで弾くもの：inputs が空、outputs と draw が両方空、items.json に無いID、count <= 0。
# MasterDataLoader が返す数値は float のため int() で包む。包み忘れると
# セーブに 1800.0 と書かれる。
#
# ⚠ outputs（固定）と draw（抽選）は「どちらかが非空」なら妥当（段階11・決め1）。
#   ⚠ 装飾のくじは outputs が空で draw だけを持つ。
func _normalized_recipe(recipe_id: String) -> Dictionary:
	var definition: Dictionary = MasterDataLoader.get_recipe(recipe_id)
	if definition.is_empty():
		return {}

	var inputs: Array = _normalized_io(definition.get(RECIPE_INPUTS, []), recipe_id, RECIPE_INPUTS)
	if inputs.is_empty():
		return {}
	# ⚠ outputs が空でも黄を出さない（draw だけのレシピが正常系のため）。
	var outputs: Array = []
	if _is_non_empty_array(definition.get(RECIPE_OUTPUTS, [])):
		outputs = _normalized_io(definition.get(RECIPE_OUTPUTS, []), recipe_id, RECIPE_OUTPUTS)
		if outputs.is_empty():
			return {}
	var draw: Dictionary = {}
	if definition.get(RECIPE_DRAW, null) is Dictionary:
		draw = _normalized_draw(definition.get(RECIPE_DRAW) as Dictionary, recipe_id)
		if draw.is_empty():
			return {}
	if outputs.is_empty() and draw.is_empty():
		push_warning("[GameManager] recipes.json: '%s' に outputs も draw も無い" % recipe_id)
		return {}

	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, 0))
	if duration_sec <= 0:
		duration_sec = _default_craft_duration_sec()

	return {
		RECIPE_ID: recipe_id,
		RECIPE_DURATION_SEC: duration_sec,
		RECIPE_INPUTS: inputs,
		RECIPE_OUTPUTS: outputs,
		RECIPE_DRAW: draw,
		RECIPE_SORT_ORDER: int(definition.get(RECIPE_SORT_ORDER, 0)),
	}


func _is_non_empty_array(value: Variant) -> bool:
	return value is Array and not (value as Array).is_empty()


# recipes.json の draw を検証して正規化する。妥当でなければ空。
#
# ⚠ 宝箱と違い、item_id が "" のハズレ枠を許さない（決め3）。
#   ⚠ 素材と時間を払って何も出ない状態を作らないため。
# ⚠ 同じことを E129 も見ている。あちらはロード時に赤で言う役、ここは走らせない役。
func _normalized_draw(draw_def: Dictionary, recipe_id: String) -> Dictionary:
	var rows: Variant = draw_def.get(CHEST_DRAW_ENTRIES, [])
	if not _is_non_empty_array(rows):
		push_warning("[GameManager] recipes.json: '%s' の draw.entries が空" % recipe_id)
		return {}
	var entries: Array = []
	var total_weight: int = 0
	for row: Variant in (rows as Array):
		if not (row is Dictionary):
			push_warning("[GameManager] recipes.json: '%s' の draw.entries に Dictionary でない要素" % recipe_id)
			return {}
		var entry: Dictionary = row
		var item_id: String = str(entry.get(CHEST_DRAW_ITEM_ID, ""))
		if _item_storage(item_id) == "":
			push_warning("[GameManager] recipes.json: '%s' の draw.entries に items.json へ無いID: '%s'" % [recipe_id, item_id])
			return {}
		var weight: int = maxi(0, int(entry.get(CHEST_DRAW_WEIGHT, 0)))
		total_weight += weight
		entries.append({
			CHEST_DRAW_ITEM_ID: item_id,
			CHEST_DRAW_WEIGHT: weight,
			CHEST_DRAW_COUNT: maxi(1, int(entry.get(CHEST_DRAW_COUNT, 1))),
		})
	if total_weight <= 0:
		push_warning("[GameManager] recipes.json: '%s' の draw.entries の weight の合計が 0 以下" % recipe_id)
		return {}
	return {
		CHEST_DRAW_ROLLS: maxi(1, int(draw_def.get(CHEST_DRAW_ROLLS, 1))),
		CHEST_DRAW_ENTRIES: entries,
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
	# 持ち物の個数。materials と同じ理由で int に戻す（宿題12・2026-08-25）。
	# ⚠ これを飛ばすと、セーブ→ロード→セーブで "count": 5.0 と書かれ続ける。
	#   読む側（get_item_count / _remove_from_inventory / use_stamina_potion）が
	#   全部 int() を通しているため表示と判定は壊れないが、セーブの形が汚れる。
	# ⚠ 直すのは count だけ。type / slot_position / properties は触らない
	#   （「対象を限定する」という上の決定事項をここでも守る）。
	if new_state.has(GameStateKeys.INVENTORY) and new_state[GameStateKeys.INVENTORY] is Dictionary:
		var inv: Dictionary = new_state[GameStateKeys.INVENTORY]
		for item_id: String in inv:
			if not (inv[item_id] is Dictionary):
				continue
			var item_entry: Dictionary = inv[item_id]
			if item_entry.has(GameStateKeys.ITEM_COUNT):
				item_entry[GameStateKeys.ITEM_COUNT] = int(item_entry[GameStateKeys.ITEM_COUNT])
	# フロア探索（段階14-a）。JSONから戻すと数値が全部 float になるため int に戻す。
	# ⚠ これを飛ばすとセーブに "layer": 3.0 / "torch_grade": 0.0 と書かれ続ける
	#   （CLAUDE.md 3番。宿題57 が STORY で同じ形を起こしている）。
	# ⚠ 直すのは数値の欄だけ。floor_id / position / kind / next は文字列なので触らない。
	if new_state.has(GameStateKeys.FLOOR_RUN) and new_state[GameStateKeys.FLOOR_RUN] is Dictionary:
		var run: Dictionary = new_state[GameStateKeys.FLOOR_RUN]
		if run.has(GameStateKeys.FLOOR_RUN_TORCH_GRADE):
			run[GameStateKeys.FLOOR_RUN_TORCH_GRADE] = int(run[GameStateKeys.FLOOR_RUN_TORCH_GRADE])
		if run.has(GameStateKeys.FLOOR_RUN_CHEST_COUNT):
			run[GameStateKeys.FLOOR_RUN_CHEST_COUNT] = int(run[GameStateKeys.FLOOR_RUN_CHEST_COUNT])
		if run.has(GameStateKeys.FLOOR_RUN_HP_CARRY) and run[GameStateKeys.FLOOR_RUN_HP_CARRY] is Dictionary:
			var hp_carry: Dictionary = run[GameStateKeys.FLOOR_RUN_HP_CARRY]
			for character_id: String in hp_carry:
				hp_carry[character_id] = int(hp_carry[character_id])
		if run.has(GameStateKeys.FLOOR_RUN_CONSUMABLES) and run[GameStateKeys.FLOOR_RUN_CONSUMABLES] is Dictionary:
			var consumables: Dictionary = run[GameStateKeys.FLOOR_RUN_CONSUMABLES]
			for item_id: String in consumables:
				consumables[item_id] = int(consumables[item_id])
		if run.has(GameStateKeys.FLOOR_RUN_NODES) and run[GameStateKeys.FLOOR_RUN_NODES] is Dictionary:
			var floor_nodes: Dictionary = run[GameStateKeys.FLOOR_RUN_NODES]
			for node_id: String in floor_nodes:
				if not (floor_nodes[node_id] is Dictionary):
					continue
				var node_entry: Dictionary = floor_nodes[node_id]
				if node_entry.has(GameStateKeys.FLOOR_NODE_LAYER):
					node_entry[GameStateKeys.FLOOR_NODE_LAYER] = int(node_entry[GameStateKeys.FLOOR_NODE_LAYER])
	# 難ダンジョンのラン（段階17-a）。フロア探索と同じ理由で int に戻す。
	# ⚠ 数値の欄は5つ（floor_index / bag_slots / currency / torch_grade / loot_count）と、
	#   辞書3本（max_hp / hp / bag）と、ノードの layer。⚠ 1つでも飛ばすと
	#   セーブに "currency": 120.0 と書かれ、鞄の枠計算にも .0 が乗る。
	# ⚠ dungeon_id / phase / position / kind は文字列なので触らない。
	# ⚠⚠ next は [{to, effect}] になった（段階19-c-1）。⚠ 中身は文字列2つなので
	#   いまは触らなくてよい。⚠⚠ 19-c-2 で通路に数値（削る量・拾う個数）を持たせたら、
	#   ⚠ ここに int() で包む枝を足すこと（⚠ 足さないと "amount": 3.0 がセーブに焼き付く）。
	if new_state.has(GameStateKeys.DUNGEON_RUN) and new_state[GameStateKeys.DUNGEON_RUN] is Dictionary:
		var dungeon_run: Dictionary = new_state[GameStateKeys.DUNGEON_RUN]
		for number_key: String in [
			GameStateKeys.DUNGEON_RUN_FLOOR_INDEX,
			GameStateKeys.DUNGEON_RUN_BAG_SLOTS,
			GameStateKeys.DUNGEON_RUN_CURRENCY,
			GameStateKeys.DUNGEON_RUN_TORCH_GRADE,
			GameStateKeys.DUNGEON_RUN_LOOT_COUNT,
		]:
			if dungeon_run.has(number_key):
				dungeon_run[number_key] = int(dungeon_run[number_key])
		for dict_key: String in [
			GameStateKeys.DUNGEON_RUN_MAX_HP,
			GameStateKeys.DUNGEON_RUN_HP,
			GameStateKeys.DUNGEON_RUN_BAG,
			# ⚠ 拾い待ち（段階20-e）。⚠ {item_id: 個数} なので鞄と同じ扱い。
			GameStateKeys.DUNGEON_RUN_PENDING_LOOT,
		]:
			if dungeon_run.has(dict_key) and dungeon_run[dict_key] is Dictionary:
				var number_map: Dictionary = dungeon_run[dict_key]
				for map_key: String in number_map:
					number_map[map_key] = int(number_map[map_key])
		if dungeon_run.has(GameStateKeys.DUNGEON_RUN_NODES) and dungeon_run[GameStateKeys.DUNGEON_RUN_NODES] is Dictionary:
			var dungeon_nodes: Dictionary = dungeon_run[GameStateKeys.DUNGEON_RUN_NODES]
			for dungeon_node_id: String in dungeon_nodes:
				if not (dungeon_nodes[dungeon_node_id] is Dictionary):
					continue
				var dungeon_node: Dictionary = dungeon_nodes[dungeon_node_id]
				if dungeon_node.has(GameStateKeys.DUNGEON_NODE_LAYER):
					dungeon_node[GameStateKeys.DUNGEON_NODE_LAYER] = int(dungeon_node[GameStateKeys.DUNGEON_NODE_LAYER])
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
	# ⚠⚠ 段階18-b：倉庫が満杯でも、⚠ 集中した時間を捨てないこと（PLAN_INVENTORY.md §4-1）。
	#   ⚠ 入らなかったぶんは「集中の端数」に戻す。⚠ 倉庫を空ければ次のポモドーロで受け取れる。
	#   ⚠ ここだけ他の5本と扱いが違う（⚠ 押し戻す先がある唯一の口）。
	#   ⚠ 「入らないから配らない」で終わらせないこと。⚠ 集中の時間はやり直せない。
	var accepted: int = 0
	if count > 0:
		accepted = add_to_inventory(
			GameStateKeys.ITEM_STAMINA_POTION, count, GameStateKeys.ITEM_TYPE_CONSUMABLE
		)
	var not_granted: int = count - accepted
	_state[GameStateKeys.POTION_FOCUS_REMAINDER] = (total_min % unit_per_min) + not_granted * unit_per_min
	if not_granted > 0:
		push_warning("[GameManager] W25 grant_stamina_potions: 倉庫が満杯で %d 個ぶんを集中の端数へ戻した（%d 分ぶん）" % [
			not_granted, not_granted * unit_per_min
		])
	return accepted

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


# ========================================================================
# フロア探索（段階14-a・PLAN_SCENARIO_MAP.md §3 / §7-1・EXEC_SCENARIO_FLOOR.md §4）
#
# ⚠ この回で作るのは器だけ。画面は 14-c、宝箱は 14-b、レリックは 14-d。
# ⚠ スタミナはここで払わない。いま払っているのは adventure_select.gd（画面側）で、
#   どこへ移すかは 14-c で決める。
# ========================================================================

# フロアに入っていない状態の器。
#
# ⚠ 9つの欄を最初から全部持たせる（PLAN_SCENARIO_MAP.md §7-1）。
#   あとから欄を足すと AGENTS.md の表と load_state() の int() 一覧を何度も触ることになる。
func _empty_floor_run() -> Dictionary:
	return {
		GameStateKeys.FLOOR_RUN_FLOOR_ID: "",
		GameStateKeys.FLOOR_RUN_NODES: {},
		GameStateKeys.FLOOR_RUN_POSITION: "",
		GameStateKeys.FLOOR_RUN_VISITED: {},
		GameStateKeys.FLOOR_RUN_TORCH_GRADE: 0,
		GameStateKeys.FLOOR_RUN_RELICS: [],
		GameStateKeys.FLOOR_RUN_HP_CARRY: {},
		GameStateKeys.FLOOR_RUN_CHEST_COUNT: 0,
		GameStateKeys.FLOOR_RUN_CONSUMABLES: {},
	}


# フロア形式のステージか。
#
# ⚠ stages.json の2形式を見分ける唯一の口（EXEC_SCENARIO_FLOOR.md §1-1）。
#   layers を持つ = フロア（floor_1..5）／waves を持つ = 検証用（stage_dbg_* 5本）。
# ⚠ ここ以外で "layers" の有無を見ないこと。
func is_floor_stage(stage_id: String) -> bool:
	var stage: Dictionary = MasterDataLoader.get_stage(stage_id)
	return stage.get(STAGE_MASTER_LAYERS, null) is Array


# フロアの層数。フロア形式でなければ 0。
func get_floor_layer_count(floor_id: String) -> int:
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	var layers: Variant = stage.get(STAGE_MASTER_LAYERS, null)
	if not (layers is Array):
		return 0
	return (layers as Array).size()


# いまフロアに入っているか。
func is_in_floor() -> bool:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	return str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")) != ""


# 進行中のフロアの読み取り専用スナップショット。
func get_floor_run() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	return run.duplicate(true)


# ノード1つ。無ければ空。
func get_floor_node(node_id: String) -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var nodes: Dictionary = run.get(GameStateKeys.FLOOR_RUN_NODES, {})
	var node: Variant = nodes.get(node_id, null)
	if not (node is Dictionary):
		return {}
	return (node as Dictionary).duplicate(true)


# いまの位置から進めるノードIDの配列。
#
# ⚠ 「進めるか」の判定はここ1本だけ。move_to_node() もこれを呼ぶ。
#   2本目を書くと、画面が押せるのに弾かれる／その逆が起きる。
func get_available_moves() -> Array:
	var result: Array = []
	if not is_in_floor():
		return result
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var position: String = str(run.get(GameStateKeys.FLOOR_RUN_POSITION, ""))
	var node: Dictionary = get_floor_node(position)
	if node.is_empty():
		return result
	for entry: Variant in (node.get(GameStateKeys.FLOOR_NODE_NEXT, []) as Array):
		result.append(str(entry))
	return result


# フロアに入る。マップを生成して入口に立つ。
#
# ⚠ 状態を触るのは最後の1回だけ（CLAUDE.md 6番）。判定を全部先に終える。
# ⚠ スタミナは見ない（14-c で決める）。
func start_floor(floor_id: String) -> bool:
	if not is_floor_stage(floor_id):
		push_warning("[GameManager] start_floor: フロア形式でない stage_id: " + floor_id)
		return false
	if is_in_floor():
		push_warning("[GameManager] start_floor: すでにフロアの中にいる（先に abandon_floor()）")
		return false

	var map: Dictionary = _build_floor_map(floor_id)
	if map.is_empty():
		push_warning("[GameManager] start_floor: マップを組めなかった: " + floor_id)
		return false

	var entry_id: String = str(map.get("entry", ""))
	var nodes: Dictionary = map.get("nodes", {})
	if entry_id == "" or not nodes.has(entry_id):
		push_warning("[GameManager] start_floor: 入口が無い: " + floor_id)
		return false

	# ここから状態を触る。
	var run: Dictionary = _empty_floor_run()
	run[GameStateKeys.FLOOR_RUN_FLOOR_ID] = floor_id
	run[GameStateKeys.FLOOR_RUN_NODES] = nodes
	run[GameStateKeys.FLOOR_RUN_POSITION] = entry_id
	run[GameStateKeys.FLOOR_RUN_VISITED] = {entry_id: true}
	_state[GameStateKeys.FLOOR_RUN] = run

	print("[GameManager] start_floor('%s') -> nodes=%d entry='%s'" % [
		floor_id, nodes.size(), entry_id
	])
	floor_run_changed.emit(floor_id)
	return true


# 隣のノードへ進む。
#
# ⚠ get_available_moves() に無いノードは弾く。弾くときに状態を触らない。
func move_to_node(node_id: String) -> bool:
	if not is_in_floor():
		push_warning("[GameManager] move_to_node: フロアに入っていない")
		return false
	if not (node_id in get_available_moves()):
		print("[GameManager] move_to_node('%s') -> false (進めない)" % node_id)
		return false

	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.FLOOR_RUN_POSITION] = node_id
	var visited: Dictionary = run.get(GameStateKeys.FLOOR_RUN_VISITED, {})
	visited[node_id] = true
	run[GameStateKeys.FLOOR_RUN_VISITED] = visited
	_state[GameStateKeys.FLOOR_RUN] = run

	print("[GameManager] move_to_node('%s') -> true (kind=%s)" % [
		node_id, str(get_floor_node(node_id).get(GameStateKeys.FLOOR_NODE_KIND, ""))
	])
	# ⚠ 宝箱は「ノード」ではなく「移動」に紐づく（PLAN_SCENARIO_MAP.md §4）。
	#   移動が確定してから引く。弾いたときには引かない。
	_roll_floor_chest(node_id)
	floor_run_changed.emit(str(run[GameStateKeys.FLOOR_RUN_FLOOR_ID]))
	return true


# 移動1回ぶんの宝箱抽選（段階14-b）。
#
# ⚠ 出るか出ないかを先に決め、出ると決まってから中身を引く。
#   いまの chests.json にはハズレ枠が1件も無いので、引いたら必ず何か出る。
# ⚠ 1フロア最低1回の保証：ボスに着いた時点で1個も出ていなければ確定で出す
#   （PLAN_SCENARIO_MAP.md §4-4）。
# ⚠ grant_chest() を呼ぶだけ。積む口は増やさない（CLAUDE.md 8番と同じ理由）。
func _roll_floor_chest(node_id: String) -> void:
	var node: Dictionary = get_floor_node(node_id)
	if node.is_empty():
		return
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var floor_id: String = str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, ""))
	var count: int = int(run.get(GameStateKeys.FLOOR_RUN_CHEST_COUNT, 0))
	var is_boss: bool = str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_BOSS

	var chance: int = int(Balance.floor.chest_chance_pct)
	var hit: bool = randi_range(1, 100) <= chance
	# ⚠ 保証。⚠ 「出なかった」ときだけ効く。出ていれば何もしない。
	if not hit and is_boss and count <= 0:
		hit = true
	if not hit:
		return

	var layer: int = int(node.get(GameStateKeys.FLOOR_NODE_LAYER, 1))
	var rarity: String = _roll_chest_rarity(layer)
	var chest_id: String = _floor_chest_id(floor_id, rarity)
	if chest_id == "":
		push_warning("[GameManager] _roll_floor_chest: chest_ids に %s が無い: %s" % [rarity, floor_id])
		return
	if not grant_chest(chest_id, GameStateKeys.CHEST_SOURCE_FLOOR):
		return

	var next_run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	next_run[GameStateKeys.FLOOR_RUN_CHEST_COUNT] = count + 1
	_state[GameStateKeys.FLOOR_RUN] = next_run
	# ⚠ 状態を書き終えてから知らせる。先に飛ばすと、購読側が古い件数を読む
	#   （宝箱の件数と同じ形＝apply_battle_rewards のコメント）。
	floor_chest_found.emit(chest_id, rarity)


# 層の深さでレアリティを1つ引く。
#
# ⚠ _roll_weighted_table() は使わない。あちらは {item_id: count} を返す口で用途が違う
#   （_roll_node_kind() と同じ理由）。
# ⚠ 配列より深い層に着いたら末尾を使う。
func _roll_chest_rarity(layer: int) -> String:
	var table: Dictionary = {
		CHEST_RARITY_COMMON: Balance.floor.chest_weight_common,
		CHEST_RARITY_RARE: Balance.floor.chest_weight_rare,
		CHEST_RARITY_EPIC: Balance.floor.chest_weight_epic,
		CHEST_RARITY_LEGENDARY: Balance.floor.chest_weight_legendary,
	}
	# ⚠ 綴り順で回す（Dictionary のキー順は不定・_roll_node_kind() と同じ）。
	var rarities: Array = [
		CHEST_RARITY_COMMON, CHEST_RARITY_EPIC, CHEST_RARITY_LEGENDARY, CHEST_RARITY_RARE,
	]
	var weights: Dictionary = {}
	var total: int = 0
	for rarity: String in rarities:
		var row: Array = table[rarity]
		if row.is_empty():
			continue
		var index: int = clampi(layer - 1, 0, row.size() - 1)
		var w: int = maxi(0, int(row[index]))
		weights[rarity] = w
		total += w
	if total <= 0:
		return CHEST_RARITY_COMMON
	var roll: int = randi() % total
	for rarity: String in rarities:
		roll -= int(weights.get(rarity, 0))
		if roll < 0:
			return rarity
	return CHEST_RARITY_COMMON


# フロアの chest_ids から1件引く。無ければ ""。
#
# ⚠ floor_id から組み立てない（STAGE_MASTER_CHEST_IDS のコメント）。
func _floor_chest_id(floor_id: String, rarity: String) -> String:
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	var ids: Variant = stage.get(STAGE_MASTER_CHEST_IDS, null)
	if not (ids is Dictionary):
		return ""
	return str((ids as Dictionary).get(rarity, ""))


# ========================================================================
# レリック（段階14-d・PLAN_SCENARIO_MAP.md §5-2）
#
# ⚠ レリック＝フロア内限定のパッシブ。器はパッシブをそのまま借りる。
#   ⚠ 定義は relics.json にあり、MasterDataLoader が _cache_skills にマージ済み。
#   ⚠ get_effective_stats() も skill_schema.gd も触らない。
# ⚠ フロアを降りると全部消える（abandon_floor）。
# ========================================================================

const RELIC_SCOPE: String = "relic_scope"
const RELIC_SCOPE_PARTY: String = "party"
const RELIC_SCOPE_SINGLE: String = "single"


# いま持っているレリック。[{relic_id, character_id}]。character_id が "" なら全員。
func get_floor_relics() -> Array:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var relics: Array = run.get(GameStateKeys.FLOOR_RUN_RELICS, [])
	return relics.duplicate(true)


# そのレリックが1人用か。
func is_single_relic(relic_id: String) -> bool:
	var relic: Dictionary = MasterDataLoader.get_relic(relic_id)
	return str(relic.get(RELIC_SCOPE, RELIC_SCOPE_PARTY)) == RELIC_SCOPE_SINGLE


# 選択肢を count 件引く（重複なし）。
#
# ⚠ すでに持っているものも候補に入れる（同じレリックは重ねてよい＝§5-2-5）。
# ⚠ 状態を触らない。引くだけ。
func roll_relic_choices(count: int) -> Array:
	var pool: Array[String] = MasterDataLoader.get_all_relic_ids()
	if pool.is_empty():
		push_warning("[GameManager] roll_relic_choices: relics.json が空")
		return []
	pool.shuffle()
	var picked: Array = []
	for relic_id: String in pool:
		if picked.size() >= count:
			break
		picked.append(relic_id)
	return picked


# レリックを1つ取る。
#
# ⚠ 判定を全部先に終えてから状態を触る（CLAUDE.md 6番）。
# ⚠ 1人用なのに character_id が空なら弾く。全体用なのに入っていたら空に直す。
func take_relic(relic_id: String, character_id: String = "") -> bool:
	if not is_in_floor():
		push_warning("[GameManager] take_relic: フロアに入っていない")
		return false
	if MasterDataLoader.get_relic(relic_id).is_empty():
		push_warning("[GameManager] take_relic: relics.json に無い: " + relic_id)
		return false
	var single: bool = is_single_relic(relic_id)
	var owner: String = character_id if single else ""
	if single:
		if owner == "":
			push_warning("[GameManager] take_relic: 1人用なのに character_id が空: " + relic_id)
			return false
		if not (owner in get_party_members()):
			push_warning("[GameManager] take_relic: 編成に居ない: " + owner)
			return false

	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	var relics: Array = run.get(GameStateKeys.FLOOR_RUN_RELICS, [])
	relics.append({
		GameStateKeys.FLOOR_RELIC_ID: relic_id,
		GameStateKeys.FLOOR_RELIC_CHARACTER_ID: owner,
	})
	run[GameStateKeys.FLOOR_RUN_RELICS] = relics
	_state[GameStateKeys.FLOOR_RUN] = run

	print("[GameManager] take_relic('%s', '%s') -> 所持 %d 件" % [relic_id, owner, relics.size()])
	floor_run_changed.emit(str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")))
	return true


# そのキャラに効くレリックのID配列（段階14-d）。
#
# ⚠ get_battle_passives() と1本にまとめない。あちらは「レベルで解放された恒久の
#   パッシブ」で、育成画面のスキル枠にも出る。レリックはフロア内限定で拠点に出ない。
#   混ぜると、スキル選択画面にフロアのレリックが並ぶ。
# ⚠ 戦闘画面は2本を足して unit.passive_ids に入れる。
func get_floor_relic_passives(character_id: String) -> Array:
	var result: Array = []
	if not is_in_floor():
		return result
	for entry: Variant in get_floor_relics():
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var owner: String = str(row.get(GameStateKeys.FLOOR_RELIC_CHARACTER_ID, ""))
		if owner != "" and owner != character_id:
			continue
		result.append(str(row.get(GameStateKeys.FLOOR_RELIC_ID, "")))
	return result


# ========================================================================
# たいまつとフロア内ショップ（段階14-e・PLAN_SCENARIO_MAP.md §5 / §3-4）
#
# ⚠ たいまつはアイテムではなくフロア内の状態（人間の決定3）。倉庫にも図鑑にも出ない。
# ⚠ 層構造なので視界は「半径」ではなく「何層先まで中身が見えるか」。
# ⚠ フロアを降りると grade 0 に戻る（_empty_floor_run）。
# ========================================================================

# 無料ガチャの抽選プール。⚠ 宝箱の器を借りる（積む口は grant_chest の1本だけ）。
const FLOOR_GACHA_CHEST_ID: String = "floor_gacha"


func get_floor_torch_grade() -> int:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	return int(run.get(GameStateKeys.FLOOR_RUN_TORCH_GRADE, 0))


# たいまつの上限グレード。⚠ 配列の長さがそのまま上限（メモ「上限グレードあり」）。
func get_floor_torch_max_grade() -> int:
	var table: Array[int] = Balance.floor.torch_reveal_layers
	return maxi(0, table.size() - 1)


# いまのたいまつで「何層先まで中身が見えるか」。
func get_floor_reveal_layers() -> int:
	var table: Array[int] = Balance.floor.torch_reveal_layers
	if table.is_empty():
		return 1
	var index: int = clampi(get_floor_torch_grade(), 0, table.size() - 1)
	return maxi(1, int(table[index]))


# 次のグレードの値段。⚠ 上限なら -1（買えない）。
func get_floor_torch_next_price() -> int:
	var next_grade: int = get_floor_torch_grade() + 1
	if next_grade > get_floor_torch_max_grade():
		return -1
	var prices: Array[int] = Balance.floor.torch_prices
	if next_grade >= prices.size():
		return -1
	return int(prices[next_grade])


# そのノードの中身が見えるか（段階14-e）。
#
# ⚠ ボスは常に見える（メモ「ボスの位置だけは最初から常に見えている」）。
# ⚠ 踏破済みも見える（一度見たものは隠さない）。
# ⚠ ここが視界の判定の1本。画面側で層を数え直さないこと。
func is_floor_node_revealed(node_id: String) -> bool:
	if not is_in_floor():
		return false
	var node: Dictionary = get_floor_node(node_id)
	if node.is_empty():
		return false
	if str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_BOSS:
		return true
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var visited: Dictionary = run.get(GameStateKeys.FLOOR_RUN_VISITED, {})
	if visited.has(node_id):
		return true
	var here: Dictionary = get_floor_node(str(run.get(GameStateKeys.FLOOR_RUN_POSITION, "")))
	var here_layer: int = int(here.get(GameStateKeys.FLOOR_NODE_LAYER, 1))
	var node_layer: int = int(node.get(GameStateKeys.FLOOR_NODE_LAYER, 1))
	return node_layer - here_layer <= get_floor_reveal_layers()


# たいまつを1段階上げる。
#
# ⚠ 判定を全部先に終えてから状態を触る（CLAUDE.md 6番）。
# ⚠ ゴールドは恒久通貨。フロアを降りても戻らない（メモ「価格は高め」）。
func buy_floor_torch() -> bool:
	if not is_in_floor():
		return false
	var price: int = get_floor_torch_next_price()
	if price < 0:
		print("[GameManager] buy_floor_torch() -> false (上限グレード)")
		return false
	if int(_state.get(GameStateKeys.GOLD, 0)) < price:
		print("[GameManager] buy_floor_torch() -> false (ゴールド不足 %d)" % price)
		return false

	add_gold(-price)
	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.FLOOR_RUN_TORCH_GRADE] = get_floor_torch_grade() + 1
	_state[GameStateKeys.FLOOR_RUN] = run
	print("[GameManager] buy_floor_torch() -> grade=%d（%d 層先まで見える）" % [
		int(run[GameStateKeys.FLOOR_RUN_TORCH_GRADE]), get_floor_reveal_layers()
	])
	floor_run_changed.emit(str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")))
	return true


# フロア内ショップの回復を買う。⚠ 買うとその場で効く（持ち物にしない）。
#
# ⚠ 持ち越しHPを直接持ち上げる。欄が無いキャラは満タンなので触らない。
func buy_floor_heal() -> bool:
	if not is_in_floor():
		return false
	var price: int = int(Balance.floor.shop_heal_price)
	if int(_state.get(GameStateKeys.GOLD, 0)) < price:
		print("[GameManager] buy_floor_heal() -> false (ゴールド不足 %d)" % price)
		return false
	var pct: int = int(Balance.floor.shop_heal_pct)
	var carry: Dictionary = get_floor_hp_carry()
	if carry.is_empty():
		print("[GameManager] buy_floor_heal() -> false (全員すでに満タン)")
		return false

	add_gold(-price)
	var healed: Dictionary = {}
	for character_id: Variant in carry:
		var cid: String = str(character_id)
		var max_hp: int = int(get_effective_stats(cid).get(GameStateKeys.STAT_HP, 0))
		var gain: int = int(float(max_hp) * float(pct) / 100.0)
		var next_hp: int = mini(max_hp, int(carry[cid]) + gain)
		# ⚠ 満タンになったキャラは欄ごと落とす。「欄が無い＝満タン」が約束なので、
		#   残すと次のフロアの計算で余計な分岐が要る。
		if next_hp < max_hp:
			healed[cid] = next_hp
	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.FLOOR_RUN_HP_CARRY] = healed
	_state[GameStateKeys.FLOOR_RUN] = run
	print("[GameManager] buy_floor_heal(%d%%) -> %s" % [pct, str(healed)])
	floor_run_changed.emit(str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")))
	return true


# ショップに入ったときの無料ガチャ（段階14-e）。
#
# ⚠ 恒久資産として持ち帰れる（メモ「宝箱とは別枠、恒久資産」）。
# ⚠ 積む口は grant_chest の1本だけ。2本目を書かない。
# ⚠ chest_count には数えない（宝箱の最低1回保証とは別物）。
func grant_floor_gacha() -> bool:
	if not is_in_floor():
		return false
	return grant_chest(FLOOR_GACHA_CHEST_ID, GameStateKeys.CHEST_SOURCE_FLOOR)


# ========================================================================
# 周回の自動処理（段階14-f・PLAN_SCENARIO_MAP.md §6）
#
# ⚠ 宿題49（周回ステージ・スキップ周回）がここで閉じる。
# ⚠ 「歩かずに結果だけ作る」のではなく、内部で本当に歩かせる。
#   ⚠ 宝箱の抽選も最低1回の保証も move_to_node() に紐づいているので、
#     別経路を書くと「周回だけ宝箱が出ない／出すぎる」が無音で起きる（14-b の申し送り2）。
# ⚠ 発生するもの … 戦闘結果・宝箱・ショップの無料ガチャ
# ⚠ 発生しないもの … レリック・休憩・消耗品・たいまつ（フロア内限定のものは全部）
# ========================================================================

# 周回の結果。呼び出し側が読む欄。
const AUTO_RUN_CHESTS: String = "chests"
const AUTO_RUN_GACHA: String = "gacha"
const AUTO_RUN_STEPS: String = "steps"
const AUTO_RUN_REWARDS: String = "rewards"


# そのフロアを周回できるか。できないなら理由を返す（できるなら ""）。
#
# ⚠ 判定はここ1本。run_floor_auto() も画面もこれを呼ぶ（CLAUDE.md 6番）。
func get_floor_auto_reject_reason(floor_id: String) -> String:
	if not is_floor_stage(floor_id):
		return "not_floor"
	# ⚠ 踏破済みだけ。初回はマップを歩く（メモ「初回は実際に歩いて探索する」）。
	if not is_stage_cleared(floor_id):
		return "not_cleared"
	if is_in_floor():
		return "in_floor"
	var cost: int = int(Balance.adventure.stamina_cost_per_stage)
	var stamina: Dictionary = _state.get(GameStateKeys.STAMINA, {})
	if int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)) < cost:
		return "stamina"
	return ""


# 1周ぶんを内部で走らせて、結果だけ返す。
#
# ⚠ 戦闘は勝った前提（踏破済みのフロアなので）。負ける枝を作らない。
# ⚠ スタミナと固定報酬は、初回と同じ「ボスを倒したときに1回」の形に揃える。
func run_floor_auto(floor_id: String) -> Dictionary:
	var empty: Dictionary = {
		AUTO_RUN_CHESTS: 0, AUTO_RUN_GACHA: 0, AUTO_RUN_STEPS: 0, AUTO_RUN_REWARDS: {},
	}
	var reason: String = get_floor_auto_reject_reason(floor_id)
	if reason != "":
		print("[GameManager] run_floor_auto('%s') -> false (%s)" % [floor_id, reason])
		return empty
	if not start_floor(floor_id):
		return empty

	var gacha: int = 0
	var steps: int = 0
	# ⚠ 道中の戦闘ぶん（宿題63）。⚠ 初回と同じ get_floor_node_rewards() を通す。
	#   ⚠ 「周回では出ない」にしないこと。出ないとゴールドが初回の半分になり、
	#     周回するほど損になる（周回は瞬時にスキップする前提＝§6 と噛み合わない）。
	var node_gold: int = 0
	var node_battles: int = 0
	while true:
		var moves: Array = get_available_moves()
		if moves.is_empty():
			break
		# ⚠ ルートはランダムに選ぶ。決め打ちにすると、周回のたびに同じ層の
		#   同じノードだけを踏み、宝箱のレアリティが偏る。
		var next_id: String = str(moves[randi() % moves.size()])
		if not move_to_node(next_id):
			break
		steps += 1
		# ⚠ ショップは無料ガチャだけ自動処理（持ち帰れる資産なので）。
		#   ⚠ 購入もたいまつも発生しない（フロア内限定＝§3-4）。
		if str(get_floor_node(next_id).get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_SHOP:
			if grant_floor_gacha():
				gacha += 1
		# ⚠ 戦闘ノードかどうかは get_floor_node_rewards() が決める（空なら戦闘ではない）。
		#   ⚠ ここで kind をもう一度見ないこと。判定が2箇所になる。
		var node_reward: Dictionary = get_floor_node_rewards(floor_id, next_id)
		if not node_reward.is_empty():
			node_battles += 1
			node_gold += int(node_reward.get(GameStateKeys.REWARD_GOLD, 0))
		if steps > 50:
			push_warning("[GameManager] run_floor_auto: 50手で終わらない: " + floor_id)
			break

	var chests: int = get_floor_chest_count()
	var rewards: Dictionary = (MasterDataLoader.get_stage(floor_id).get(GameStateKeys.BATTLE_REWARDS, {}) as Dictionary).duplicate(true)
	# ⚠ ボスのぶんに道中のぶんを足して1回で配る（宿題63）。
	#   ⚠ apply_battle_rewards() を2回呼ばない。⚠ battle_finished が2本飛び、
	#     結果画面と購読側が二重に動く。
	# ⚠ 足すのは gold だけ。⚠ node_rewards に materials を入れない決定（定数のコメント）。
	if node_gold > 0:
		rewards[GameStateKeys.REWARD_GOLD] = int(rewards.get(GameStateKeys.REWARD_GOLD, 0)) + node_gold
	print("[GameManager] run_floor_auto('%s') 道中の戦闘 %d 回 -> +%d G" % [floor_id, node_battles, node_gold])

	# ⚠ 初回と同じ順で配る。スタミナ → 報酬 → 降りる。
	var cost: int = int(Balance.adventure.stamina_cost_per_stage)
	if cost > 0 and not spend_stamina(cost):
		push_warning("[GameManager] run_floor_auto: スタミナ消費に失敗した（判定は通っている）")
	apply_battle_rewards({
		GameStateKeys.BATTLE_VICTORY: true,
		GameStateKeys.BATTLE_WAVES_CLEARED: steps,
		GameStateKeys.BATTLE_REWARDS: rewards,
	})
	abandon_floor()

	print("[GameManager] run_floor_auto('%s') -> %d手 / 宝箱 %d / ガチャ %d" % [
		floor_id, steps, chests, gacha
	])
	return {
		AUTO_RUN_CHESTS: chests,
		AUTO_RUN_GACHA: gacha,
		AUTO_RUN_STEPS: steps,
		AUTO_RUN_REWARDS: rewards,
	}


# このフロアでいままでに出た宝箱の数。
func get_floor_chest_count() -> int:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	return int(run.get(GameStateKeys.FLOOR_RUN_CHEST_COUNT, 0))


# そのノードがボスか（段階14-c）。
#
# ⚠ ボス判定の口はここ1本だけ。戦闘画面が kind の綴りを自分で比べないこと。
func is_floor_boss_node(node_id: String) -> bool:
	var node: Dictionary = get_floor_node(node_id)
	if node.is_empty():
		return false
	return str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) == GameStateKeys.FLOOR_NODE_KIND_BOSS


# フロア内で持ち越しているHP。{character_id: int}。
#
# ⚠ 欄が無いキャラは「満タン」の意味。0 を書かないこと
#   （0 だと復帰できず、全滅の判定と噛み合わない）。
func get_floor_hp_carry() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var carry: Dictionary = run.get(GameStateKeys.FLOOR_RUN_HP_CARRY, {})
	return carry.duplicate(true)


# 戦闘のあとに残HPを書き込む（段階14-c）。
#
# ⚠ 倒れた味方は 1 で残す。次の戦闘に出られなくなるのを防ぐ（EXEC §1-4）。
# ⚠ フロアに入っていなければ何もしない（検証用ステージがここを通っても無害）。
func set_floor_hp_carry(hp_by_character: Dictionary) -> void:
	if not is_in_floor():
		return
	var carry: Dictionary = {}
	for character_id: Variant in hp_by_character:
		carry[str(character_id)] = maxi(1, int(hp_by_character[character_id]))
	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.FLOOR_RUN_HP_CARRY] = carry
	_state[GameStateKeys.FLOOR_RUN] = run
	print("[GameManager] set_floor_hp_carry(%s)" % str(carry))


# 休憩ノード（段階14-c）。持ち越しHPを捨てる＝全員が満タンで次の戦闘に入る。
#
# ⚠ この関数は Balance を1行も読んでいない。⚠ 以前ここのコメントは
#   Balance.adventure.floor_rest_full_heal を指していたが、⚠ あの欄は
#   誰も読まない死に欄だった（2026-08-28に発見＝ズレ46）。⚠ 欄ごと消した。
# ⚠ 割合回復にするなら FloorConfig に rest_heal_pct を足し（shop_heal_pct と同じ形）、
#   ここで hp_carry を書き換える＝宿題64。⚠ 実装せずに欄だけ足さないこと。
func rest_at_node() -> bool:
	if not is_in_floor():
		return false
	var run: Dictionary = (_state[GameStateKeys.FLOOR_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.FLOOR_RUN_HP_CARRY] = {}
	_state[GameStateKeys.FLOOR_RUN] = run
	print("[GameManager] rest_at_node() -> hp_carry を空にした（全員満タン）")
	floor_run_changed.emit(str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")))
	return true


# ノードで戦う1ウェーブぶんの敵（段階14-c）。
#
# ⚠ ボスなら stages.json の boss、それ以外は battle_pool から1本引く。
# ⚠ 戦闘画面が battle_pool を直接読まないこと（引き方が2箇所になる）。
func get_floor_node_wave(node_id: String) -> Dictionary:
	if not is_in_floor():
		return {}
	var run: Dictionary = _state.get(GameStateKeys.FLOOR_RUN, {})
	var floor_id: String = str(run.get(GameStateKeys.FLOOR_RUN_FLOOR_ID, ""))
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	if is_floor_boss_node(node_id):
		var boss: Variant = stage.get(STAGE_MASTER_BOSS, null)
		if boss is Dictionary:
			return (boss as Dictionary).duplicate(true)
		push_warning("[GameManager] get_floor_node_wave: boss が無い: " + floor_id)
		return {}
	var pool: Variant = stage.get(STAGE_MASTER_BATTLE_POOL, null)
	if not (pool is Array) or (pool as Array).is_empty():
		push_warning("[GameManager] get_floor_node_wave: battle_pool が無い: " + floor_id)
		return {}
	var list: Array = pool as Array
	return (list[randi() % list.size()] as Dictionary).duplicate(true)


# フロアを降りる。進行中のものを丸ごと捨てる。
#
# ⚠ フロア内限定のもの（たいまつ・レリック・消耗品・持ち越しHP）はここで一緒に消える。
#   これが「フロアごとにリセット」の実体（PLAN_SCENARIO_MAP.md §5）。
func abandon_floor() -> void:
	if not is_in_floor():
		return
	var previous: String = str(
		(_state[GameStateKeys.FLOOR_RUN] as Dictionary).get(GameStateKeys.FLOOR_RUN_FLOOR_ID, "")
	)
	_state[GameStateKeys.FLOOR_RUN] = _empty_floor_run()
	print("[GameManager] abandon_floor() <- '%s'" % previous)
	floor_run_changed.emit("")


# 層構造のマップを組む（PLAN_SCENARIO_MAP.md §3-2）。
#
# 戻り値: {"entry": node_id, "boss": node_id, "nodes": {node_id: {layer, kind, next, cleared}}}
#
# ⚠ ノードを作るのはここ1本だけ。2本目を書かないこと。
# ⚠ 接続は決め打ち（乱数を使わない）。乱数が入るのはノードの種類だけ。
#   接続まで乱数にすると「ボスに着かないルート」が低確率で生まれ、再現できない事故になる。
# ⚠ 最終層の全ノードがボスへ入る＝どのルートを選んでも必ずボスに着く
#   （§3-2 で「最終段だけ合流」を選んだ理由）。
func _build_floor_map(floor_id: String) -> Dictionary:
	var stage: Dictionary = MasterDataLoader.get_stage(floor_id)
	var raw_layers: Variant = stage.get(STAGE_MASTER_LAYERS, null)
	if not (raw_layers is Array) or (raw_layers as Array).is_empty():
		return {}
	var layers: Array = raw_layers as Array

	# 1. 層ごとにノードを作る。種類だけ抽選する。
	var ids_by_layer: Array = []
	var nodes: Dictionary = {}
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
		var count: int = int(layer.get(LAYER_NODE_COUNT, 0))
		# ⚠ 重みは stages.json ではなく FloorConfig（段階14-i）。
		#   ⚠ 全フロア共通の1枚。⚠ フロアごとに変えたくなったら、
		#     stages.json 側に「この層だけ上書き」を足すのではなく、
		#     FloorConfig を配列の配列にすること（置き場を2つにしない）。
		var weights: Dictionary = get_floor_layer_weights(layer_index + 1)
		var row: Array = []
		for i: int in range(count):
			var node_id: String = "n_%d_%d" % [layer_index + 1, i]
			nodes[node_id] = {
				GameStateKeys.FLOOR_NODE_LAYER: layer_index + 1,
				GameStateKeys.FLOOR_NODE_KIND: _roll_node_kind(weights),
				GameStateKeys.FLOOR_NODE_NEXT: [],
				GameStateKeys.FLOOR_NODE_CLEARED: false,
			}
			row.append(node_id)
		if row.is_empty():
			push_warning("[GameManager] _build_floor_map: 層 %d のノードが0件: %s" % [
				layer_index + 1, floor_id
			])
			return {}
		ids_by_layer.append(row)

	# 2. ボス。最終層の1つ先に置く。
	var boss_id: String = "boss"
	nodes[boss_id] = {
		GameStateKeys.FLOOR_NODE_LAYER: layers.size() + 1,
		GameStateKeys.FLOOR_NODE_KIND: GameStateKeys.FLOOR_NODE_KIND_BOSS,
		GameStateKeys.FLOOR_NODE_NEXT: [],
		GameStateKeys.FLOOR_NODE_CLEARED: false,
	}

	# 3. 層と層をつなぐ。
	for layer_index: int in range(ids_by_layer.size() - 1):
		_connect_layers(nodes, ids_by_layer[layer_index], ids_by_layer[layer_index + 1])
	# 最終層 -> ボス（合流）。
	for node_id: Variant in (ids_by_layer[ids_by_layer.size() - 1] as Array):
		(nodes[str(node_id)] as Dictionary)[GameStateKeys.FLOOR_NODE_NEXT] = [boss_id]

	return {
		"entry": str((ids_by_layer[0] as Array)[0]),
		"boss": boss_id,
		"nodes": nodes,
	}


# 隣り合う2つの層をつなぐ。
#
# ⚠ 上の層の各ノードが、下の層の「持ち分の窓」＋1つ先へつながる。
#   これで (a) どのノードにも進める先が1つ以上ある
#        (b) 下の層のどのノードにも入ってくる線が1本以上ある
#   の両方が、層のノード数の組み合わせによらず成り立つ。
# ⚠ (b) が崩れると「絶対に通れないノード」が生まれる。scenario=floor の
#   全ルート総当たりがそれを見張る。
func _connect_layers(nodes: Dictionary, upper: Array, lower: Array) -> void:
	var n: int = upper.size()
	var m: int = lower.size()
	for j: int in range(n):
		var lo: int = int(floor(float(j) * float(m) / float(n)))
		var hi: int = int(ceil(float(j + 1) * float(m) / float(n))) - 1
		hi = maxi(hi, lo)
		# 隣へも1つ伸ばして分岐を作る（2択になる）。
		hi = mini(hi + 1, m - 1)
		var next_ids: Array = []
		for k: int in range(lo, hi + 1):
			next_ids.append(str(lower[k]))
		(nodes[str(upper[j])] as Dictionary)[GameStateKeys.FLOOR_NODE_NEXT] = next_ids


# 道中のノード1つぶんの報酬を返す（段階14-i・宿題63）。無ければ空。
#
# ⚠ 判定はここ1本。⚠ battle_controller も run_floor_auto も debug_boot もこれを呼ぶ
#   （CLAUDE.md 6番「同じ形の判定が散っていたら1本に寄せる」）。
# ⚠ 出るのは戦闘ノードだけ。⚠ ボスは stages.json の rewards（別の欄）。
#   ⚠ 休憩・ショップ・レリックは0。⚠ 踏んでも金が入るなら「戦闘を踏む理由」にならない。
# ⚠ スタミナもクリア記録も画面解放もここでは動かさない。⚠ 動かすと1マス目で
#   画面が全部開き、1周で25スタミナ払うことになる（battle_controller.gd の
#   14-c のコメントが警告している事故）。
func get_floor_node_rewards(floor_id: String, node_id: String) -> Dictionary:
	if floor_id == "" or node_id == "":
		return {}
	var node: Dictionary = get_floor_node(node_id)
	if node.is_empty():
		return {}
	if str(node.get(GameStateKeys.FLOOR_NODE_KIND, "")) != GameStateKeys.FLOOR_NODE_KIND_BATTLE:
		return {}
	var raw: Variant = MasterDataLoader.get_stage(floor_id).get(STAGE_MASTER_NODE_REWARDS, null)
	if not (raw is Dictionary):
		return {}
	return (raw as Dictionary).duplicate(true)


# 層 N のノード出現比を {kind: weight} で返す（段階14-i）。
#
# ⚠ 置き場は FloorConfig の1本だけ。⚠ stages.json の layers は node_count しか持たない。
# ⚠ 配列より深い層を聞かれたら末尾を使う（_roll_chest_rarity と同じ clampi）。
# ⚠ 重みが全部 0 の層は _roll_node_kind() が battle を返す（あちらの保険）。
func get_floor_layer_weights(layer: int) -> Dictionary:
	var table: Dictionary = {
		GameStateKeys.FLOOR_NODE_KIND_BATTLE: Balance.floor.layer_weight_battle,
		GameStateKeys.FLOOR_NODE_KIND_RELIC: Balance.floor.layer_weight_relic,
		GameStateKeys.FLOOR_NODE_KIND_REST: Balance.floor.layer_weight_rest,
		GameStateKeys.FLOOR_NODE_KIND_SHOP: Balance.floor.layer_weight_shop,
	}
	var out: Dictionary = {}
	for kind: String in table:
		var row: Array = table[kind]
		if row.is_empty():
			continue
		var w: int = maxi(0, int(row[clampi(layer - 1, 0, row.size() - 1)]))
		# ⚠ 0 の枠は入れない。⚠ _roll_node_kind() は綴り順に減算するだけなので
		#   0 を入れても結果は変わらないが、ログとデバッグ表示が読みにくくなる。
		if w > 0:
			out[kind] = w
	return out


# ノードの種類を1つ引く。{kind: weight} の重み付き抽選。
#
# ⚠ _roll_weighted_table() は使わない。あちらは {item_id: count} を返す
#   「何個もらえるか」の口で、用途が違う。無理に共通化すると
#   片方の都合でもう片方が壊れる（NEXT_STEPS §2-6）。
func _roll_node_kind(weights: Dictionary) -> String:
	var total: int = 0
	for kind: Variant in weights:
		total += maxi(0, int(weights[kind]))
	if total <= 0:
		return GameStateKeys.FLOOR_NODE_KIND_BATTLE
	var roll: int = randi() % total
	# ⚠ キーの並び順に依存しないよう綴り順で回す（Dictionary のキー順は不定）。
	var kinds: Array = weights.keys()
	kinds.sort()
	for kind: Variant in kinds:
		roll -= maxi(0, int(weights[kind]))
		if roll < 0:
			return str(kind)
	return GameStateKeys.FLOOR_NODE_KIND_BATTLE


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


# ========================================================================
# 難ダンジョン（段階17-a・PLAN_HARD_DUNGEON.md §4 / §5 / §7）
#
# ⚠⚠ シナリオ（floor_1..5）の器を1つも借りていない。
#   ⚠ FLOOR_RUN も _build_floor_map() も get_available_moves() も
#     _roll_floor_chest() も使わない（台帳 §7）。形が同じでも仕様が別で、
#     借りると1本の関数に2つの仕様が同居する。
#
# ⚠ この回で作るのは器だけ。⚠ 画面は 17-d、戦闘との接続は 17-b、
#   ポーション・蘇生・休憩の中身は 17-c、ショップとたいまつは 17-e。
# ⚠ 数値は全部「仮置き」（決定14）。遊んでから測る（17-g）。
#
# 1ランの形（決定15・§5-0）：
#   ラン開始（鞄は空）→ 層1 → … → 層N → ボス
#     → ボスを倒す（phase=boss_cleared）→ ショップを見せる（17-e）
#     → 「続行する」＝次のフロアへ（ランの MAX HP と鞄はそのまま持ち越す）
#       「撤退する」＝鞄の中身を持ち帰ってラン終了
# ⚠ 層の途中に降り口を足さないこと（決定15）。足すと「潜るか降りるか」の
#   決断が消え、一貫原則の柱が1本抜ける。
#   ⚠ 詰んだ人の逃げ道は abandon_dungeon_run()（＝全ロスト。タダではない）。
# ========================================================================

# いま在るダンジョンは1本だけ。⚠ 入口（未決7）は 17-g。
# ⚠ 名指しで要るのはここだけ。⚠ ダンジョンを増やしたら dungeon.json に足す
#   （この定数を増やさない。一覧は MasterDataLoader.get_all_dungeon_ids()）。
const DUNGEON_DEFAULT_ID: String = "dungeon_hard"

# dungeon.json のキー。⚠ stages.json の STAGE_MASTER_* とは別（ファイルが別）。
const DUNGEON_MASTER_LAYERS: String = "layers"
const DUNGEON_MASTER_BATTLE_POOL: String = "battle_pool"
const DUNGEON_MASTER_BOSS: String = "boss"
const DUNGEON_MASTER_LOOT: String = "loot"
const DUNGEON_MASTER_CURRENCY: String = "currency"
# 通路の表（段階19-c-2・決定24）。⚠ 何が出るかは JSON、⚠ どれくらい出るかは Config。
const DUNGEON_MASTER_EDGES: String = "edges"
const DUNGEON_EDGES_EFFECTS: String = "effects"     # [{effect, weight}]
const DUNGEON_EDGES_RESOURCE: String = "resource"   # [{kind, weight, item_id, count}]
const DUNGEON_EDGES_EFFECT: String = "effect"
const DUNGEON_EDGES_WEIGHT: String = "weight"
const DUNGEON_EDGES_KIND: String = "kind"
const DUNGEON_EDGES_KIND_CURRENCY: String = "currency"
const DUNGEON_EDGES_KIND_ITEM: String = "item"
# 通路の宝箱の戦利品表。⚠ loot の中に置く（⚠ ノードの chest とは別の行）。
#   ⚠ マスの宝箱より薄い（rolls 1）。⚠ 同じ表にしないこと＝マスの宝箱の意味が消える。
const DUNGEON_LOOT_EDGE_CHEST: String = "edge_chest"
# layers[] の中身。⚠ 綴りは stages.json と同じだが、読む先が別のファイルなので
#   定数も別に持つ（片方の綴りを変えたときにもう片方が黙って壊れないため）。
const DUNGEON_LAYER_NODE_COUNT: String = "node_count"


# ランに入っていない状態の器。
#
# ⚠ 14 欄を最初から全部持たせる（14-a の教訓）。17-b〜17-e が埋める欄も空で置く。
#   ⚠ あとから欄を足すと _empty_state_template()・load_state() の int() 一覧・
#     AGENTS.md の表を何度も触ることになる。
func _empty_dungeon_run() -> Dictionary:
	return {
		GameStateKeys.DUNGEON_RUN_DUNGEON_ID: "",
		GameStateKeys.DUNGEON_RUN_FLOOR_INDEX: 0,
		GameStateKeys.DUNGEON_RUN_PHASE: "",
		GameStateKeys.DUNGEON_RUN_NODES: {},
		GameStateKeys.DUNGEON_RUN_POSITION: "",
		GameStateKeys.DUNGEON_RUN_VISITED: {},
		GameStateKeys.DUNGEON_RUN_MAX_HP: {},
		GameStateKeys.DUNGEON_RUN_HP: {},
		GameStateKeys.DUNGEON_RUN_BAG: {},
		GameStateKeys.DUNGEON_RUN_BAG_SLOTS: 0,
		GameStateKeys.DUNGEON_RUN_CURRENCY: 0,
		GameStateKeys.DUNGEON_RUN_TORCH_GRADE: 0,
		# ⚠ 通路の宝箱の持ち越し（段階19-c-2）。⚠ "" なら持ち越していない。
		GameStateKeys.DUNGEON_RUN_CORRIDOR_CHEST: "",
		# ⚠ 拾い待ちの品（段階20-e）。⚠ 鞄の枠を1つも使わない。
		GameStateKeys.DUNGEON_RUN_PENDING_LOOT: {},
		GameStateKeys.DUNGEON_RUN_RELICS: [],
		GameStateKeys.DUNGEON_RUN_LOOT_COUNT: 0,
	}


var _dungeon_config_warned: bool = false


# ⚠ Balance.dungeon を読む唯一の口。⚠ null のときに何度も鳴かせない
#   （_equipment() / _part() と同じ形）。
func _dungeon() -> DungeonConfig:
	if Balance == null or Balance.dungeon == null:
		if not _dungeon_config_warned:
			_dungeon_config_warned = true
			push_error("[GameManager] E133 balance.tscn: Balance.dungeon が null。dungeon_config.tres を Balance ノードの dungeon 欄に割り当てること")
		return null
	return Balance.dungeon


# --- 読み取り ---------------------------------------------------------

# いまランの中にいるか。
func is_in_dungeon() -> bool:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return str(run.get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")) != ""


# 進行中のランの読み取り専用スナップショット。
func get_dungeon_run() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return run.duplicate(true)


# ノード1つ。無ければ空。
func get_dungeon_node(node_id: String) -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	var node: Variant = nodes.get(node_id, null)
	if not (node is Dictionary):
		return {}
	return (node as Dictionary).duplicate(true)


# いまの位置から進めるノードIDの配列。
#
# ⚠ 「進めるか」の判定はここ1本だけ。move_in_dungeon() もこれを呼ぶ。
# ⚠ get_available_moves()（シナリオ側）を借りない。⚠ こちらは phase も見る
#   （ボスを倒したあとは、続行か撤退を選ぶまでどこへも進めない）。
func get_dungeon_moves() -> Array:
	var result: Array = []
	if not is_in_dungeon():
		return result
	if get_dungeon_phase() != GameStateKeys.DUNGEON_PHASE_MAP:
		return result
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var node: Dictionary = get_dungeon_node(str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, "")))
	if node.is_empty():
		return result
	# ⚠ 通路は {to, effect}（段階19-c-1）。⚠ str(entry) で読まないこと。
	#   ⚠ 読むと Dictionary の文字列表現が返り、⚠ 「どこへも進めない」形で静かに壊れる。
	for entry: Variant in get_dungeon_edges(str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, ""))):
		result.append(str((entry as Dictionary).get(GameStateKeys.DUNGEON_EDGE_TO, "")))
	return result


# そのノードから出ている通路（[{to, effect}]）。段階19-c-1。
#
# ⚠⚠ 通路を読む口はここ1本だけ。⚠ 画面や検証で `next` を直接読まないこと。
# ⚠ get_dungeon_moves() との違い：⚠ あちらは「行き先のIDだけ」を返す（画面用）。
#   ⚠ こちらは効果まで返す。⚠ 「進めるか」の判定は get_dungeon_moves() のまま1本。
# ⚠ ここは phase を見ない（⚠ マップを描くのにボスの先でも要る）。
func get_dungeon_edges(node_id: String) -> Array:
	var result: Array = []
	var node: Dictionary = get_dungeon_node(node_id)
	if node.is_empty():
		return result
	for entry: Variant in (node.get(GameStateKeys.DUNGEON_NODE_NEXT, []) as Array):
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


# from から to へ向かう通路1本。⚠ 無ければ空。段階19-c-1。
#
# ⚠ 効果を効かせるとき（19-c-2）に move_in_dungeon() が引く。
func get_dungeon_edge(from_node_id: String, to_node_id: String) -> Dictionary:
	for entry: Variant in get_dungeon_edges(from_node_id):
		var edge: Dictionary = entry
		if str(edge.get(GameStateKeys.DUNGEON_EDGE_TO, "")) == to_node_id:
			return edge
	return {}


# 何枚目のフロアか（1 から）。ランに入っていなければ 0。
func get_dungeon_floor_index() -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return int(run.get(GameStateKeys.DUNGEON_RUN_FLOOR_INDEX, 0))


# いま「マップを歩いている」のか「ボスを倒した先に居る」のか。
func get_dungeon_phase() -> String:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return str(run.get(GameStateKeys.DUNGEON_RUN_PHASE, ""))


# 撤退できるか（決定15）。⚠ ボスを倒した直後だけ true。
#
# ⚠ 判定の口はここ1本。⚠ 画面側で phase の綴りを比べないこと。
func can_retreat_from_dungeon() -> bool:
	return is_in_dungeon() and get_dungeon_phase() == GameStateKeys.DUNGEON_PHASE_BOSS_CLEARED


# もう1階潜れるか（段階20-a・人間の決定26「1ラン ＝ 3階 × 25層」）。
#
# ⚠ 「撤退できるか」とは別物。⚠ 最後の階を突破したら、⚠ 撤退はできるが続行はできない。
# ⚠ 画面で階の数を数えないこと。⚠ 判定はここ1本。
func can_descend_dungeon_floor() -> bool:
	if not can_retreat_from_dungeon():
		return false
	var config: DungeonConfig = _dungeon()
	if config == null:
		return false
	return get_dungeon_floor_index() < maxi(1, int(config.max_floors))


# 1ランで潜れる階の数（＝フロアの枚数）。⚠ 画面が「3階のうち何階目か」を出すのに使う。
func get_dungeon_max_floors() -> int:
	var config: DungeonConfig = _dungeon()
	return 1 if config == null else maxi(1, int(config.max_floors))


# 鞄の中身。{item_id: 個数}。
func get_dungeon_bag() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var bag: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_BAG, {})
	return bag.duplicate(true)


# 鞄の枠数。
func get_dungeon_bag_slots() -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return int(run.get(GameStateKeys.DUNGEON_RUN_BAG_SLOTS, 0))


# 鞄が埋まっている数。
#
# ⚠ 個数制限方式なので「種類」ではなく「個数」の合計（コンセプト文書「一律1枠」）。
#   ⚠ 重み付けを入れないこと（タルコフの煩雑さを持ち込まないという決定）。
func get_dungeon_bag_used() -> int:
	var used: int = 0
	var bag: Dictionary = get_dungeon_bag()
	for item_id: Variant in bag:
		used += int(bag[item_id])
	return used


# ランの一時通貨（決定16。1種類）。
func get_dungeon_currency() -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return int(run.get(GameStateKeys.DUNGEON_RUN_CURRENCY, 0))


# ランの MAX HP。{character_id: int}（決定8・§4-4）。
#
# ⚠⚠ 素の MAX HP（get_effective_stats().hp）とは別のもの。
#   ⚠ ダンジョンが書き換えてよいのはこちらだけ。素のほうを書き換えると
#     セーブに削れた値が焼き付いて二度と戻らない。
func get_dungeon_max_hp() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var max_hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_MAX_HP, {})
	return max_hp.duplicate(true)


# ランのいまの HP。{character_id: int}。
func get_dungeon_hp() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_HP, {})
	return hp.duplicate(true)


# --- ランの開始と進行 -------------------------------------------------

# ランに入る。⚠ 鞄は空・一時通貨0・ランの MAX HP は素の MAX HP から写す。
#
# ⚠ 状態を触るのは最後の1回だけ（CLAUDE.md 6番）。判定を全部先に終える。
# ⚠ 入るコストは取らない（決定11。テストプレイ優先。⚠ リリース前に必ず入れ直す＝未決7）。
func start_dungeon_run(dungeon_id: String = DUNGEON_DEFAULT_ID) -> bool:
	if is_in_dungeon():
		push_warning("[GameManager] start_dungeon_run: すでにランの中にいる（先に abandon_dungeon_run()）")
		return false
	if MasterDataLoader.get_dungeon(dungeon_id).is_empty():
		push_warning("[GameManager] start_dungeon_run: dungeon.json に無い: " + dungeon_id)
		return false
	var config: DungeonConfig = _dungeon()
	if config == null:
		return false
	var map: Dictionary = _build_dungeon_map(dungeon_id)
	if map.is_empty():
		push_warning("[GameManager] start_dungeon_run: マップを組めなかった: " + dungeon_id)
		return false

	# ⚠ 素の MAX HP から写す。⚠ 数値だけ（マスターデータを複製しない＝CLAUDE.md 4番）。
	var max_hp: Dictionary = {}
	for member: Variant in get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		max_hp[character_id] = int(get_effective_stats(character_id).get(GameStateKeys.STAT_HP, 0))

	# ここから状態を触る。
	var run: Dictionary = _empty_dungeon_run()
	run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID] = dungeon_id
	run[GameStateKeys.DUNGEON_RUN_FLOOR_INDEX] = 1
	run[GameStateKeys.DUNGEON_RUN_MAX_HP] = max_hp
	# ⚠ 入った時点では満タン。⚠ 同じ数値だが意味が別（§4-4 の表）。
	run[GameStateKeys.DUNGEON_RUN_HP] = max_hp.duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_BAG_SLOTS] = maxi(0, int(config.bag_initial_slots))
	# ⚠ たいまつを最初から持たせる（段階19-c-2・人間の決定25）。
	#   ⚠ 等級0 は「何も見えない」（⚠ 落ちる手段はいま無い。⚠ 将来の罠の落ち先）。
	#   ⚠ 上限で丸める（⚠ 目盛りを縮めたときに範囲の外を指さないように）。
	run[GameStateKeys.DUNGEON_RUN_TORCH_GRADE] = clampi(
		int(config.torch_initial_grade), 0, get_dungeon_torch_max_grade()
	)
	_apply_dungeon_map(run, map)
	_state[GameStateKeys.DUNGEON_RUN] = run

	print("[GameManager] start_dungeon_run('%s') -> フロア1 / ノード%d / 鞄 %d 枠 / ランのMAX HP %s" % [
		dungeon_id, (run[GameStateKeys.DUNGEON_RUN_NODES] as Dictionary).size(),
		int(run[GameStateKeys.DUNGEON_RUN_BAG_SLOTS]), str(max_hp),
	])
	dungeon_run_changed.emit(dungeon_id)
	return true


# 組んだマップを run に載せる（開始と潜行の共通部分）。
#
# ⚠ 2本に分けて書かないこと。片方だけ直すと「1枚目は正しいが2枚目から壊れている」
#   （またはその逆）になり、どちらもエラーが出ない（_build_new_game_state と同じ理由）。
func _apply_dungeon_map(run: Dictionary, map: Dictionary) -> void:
	var entry_id: String = str(map.get("entry", ""))
	run[GameStateKeys.DUNGEON_RUN_NODES] = map.get("nodes", {})
	run[GameStateKeys.DUNGEON_RUN_POSITION] = entry_id
	run[GameStateKeys.DUNGEON_RUN_VISITED] = {entry_id: true}
	run[GameStateKeys.DUNGEON_RUN_PHASE] = GameStateKeys.DUNGEON_PHASE_MAP
	# ⚠⚠ たいまつは戻さない（段階17-e で 17-a の実装を覆した）。
	#   ⚠ 17-a は「フロア単位で戻す（シナリオ側と同じ扱い）」と書いていたが、
	#     ⚠ 買える場所がボスの先のショップだけ（決定15）なので、⚠ 戻すと
	#       「買った瞬間に無駄になる」品になる（⚠ そのフロアはもう全部踏んでいる）。
	#   ⚠ 鞄・通貨・HP と同じく持ち越す。⚠ ランを出れば一緒に消える。


# 隣のノードへ進む。
#
# ⚠ get_dungeon_moves() に無いノードは弾く。弾くときに状態を触らない。
# ⚠⚠ 戦利品は「移動」ではなく「着いたノードの種類」に紐づく（§5-2）。
#   ⚠ 移動に紐づけ直さないこと。層構造だと歩数がどのルートでも同じなので、
#     どの分岐を選んでも報酬の総量が動かなくなり、休憩場所のコストも
#     たいまつを買う理由も同時に消える（FLOOR_GAMEPLAY_CURRENT.md §2-B）。
func move_in_dungeon(node_id: String) -> bool:
	if not is_in_dungeon():
		push_warning("[GameManager] move_in_dungeon: ランに入っていない")
		return false
	if not (node_id in get_dungeon_moves()):
		print("[GameManager] move_in_dungeon('%s') -> false (進めない)" % node_id)
		return false

	# ⚠ 前の1回ぶんを消す（段階20-d）。⚠ 消さないと、⚠ 効果の無い通路を通ったときに
	#   前のできごとがもう一度モーダルで出る。
	_last_dungeon_edge_event = {}
	# ⚠ 通路の効果は「動く前」に引いておく（段階19-c-2）。⚠ 動いたあとだと
	#   position が変わっていて、⚠ どの通路を通ったかが分からなくなる。
	var from_node_id: String = str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var edge_effect: String = str(
		get_dungeon_edge(from_node_id, node_id).get(GameStateKeys.DUNGEON_EDGE_EFFECT, "")
	)

	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_POSITION] = node_id
	var visited: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_VISITED, {})
	visited[node_id] = true
	run[GameStateKeys.DUNGEON_RUN_VISITED] = visited
	_state[GameStateKeys.DUNGEON_RUN] = run

	var kind: String = str(get_dungeon_node(node_id).get(GameStateKeys.DUNGEON_NODE_KIND, ""))
	print("[GameManager] move_in_dungeon('%s') -> true (kind=%s / 通路=%s)" % [
		node_id, kind, edge_effect if edge_effect != "" else "なし"
	])
	# ⚠⚠ 通路が先、ノードが後（段階19-c-2）。⚠ 「通路を歩いてから部屋に着く」の順。
	#   ⚠ 逆にすると、⚠ 罠で削られる前の HP で戦闘の下ごしらえが走る。
	if edge_effect != "":
		_apply_dungeon_edge_effect(edge_effect, node_id)
	# ⚠ ボスは踏んだだけでは何も出ない。⚠ 倒したときに clear_dungeon_boss() が配る
	#   （踏んだ時点で配ると、負けても報酬が残る）。
	# ⚠⚠ 宝箱も踏んだだけでは出ない（段階19-b）。⚠ open_dungeon_chest() が配る。
	#   ⚠ ここで配ると「開ける」動作が飾りになり、⚠ 画面が中身を見せる前に鞄へ入る。
	# ⚠⚠ 戦闘のマスも踏んだだけでは出ない（不1・2026-09-05）。⚠ clear_dungeon_battle() が配る。
	#   ⚠ 踏んだ時点で配っていたため、⚠ (1) 負けても報酬が残り、⚠ (2) 拾い待ちが立って
	#     画面が拾いものへ送られ、⚠ 戦闘そのものが起きなかった（⚠ 人間「戦闘が起きずに報酬だけもらえる」）。
	if kind != GameStateKeys.DUNGEON_NODE_KIND_BOSS \
			and kind != GameStateKeys.DUNGEON_NODE_KIND_CHEST \
			and kind != GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
		# ⚠⚠ 段階20-f：⚠ 戦利品も拾い待ちへ（⚠ 人間の指示「戦利品も選ばせる」）。
		#   ⚠ これで鞄へ直接入る経路は1つも無くなった。⚠ 入れるのは必ずプレイヤーが選ぶ。
		_grant_dungeon_node_gains(kind, true)
	# 休憩は踏んだら効く（段階17-c・§4-9）。⚠ ボタンを作らない（17-d）。
	# ⚠ 戦利品を配ったあとに置くこと。⚠ 逆にすると、休憩で戦利品が出る設定（W22）を
	#   入れてしまったときに、回復のログと戦利品のログが入れ替わって読めなくなる。
	if kind == GameStateKeys.DUNGEON_NODE_KIND_REST:
		apply_dungeon_rest()
	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return true


# ボスを倒した。⚠ ここで初めてボスの戦利品と通貨が入り、撤退できるようになる。
#
# ⚠ 17-a の時点で呼ぶのは scenario=dungeon だけ。⚠ 戦闘から呼ぶのは 17-b。
# ⚠ 位置がボスノードでなければ弾く（弾くときに状態を触らない）。
func clear_dungeon_boss() -> bool:
	if not is_in_dungeon():
		return false
	if get_dungeon_phase() != GameStateKeys.DUNGEON_PHASE_MAP:
		print("[GameManager] clear_dungeon_boss() -> false (すでにボスの先に居る)")
		return false
	var position: String = str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var node: Dictionary = get_dungeon_node(position)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) != GameStateKeys.DUNGEON_NODE_KIND_BOSS:
		print("[GameManager] clear_dungeon_boss() -> false (ボスノードに居ない: %s)" % position)
		return false

	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	(nodes[position] as Dictionary)[GameStateKeys.DUNGEON_NODE_CLEARED] = true
	run[GameStateKeys.DUNGEON_RUN_NODES] = nodes
	# ⚠ ここが「お預けポイント」の代わり（決定15）。ショップ（17-e）を見せてから
	#   「続行する／撤退する」を選ばせる場所。
	run[GameStateKeys.DUNGEON_RUN_PHASE] = GameStateKeys.DUNGEON_PHASE_BOSS_CLEARED
	_state[GameStateKeys.DUNGEON_RUN] = run

	# ⚠ ボスの戦利品も拾い待ちへ（段階20-f）。⚠ 画面が「何を持ち帰るか」を選ばせる。
	_grant_dungeon_node_gains(GameStateKeys.DUNGEON_NODE_KIND_BOSS, true)
	print("[GameManager] clear_dungeon_boss() -> フロア%d 突破。撤退できる状態になった" % get_dungeon_floor_index())
	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return true


# 戦闘のマスに勝った。⚠ ここで初めて戦闘の戦利品と一時通貨が入る（不1・2026-09-05）。
#
# ⚠⚠ 段階20-f までは move_in_dungeon() が「踏んだ時点」で配っていた。⚠ それを勝利時に移した。
#   ⚠ 踏んだ時点で配ると、⚠ ボス（clear_dungeon_boss）と宝箱（open_dungeon_chest）で
#     避けたのと同じ穴が戦闘だけに残る＝⚠ 負けても報酬が残る。
#   ⚠⚠ さらに 20-f で戦利品が拾い待ちへ回ったため、⚠ 踏んだ瞬間に拾い待ちが立ち、
#     ⚠ dungeon_map が拾いものの画面へ送って戦闘が始まらなくなっていた。
# ⚠ 1マス1回（⚠ cleared で覚える）。⚠ ボスは clear_dungeon_boss() の担当。ここでは弾く。
func clear_dungeon_battle() -> bool:
	if not is_in_dungeon():
		return false
	if get_dungeon_phase() != GameStateKeys.DUNGEON_PHASE_MAP:
		print("[GameManager] clear_dungeon_battle() -> false (すでにボスの先に居る)")
		return false
	var position: String = str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, ""))
	var node: Dictionary = get_dungeon_node(position)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) != GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
		print("[GameManager] clear_dungeon_battle() -> false (戦闘のマスに居ない: %s)" % position)
		return false
	if bool(node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
		print("[GameManager] clear_dungeon_battle() -> false (もう倒したマス: %s)" % position)
		return false

	# --- ここから状態を変える（⚠ 判定は全部上で終えている・CLAUDE.md 6番）---
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	(nodes[position] as Dictionary)[GameStateKeys.DUNGEON_NODE_CLEARED] = true
	run[GameStateKeys.DUNGEON_RUN_NODES] = nodes
	_state[GameStateKeys.DUNGEON_RUN] = run

	# ⚠ 配る口は _grant_dungeon_node_gains() の1本のまま（⚠ 2本目を書かない）。
	# ⚠ 拾い待ちへ積む（段階20-f）。⚠ 鞄へ入れるのはプレイヤーが選ぶ。
	var result: Dictionary = _grant_dungeon_node_gains(
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE, true
	)
	print("[GameManager] clear_dungeon_battle('%s') -> 拾い待ちへ %s" % [
		position, result.get("granted", {})
	])
	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return true


# 次のフロアへ潜る（続行する）。
#
# ⚠ ランの MAX HP・HP・鞄・鞄の枠・一時通貨はそのまま持ち越す（§5-0 の表）。
# ⚠ ボスを倒した先でしか呼べない。⚠ 層の途中から呼べる形にしないこと。
func descend_dungeon_floor() -> bool:
	if not can_retreat_from_dungeon():
		print("[GameManager] descend_dungeon_floor() -> false (ボスを倒した先に居ない)")
		return false
	# ⚠ 1ランは3階まで（段階20-a・決定26）。⚠ 最後の階のボスを倒したら持ち帰るしかない。
	if not can_descend_dungeon_floor():
		print("[GameManager] descend_dungeon_floor() -> false (最後の階。持ち帰るしかない)")
		return false
	var dungeon_id: String = str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	var map: Dictionary = _build_dungeon_map(dungeon_id)
	if map.is_empty():
		push_warning("[GameManager] descend_dungeon_floor: マップを組めなかった: " + dungeon_id)
		return false

	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_FLOOR_INDEX] = get_dungeon_floor_index() + 1
	_apply_dungeon_map(run, map)
	_state[GameStateKeys.DUNGEON_RUN] = run

	print("[GameManager] descend_dungeon_floor() -> フロア%d / 鞄 %d/%d / 通貨 %d（持ち越した）" % [
		int(run[GameStateKeys.DUNGEON_RUN_FLOOR_INDEX]),
		get_dungeon_bag_used(), get_dungeon_bag_slots(), get_dungeon_currency(),
	])
	dungeon_run_changed.emit(dungeon_id)
	return true


# 撤退する（鞄の中身を持ち帰ってラン終了）。
#
# 戻り値: {"granted": {item_id: 個数}, "discarded": {item_id: 個数}}
#
# ⚠⚠ 個体化の口は _grant_item() → add_to_inventory() の1本だけ（CLAUDE.md 8番）。
#   ⚠ ここで inventory を直接書かないこと。装備が個体にならず静かに消える。
# ⚠ ラン専用の型（ITEM_TYPE_DUNGEON）のものは持ち帰らない（決定17・§4-3-1）。
#   ⚠ 「拠点で買えない・拠点で使えない」ものが拠点の倉庫に並ぶのを、型の判定1つで
#     止めている。⚠ ID の綴りで見分けないこと。
func retreat_from_dungeon() -> Dictionary:
	var result: Dictionary = {"granted": {}, "discarded": {}, "left_behind": {}}
	if not can_retreat_from_dungeon():
		print("[GameManager] retreat_from_dungeon() -> 何もしない (ボスを倒した先に居ない)")
		return result

	var bag: Dictionary = get_dungeon_bag()
	var item_ids: Array = bag.keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		var count: int = int(bag[item_id])
		if count <= 0:
			continue
		if _is_dungeon_only_item(item_id):
			(result["discarded"] as Dictionary)[item_id] = count
			continue
		# ⚠ 段階18-b：倉庫に入るぶんだけ持ち帰る（PLAN_INVENTORY.md §4-1）。
		#   ⚠ 置いていったものを黙って消さない。⚠ 戻り値に出して画面が言えるようにする。
		#   ⚠ 素材はマスを使わないので、⚠ ここで弾かれるのは装備・装飾・消耗品だけ。
		var takeable: int = _inventory_slots_needed_for_item(item_id, count)
		if takeable > 0 and not can_accept_inventory(takeable):
			var can_take: int = get_inventory_free_slots()
			if can_take > 0:
				_grant_item(item_id, can_take)
				(result["granted"] as Dictionary)[item_id] = can_take
			(result["left_behind"] as Dictionary)[item_id] = count - can_take
			continue
		_grant_item(item_id, count)
		(result["granted"] as Dictionary)[item_id] = count

	var floors: int = get_dungeon_floor_index()
	_end_dungeon_run()
	print("[GameManager] retreat_from_dungeon() -> フロア%d まで潜って持ち帰った: %s（ラン専用で消えたもの: %s ／ 倉庫が満杯で置いてきたもの: %s）" % [
		floors, str(result["granted"]), str(result["discarded"]), str(result["left_behind"]),
	])
	return result


# ランを失う（死亡／その場で降りる）。⚠ 鞄の中身は全部消える（§4-2・§4-8）。
#
# ⚠ 「その場で降りる」のボタンを消さないこと。⚠ 消すと詰んだ人が閉じ込められる
#   （Roguebook の知見）。⚠ ただしタダにもしない。ここを通ると持ち帰りはゼロ。
# ⚠ 失うのは鞄と一時通貨だけ。⚠ 装備・装飾・ルーン・レベル・研究は失わない（決定7）。
#   ⚠ 「装備を除外する条件分岐」を書かないこと。⚠ 鞄に持ち込みが入らないので
#     構造で外れている。
func abandon_dungeon_run() -> void:
	if not is_in_dungeon():
		return
	var lost: Dictionary = get_dungeon_bag()
	var floors: int = get_dungeon_floor_index()
	_end_dungeon_run()
	print("[GameManager] abandon_dungeon_run() -> フロア%d で全ロスト。失った鞄の中身: %s" % [floors, str(lost)])


# ランの状態を捨てる。⚠ 撤退と全ロストの共通部分。
#
# ⚠ ランの MAX HP はここで一緒に消える。⚠ 次に入るときは素の MAX HP から
#   満タンで始まる（決定9＝案A）。⚠ CHARACTER_GROWTH には1文字も書いていない。
func _end_dungeon_run() -> void:
	_state[GameStateKeys.DUNGEON_RUN] = _empty_dungeon_run()
	dungeon_run_changed.emit("")


# --- 鞄と一時通貨 -----------------------------------------------------

# 鞄に入れる。⚠ 戻り値は「実際に入った個数」。
#
# ⚠ 溢れたぶんは入らない（＝拾えない）。⚠ 勝手に何かを捨てて空けないこと。
#   ⚠ 「何を残し何を捨てるか」はプレイヤーが選ぶもの（コンセプト文書）。画面は 17-d。
# ⚠ 鞄が持つのは item_id と個数だけ。⚠ 個体（instance_id）にしない（§4-1）。
#   ⚠ ここを add_to_inventory() の2本目の入口にしないこと（CLAUDE.md 8番）。
func add_to_dungeon_bag(item_id: String, count: int) -> int:
	if not is_in_dungeon() or count <= 0:
		return 0
	var used: int = get_dungeon_bag_used()
	var slots: int = get_dungeon_bag_slots()
	var accepted: int = mini(count, maxi(0, slots - used))
	if accepted <= 0:
		print("[GameManager] add_to_dungeon_bag('%s', %d) -> 0（鞄が満杯 %d/%d）" % [
			item_id, count, used, slots
		])
		return 0

	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var bag: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_BAG, {})
	bag[item_id] = int(bag.get(item_id, 0)) + accepted
	run[GameStateKeys.DUNGEON_RUN_BAG] = bag
	run[GameStateKeys.DUNGEON_RUN_LOOT_COUNT] = int(run.get(GameStateKeys.DUNGEON_RUN_LOOT_COUNT, 0)) + accepted
	_state[GameStateKeys.DUNGEON_RUN] = run

	if accepted < count:
		print("[GameManager] add_to_dungeon_bag('%s', %d) -> %d だけ入った（鞄 %d/%d）" % [
			item_id, count, accepted, get_dungeon_bag_used(), slots
		])
	return accepted


# --- 拾い待ちの品（段階20-e・人間の指示） -----------------------------
#
# ⚠⚠ 人間の言葉：「⚠ 何を拾ったか、表示するように」「⚠ モーダルの中にアイテムとして見せて」
#   「⚠ インベントリの中に何を入れるか選べるように」。
# ⚠⚠ コンセプト文書の「何を残し何を捨てるかはプレイヤーが選ぶもの」がここで実装された
#   （⚠ `add_to_dungeon_bag()` のコメントが 17-a から「画面は 17-d」と予告していたもの）。
# ⚠ 鞄の枠を1つも使わない。⚠ 「拾うかどうかを決めていないもの」の置き場。
# ⚠⚠ 画面を出ると残りは消える（⚠ 引き返さないので拾い直せない）。

# 拾い待ちの品（{item_id: 個数}）。⚠ 画面はこの1本に聞く。
func get_dungeon_pending_loot() -> Dictionary:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var loot: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_PENDING_LOOT, {})
	return loot.duplicate(true)


# 拾い待ちがあるか。⚠ 画面が「拾いものの画面へ行くか」を決めるのに使う。
func has_dungeon_pending_loot() -> bool:
	return not get_dungeon_pending_loot().is_empty()


# 拾い待ちのマス目（段階20-e）。⚠ 鞄のマス目と同じ形。
#
# ⚠ 空きマスは足さない（⚠ 枠が無いもの＝「あと何個入るか」の概念が無い）。
func get_dungeon_pending_loot_slot_layout() -> Array:
	return _dungeon_item_slot_layout(get_dungeon_pending_loot())


# {item_id: 個数} を1個1マスのマス目にする（段階20-e）。
#
# ⚠ 鞄のマス目（get_dungeon_bag_slot_layout）と同じ組み立て。⚠ あちらは空きマスを足すので
#   1本にまとめていない（⚠ まとめると「枠」の概念がこちらに漏れる）。
func _dungeon_item_slot_layout(source: Dictionary) -> Array:
	var result: Array = []
	var item_ids: Array = source.keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		var count: int = int(source[item_id])
		for _i: int in range(maxi(0, count)):
			result.append({
				SLOT_ENTRY_KIND: SLOT_KIND_ITEM,
				SLOT_ENTRY_ITEM_ID: item_id,
				SLOT_ENTRY_INSTANCE_ID: "",
				SLOT_ENTRY_GRADE: 0,
				SLOT_ENTRY_EQUIPPED_BY: "",
				SLOT_ENTRY_COUNT: count,
			})
	return result


# 拾い待ちに積む。⚠ 積む口はここ1本だけ。
#
# ⚠ 鞄と違って枠が無いので、⚠ 溢れるという概念が無い。
func _add_dungeon_pending_loot(item_id: String, count: int) -> void:
	if not is_in_dungeon() or count <= 0:
		return
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var loot: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_PENDING_LOOT, {})
	loot[item_id] = int(loot.get(item_id, 0)) + count
	run[GameStateKeys.DUNGEON_RUN_PENDING_LOOT] = loot
	_state[GameStateKeys.DUNGEON_RUN] = run


# 拾い待ちから1個減らす。⚠ 拾う／捨てるの共通部分。
func _remove_dungeon_pending_loot(item_id: String) -> bool:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var loot: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_PENDING_LOOT, {})
	var left: int = int(loot.get(item_id, 0)) - 1
	if left < 0:
		return false
	if left > 0:
		loot[item_id] = left
	else:
		loot.erase(item_id)
	run[GameStateKeys.DUNGEON_RUN_PENDING_LOOT] = loot
	_state[GameStateKeys.DUNGEON_RUN] = run
	return true


# 拾い待ちから1個を鞄へ入れる（段階20-e）。⚠ 鞄が満杯なら false（⚠ 拾い待ちは減らない）。
#
# ⚠ 状態を変える前に判定を全部終える（CLAUDE.md 6番）。
func take_dungeon_pending_loot(item_id: String) -> bool:
	if not is_in_dungeon():
		return false
	if int(get_dungeon_pending_loot().get(item_id, 0)) <= 0:
		print("[GameManager] take_dungeon_pending_loot: 拾い待ちに無い: " + item_id)
		return false
	if get_dungeon_bag_used() >= get_dungeon_bag_slots():
		print("[GameManager] take_dungeon_pending_loot: 鞄が満杯（%d/%d）" % [
			get_dungeon_bag_used(), get_dungeon_bag_slots()
		])
		return false

	# --- ここから状態を変える ---
	if not _remove_dungeon_pending_loot(item_id):
		return false
	var accepted: int = add_to_dungeon_bag(item_id, 1)
	if accepted <= 0:
		# ⚠ 起きないはず（⚠ 上で空きを見ている）。⚠ 起きたら拾い待ちへ戻す。
		push_warning("[GameManager] take_dungeon_pending_loot: 鞄に入らなかったので戻す: " + item_id)
		_add_dungeon_pending_loot(item_id, 1)
		return false
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return true


# 入るだけ鞄へ入れる（段階20-e）。⚠ 戻り値は入ったもの（{item_id: 個数}）。
#
# ⚠ 綴り順で入れる（⚠ 鞄が満杯になったときに「何が入って何が残ったか」が
#   起動ごとに変わらないようにする＝add_to_dungeon_bag と同じ流儀）。
func take_all_dungeon_pending_loot() -> Dictionary:
	var taken: Dictionary = {}
	if not is_in_dungeon():
		return taken
	var item_ids: Array = get_dungeon_pending_loot().keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		while int(get_dungeon_pending_loot().get(item_id, 0)) > 0:
			if not take_dungeon_pending_loot(item_id):
				break
			taken[item_id] = int(taken.get(item_id, 0)) + 1
	print("[GameManager] take_all_dungeon_pending_loot() -> 入れた %s ／ 残り %s（鞄 %d/%d）" % [
		str(taken), str(get_dungeon_pending_loot()),
		get_dungeon_bag_used(), get_dungeon_bag_slots(),
	])
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return taken


# 拾い待ちから1個を捨てる（段階20-e）。⚠ 鞄には入らない。⚠ 戻りは無い。
func discard_dungeon_pending_loot(item_id: String) -> bool:
	if not is_in_dungeon():
		return false
	if int(get_dungeon_pending_loot().get(item_id, 0)) <= 0:
		return false
	if not _remove_dungeon_pending_loot(item_id):
		return false
	print("[GameManager] discard_dungeon_pending_loot('%s') -> 残り %s" % [
		item_id, str(get_dungeon_pending_loot())
	])
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return true


# 拾い待ちを丸ごと捨てる（段階20-e）。⚠ 画面を出るときに呼ぶ。
#
# ⚠ 戻り値は捨てたもの（⚠ 画面が「置いてきた」と言えるように）。
# ⚠⚠ 引き返さないので拾い直せない。⚠ 「あとで取りに戻る」を作らないこと。
func clear_dungeon_pending_loot() -> Dictionary:
	var left: Dictionary = get_dungeon_pending_loot()
	if left.is_empty():
		return left
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_PENDING_LOOT] = {}
	_state[GameStateKeys.DUNGEON_RUN] = run
	print("[GameManager] clear_dungeon_pending_loot() -> 置いてきた %s" % str(left))
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return left


# 鞄から1個捨てる（段階20-e・人間の指示「⚠ 入れ替えられる」）。
#
# ⚠⚠ 拾いものの画面で「鞄を空けて入れ替える」ために要る。⚠ 戻りは無い。
# ⚠ 拠点の `discard_inventory_slot()` を借りない（⚠ 器が別＝台帳 §7）。
func discard_dungeon_bag_item(item_id: String) -> bool:
	if not is_in_dungeon():
		return false
	if int(get_dungeon_bag().get(item_id, 0)) <= 0:
		return false
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var bag: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_BAG, {})
	var left: int = int(bag.get(item_id, 0)) - 1
	if left > 0:
		bag[item_id] = left
	else:
		bag.erase(item_id)
	run[GameStateKeys.DUNGEON_RUN_BAG] = bag
	_state[GameStateKeys.DUNGEON_RUN] = run
	print("[GameManager] discard_dungeon_bag_item('%s') -> 鞄 %d/%d" % [
		item_id, get_dungeon_bag_used(), get_dungeon_bag_slots()
	])
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return true


# 一時通貨を増やす（決定16。1種類）。⚠ ゴールドと混ぜないこと。
func add_dungeon_currency(amount: int) -> void:
	if not is_in_dungeon() or amount == 0:
		return
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_CURRENCY] = maxi(0, get_dungeon_currency() + amount)
	_state[GameStateKeys.DUNGEON_RUN] = run


# その item_id がラン専用の型か（決定17・§4-3-1）。
#
# ⚠ 見るのは items.json の item_type だけ。⚠ ID の綴りで見分けないこと
#   （ITEM_MASTER_PART_KIND のコメントと同じ理由）。
func _is_dungeon_only_item(item_id: String) -> bool:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return false
	return str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_DUNGEON


# --- 戦利品（ノード種に紐づく。§5-2） ---------------------------------

# 着いたノードの種類に応じて、戦利品と一時通貨を配る。
#
# 戻り値: {"granted": {item_id: 個数}, "left_behind": {item_id: 個数}}
#
# ⚠ 抽選の本体は _roll_weighted_table() の1本（台帳 §7）。⚠ あちらにボーナスを足さない。
# ⚠ 出るか出ないかを先に決め、出ると決まってから中身を引く（_roll_floor_chest と同じ形）。
# ⚠ 宝箱（pending_chests）には積まない。⚠ ランの戦利品は鞄に入り、
#   持ち帰りが確定するまで拠点の資産にならない。
#
# ⚠⚠ 段階19-b で戻り値を void → Dictionary にした。⚠ 宝箱のマスだけは「開けた結果」を
#   画面に出す必要があるため（⚠ 他のノード種は踏んだ瞬間に黙って配るまま）。
#   ⚠ 配る口を2本目にしないための変更。⚠ 呼び出し元3箇所のうち2箇所は戻り値を捨てる。
func _grant_dungeon_node_gains(kind: String, to_pending: bool = false) -> Dictionary:
	# ⚠⚠ to_pending＝拾い待ちに積む（段階20-e）。⚠ 鞄には入れず、⚠ プレイヤーが選ぶ。
	#   ⚠⚠ 段階20-f 以降は呼び出し元が全部 true（⚠ 鞄へ直接入る経路は1つも無い）。
	#   ⚠ 拾い待ちには枠が無いので、⚠ そのときの left_behind は必ず空になる。
	var result: Dictionary = {"granted": {}, "left_behind": {}}
	var config: DungeonConfig = _dungeon()
	if config == null:
		return result
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(
		str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	)
	if dungeon.is_empty():
		return result

	# 1. 一時通貨。⚠ フロアが深いほど増える（§2「深く潜る＝より良い戦利品」）。
	var currency_table: Variant = dungeon.get(DUNGEON_MASTER_CURRENCY, null)
	if currency_table is Dictionary:
		# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
		var base: int = int((currency_table as Dictionary).get(kind, 0))
		if base > 0:
			var growth: int = maxi(0, int(config.currency_growth_pct_per_floor))
			var depth: int = maxi(0, get_dungeon_floor_index() - 1)
			add_dungeon_currency(int(float(base) * (1.0 + float(growth) * float(depth) / 100.0)))

	# 2. 戦利品。⚠ ノード種ごとの確率で引く。
	var chance: int = _dungeon_loot_chance_pct(kind)
	if chance <= 0 or randi_range(1, 100) > chance:
		return result
	var loot_table: Variant = dungeon.get(DUNGEON_MASTER_LOOT, null)
	if not (loot_table is Dictionary):
		return result
	var entry: Variant = (loot_table as Dictionary).get(kind, null)
	if not (entry is Dictionary):
		return result
	var draw: Dictionary = entry
	var rolls: int = int(draw.get(CHEST_DRAW_ROLLS, 0))
	if rolls <= 0:
		return result
	var rolled: Dictionary = _roll_weighted_table(draw.get(CHEST_DRAW_ENTRIES, []), rolls)
	# ⚠ 綴り順で入れる（Dictionary のキー順は不定。鞄が溢れたときに
	#   「何が入って何が入らなかったか」が起動ごとに変わらないようにする）。
	var item_ids: Array = rolled.keys()
	item_ids.sort()
	for item_entry: Variant in item_ids:
		var item_id: String = str(item_entry)
		var wanted: int = int(rolled[item_entry])
		if to_pending:
			# ⚠ 拾い待ちには枠が無いので全部積む。⚠ 鞄へ入れるのはプレイヤーが選ぶ。
			_add_dungeon_pending_loot(item_id, wanted)
			(result["granted"] as Dictionary)[item_id] = wanted
			continue
		var accepted: int = add_to_dungeon_bag(item_id, wanted)
		if accepted > 0:
			(result["granted"] as Dictionary)[item_id] = accepted
		# ⚠ 入り切らなかったぶんを黙って消さない。⚠ 画面が「置いてきた」と言えるようにする
		#   （⚠ retreat_from_dungeon() の left_behind と同じ形）。
		if accepted < wanted:
			(result["left_behind"] as Dictionary)[item_id] = wanted - accepted
	return result


# ノード種ごとの「戦利品を引く確率（％）」。
#
# ⚠ 置き場は DungeonConfig の1本だけ。⚠ dungeon.json 側に確率を書かないこと。
func _dungeon_loot_chance_pct(kind: String) -> int:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return 0
	match kind:
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE:
			return int(config.loot_chance_battle_pct)
		GameStateKeys.DUNGEON_NODE_KIND_RELIC:
			return int(config.loot_chance_relic_pct)
		GameStateKeys.DUNGEON_NODE_KIND_REST:
			return int(config.loot_chance_rest_pct)
		GameStateKeys.DUNGEON_NODE_KIND_CHEST:
			return int(config.loot_chance_chest_pct)
		DUNGEON_LOOT_EDGE_CHEST:
			# ⚠ 通路の宝箱もマスの宝箱と同じつまみを使う（段階19-c-2）。
			#   ⚠ 「開けたのに空」を許さないという理由が同じなので、⚠ 欄を2本にしない。
			#   ⚠ 中身の薄さは dungeon.json の loot.edge_chest（rolls 1）で付けている。
			return int(config.loot_chance_chest_pct)
		GameStateKeys.DUNGEON_NODE_KIND_BOSS:
			return int(config.loot_chance_boss_pct)
	return 0


# --- マップ -----------------------------------------------------------

# 層構造のマップを組む（決定12。下から上へ・合流あり・引き返さない）。
#
# 戻り値: {"entry": node_id, "boss": node_id, "nodes": {node_id: {layer, kind, next, cleared}}}
#
# ⚠⚠ _build_floor_map() を借りない（台帳 §7）。⚠ 形は同じでも仕様が別で、
#   借りると両方の仕様が1本の関数に同居する。
# ⚠ ノードを作るのはここ1本だけ。⚠ 2本目を書かないこと。
# ⚠ 接続は決め打ち（乱数を使わない）。乱数が入るのはノードの種類だけ。
#   接続まで乱数にすると「ボスに着かないルート」が低確率で生まれ、再現できない事故になる。
# ⚠ 最終層の全ノードがボスへ入る＝どのルートを選んでも必ずボスに着く。
func _build_dungeon_map(dungeon_id: String) -> Dictionary:
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
	var raw_layers: Variant = dungeon.get(DUNGEON_MASTER_LAYERS, null)
	if not (raw_layers is Array) or (raw_layers as Array).is_empty():
		return {}
	var layers: Array = raw_layers as Array

	# ⚠⚠ 区画（合流しないエリア。段階20-b・人間の決定28）。
	#   ⚠ 層の並びのどこが区画帯かを先に決める。⚠ 帯の中は「区画ごと」にしか繋がない。
	var seg: Array[int] = _dungeon_segment_of_layers(layers.size())
	var seg_count: int = _dungeon_segment_count()
	var inner_nodes: int = _dungeon_segment_inner_nodes()

	# 1. 層ごとにノードを作る。種類だけ抽選する。
	# ⚠ 区画帯の層はノード数を JSON ではなく区画の形から決める
	#   （⚠ 入口／出口＝区画の数 ／ 中＝区画の数 × 中のノード数）。
	var ids_by_layer: Array = []
	# ⚠ ノードごとの区画番号（⚠ -1 は通常の層）。⚠ 繋ぐときに「同じ区画か」を見る。
	var seg_by_layer: Array = []
	var nodes: Dictionary = {}
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
		var count: int = int(layer.get(DUNGEON_LAYER_NODE_COUNT, 0))
		var weights: Dictionary = get_dungeon_layer_weights(layer_index + 1)
		var row: Array = []
		var seg_row: Array[int] = []
		var slot: int = seg[layer_index]
		if slot == DUNGEON_SEGMENT_NONE:
			for i: int in range(count):
				row.append(_make_dungeon_node(nodes, layer_index + 1, i, weights))
				seg_row.append(DUNGEON_SEGMENT_NONE)
		else:
			# ⚠ 区画帯。⚠ 端（入口・出口）は区画ごとに1ノード、⚠ 中は inner_nodes ずつ。
			var per_segment: int = 1 if (slot == DUNGEON_SEGMENT_EDGE) else inner_nodes
			var index: int = 0
			for k: int in range(seg_count):
				for _n: int in range(per_segment):
					row.append(_make_dungeon_node(nodes, layer_index + 1, index, weights))
					seg_row.append(k)
					index += 1
		if row.is_empty():
			push_warning("[GameManager] _build_dungeon_map: 層 %d のノードが0件: %s" % [
				layer_index + 1, dungeon_id
			])
			return {}
		ids_by_layer.append(row)
		seg_by_layer.append(seg_row)

	# 2. ボス。最終層の1つ先に置く。
	var boss_id: String = "d_boss"
	nodes[boss_id] = {
		GameStateKeys.DUNGEON_NODE_LAYER: layers.size() + 1,
		GameStateKeys.DUNGEON_NODE_KIND: GameStateKeys.DUNGEON_NODE_KIND_BOSS,
		GameStateKeys.DUNGEON_NODE_NEXT: [],
		GameStateKeys.DUNGEON_NODE_CLEARED: false,
	}

	# 3. 層と層をつなぐ。
	# ⚠⚠ 上下とも区画帯なら「同じ区画どうし」だけを繋ぐ（段階20-b）。
	#   ⚠ これが「区画と区画のあいだは合流しない」の実体。⚠ 一度入ったら隣へ移れない。
	# ⚠ 通常 → 区画の入口 だけ上限を上げる（⚠ 人間の裁き「入り口は3」）。
	for layer_index: int in range(ids_by_layer.size() - 1):
		var upper: Array = ids_by_layer[layer_index]
		var lower: Array = ids_by_layer[layer_index + 1]
		var upper_seg: Array = seg_by_layer[layer_index]
		var lower_seg: Array = seg_by_layer[layer_index + 1]
		if seg[layer_index] != DUNGEON_SEGMENT_NONE and seg[layer_index + 1] != DUNGEON_SEGMENT_NONE:
			for k: int in range(seg_count):
				_connect_dungeon_layers(
					nodes, _dungeon_nodes_of_segment(upper, upper_seg, k),
					_dungeon_nodes_of_segment(lower, lower_seg, k), dungeon_id
				)
			continue
		var override: int = 0
		if seg[layer_index] == DUNGEON_SEGMENT_NONE and seg[layer_index + 1] != DUNGEON_SEGMENT_NONE:
			override = _dungeon_segment_choices()
		_connect_dungeon_layers(nodes, upper, lower, dungeon_id, override)
	# 最終層 -> ボス（合流）。
	# ⚠ ボスへの通路にも効果が付く（⚠ 特別扱いしない。⚠ 最後の1歩にも選択が要る）。
	for node_id: Variant in (ids_by_layer[ids_by_layer.size() - 1] as Array):
		(nodes[str(node_id)] as Dictionary)[GameStateKeys.DUNGEON_NODE_NEXT] = [
			_make_dungeon_edge(boss_id, dungeon_id)
		]

	return {
		"entry": str((ids_by_layer[0] as Array)[0]),
		"boss": boss_id,
		"nodes": nodes,
	}


# 隣り合う2つの層をつなぐ。
#
# ⚠ 上の層の各ノードが、下の層の「持ち分の窓」＋1つ先へつながる。
#   これで (a) どのノードにも進める先が1つ以上ある
#        (b) 下の層のどのノードにも入ってくる線が1本以上ある
#   の両方が、層のノード数の組み合わせによらず成り立つ。
# ⚠ (b) が崩れると「絶対に通れないノード」が生まれる。scenario=dungeon の
#   全ルート総当たりがそれを見張る。
#
# ⚠ 段階19-d：⚠ 隣へ何個伸ばすかを DungeonConfig.branch_spread のつまみにした。
#   ⚠ 0 にすると一本道になる（⚠ 分岐が消えるので、たいまつも休憩のコストも効かなくなる）。
#
# ⚠⚠ 段階19-f：⚠ 1ノードから出る通路に上限を付けた（DungeonConfig.max_edges_per_node）。
#   ⚠ 人間の指摘「⚠ そんなに入り組ませないでほしい　ルートを」。
#   ⚠ 上限で切ると (b) が崩れるので、⚠ 切ったあとに「入ってくる線が0本のマス」を
#     数え直して補う。⚠ 補う口はここ1本（⚠ 総当たりが 0 件であることを見張る）。
#
# ⚠ 段階20-b：⚠ `max_edges_override` を足した。⚠ 区画の入口だけ上限を上げるため
#   （⚠ 人間の裁き「入り口は3」）。⚠ 0 以下なら Config の上限を使う。
func _connect_dungeon_layers(
		nodes: Dictionary, upper: Array, lower: Array, dungeon_id: String = "",
		max_edges_override: int = 0
) -> void:
	var config: DungeonConfig = _dungeon()
	var spread: int = 1 if config == null else maxi(0, int(config.branch_spread))
	var max_edges: int = 2 if config == null else maxi(1, int(config.max_edges_per_node))
	if max_edges_override > 0:
		max_edges = max_edges_override
	var n: int = upper.size()
	var m: int = lower.size()
	# ⚠ 先に「どこへ繋ぐか」を番号で決め切る。⚠ 通路を作るのは最後にまとめて
	#   （⚠ 途中で作ると、⚠ 補正で捨てる通路の効果まで抽選してしまう）。
	var targets_by_upper: Array = []
	var incoming: Array[int] = []
	incoming.resize(m)
	for j: int in range(n):
		var base_lo: int = int(floor(float(j) * float(m) / float(n)))
		var base_hi: int = maxi(int(ceil(float(j + 1) * float(m) / float(n))) - 1, base_lo)
		var lo: int = base_lo
		var hi: int = base_hi
		# ⚠⚠ 隣へ伸ばす向きを1つおきに入れ替える（段階20-i・人間の指摘）。
		#   ⚠ 人間の言葉：「⚠ 左上のノードにいく生成がないような気がする」。
		#   ⚠⚠ 前は右へしか伸ばしておらず、⚠ マップ全体が右へ流れていた
		#     （⚠ 「左から右に行く道がやたら生成される」も同じ原因の別の見え方だった）。
		#   ⚠ 左へ伸ばす番と右へ伸ばす番を交互にすると、⚠ 左のマスにも入ってくる線ができる。
		#   ⚠ 乱数にしないこと（⚠ 起動ごとに形が変わると検証が読めなくなる）。
		if (j % 2) == 0:
			hi = mini(hi + spread, m - 1)
			# ⚠ 上限まで（⚠ lo 側から取る＝真下が必ず残る）。
			hi = mini(hi, lo + max_edges - 1)
		else:
			lo = maxi(lo - spread, 0)
			# ⚠ 上限まで（⚠ hi 側から取る＝真下が必ず残る）。
			lo = maxi(lo, hi - max_edges + 1)
		var targets: Array[int] = []
		for k: int in range(lo, hi + 1):
			targets.append(k)
			incoming[k] += 1
		targets_by_upper.append(targets)

	# ⚠⚠ 入ってくる線が0本のマスを補う。⚠ 補わないと「絶対に通れないノード」が生まれる。
	#   ⚠ 一番近い上の層のマスから1本足す（⚠ 上限を超えてでも足す＝到達性が優先）。
	for k: int in range(m):
		if incoming[k] > 0:
			continue
		var j_near: int = clampi(int(float(k) * float(n) / float(m)), 0, n - 1)
		(targets_by_upper[j_near] as Array).append(k)
		(targets_by_upper[j_near] as Array).sort()
		incoming[k] += 1

	for j: int in range(n):
		var next_edges: Array = []
		for k: Variant in (targets_by_upper[j] as Array):
			next_edges.append(_make_dungeon_edge(str(lower[int(k)]), dungeon_id))
		(nodes[str(upper[j])] as Dictionary)[GameStateKeys.DUNGEON_NODE_NEXT] = next_edges


# --- 区画（合流しないエリア。段階20-b・人間の決定28） ---------------
#
# ⚠⚠ 人間の裁き：「⚠ 1区間は5層まで　⚠ 1回に3個　⚠ 入り口は3　⚠ 中で分岐してもいい」。
# ⚠⚠ 「合流しない」のは**区画と区画のあいだ**。⚠ 区画の中では合流してよい
#   （⚠ 外の台帳 §3-2 の図がそう。⚠ 入口1・出口1の箱で、⚠ 中は分岐して合流する）。
# ⚠ 区画に入ったら隣の区画へは移れない＝⚠ 5層ぶんをまとめて賭ける重い判断。

## 通常の層（区画帯ではない）。
const DUNGEON_SEGMENT_NONE: int = -1
## 区画帯の端（入口・出口の層）。⚠ 区画ごとに1ノード。
const DUNGEON_SEGMENT_EDGE: int = 0
## 区画帯の中の層。⚠ 区画ごとに segment_inner_nodes ノード。
const DUNGEON_SEGMENT_INNER: int = 1


func _dungeon_segment_count() -> int:
	var config: DungeonConfig = _dungeon()
	return 0 if config == null else maxi(0, int(config.segment_count))


func _dungeon_segment_layers() -> int:
	var config: DungeonConfig = _dungeon()
	return 0 if config == null else maxi(0, int(config.segment_layers))


func _dungeon_segment_choices() -> int:
	var config: DungeonConfig = _dungeon()
	return 0 if config == null else maxi(1, int(config.segment_choices))


func _dungeon_segment_inner_nodes() -> int:
	var config: DungeonConfig = _dungeon()
	return 1 if config == null else maxi(1, int(config.segment_inner_nodes))


# 層ごとに「通常 / 区画の端 / 区画の中」を割り当てる（段階20-b）。
#
# ⚠ 層1（入口）は必ず通常。⚠ 合流点が1ノードなので、⚠ ここを区画にすると選べない。
# ⚠ 帯は等間隔に置く。⚠ 入り切らないぶんは置かない（W34 が鳴く）。
# ⚠ 割り当てる口はここ1本だけ。⚠ 画面や検証で層番号から計算し直さないこと。
func _dungeon_segment_of_layers(total_layers: int) -> Array[int]:
	var result: Array[int] = []
	for _i: int in range(total_layers):
		result.append(DUNGEON_SEGMENT_NONE)
	var seg_len: int = _dungeon_segment_layers()
	var seg_count: int = _dungeon_segment_count()
	# ⚠ 3 未満だと「中」が無くなり、⚠ 中で分岐できない（人間の裁きと食い違う）。
	if seg_count <= 0 or seg_len < 3:
		return result
	# ⚠ 層1 を除いた残りに等間隔で置く。
	var usable: int = total_layers - 1
	if seg_len * seg_count > usable:
		push_warning("[GameManager] W34 dungeon_config.gd: 区画 %d 個 × %d 層 が層の総数 %d に入り切らない。置ける数だけ置く" % [
			seg_count, seg_len, total_layers
		])
		seg_count = usable / seg_len
	if seg_count <= 0:
		return result
	var step: int = usable / seg_count
	for k: int in range(seg_count):
		var start: int = 1 + k * step
		if start + seg_len > total_layers:
			break
		for offset: int in range(seg_len):
			# ⚠ 端（最初と最後）は入口・出口。⚠ それ以外が中。
			result[start + offset] = (
				DUNGEON_SEGMENT_EDGE if (offset == 0 or offset == seg_len - 1)
				else DUNGEON_SEGMENT_INNER
			)
	return result


# その層のノードのうち、区画 k に属するものだけを返す（段階20-b）。
func _dungeon_nodes_of_segment(row: Array, seg_row: Array, k: int) -> Array:
	var result: Array = []
	for i: int in range(mini(row.size(), seg_row.size())):
		if int(seg_row[i]) == k:
			result.append(row[i])
	return result


# ノードを1つ作る（段階20-b で切り出した）。
#
# ⚠ ノードを作る口はここ1本だけ。⚠ 2本目を書かないこと。
func _make_dungeon_node(nodes: Dictionary, layer: int, index: int, weights: Dictionary) -> String:
	var node_id: String = "d_%d_%d" % [layer, index]
	nodes[node_id] = {
		GameStateKeys.DUNGEON_NODE_LAYER: layer,
		GameStateKeys.DUNGEON_NODE_KIND: _roll_dungeon_node_kind(weights),
		GameStateKeys.DUNGEON_NODE_NEXT: [],
		GameStateKeys.DUNGEON_NODE_CLEARED: false,
	}
	return node_id


# 通路を1本作る（段階19-c-1）。
#
# ⚠⚠ 通路を作る口はここ1本だけ。⚠ 2本目を書かないこと（⚠ ノードと同じ流儀）。
# ⚠ 19-c-1 の時点では effect は必ず ""（⚠ 器だけ先に入れた）。
#   ⚠ 抽選（5本に1本・決定24）を足すのは 19-c-2。⚠ ここに足す。
func _make_dungeon_edge(to_node_id: String, dungeon_id: String = "") -> Dictionary:
	return {
		GameStateKeys.DUNGEON_EDGE_TO: to_node_id,
		GameStateKeys.DUNGEON_EDGE_EFFECT: _roll_dungeon_edge_effect(dungeon_id),
	}


# 通路の効果を1つ引く（段階19-c-2）。⚠ 付かなければ ""。
#
# ⚠ 「効果が付くか」（Config の割合）を先に決め、⚠ 付くと決まってから
#   「何が付くか」（dungeon.json の重み）を引く。⚠ _grant_dungeon_node_gains() と同じ形。
# ⚠⚠ 逃げ道を保証しない（⚠ 人間の決定：「全部ペナルティもあり」）。
#   ⚠ 「分岐に1本は無害を混ぜる」処理をここに足さないこと。
# ⚠ dungeon_id が "" なら効果を付けない（⚠ 引く先が分からないため）。
func _roll_dungeon_edge_effect(dungeon_id: String) -> String:
	if dungeon_id == "":
		return ""
	var config: DungeonConfig = _dungeon()
	if config == null:
		return ""
	var chance: int = clampi(int(config.edge_effect_chance_pct), 0, 100)
	if chance <= 0 or randi_range(1, 100) > chance:
		return ""
	var weights: Dictionary = _dungeon_edge_effect_weights(dungeon_id)
	if weights.is_empty():
		return ""
	var total: int = 0
	for effect: Variant in weights:
		total += maxi(0, int(weights[effect]))
	if total <= 0:
		return ""
	var roll: int = randi() % total
	# ⚠ キーの並び順に依存しないよう綴り順で回す（Dictionary のキー順は不定）。
	var effects: Array = weights.keys()
	effects.sort()
	for effect: Variant in effects:
		roll -= maxi(0, int(weights[effect]))
		if roll < 0:
			return str(effect)
	return ""


# dungeon.json の edges.effects を {effect: weight} にして返す。
#
# ⚠ 知らない effect はここで落とす（⚠ E139 が起動時に赤で言っている）。
#   ⚠ 落とさないと、⚠ 綴りを間違えた通路が「何も起きないのに効果つき」になる。
func _dungeon_edge_effect_weights(dungeon_id: String) -> Dictionary:
	var result: Dictionary = {}
	var edges: Variant = MasterDataLoader.get_dungeon(dungeon_id).get(DUNGEON_MASTER_EDGES, null)
	if not (edges is Dictionary):
		return result
	var rows: Variant = (edges as Dictionary).get(DUNGEON_EDGES_EFFECTS, null)
	if not (rows is Array):
		return result
	for raw: Variant in (rows as Array):
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var effect: String = str(row.get(DUNGEON_EDGES_EFFECT, ""))
		if not (effect in DUNGEON_EDGE_EFFECTS_KNOWN):
			continue
		# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
		result[effect] = maxi(0, int(row.get(DUNGEON_EDGES_WEIGHT, 0)))
	return result


# 知っている通路の効果。⚠ 増やすときは _apply_dungeon_edge_effect() の分岐と
#   Glyphs.for_dungeon_edge() も一緒に足すこと。
const DUNGEON_EDGE_EFFECTS_KNOWN: Array[String] = [
	GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP,
	GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY,
	GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG,
	GameStateKeys.DUNGEON_EDGE_EFFECT_CHEST,
	GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE,
]


# 層 N のノード出現比を {kind: weight} で返す。
#
# ⚠ 置き場は DungeonConfig の1本だけ。⚠ dungeon.json の layers は node_count しか持たない。
# ⚠ 配列より深い層を聞かれたら末尾を使う（シナリオ側の clampi と同じ考え方）。
# ⚠ shop は返さない。ショップはボスを倒した先だけ（決定15）。
func get_dungeon_layer_weights(layer: int) -> Dictionary:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return {}
	var table: Dictionary = {
		GameStateKeys.DUNGEON_NODE_KIND_BATTLE: config.layer_weight_battle,
		GameStateKeys.DUNGEON_NODE_KIND_RELIC: config.layer_weight_relic,
		GameStateKeys.DUNGEON_NODE_KIND_REST: config.layer_weight_rest,
		GameStateKeys.DUNGEON_NODE_KIND_CHEST: config.layer_weight_chest,
	}
	var out: Dictionary = {}
	for kind: String in table:
		var row: Array = table[kind]
		if row.is_empty():
			continue
		var w: int = maxi(0, int(row[clampi(layer - 1, 0, row.size() - 1)]))
		if w > 0:
			out[kind] = w
	return out


# ノードの種類を1つ引く。{kind: weight} の重み付き抽選。
#
# ⚠ _roll_node_kind()（シナリオ側）を借りない。⚠ 保険で返す値が別の定数だから
#   （あちらは FLOOR_NODE_KIND_BATTLE）。⚠ 借りると、片方の保険を直したときに
#   もう片方が黙って変わる。
# ⚠ _roll_weighted_table() も使わない。あちらは {item_id: count} を返す
#   「何個もらえるか」の口で、用途が違う。
func _roll_dungeon_node_kind(weights: Dictionary) -> String:
	var total: int = 0
	for kind: Variant in weights:
		total += maxi(0, int(weights[kind]))
	if total <= 0:
		return GameStateKeys.DUNGEON_NODE_KIND_BATTLE
	var roll: int = randi() % total
	# ⚠ キーの並び順に依存しないよう綴り順で回す（Dictionary のキー順は不定）。
	var kinds: Array = weights.keys()
	kinds.sort()
	for kind: Variant in kinds:
		roll -= maxi(0, int(weights[kind]))
		if roll < 0:
			return str(kind)
	return GameStateKeys.DUNGEON_NODE_KIND_BATTLE


# ノード1つぶんの敵（戦闘が引く。段階17-b）。
#
# ⚠ ボスなら dungeon.json の boss、それ以外は battle_pool から1本引く。
# ⚠ 戦闘画面が battle_pool を直接読まないこと（引き方が2箇所になる）。
func get_dungeon_node_wave(node_id: String) -> Dictionary:
	if not is_in_dungeon():
		return {}
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(
		str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	)
	if dungeon.is_empty():
		return {}
	var node: Dictionary = get_dungeon_node(node_id)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
		var boss: Variant = dungeon.get(DUNGEON_MASTER_BOSS, null)
		if boss is Dictionary:
			return (boss as Dictionary).duplicate(true)
		push_warning("[GameManager] get_dungeon_node_wave: boss が無い")
		return {}
	var pool: Variant = dungeon.get(DUNGEON_MASTER_BATTLE_POOL, null)
	if not (pool is Array) or (pool as Array).is_empty():
		push_warning("[GameManager] get_dungeon_node_wave: battle_pool が無い")
		return {}
	var list: Array = pool as Array
	return (list[randi() % list.size()] as Dictionary).duplicate(true)


# --- 戦闘との接続（段階17-b・§4-4 / §4-4-2） --------------------------
#
# ⚠⚠ ここで書き換えてよいのは「ランの MAX HP」だけ。⚠ CHARACTER_GROWTH の
#   stats.hp には1文字も書かない（台帳 §7）。書くとセーブに削れた値が
#   焼き付いて二度と戻らない。

# そのノードがボスか。⚠ 判定の口はここ1本（戦闘画面が kind の綴りを比べない）。
func is_dungeon_boss_node(node_id: String) -> bool:
	var node: Dictionary = get_dungeon_node(node_id)
	if node.is_empty():
		return false
	return str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS


# 1人ぶんのランの MAX HP。⚠ ランに入っていなければ 0。
#
# ⚠ 素の MAX HP（get_effective_stats().hp）と混ぜないこと。戦闘に渡すのはこちら。
func get_dungeon_character_max_hp(character_id: String) -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var max_hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_MAX_HP, {})
	return int(max_hp.get(character_id, 0))


# 1人ぶんのランのいまの HP。
func get_dungeon_character_hp(character_id: String) -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_HP, {})
	return int(hp.get(character_id, 0))


# そのランのあいだ脱落しているか（ランの MAX HP が 0＝§4-4-2）。
#
# ⚠ 脱落は「そのランのあいだ」。⚠ ランを出れば素の MAX HP から満タンで始まる（決定9）。
# ⚠ 戻す口は 17-c（蘇生用ポーションと休憩場所）。⚠ 戦闘の中では戻さない（§4-9）。
func is_dungeon_character_downed(character_id: String) -> bool:
	if not is_in_dungeon():
		return false
	return get_dungeon_character_max_hp(character_id) <= 0


# 戦闘に出られる編成メンバー（脱落していない者）。
func get_dungeon_active_members() -> Array:
	var result: Array = []
	if not is_in_dungeon():
		return result
	for member: Variant in get_party_members():
		var character_id: String = str(member)
		if character_id == "" or is_dungeon_character_downed(character_id):
			continue
		result.append(character_id)
	return result


# 戦闘が終わったときの HP を、ランの MAX HP へ写す（§4-4「目減り」の実体）。
#
# ⚠⚠ これが目減りそのもの。⚠ 独立したつまみは無い（未決4）。⚠ 戦闘が削った量が
#   そのまま目減り量になる。⚠ ここに係数や下限を足さないこと（§4-4-1 で下限は撤回済み）。
# ⚠ HP も同じ値にする。⚠ 次の戦闘はその上限から始まる。
# ⚠ 書き込む口はここ1本。⚠ set_floor_hp_carry() を借りない（あちらは FLOOR_RUN）。
#
# 戻り値: 全員が脱落して「死亡」になったか（＝鞄を失ってランが終わったか）。
func apply_dungeon_battle_result(hp_by_character: Dictionary) -> bool:
	if not is_in_dungeon():
		return false
	if hp_by_character.is_empty():
		push_warning("[GameManager] W23 apply_dungeon_battle_result: 書き戻す HP が空。戦闘がランの HP を1人ぶんも返していない")
		return false

	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var max_hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_MAX_HP, {})
	var hp: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_HP, {})
	var lines: Array[String] = []
	for entry: Variant in hp_by_character:
		var character_id: String = str(entry)
		if not max_hp.has(character_id):
			# ⚠ ランに入ったときの編成に居ない者。⚠ 黙って欄を増やさない
			#   （増やすと「脱落していないのに MAX HP が無い」状態が作れてしまう）。
			push_warning("[GameManager] apply_dungeon_battle_result: ランの編成に居ないキャラ: " + character_id)
			continue
		var before: int = int(max_hp[character_id])
		var after: int = maxi(0, int(hp_by_character[character_id]))
		max_hp[character_id] = after
		hp[character_id] = after
		lines.append("%s %d -> %d" % [character_id, before, after])
	run[GameStateKeys.DUNGEON_RUN_MAX_HP] = max_hp
	run[GameStateKeys.DUNGEON_RUN_HP] = hp
	_state[GameStateKeys.DUNGEON_RUN] = run

	print("[GameManager] apply_dungeon_battle_result: ランのMAX HP %s" % " / ".join(lines))

	# 全員が脱落＝死亡（§4-4-2）。⚠ 鞄を失う。⚠ 装備は失わない（決定7。
	#   鞄に持ち込みが入らないので、条件分岐を書かずに構造で外れている）。
	if get_dungeon_active_members().is_empty():
		print("[GameManager] 編成が全員脱落した -> 死亡（鞄を失う）")
		abandon_dungeon_run()
		return true

	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return false


# --- ラン専用アイテムと休憩（段階17-c・§4-3 / §4-9） -------------------
#
# ⚠⚠ 戦闘の外だけ。⚠ 戦闘の中からここを呼ばないこと（§4-9）。
#   ⚠ 中で使えるようにすると「死者を対象に取る」器が要り、規模が跳ねる。
# ⚠ 基準は全部「素の MAX HP」。⚠ 戦闘時 MAX HP を基準にしない（DungeonConfig のコメント）。

# 素の MAX HP（育成の値）。⚠ ポーションと蘇生と休憩が戻す量の基準。
#
# ⚠ 読むだけ。⚠ CHARACTER_GROWTH には1文字も書かない（台帳 §7）。
func get_dungeon_base_max_hp(character_id: String) -> int:
	return int(get_effective_stats(character_id).get(GameStateKeys.STAT_HP, 0))


# その品がランの中で何をするか（"" なら何もしない品）。
func get_dungeon_item_effect(item_id: String) -> String:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return ""
	if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_DUNGEON:
		return ""
	return str(definition.get(ITEM_MASTER_DUNGEON_EFFECT, ""))


# 鞄のものを1個使う。⚠ 使う口はここ1本（画面も道具もここを通す）。
#
# ⚠ 状態を触る前に判定を全部終える（CLAUDE.md 6番）。⚠ 途中で弾くと
#   「鞄からは減ったのに効いていない」が起きる。
# ⚠ 効かない相手には使わせない（満タンの者に回復・生きている者に蘇生）。
#   ⚠ 鞄の枠は資源なので、無駄撃ちを黙って受け付けないこと。
func use_dungeon_item(item_id: String, character_id: String) -> bool:
	if not is_in_dungeon():
		push_warning("[GameManager] use_dungeon_item: ランに入っていない")
		return false
	var config: DungeonConfig = _dungeon()
	if config == null:
		return false
	if int(get_dungeon_bag().get(item_id, 0)) <= 0:
		print("[GameManager] use_dungeon_item('%s') -> false（鞄に無い）" % item_id)
		return false
	var effect: String = get_dungeon_item_effect(item_id)
	var base_max_hp: int = get_dungeon_base_max_hp(character_id)
	if base_max_hp <= 0:
		print("[GameManager] use_dungeon_item('%s') -> false（編成に居ないキャラ: %s）" % [item_id, character_id])
		return false

	match effect:
		DUNGEON_EFFECT_HEAL:
			if is_dungeon_character_downed(character_id):
				print("[GameManager] use_dungeon_item('%s') -> false（%s は脱落している。要るのは蘇生）" % [item_id, character_id])
				return false
			if get_dungeon_character_max_hp(character_id) >= base_max_hp:
				print("[GameManager] use_dungeon_item('%s') -> false（%s は満タン）" % [item_id, character_id])
				return false
		DUNGEON_EFFECT_REVIVE:
			if not is_dungeon_character_downed(character_id):
				print("[GameManager] use_dungeon_item('%s') -> false（%s は脱落していない）" % [item_id, character_id])
				return false
		_:
			print("[GameManager] use_dungeon_item('%s') -> false（ランの中で使える品ではない）" % item_id)
			return false

	# ここから状態を触る。
	_take_from_dungeon_bag(item_id, 1)
	if effect == DUNGEON_EFFECT_HEAL:
		_heal_dungeon_character(character_id, int(config.potion_heal_pct))
	else:
		_revive_dungeon_character(character_id)
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return true


# 鞄から取り出す。⚠ 減らす口はここ1本。⚠ 0 になったキーは消す（鞄の残量が狂う）。
func _take_from_dungeon_bag(item_id: String, count: int) -> void:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var bag: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_BAG, {})
	var left: int = int(bag.get(item_id, 0)) - count
	if left > 0:
		bag[item_id] = left
	else:
		bag.erase(item_id)
	run[GameStateKeys.DUNGEON_RUN_BAG] = bag
	_state[GameStateKeys.DUNGEON_RUN] = run


# 戦闘時 MAX HP を「素の MAX HP の pct％」ぶん戻す（上限は素の MAX HP）。
#
# ⚠⚠ HP は上限まで戻す。⚠ 「上限だけ上げて HP を据え置く」形にしないこと。
#   ⚠ 蘇生の直後だけ HP ＜ 上限になるが、そこを埋める手段が他に無く、
#     差が二度と埋まらないまま残る（決定18「上限で満タンから始まる」が崩れる）。
# ⚠ 脱落者（上限 0）には効かない。⚠ 呼ぶ前に弾くこと。
func _heal_dungeon_character(character_id: String, pct: int) -> void:
	var base_max_hp: int = get_dungeon_base_max_hp(character_id)
	var before: int = get_dungeon_character_max_hp(character_id)
	var healed: int = mini(base_max_hp, before + int(base_max_hp * pct / 100.0))
	_write_dungeon_hp(character_id, healed, healed)
	print("[GameManager] 回復: %s 戦闘時MAX HP %d -> %d（素 %d の %d%%）" % [
		character_id, before, healed, base_max_hp, pct
	])


# 脱落したキャラを戻す（決定13・§4-9-2）。⚠ 基準は素の MAX HP。
#
# ⚠ 戦闘時 MAX HP を基準にしないこと。⚠ 脱落者はそれが 0 なので、何％でも 0 のまま。
func _revive_dungeon_character(character_id: String) -> void:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return
	var base_max_hp: int = get_dungeon_base_max_hp(character_id)
	var max_hp: int = maxi(1, int(base_max_hp * int(config.revive_max_hp_pct) / 100.0))
	var hp: int = maxi(1, int(max_hp * int(config.revive_hp_pct) / 100.0))
	_write_dungeon_hp(character_id, max_hp, hp)
	print("[GameManager] 蘇生: %s 戦闘時MAX HP 0 -> %d ／ HP %d（素 %d）" % [
		character_id, max_hp, hp, base_max_hp
	])


# ランの HP を書く。⚠ 書く口はここ1本（apply_dungeon_battle_result も通す形にしない
#   ＝あちらは全員ぶんをまとめて書き、死亡の判定まで持つ。⚠ こちらは1人ぶん）。
# ⚠ HP は上限を超えない。
func _write_dungeon_hp(character_id: String, max_hp: int, hp: int) -> void:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var max_hp_map: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_MAX_HP, {})
	var hp_map: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_HP, {})
	if not max_hp_map.has(character_id):
		push_warning("[GameManager] _write_dungeon_hp: ランの編成に居ないキャラ: " + character_id)
		return
	max_hp_map[character_id] = maxi(0, max_hp)
	hp_map[character_id] = clampi(hp, 0, maxi(0, max_hp))
	run[GameStateKeys.DUNGEON_RUN_MAX_HP] = max_hp_map
	run[GameStateKeys.DUNGEON_RUN_HP] = hp_map
	_state[GameStateKeys.DUNGEON_RUN] = run


# 休憩ノードに着いた（§4-9・蘇生の2本目）。
#
# ⚠ 呼ぶのは move_in_dungeon() の1本。⚠ 「休む」ボタンを作らないこと（17-d）。
#   ⚠ 踏んだら効くのが仕様。⚠ コストは「その層の戦闘・レリック・戦利品を諦めたこと」で
#     もう払っている（§4-9-1）。⚠ ここで追加の対価を取らない。
# ⚠ 戻すのは生きている者の回復が先、⚠ そのあと脱落者を rest_revive_count 人まで。
#   ⚠ 順番を入れ替えないこと。⚠ 先に蘇生すると、その者が回復の対象に入って
#     「休憩1回で満タンの仲間が増える」（決定13 の半分が効かなくなる）。
func apply_dungeon_rest() -> void:
	if not is_in_dungeon():
		return
	var config: DungeonConfig = _dungeon()
	if config == null:
		return
	print("[GameManager] 休憩ノード: 回復 %d%% ／ 蘇生 %d 人まで" % [
		int(config.rest_heal_pct), int(config.rest_revive_count)
	])
	for member: Variant in get_party_members():
		var character_id: String = str(member)
		if character_id == "" or is_dungeon_character_downed(character_id):
			continue
		if get_dungeon_character_max_hp(character_id) >= get_dungeon_base_max_hp(character_id):
			continue
		_heal_dungeon_character(character_id, int(config.rest_heal_pct))

	var revived: int = 0
	for member: Variant in get_party_members():
		if revived >= int(config.rest_revive_count):
			break
		var character_id: String = str(member)
		if character_id == "" or not is_dungeon_character_downed(character_id):
			continue
		_revive_dungeon_character(character_id)
		revived += 1


# --- 通路の効果（段階19-c-2・人間の決定24・台帳 §5-3-1） -------------
#
# ⚠⚠ 効かせる口はここ1本だけ。⚠ 2本目を書かないこと。
# ⚠ 呼ぶのは move_in_dungeon() だけ（⚠ 通った瞬間に効く）。
# ⚠ 宝箱だけ「持ち越し」にする（⚠ 画面を出すため）。⚠ 他は即座に効く。

# 直前に通った通路で何が起きたか（段階20-d・人間の指示「⚠ 何かわかるような演出がしたい」）。
#
# ⚠⚠ 状態（`_state`）に入れない。⚠ セーブに残るものではなく、⚠ 「いま出す1回」だけの値。
#   ⚠ 入れると `load_state()` の正規化と状態の表を触ることになる。
# ⚠ 形： {effect: String, amount: int, items: {item_id: 個数}}
#   ⚠ amount の意味は effect ごとに違う（⚠ HP＝削った量 ／ 通貨＝増減 ／ 鞄＝落とした個数）。
# ⚠ 画面が数字を組み立て直さない（⚠ ここが唯一の出どころ）。
var _last_dungeon_edge_event: Dictionary = {}


# 直前の通路のできごと。⚠ 何も起きていなければ空。⚠ 画面はこの1本に聞く。
func get_last_dungeon_edge_event() -> Dictionary:
	return _last_dungeon_edge_event.duplicate(true)


# 通った通路の効果を効かせる。
#
# ⚠ to_node_id は行き先。⚠ 宝箱の持ち越しに「どこで出たか」として記録する。
func _apply_dungeon_edge_effect(effect: String, to_node_id: String) -> void:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return
	# ⚠ 「何が起きたか」を必ず埋める（⚠ 埋め忘れると画面が黙る）。
	# ⚠ `left_behind` は「鞄が満杯で拾えなかったもの」（⚠ 宝箱の戻り値と同じ形）。
	#   ⚠ 空でなければ画面は「拾った」ではなく「拾えなかった」と言う。
	_last_dungeon_edge_event = {
		GameStateKeys.DUNGEON_EDGE_EFFECT: effect, "amount": 0, "items": {}, "left_behind": {},
	}
	match effect:
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_HP:
			_last_dungeon_edge_event["amount"] = _apply_dungeon_edge_trap_hp(
				int(config.edge_trap_hp_pct)
			)
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_CURRENCY:
			var lost: int = mini(get_dungeon_currency(), maxi(0, int(config.edge_trap_currency)))
			add_dungeon_currency(-lost)
			_last_dungeon_edge_event["amount"] = lost
			print("[GameManager] 通路の罠（通貨）: %d 失った -> 残り %d" % [lost, get_dungeon_currency()])
		GameStateKeys.DUNGEON_EDGE_EFFECT_TRAP_BAG:
			var dropped: Dictionary = _apply_dungeon_edge_trap_bag(
				maxi(0, int(config.edge_trap_bag_count))
			)
			_last_dungeon_edge_event["items"] = dropped
			for dropped_id: Variant in dropped:
				_last_dungeon_edge_event["amount"] = int(_last_dungeon_edge_event["amount"]) \
					+ int(dropped[dropped_id])
		GameStateKeys.DUNGEON_EDGE_EFFECT_CHEST:
			_set_dungeon_corridor_chest(to_node_id)
			print("[GameManager] 通路の宝箱: 持ち越した（行き先 %s）" % to_node_id)
		GameStateKeys.DUNGEON_EDGE_EFFECT_RESOURCE:
			var gained: Dictionary = _apply_dungeon_edge_resource()
			_last_dungeon_edge_event["amount"] = int(gained.get("currency", 0))
			_last_dungeon_edge_event["items"] = gained.get("items", {})
			_last_dungeon_edge_event["left_behind"] = gained.get("left_behind", {})
		_:
			push_warning("[GameManager] W33 知らない通路の効果（何も起きない）: " + effect)
			_last_dungeon_edge_event = {}


# 罠（HP）。⚠ 編成の全員の戦闘時 MAX HP を、素の MAX HP の pct% ぶん削る。
#
# ⚠⚠ 罠では脱落させない（⚠ 最低1は残す）。⚠ 死ぬのは戦闘だけ（§4-4-2）。
#   ⚠ 見えない通路を通っただけで全ロストになるのは、⚠ 一貫原則ではなく理不尽。
#   ⚠ 設計役の判断。⚠ 覆すならここの maxi(1, ...) を外す。
# ⚠ 脱落している者は飛ばす（⚠ 0 を削っても意味が無い）。
# ⚠ HP と上限は常に同じ値（決定18）。⚠ 2つ別々に書かないこと。
# 戻り値: 実際に削った合計（⚠ 画面が「どれだけ減ったか」を出すのに使う）。
func _apply_dungeon_edge_trap_hp(pct: int) -> int:
	var lost_total: int = 0
	for member: Variant in get_party_members():
		var character_id: String = str(member)
		if character_id == "" or is_dungeon_character_downed(character_id):
			continue
		var base_max_hp: int = get_dungeon_base_max_hp(character_id)
		var before: int = get_dungeon_character_max_hp(character_id)
		var after: int = maxi(1, before - int(base_max_hp * pct / 100.0))
		_write_dungeon_hp(character_id, after, after)
		lost_total += before - after
		print("[GameManager] 通路の罠（HP）: %s 戦闘時MAX HP %d -> %d（素 %d の %d%%・⚠ 脱落はさせない）" % [
			character_id, before, after, base_max_hp, pct
		])
	return lost_total


# 罠（鞄）。⚠ 鞄から count 個落とす。⚠ 鞄が空なら何も起きない。
#
# ⚠ 落とすものは綴り順の先頭（⚠ add_to_dungeon_bag と同じ流儀）。
#   ⚠ 乱数で選ばないこと。⚠ 起動ごとに結果が変わると検証が読めなくなる。
# 戻り値: 落としたもの（{item_id: 個数}）。⚠ 画面が「何を落としたか」を出すのに使う。
func _apply_dungeon_edge_trap_bag(count: int) -> Dictionary:
	var dropped: Dictionary = {}
	if count <= 0:
		return dropped
	for _i: int in range(count):
		var bag: Dictionary = get_dungeon_bag()
		var item_ids: Array = bag.keys()
		if item_ids.is_empty():
			break
		item_ids.sort()
		var item_id: String = str(item_ids[0])
		var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
		var live_bag: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_BAG, {})
		var left: int = int(live_bag.get(item_id, 0)) - 1
		if left > 0:
			live_bag[item_id] = left
		else:
			live_bag.erase(item_id)
		run[GameStateKeys.DUNGEON_RUN_BAG] = live_bag
		_state[GameStateKeys.DUNGEON_RUN] = run
		dropped[item_id] = int(dropped.get(item_id, 0)) + 1
	print("[GameManager] 通路の罠（鞄）: 落とした %s -> 鞄 %d/%d" % [
		str(dropped), get_dungeon_bag_used(), get_dungeon_bag_slots()
	])
	return dropped


# 資源。⚠ 一時通貨か素材のどちらか（⚠ 通路ごとに抽選＝人間の決定24）。
#
# ⚠ 表は dungeon.json の edges.resource。⚠ 通貨の額だけ Config（つまみ）。
# ⚠ 素材は鞄へ。⚠ 鞄が満杯なら入らない（⚠ 勝手に何かを捨てない）。
# 戻り値: {"currency": int, "items": {item_id: 個数}}。⚠ 画面が「何を拾ったか」を出すのに使う。
func _apply_dungeon_edge_resource() -> Dictionary:
	var result: Dictionary = {"currency": 0, "items": {}, "left_behind": {}}
	var config: DungeonConfig = _dungeon()
	if config == null:
		return result
	var row: Dictionary = _roll_dungeon_edge_resource()
	if row.is_empty():
		return result
	if str(row.get(DUNGEON_EDGES_KIND, "")) == DUNGEON_EDGES_KIND_CURRENCY:
		var amount: int = maxi(0, int(config.edge_resource_currency))
		add_dungeon_currency(amount)
		result["currency"] = amount
		print("[GameManager] 通路の資源（通貨）: +%d -> %d" % [amount, get_dungeon_currency()])
		return result
	# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
	var item_id: String = str(row.get(CHEST_DRAW_ITEM_ID, ""))
	var count: int = maxi(1, int(row.get("count", 1)))
	# ⚠⚠ 段階20-e：⚠ 鞄へ直接入れない。⚠ 拾い待ちへ積み、⚠ プレイヤーが選ぶ
	#   （⚠ 人間の指示「インベントリの中に何を入れるか選べるように」）。
	#   ⚠ 拾い待ちには枠が無いので `left_behind` は出ない。
	_add_dungeon_pending_loot(item_id, count)
	(result["items"] as Dictionary)[item_id] = count
	print("[GameManager] 通路の資源（素材）: %s x%d -> 拾い待ちへ（鞄 %d/%d）" % [
		item_id, count, get_dungeon_bag_used(), get_dungeon_bag_slots()
	])
	return result


# edges.resource を1行引く。⚠ 重み付き。⚠ 引けなければ空。
func _roll_dungeon_edge_resource() -> Dictionary:
	var edges: Variant = MasterDataLoader.get_dungeon(
		str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	).get(DUNGEON_MASTER_EDGES, null)
	if not (edges is Dictionary):
		return {}
	var rows: Variant = (edges as Dictionary).get(DUNGEON_EDGES_RESOURCE, null)
	if not (rows is Array) or (rows as Array).is_empty():
		return {}
	var total: int = 0
	for raw: Variant in (rows as Array):
		if raw is Dictionary:
			total += maxi(0, int((raw as Dictionary).get(DUNGEON_EDGES_WEIGHT, 0)))
	if total <= 0:
		return {}
	var roll: int = randi() % total
	for raw: Variant in (rows as Array):
		if not (raw is Dictionary):
			continue
		roll -= maxi(0, int((raw as Dictionary).get(DUNGEON_EDGES_WEIGHT, 0)))
		if roll < 0:
			return (raw as Dictionary).duplicate(true)
	return {}


# --- 通路の宝箱（段階19-c-2） -----------------------------------------
#
# ⚠⚠ 通路には cleared を置く場所が無い（⚠ あれはノードの欄）。
#   ⚠ 代わりに DUNGEON_RUN に「持ち越し」を1本だけ持つ（⚠ 台帳 §5-3-1）。
# ⚠ 開けるまで残る＝⚠ 開けずにマップへ戻っても取りに行き直せる。
# ⚠ 画面は dungeon_chest.tscn を共有する（⚠ 人間の指示。⚠ 画面を分けない）。

# いま持ち越している通路の宝箱があるか。⚠ 画面はこの1本に聞く。
func has_pending_dungeon_corridor_chest() -> bool:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return str(run.get(GameStateKeys.DUNGEON_RUN_CORRIDOR_CHEST, "")) != ""


func _set_dungeon_corridor_chest(to_node_id: String) -> void:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_CORRIDOR_CHEST] = to_node_id
	_state[GameStateKeys.DUNGEON_RUN] = run


# 通路の宝箱を開ける。
#
# 戻り値: {"granted": {item_id: 個数}, "left_behind": {item_id: 個数}}
#
# ⚠ open_dungeon_chest()（マスの宝箱）と1本にまとめない。⚠ 覚え方が別
#   （⚠ あちらはノードの cleared、⚠ こちらは持ち越しの欄）。⚠ 混ぜると
#   「どちらを消したか」が読めなくなる。
# ⚠ 状態を触る前に判定を全部終える（CLAUDE.md 6番）。
# ⚠ 先に持ち越しを消す。⚠ 配るほうが先だと、⚠ 鞄が満杯で1個も入らなかったときに
#   持ち越しが残り、⚠ 何度でも引き直せる（＝抽選し放題）。
func open_dungeon_corridor_chest() -> Dictionary:
	var empty: Dictionary = {"granted": {}, "left_behind": {}}
	if not is_in_dungeon():
		return empty
	if not has_pending_dungeon_corridor_chest():
		print("[GameManager] open_dungeon_corridor_chest: 持ち越している通路の宝箱が無い")
		return empty

	# --- ここから状態を変える ---
	_set_dungeon_corridor_chest("")
	# ⚠ 配る口は _grant_dungeon_node_gains() の1本のまま（⚠ 2本目を書かない）。
	#   ⚠ 表は loot.edge_chest（⚠ マスの宝箱より薄い＝rolls 1）。
	# ⚠ 拾い待ちへ積む（段階20-e）。⚠ 鞄へ入れるのはプレイヤーが選ぶ。
	var result: Dictionary = _grant_dungeon_node_gains(DUNGEON_LOOT_EDGE_CHEST, true)
	# ⚠ 段階20-e：⚠ 鞄には入らない。⚠ 拾い待ちへ積むだけ。
	print("[GameManager] open_dungeon_corridor_chest() -> 拾い待ちへ: %s（鞄 %d/%d は動かない）" % [
		str(result["granted"]), get_dungeon_bag_used(), get_dungeon_bag_slots(),
	])
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return result


# --- ランのレリック（段階17-e-2・人間の決定：⚠ 表はシナリオ側と共有する） ---
#
# ⚠⚠ `relics.json` の12件をそのまま使う（⚠ 人間の言葉：「レリックは簡単なほうの
#   シナリオのほうと共有でいいよ」）。⚠ ダンジョン専用の表は作らない。
# ⚠ 効果の器（パッシブ）も共有。⚠ 置き場だけ別（`DUNGEON_RUN_RELICS`）。
#   ⚠ `FLOOR_RUN_RELICS` を借りない（台帳 §7）。⚠ ランを出れば一緒に消える。
# ⚠ 選ぶ画面（floor_relic_select）は借りない。⚠ あちらは FLOOR_RUN を読む。

# 候補は「ノードごとに固定」。⚠ 描き直すたびに引き直さないこと。
#
# ⚠⚠ 状態に候補を持たせていない。⚠ 代わりに（ダンジョン・フロア・ノードID）から
#   決まる種で引く＝⚠ 何度呼んでも同じ3件が返る。
#   ⚠ 状態の欄を1つ増やさずに「固定」を作れるのでこの形にした。
#   ⚠ 種の作り方を変えると、⚠ 進行中のランの候補が入れ替わる（⚠ 触らないこと）。
func get_dungeon_relic_choices(node_id: String) -> Array:
	var result: Array = []
	if not is_in_dungeon():
		return result
	var node: Dictionary = get_dungeon_node(node_id)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) != GameStateKeys.DUNGEON_NODE_KIND_RELIC:
		return result
	var pool: Array[String] = MasterDataLoader.get_all_relic_ids()
	if pool.is_empty():
		push_warning("[GameManager] get_dungeon_relic_choices: relics.json が空")
		return result
	var config: DungeonConfig = _dungeon()
	var count: int = 3 if config == null else maxi(1, int(config.relic_choice_count))

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%s" % [
		str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")),
		get_dungeon_floor_index(), node_id,
	])
	var remaining: Array[String] = pool.duplicate()
	while result.size() < count and not remaining.is_empty():
		result.append(remaining.pop_at(rng.randi() % remaining.size()))
	return result


# レリックを1つ取る（段階17-e-2）。
#
# ⚠ 状態を触る前に判定を全部終える（CLAUDE.md 6番）。
# ⚠ 踏んだノードでしか取れない。⚠ 1ノードにつき1つだけ（⚠ cleared で覚える）。
# ⚠ 1人用なのに character_id が空なら弾く。⚠ 全体用なら空に直す（take_relic と同じ形）。
func take_dungeon_relic(node_id: String, relic_id: String, character_id: String = "") -> bool:
	if not is_in_dungeon():
		return false
	if str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")) != node_id:
		print("[GameManager] take_dungeon_relic: そのノードに居ない: " + node_id)
		return false
	var node: Dictionary = get_dungeon_node(node_id)
	if bool(node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
		print("[GameManager] take_dungeon_relic: もう取っている: " + node_id)
		return false
	if not (relic_id in get_dungeon_relic_choices(node_id)):
		print("[GameManager] take_dungeon_relic: 候補に無い: " + relic_id)
		return false
	var single: bool = is_single_relic(relic_id)
	var owner: String = character_id if single else ""
	if single:
		if owner == "" or not (owner in get_party_members()):
			print("[GameManager] take_dungeon_relic: 1人用なのに相手が決まっていない: " + relic_id)
			return false
		# ⚠ 脱落しているキャラには付けない（⚠ そのランのあいだ戦闘に出ない）。
		if is_dungeon_character_downed(owner):
			print("[GameManager] take_dungeon_relic: 脱落しているキャラには付けられない: " + owner)
			return false

	# --- ここから状態を変える ---
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var relics: Array = run.get(GameStateKeys.DUNGEON_RUN_RELICS, [])
	relics.append({
		GameStateKeys.DUNGEON_RELIC_ID: relic_id,
		GameStateKeys.DUNGEON_RELIC_CHARACTER_ID: owner,
	})
	run[GameStateKeys.DUNGEON_RUN_RELICS] = relics
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	(nodes[node_id] as Dictionary)[GameStateKeys.DUNGEON_NODE_CLEARED] = true
	run[GameStateKeys.DUNGEON_RUN_NODES] = nodes
	_state[GameStateKeys.DUNGEON_RUN] = run

	print("[GameManager] take_dungeon_relic('%s', '%s') -> 所持 %d 件" % [relic_id, owner, relics.size()])
	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return true


# --- 宝箱のマス（段階19-b・5つ目のノード種） --------------------------
#
# ⚠⚠ 案A＝「その場で開く」（⚠ 設計役の推奨。⚠ 台帳 §4-8 の決定7 と噛み合う）。
#   ⚠ 拠点の `PENDING_CHESTS` には1件も積まない。⚠ 積むと「死んでも宝箱は残る」に
#     なり、⚠ 全ロストの一貫原則が1点で崩れる。
# ⚠ 中身は鞄へ入る。⚠ 鞄が満杯なら入らない（＝拾えない）。⚠ 勝手に何かを捨てない。
# ⚠ 開けるまで中身は決まらない（⚠ 抽選は開けた瞬間）。⚠ レリックのように
#   「ノードごとに固定の種で先に見せる」形にしていない。⚠ 見せてしまうと
#   「開けるか開けないか」の選択が消え、⚠ ただの確認ボタンになる。

# 宝箱を開ける。
#
# 戻り値: {"granted": {item_id: 個数}, "left_behind": {item_id: 個数}}
#         ⚠ 開けられなかったときは両方とも空。⚠ 成否は was_dungeon_chest_opened() で見る。
#
# ⚠ 状態を触る前に判定を全部終える（CLAUDE.md 6番）。
# ⚠ 踏んだノードでしか開けられない。⚠ 1ノードにつき1回だけ（⚠ cleared で覚える）。
#   ⚠ take_dungeon_relic() と同じ形にしてある。⚠ 判定の順番を変えないこと。
func open_dungeon_chest(node_id: String) -> Dictionary:
	var empty: Dictionary = {"granted": {}, "left_behind": {}}
	if not is_in_dungeon():
		return empty
	if str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_POSITION, "")) != node_id:
		print("[GameManager] open_dungeon_chest: そのノードに居ない: " + node_id)
		return empty
	var node: Dictionary = get_dungeon_node(node_id)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) != GameStateKeys.DUNGEON_NODE_KIND_CHEST:
		print("[GameManager] open_dungeon_chest: 宝箱のマスではない: " + node_id)
		return empty
	if bool(node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false)):
		print("[GameManager] open_dungeon_chest: もう開けている: " + node_id)
		return empty

	# --- ここから状態を変える ---
	# ⚠ 先に cleared を立てる。⚠ 配るほうが先だと、⚠ 鞄が満杯で1個も入らなかったときに
	#   「開いていない宝箱」が残り、⚠ 何度でも引き直せる（＝抽選し放題になる）。
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	(nodes[node_id] as Dictionary)[GameStateKeys.DUNGEON_NODE_CLEARED] = true
	run[GameStateKeys.DUNGEON_RUN_NODES] = nodes
	_state[GameStateKeys.DUNGEON_RUN] = run

	# ⚠ 配る口は _grant_dungeon_node_gains() の1本だけ（⚠ 2本目を書かない）。
	#   ⚠ 一時通貨も同じ口が配る（dungeon.json の currency.chest）。
	# ⚠ 拾い待ちへ積む（段階20-e）。⚠ 鞄へ入れるのはプレイヤーが選ぶ。
	var result: Dictionary = _grant_dungeon_node_gains(GameStateKeys.DUNGEON_NODE_KIND_CHEST, true)
	# ⚠ 段階20-e：⚠ 鞄には入らない。⚠ 拾い待ちへ積むだけ（⚠ 入れるのはプレイヤーが選ぶ）。
	print("[GameManager] open_dungeon_chest('%s') -> 拾い待ちへ: %s（鞄 %d/%d は動かない）" % [
		node_id, str(result["granted"]), get_dungeon_bag_used(), get_dungeon_bag_slots(),
	])
	dungeon_run_changed.emit(str(run[GameStateKeys.DUNGEON_RUN_DUNGEON_ID]))
	return result


# その宝箱をもう開けたか。⚠ 画面が「開ける」を出すかの判定はこれ1本。
#
# ⚠ 画面側で cleared を読まないこと（⚠ 判定を2箇所にしない）。
func was_dungeon_chest_opened(node_id: String) -> bool:
	var node: Dictionary = get_dungeon_node(node_id)
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) != GameStateKeys.DUNGEON_NODE_KIND_CHEST:
		return false
	return bool(node.get(GameStateKeys.DUNGEON_NODE_CLEARED, false))


# いま持っているレリック（{relic_id, character_id} の配列）。
func get_dungeon_relics() -> Array:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var relics: Array = run.get(GameStateKeys.DUNGEON_RUN_RELICS, [])
	return relics.duplicate(true)


# そのキャラに効くレリックのID配列（段階17-e-2）。
#
# ⚠ get_floor_relic_passives() と1本にまとめない（⚠ 読む器が別）。
# ⚠ get_battle_passives() にも混ぜない（⚠ あちらは恒久のパッシブで育成画面にも出る）。
# ⚠ 戦闘画面が足して unit.passive_ids に入れる。
func get_dungeon_relic_passives(character_id: String) -> Array:
	var result: Array = []
	if not is_in_dungeon():
		return result
	for entry: Variant in get_dungeon_relics():
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var owner: String = str(row.get(GameStateKeys.DUNGEON_RELIC_CHARACTER_ID, ""))
		if owner != "" and owner != character_id:
			continue
		result.append(str(row.get(GameStateKeys.DUNGEON_RELIC_ID, "")))
	return result


# --- ランのショップ・たいまつ・鞄の枠（段階17-e・§4-7 / §5-0） -------
#
# ⚠⚠ ショップが出るのは「ボスを倒した先」だけ（決定15）。⚠ 判定は
#   can_retreat_from_dungeon() を使い回す（⚠ phase の綴りを2箇所で比べない）。
# ⚠ 拠点のショップ（purchase_shop_item）を借りない。⚠ 通貨が別（ゴールド／一時通貨）。
# ⚠ 倉庫の枠拡張（expand_inventory）も借りない。⚠ 器も通貨も別。

# dungeon.json の shop のキー。
const DUNGEON_MASTER_SHOP: String = "shop"
const DUNGEON_SHOP_ENTRIES: String = "entries"
const DUNGEON_SHOP_KIND: String = "kind"
const DUNGEON_SHOP_COST: String = "cost"
const DUNGEON_SHOP_AMOUNT: String = "amount"
# ⚠ 品の種類は3つ。⚠ 増やすときは buy_dungeon_shop_entry() の分岐と
#   E136 の検証も同じ回に足すこと（AGENTS.md「欄だけ足して実装しない」）。
const DUNGEON_SHOP_KIND_ITEM: String = "item"
const DUNGEON_SHOP_KIND_BAG_SLOT: String = "bag_slot"
const DUNGEON_SHOP_KIND_TORCH: String = "torch"

# 断る理由（"" なら買える）。⚠ 画面はこの1本に聞く。
const DUNGEON_SHOP_REJECT_CLOSED: String = "closed"
const DUNGEON_SHOP_REJECT_CURRENCY: String = "currency"
const DUNGEON_SHOP_REJECT_BAG: String = "bag"
const DUNGEON_SHOP_REJECT_TORCH_MAX: String = "torch_max"


# ショップに並ぶもの。⚠ dungeon.json の表をそのまま返す（⚠ 並びも表のまま）。
#
# ⚠ ボスの先に居ないときは空（＝店が無い）。⚠ 画面で phase を見ないこと。
func get_dungeon_shop_entries() -> Array:
	var result: Array = []
	if not can_retreat_from_dungeon():
		return result
	var dungeon: Dictionary = MasterDataLoader.get_dungeon(
		str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, ""))
	)
	var shop: Variant = dungeon.get(DUNGEON_MASTER_SHOP, null)
	if not (shop is Dictionary):
		return result
	for entry: Variant in ((shop as Dictionary).get(DUNGEON_SHOP_ENTRIES, []) as Array):
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


# その品を買えない理由（"" なら買える）。
#
# ⚠ 状態を触る前にここを通す（CLAUDE.md 6番）。⚠ 画面は理由をそのまま出す。
func get_dungeon_shop_reject_reason(index: int) -> String:
	var entries: Array = get_dungeon_shop_entries()
	if index < 0 or index >= entries.size():
		return DUNGEON_SHOP_REJECT_CLOSED
	var entry: Dictionary = entries[index]
	if get_dungeon_currency() < int(entry.get(DUNGEON_SHOP_COST, 0)):
		return DUNGEON_SHOP_REJECT_CURRENCY
	match str(entry.get(DUNGEON_SHOP_KIND, "")):
		DUNGEON_SHOP_KIND_ITEM:
			# ⚠ 鞄に空きが無ければ買わせない。⚠ 買ってから入らないと通貨だけ消える。
			if get_dungeon_bag_used() >= get_dungeon_bag_slots():
				return DUNGEON_SHOP_REJECT_BAG
		DUNGEON_SHOP_KIND_TORCH:
			if get_dungeon_torch_grade() >= get_dungeon_torch_max_grade():
				return DUNGEON_SHOP_REJECT_TORCH_MAX
		DUNGEON_SHOP_KIND_BAG_SLOT:
			pass
		_:
			return DUNGEON_SHOP_REJECT_CLOSED
	return ""


# ショップの品を1つ買う（段階17-e）。
#
# ⚠ 一時通貨で払う。⚠ ゴールドを1枚も触らない（決定16）。
# ⚠ 買ったものはランの中だけのもの。⚠ 撤退で持ち帰れるのは鞄の中身だけ（決定17）。
func buy_dungeon_shop_entry(index: int) -> bool:
	var reason: String = get_dungeon_shop_reject_reason(index)
	if reason != "":
		print("[GameManager] buy_dungeon_shop_entry(%d) -> false (%s)" % [index, reason])
		return false
	var entry: Dictionary = get_dungeon_shop_entries()[index]
	var kind: String = str(entry.get(DUNGEON_SHOP_KIND, ""))
	var cost: int = int(entry.get(DUNGEON_SHOP_COST, 0))
	var amount: int = maxi(1, int(entry.get(DUNGEON_SHOP_AMOUNT, 1)))

	# --- ここから状態を変える ---
	add_dungeon_currency(-cost)
	match kind:
		DUNGEON_SHOP_KIND_ITEM:
			# ⚠ 鞄へ入れる口は add_to_dungeon_bag() の1本（⚠ 拠点の倉庫には入れない）。
			var accepted: int = add_to_dungeon_bag(str(entry.get(SLOT_ENTRY_ITEM_ID, "")), 1)
			print("[GameManager] buy_dungeon_shop_entry(%d) -> 品 '%s' を %d 個（%d 払った）" % [
				index, str(entry.get(SLOT_ENTRY_ITEM_ID, "")), accepted, cost
			])
		DUNGEON_SHOP_KIND_BAG_SLOT:
			_set_dungeon_bag_slots(get_dungeon_bag_slots() + amount)
			print("[GameManager] buy_dungeon_shop_entry(%d) -> 鞄の枠 +%d（%d/%d・%d 払った）" % [
				index, amount, get_dungeon_bag_used(), get_dungeon_bag_slots(), cost
			])
		DUNGEON_SHOP_KIND_TORCH:
			_set_dungeon_torch_grade(get_dungeon_torch_grade() + 1)
			print("[GameManager] buy_dungeon_shop_entry(%d) -> たいまつ 等級%d（%d 層先まで見える・%d 払った）" % [
				index, get_dungeon_torch_grade(), get_dungeon_reveal_layers(), cost
			])
	dungeon_run_changed.emit(str(get_dungeon_run().get(GameStateKeys.DUNGEON_RUN_DUNGEON_ID, "")))
	return true


func _set_dungeon_bag_slots(slots: int) -> void:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_BAG_SLOTS] = maxi(0, slots)
	_state[GameStateKeys.DUNGEON_RUN] = run


func _set_dungeon_torch_grade(grade: int) -> void:
	var run: Dictionary = (_state[GameStateKeys.DUNGEON_RUN] as Dictionary).duplicate(true)
	run[GameStateKeys.DUNGEON_RUN_TORCH_GRADE] = clampi(grade, 0, get_dungeon_torch_max_grade())
	_state[GameStateKeys.DUNGEON_RUN] = run


# たいまつの等級（段階17-e）。⚠ フロアを降りると 0 に戻る（_apply_dungeon_map）。
func get_dungeon_torch_grade() -> int:
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	return int(run.get(GameStateKeys.DUNGEON_RUN_TORCH_GRADE, 0))


# たいまつの上限の等級。⚠ 配列の長さ − 1。
func get_dungeon_torch_max_grade() -> int:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return 0
	return maxi(0, (config.torch_reveal_layers as Array).size() - 1)


# いまのたいまつで何層先まで中身が見えるか。
func get_dungeon_reveal_layers() -> int:
	var config: DungeonConfig = _dungeon()
	if config == null:
		return 1
	var table: Array = config.torch_reveal_layers
	if table.is_empty():
		return 1
	return maxi(1, int(table[clampi(get_dungeon_torch_grade(), 0, table.size() - 1)]))


# そのノードの中身が見えているか（§4-7）。
#
# ⚠ 見せるのは「そこに何が在るか（ノード種）」まで。⚠ 敵と戦利品の中身は見せない。
# ⚠ ボスと踏んだノードは必ず見える（⚠ シナリオ側と同じ流儀）。
# ⚠ 画面で層を引き算しないこと。⚠ 判定はここ1本。
func is_dungeon_node_revealed(node_id: String) -> bool:
	if not is_in_dungeon():
		return false
	var node: Dictionary = get_dungeon_node(node_id)
	if node.is_empty():
		return false
	if str(node.get(GameStateKeys.DUNGEON_NODE_KIND, "")) == GameStateKeys.DUNGEON_NODE_KIND_BOSS:
		return true
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var visited: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_VISITED, {})
	if visited.has(node_id):
		return true
	var here: Dictionary = get_dungeon_node(str(run.get(GameStateKeys.DUNGEON_RUN_POSITION, "")))
	var here_layer: int = int(here.get(GameStateKeys.DUNGEON_NODE_LAYER, 1))
	var node_layer: int = int(node.get(GameStateKeys.DUNGEON_NODE_LAYER, 1))
	return node_layer - here_layer <= get_dungeon_reveal_layers()


# その通路の中身が見えているか（段階19-c-2・人間の決定23）。
#
# ⚠⚠ 規則はマスと同じ（⚠ 人間の指示：「ノードと同じ」）。⚠ 行き先が見えていれば通路も見える。
# ⚠ 画面で層を引き算しないこと。⚠ 判定はここ1本。
# ⚠ 通ったあとの通路は見える（⚠ 行き先が visited なので is_dungeon_node_revealed が true）。
func is_dungeon_edge_revealed(_from_node_id: String, to_node_id: String) -> bool:
	return is_dungeon_node_revealed(to_node_id)


# そのノードへ入ってくる通路（[{from, effect}]）。段階19-c-2。
#
# ⚠ 画面がマスの上に「そこへ行くと何があるか」を出すために使う。
# ⚠ 合流があるので複数返ることがある（⚠ 現在地から進める先なら1本に定まる）。
# ⚠ 効果が "" のものは返さない（⚠ 出すものが無い）。
func get_dungeon_incoming_edge_effects(to_node_id: String) -> Array:
	var result: Array = []
	if not is_in_dungeon():
		return result
	var run: Dictionary = _state.get(GameStateKeys.DUNGEON_RUN, {})
	var nodes: Dictionary = run.get(GameStateKeys.DUNGEON_RUN_NODES, {})
	# ⚠ Dictionary のキー順は不定。⚠ 綴り順で回す（⚠ 画面の並びが起動ごとに変わらない）。
	var from_ids: Array = nodes.keys()
	from_ids.sort()
	for from_id: Variant in from_ids:
		for entry: Variant in get_dungeon_edges(str(from_id)):
			var edge: Dictionary = entry
			if str(edge.get(GameStateKeys.DUNGEON_EDGE_TO, "")) != to_node_id:
				continue
			var effect: String = str(edge.get(GameStateKeys.DUNGEON_EDGE_EFFECT, ""))
			if effect == "":
				continue
			result.append({"from": str(from_id), GameStateKeys.DUNGEON_EDGE_EFFECT: effect})
	return result


# 難ダンジョンの設定を見る（E133 / W22）。
#
# ⚠ 見るのは「静かに間違った形で動く」種類だけ：割り当て漏れ・層の重みの長さ違い・
#   重みが全部0の層・dungeon.json の欠け・戦利品のIDが items.json に無い。
func _validate_dungeon_config() -> void:
	if Balance == null or Balance.dungeon == null:
		push_error("[GameManager] E133 balance.tscn: Balance.dungeon が null。dungeon_config.tres を Balance ノードの dungeon 欄に割り当てること")
		return

	var errors: int = 0
	var rows: Dictionary = {
		"layer_weight_battle": Balance.dungeon.layer_weight_battle,
		"layer_weight_relic": Balance.dungeon.layer_weight_relic,
		"layer_weight_rest": Balance.dungeon.layer_weight_rest,
		"layer_weight_chest": Balance.dungeon.layer_weight_chest,
	}
	var expected: int = (rows["layer_weight_battle"] as Array).size()
	for name: String in rows:
		var size: int = (rows[name] as Array).size()
		if size != expected:
			push_error("[GameManager] E133 dungeon_config.gd: %s の長さ %d が layer_weight_battle の %d と違う（層ごとの重みがずれる）" % [
				name, size, expected
			])
			errors += 1
	if expected <= 0:
		push_error("[GameManager] E133 dungeon_config.gd: 層の重みが空。層が1つも作れない")
		errors += 1
	for layer: int in range(1, expected + 1):
		if get_dungeon_layer_weights(layer).is_empty():
			push_error("[GameManager] E133 dungeon_config.gd: 層 %d の重みが全部 0（battle に落ちる）" % layer)
			errors += 1
	if int(Balance.dungeon.bag_initial_slots) <= 0:
		push_error("[GameManager] E133 dungeon_config.gd: bag_initial_slots が 0。戦利品を1つも拾えない")
		errors += 1
	# ⚠ 休憩で戦利品が出ると、休憩のコスト（その層の戦利品を諦める）が消える。
	if _dungeon_loot_chance_pct(GameStateKeys.DUNGEON_NODE_KIND_REST) > 0:
		push_warning("[GameManager] W22 dungeon_config.gd: 休憩ノードで戦利品が出る設定になっている。休憩を選ぶコストが消える（PLAN_HARD_DUNGEON.md §4-9-1）")

	# 宝箱のマス（段階19-b）。⚠ 見るのは「開けても何も出ない」「そもそも出現しない」の2つ。
	#   ⚠ どちらも赤も黄も出さずに黙って動くので、⚠ 遊んで気づくまで時間が溶ける。
	if _dungeon_loot_chance_pct(GameStateKeys.DUNGEON_NODE_KIND_CHEST) <= 0:
		push_error("[GameManager] E137 dungeon_config.gd: loot_chance_chest_pct が 0。宝箱を開けても何も出ない（PLAN_HARD_DUNGEON.md §5-2）")
		errors += 1
	# 通路の効果（段階19-c-2）。⚠ 見るのは「黙って何も起きない」種類だけ。
	if int(Balance.dungeon.edge_effect_chance_pct) <= 0:
		push_warning("[GameManager] W33 dungeon_config.gd: edge_effect_chance_pct が 0。通路が全部ただの線になる（たいまつを買う理由が消える＝PLAN_HARD_DUNGEON.md §5-3）")
	if int(Balance.dungeon.edge_effect_chance_pct) > 100:
		push_error("[GameManager] E139 dungeon_config.gd: edge_effect_chance_pct が 100 を超えている")
		errors += 1
	if int(Balance.dungeon.torch_initial_grade) > get_dungeon_torch_max_grade():
		push_error("[GameManager] E139 dungeon_config.gd: torch_initial_grade %d が上限の等級 %d を超えている" % [
			int(Balance.dungeon.torch_initial_grade), get_dungeon_torch_max_grade()
		])
		errors += 1
	for edge_dungeon_id: String in MasterDataLoader.get_all_dungeon_ids():
		var edge_master: Variant = MasterDataLoader.get_dungeon(edge_dungeon_id).get(DUNGEON_MASTER_EDGES, null)
		if not (edge_master is Dictionary):
			push_error("[GameManager] E139 dungeon.json: %s に edges が無い（通路に効果を付けられない）" % edge_dungeon_id)
			errors += 1
			continue
		# ⚠ 知らない effect は _dungeon_edge_effect_weights() が落とす。⚠ 落ちたことを言う。
		var raw_effects: Variant = (edge_master as Dictionary).get(DUNGEON_EDGES_EFFECTS, null)
		var written: int = (raw_effects as Array).size() if raw_effects is Array else 0
		var accepted: Dictionary = _dungeon_edge_effect_weights(edge_dungeon_id)
		if written != accepted.size():
			push_error("[GameManager] E139 dungeon.json: %s の edges.effects に知らない effect がある（書いた %d 行 / 読めた %d 行。綴りは %s）" % [
				edge_dungeon_id, written, accepted.size(), str(DUNGEON_EDGE_EFFECTS_KNOWN)
			])
			errors += 1
		var effect_total: int = 0
		for effect_name: String in accepted:
			effect_total += int(accepted[effect_name])
		if effect_total <= 0:
			push_error("[GameManager] E139 dungeon.json: %s の edges.effects の重みが全部 0（効果が1本も付かない）" % edge_dungeon_id)
			errors += 1
		# 資源の表。⚠ item の行は items.json に在るIDか（⚠ 無いと「拾えたのに消える」）。
		var raw_resource: Variant = (edge_master as Dictionary).get(DUNGEON_EDGES_RESOURCE, null)
		if not (raw_resource is Array) or (raw_resource as Array).is_empty():
			push_error("[GameManager] E139 dungeon.json: %s に edges.resource が無い（資源の通路で何も出ない）" % edge_dungeon_id)
			errors += 1
		else:
			for raw_row: Variant in (raw_resource as Array):
				if not (raw_row is Dictionary):
					continue
				var resource_kind: String = str((raw_row as Dictionary).get(DUNGEON_EDGES_KIND, ""))
				if resource_kind == DUNGEON_EDGES_KIND_CURRENCY:
					continue
				if resource_kind != DUNGEON_EDGES_KIND_ITEM:
					push_error("[GameManager] E139 dungeon.json: %s の edges.resource に知らない kind: %s" % [
						edge_dungeon_id, resource_kind
					])
					errors += 1
					continue
				var resource_item: String = str((raw_row as Dictionary).get(CHEST_DRAW_ITEM_ID, ""))
				if MasterDataLoader.get_item(resource_item).is_empty():
					push_error("[GameManager] E139 dungeon.json: %s の edges.resource に items.json に無いID: %s" % [
						edge_dungeon_id, resource_item
					])
					errors += 1
		# 通路の宝箱の表。⚠ 無いと「開けても何も出ない」（⚠ E137 と同じ理由）。
		var edge_loot: Variant = MasterDataLoader.get_dungeon(edge_dungeon_id).get(DUNGEON_MASTER_LOOT, null)
		var edge_chest_ok: bool = false
		if edge_loot is Dictionary:
			var edge_chest_row: Variant = (edge_loot as Dictionary).get(DUNGEON_LOOT_EDGE_CHEST, null)
			if edge_chest_row is Dictionary:
				edge_chest_ok = int((edge_chest_row as Dictionary).get(CHEST_DRAW_ROLLS, 0)) > 0
		if not edge_chest_ok:
			push_error("[GameManager] E139 dungeon.json: %s の loot.edge_chest が無いか rolls が 0（通路の宝箱を開けても何も出ない）" % edge_dungeon_id)
			errors += 1

	var chest_weight_total: int = 0
	for weight: Variant in (Balance.dungeon.layer_weight_chest as Array):
		chest_weight_total += maxi(0, int(weight))
	if chest_weight_total <= 0:
		push_warning("[GameManager] W30 dungeon_config.gd: layer_weight_chest が全層 0。宝箱のマスが1つも出ない（実装したのに到達しない）")

	# 層の数（段階19-d）。⚠ 重みの配列と dungeon.json の layers の長さが揃っているか。
	#   ⚠ 揃っていなくても clampi で末尾に落ちるので黙って動く。⚠ そこが危ない。
	for check_id: String in MasterDataLoader.get_all_dungeon_ids():
		var check_layers: Variant = MasterDataLoader.get_dungeon(check_id).get(DUNGEON_MASTER_LAYERS, null)
		if not (check_layers is Array):
			continue
		var layer_count: int = (check_layers as Array).size()
		if layer_count != expected:
			push_warning("[GameManager] W31 dungeon.json: %s の層 %d に対して層の重みが %d 本。足りないぶんは末尾の重みを使い回す" % [
				check_id, layer_count, expected
			])

	# dungeon.json 側。⚠ 1本も無ければ事故（ここへ来る＝実装済みのはず）。
	var dungeon_ids: Array[String] = MasterDataLoader.get_all_dungeon_ids()
	if dungeon_ids.is_empty():
		push_error("[GameManager] E133 dungeon.json: ダンジョンが1本も無い")
		errors += 1
	var checked_loot: int = 0
	for dungeon_id: String in dungeon_ids:
		var dungeon: Dictionary = MasterDataLoader.get_dungeon(dungeon_id)
		var layers: Variant = dungeon.get(DUNGEON_MASTER_LAYERS, null)
		if not (layers is Array) or (layers as Array).is_empty():
			push_error("[GameManager] E133 dungeon.json: %s に layers が無い" % dungeon_id)
			errors += 1
		if not (dungeon.get(DUNGEON_MASTER_BOSS, null) is Dictionary):
			push_error("[GameManager] E133 dungeon.json: %s に boss が無い（ボスに着いても倒せない）" % dungeon_id)
			errors += 1
		var pool: Variant = dungeon.get(DUNGEON_MASTER_BATTLE_POOL, null)
		if not (pool is Array) or (pool as Array).is_empty():
			push_error("[GameManager] E133 dungeon.json: %s に battle_pool が無い" % dungeon_id)
			errors += 1
		# 戦利品のIDが items.json に在るか。⚠ 無いIDは「拾えたのに消える」形で出る。
		var loot: Variant = dungeon.get(DUNGEON_MASTER_LOOT, null)
		if loot is Dictionary:
			for kind: Variant in (loot as Dictionary):
				var draw: Variant = (loot as Dictionary)[kind]
				if not (draw is Dictionary):
					continue
				var entries: Variant = (draw as Dictionary).get(CHEST_DRAW_ENTRIES, null)
				if not (entries is Array):
					continue
				for row: Variant in (entries as Array):
					if not (row is Dictionary):
						continue
					var item_id: String = str((row as Dictionary).get(CHEST_DRAW_ITEM_ID, ""))
					checked_loot += 1
					if MasterDataLoader.get_item(item_id).is_empty():
						push_error("[GameManager] E133 dungeon.json: %s の loot.%s に items.json に無いID: %s" % [
							dungeon_id, str(kind), item_id
						])
						errors += 1

	# ラン専用アイテムと休憩（段階17-c・E134 / W24）。
	#
	# ⚠ 見るのは「静かに間違った形で動く」種類だけ：割合が範囲の外・知らない効果・
	#   ポーションがどこからも出ない（＝目減りが一方通行になって必ず詰む）。
	var pct_rows: Dictionary = {
		"potion_heal_pct": int(Balance.dungeon.potion_heal_pct),
		"revive_max_hp_pct": int(Balance.dungeon.revive_max_hp_pct),
		"revive_hp_pct": int(Balance.dungeon.revive_hp_pct),
		"rest_heal_pct": int(Balance.dungeon.rest_heal_pct),
	}
	for pct_name: String in pct_rows:
		var pct: int = int(pct_rows[pct_name])
		if pct <= 0 or pct > 100:
			push_error("[GameManager] E134 dungeon_config.gd: %s が %d（1〜100 の外。0 だと使っても何も起きない）" % [
				pct_name, pct
			])
			errors += 1
	if int(Balance.dungeon.rest_revive_count) < 0:
		push_error("[GameManager] E134 dungeon_config.gd: rest_revive_count が負")
		errors += 1

	# ラン専用の品。⚠ 効果が空／知らない綴りだと、鞄に入るのに使えない品になる。
	var dungeon_items: Dictionary = {}
	for entry: Variant in MasterDataLoader.get_all_items():
		var item_id: String = str(entry)
		var definition: Dictionary = MasterDataLoader.get_item(item_id)
		if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_DUNGEON:
			continue
		var effect: String = str(definition.get(ITEM_MASTER_DUNGEON_EFFECT, ""))
		if effect != DUNGEON_EFFECT_HEAL and effect != DUNGEON_EFFECT_REVIVE:
			push_error("[GameManager] E134 items.json: %s の %s が '%s'（知らない効果。鞄に入るのに使えない）" % [
				item_id, ITEM_MASTER_DUNGEON_EFFECT, effect
			])
			errors += 1
			continue
		dungeon_items[effect] = int(dungeon_items.get(effect, 0)) + 1
	if int(dungeon_items.get(DUNGEON_EFFECT_HEAL, 0)) <= 0:
		push_error("[GameManager] E134 items.json: item_type='%s' の回復ポーションが0件。戦闘時 MAX HP が一方通行で削れて必ず詰む（PLAN_HARD_DUNGEON.md §4-3）" % GameStateKeys.ITEM_TYPE_DUNGEON)
		errors += 1
	# ⚠ 蘇生は「無いと詰む」ではないが（休憩でも戻る）、⚠ 休憩の人数が0なら詰む。
	if int(dungeon_items.get(DUNGEON_EFFECT_REVIVE, 0)) <= 0 and int(Balance.dungeon.rest_revive_count) <= 0:
		push_error("[GameManager] E134 蘇生の手段が1つも無い（蘇生ポーション0件 かつ rest_revive_count が 0）。1人脱落したらそのランは戻せない（§4-9）")
		errors += 1

	# ショップ（段階17-e・E136 / W29）。⚠ 見るのは「静かに間違った形で動く」種類だけ。
	var config_torch: Array = Balance.dungeon.torch_reveal_layers
	if config_torch.is_empty():
		push_error("[GameManager] E136 dungeon_config.gd: torch_reveal_layers が空。たいまつを買っても何も見えない")
		errors += 1
	for dungeon_id: String in dungeon_ids:
		var shop: Variant = MasterDataLoader.get_dungeon(dungeon_id).get(DUNGEON_MASTER_SHOP, null)
		if not (shop is Dictionary):
			push_warning("[GameManager] W29 dungeon.json: %s に shop が無い。ボスの先で何も買えない（PLAN_HARD_DUNGEON.md §5-0）" % dungeon_id)
			continue
		var potions: int = 0
		for entry: Variant in ((shop as Dictionary).get(DUNGEON_SHOP_ENTRIES, []) as Array):
			if not (entry is Dictionary):
				continue
			var row: Dictionary = entry
			var kind: String = str(row.get(DUNGEON_SHOP_KIND, ""))
			if int(row.get(DUNGEON_SHOP_COST, 0)) <= 0:
				push_error("[GameManager] E136 dungeon.json: %s の shop に値段 0 の品がある（タダで買える）" % dungeon_id)
				errors += 1
			match kind:
				DUNGEON_SHOP_KIND_ITEM:
					var shop_item_id: String = str(row.get(SLOT_ENTRY_ITEM_ID, ""))
					if MasterDataLoader.get_item(shop_item_id).is_empty():
						push_error("[GameManager] E136 dungeon.json: %s の shop に items.json に無いID: %s" % [
							dungeon_id, shop_item_id
						])
						errors += 1
					elif get_dungeon_item_effect(shop_item_id) != "":
						potions += 1
				DUNGEON_SHOP_KIND_BAG_SLOT:
					if int(row.get(DUNGEON_SHOP_AMOUNT, 1)) <= 0:
						push_error("[GameManager] E136 dungeon.json: %s の shop の bag_slot が 0 枠（買っても増えない）" % dungeon_id)
						errors += 1
				DUNGEON_SHOP_KIND_TORCH:
					pass
				_:
					push_error("[GameManager] E136 dungeon.json: %s の shop に知らない kind: '%s'" % [dungeon_id, kind])
					errors += 1
		# ⚠ セーフティネット（§4-3）。⚠ ポーションが1件も並ばないと、⚠ 目減りを戻す手が
		#   戦利品の運だけになる。
		if potions <= 0:
			push_warning("[GameManager] W29 dungeon.json: %s の shop にポーションが1件も無い（セーフティネットが消える・§4-3）" % dungeon_id)

	# ⚠ 品が在っても、どのダンジョンの戦利品表にも入っていなければ手に入らない。
	#   ⚠ ショップ（17-e）が入るまでは、戦利品が唯一の入口。
	var loot_has_dungeon_item: bool = false
	for dungeon_id: String in dungeon_ids:
		var loot: Variant = MasterDataLoader.get_dungeon(dungeon_id).get(DUNGEON_MASTER_LOOT, null)
		if not (loot is Dictionary):
			continue
		for kind: Variant in (loot as Dictionary):
			var draw: Variant = (loot as Dictionary)[kind]
			if not (draw is Dictionary):
				continue
			for row: Variant in ((draw as Dictionary).get(CHEST_DRAW_ENTRIES, []) as Array):
				if not (row is Dictionary):
					continue
				if get_dungeon_item_effect(str((row as Dictionary).get(CHEST_DRAW_ITEM_ID, ""))) != "":
					loot_has_dungeon_item = true
	if not loot_has_dungeon_item:
		push_warning("[GameManager] W24 dungeon.json: ラン専用の品が戦利品表に1件も入っていない。ランの中で手に入る口が無い（PLAN_HARD_DUNGEON.md §4-3）")

	if errors > 0:
		return
	print("[GameManager] dungeon config validated: %d 層 / 分岐の広がり %d / ダンジョン %d 本 / 戦利品の行 %d / ラン専用の品 %s, 0 errors" % [
		expected, int(Balance.dungeon.branch_spread), dungeon_ids.size(), checked_loot, str(dungeon_items)
	])
