class_name GameStateKeys
extends RefCounted

# GameManager.get_state() が返すDictionaryのキー。
# DATA_SCHEMA.md の各項目に対応。文字列リテラルではなくこの定数経由で組み立てる。
#
# 【重要】トップレベルだけでなく、ネストしたDictionaryのキーもここに定義する。
# Dictionaryは存在しないキーを読んでもエラーにならず null を返すため、
# キー名を推測して書くと実行するまで誤りに気づけない。必ずここの定数を使うこと。
# 構造の全体像は AGENTS.md「GameManagerの状態構造」を参照。
#
# 【編集ルール】このファイルは追記のみ。既存の定数を削除・改名しないこと。
# 定数が1つ消えるだけで、その定数を使う画面が起動できなくなる。

# ============================================================
# トップレベルキー
# ============================================================

const GOLD: String = "gold"
const GEMS: String = "gems"
const STAMINA: String = "stamina"
const MATERIALS: String = "materials"
const INVENTORY: String = "inventory"
const PENDING_CHESTS: String = "pending_chests"
const UNLOCKED_SCREENS: String = "unlocked_screens"
const SCENARIO_CHAPTER: String = "scenario_chapter"
const BOSS_UNLOCKED: String = "boss_unlocked"
const PITY_COUNTERS: String = "pity_counters"
const TOTAL_POMODORO_COMPLETED: String = "total_pomodoro_completed"
const LAST_POMODORO_END_AT: String = "last_pomodoro_end_at"
const SAVE_VERSION: String = "save_version"
const LAST_SAVED_AT: String = "last_saved_at"
const STORY: String = "story"
const TRAINING_MODE_UNLOCKED: String = "training_mode_unlocked"
const CODEX: String = "codex"
const DAILY_SHOP: String = "daily_shop"
const WEEKLY_SHOP: String = "weekly_shop"
const MONTHLY_SHOP: String = "monthly_shop"
const CHARACTER_GROWTH: String = "character_growth"
const RESEARCH_TREE: String = "research_tree"
const RECIPES_UNLOCKED: String = "recipes_unlocked"
const CRAFTING_QUEUE: String = "crafting_queue"

# ポモドーロ（当日の進捗・受け取り待ちの宝箱）
const CUMULATIVE_FOCUS_MINUTES_TODAY: String = "cumulative_focus_minutes_today"
const REACHED_CHEST_THRESHOLDS: String = "reached_chest_thresholds"
const UNCLAIMED_CHESTS: String = "unclaimed_chests"
const LAST_PROTECTION_SELECTED_AT: String = "last_protection_selected_at"
const SELECTED_PROTECTION_TYPE: String = "selected_protection_type"

# ============================================================
# ネストしたキー
# 命名規則：親キー名_子キー名（例：STAMINA 配下の "current" → STAMINA_CURRENT）
# ============================================================

# STAMINA: {"current": int, "max": int}
const STAMINA_CURRENT: String = "current"
const STAMINA_MAX: String = "max"

# INVENTORY: {item_id: {count, type, slot_position, properties}}
const ITEM_COUNT: String = "count"
const ITEM_TYPE: String = "type"
const ITEM_SLOT_POSITION: String = "slot_position"
const ITEM_PROPERTIES: String = "properties"
# slot_position: {"x": int, "y": int}
const POS_X: String = "x"
const POS_Y: String = "y"

# ITEM_TYPE に入る値（DATA_SCHEMA.md 1. inventory.type）
const ITEM_TYPE_EQUIPMENT: String = "equipment"
const ITEM_TYPE_CONSUMABLE: String = "consumable"
const ITEM_TYPE_KEY_ITEM: String = "key_item"
const ITEM_TYPE_GIFT: String = "gift"
const ITEM_TYPE_UNKNOWN: String = ""

# PENDING_CHESTS: [{chest_id, chest_type, source, obtained_at, opened, rewards}]
const CHEST_ID: String = "chest_id"
const CHEST_TYPE: String = "chest_type"
const CHEST_SOURCE: String = "source"
const CHEST_OBTAINED_AT: String = "obtained_at"
const CHEST_OPENED: String = "opened"
const CHEST_REWARDS: String = "rewards"

# 報酬Dictionary（宝箱・ポモドーロ・戦闘で共通）
# {gold, gems, stamina, materials, inventory}
const REWARD_GOLD: String = "gold"
const REWARD_GEMS: String = "gems"
const REWARD_STAMINA: String = "stamina"
const REWARD_MATERIALS: String = "materials"
const REWARD_INVENTORY: String = "inventory"

# 戦闘結果: {victory, waves_cleared, rewards}
const BATTLE_VICTORY: String = "victory"
const BATTLE_WAVES_CLEARED: String = "waves_cleared"
const BATTLE_REWARDS: String = "rewards"

# STORY: {"current_chapter": int, "stages": {stage_id: {cleared, stars}}}
const STORY_CURRENT_CHAPTER: String = "current_chapter"
const STORY_STAGES: String = "stages"
const STAGE_CLEARED: String = "cleared"
const STAGE_STARS: String = "stars"

# CODEX: {item_id: {discovered, obtained_at}}
const CODEX_DISCOVERED: String = "discovered"
const CODEX_OBTAINED_AT: String = "obtained_at"

# 各SHOP: {"refresh_at": String, "line_up": Array}
const SHOP_REFRESH_AT: String = "refresh_at"
const SHOP_LINE_UP: String = "line_up"
# line_up の各要素: {slot_id, item_id, cost, stock_limit, purchased_count}
const SHOP_SLOT_ID: String = "slot_id"
const SHOP_ITEM_ID: String = "item_id"
const SHOP_COST: String = "cost"
const SHOP_STOCK_LIMIT: String = "stock_limit"
const SHOP_PURCHASED_COUNT: String = "purchased_count"
# cost: {"currency_type": String, "amount": int}
const COST_CURRENCY_TYPE: String = "currency_type"
const COST_AMOUNT: String = "amount"

# CHARACTER_GROWTH: {character_id: {level, stats, nodes, skills, equipment}}
const GROWTH_LEVEL: String = "level"
const GROWTH_STATS: String = "stats"
const GROWTH_SKILLS: String = "skills"
const GROWTH_EQUIPMENT: String = "equipment"
# 解放済みステータスノードのID配列（EXEC_LEVEL_ROLE_SHIFT.md）。
# 中身はノードIDの文字列だけ。効果値・コスト・前提条件は character_nodes.json から
# 毎回引く（CLAUDE.md 4番「状態にマスターデータを複製しない」）。
#
# 代償として、リリース後にノードIDを改名できない。
# 改名すると解放済みノードが黙って消え、ステータスが減る。
const GROWTH_NODES: String = "nodes"
# growth.skills の中身（EXEC_SKILL_SELECT.md §5）。{"slots": [skill_id, skill_id]}。
#
# slots[0]=スキル1、slots[1]=スキル2。表示順を安定させるために配列で持つ。
# ⚠ 枠は装備スロットに対応しない。スキルはそのまま持ち込むだけで、
# 武器・アクセサリーとの紐づきはルーン側だけの話（2026-08-15に確認）。
# "" は未選択。空の枠は戦闘時に候補の先頭で埋める（GameManager.get_battle_skills()）。
#
# 中身はスキルIDの文字列だけ。倍率・CD・解放レベルは skills.json から毎回引く
# （CLAUDE.md 4番「状態にマスターデータを複製しない」）。
#
# 代償として、リリース後にスキルIDを改名できない。
# 改名すると選択が黙って消え、フォールバックで別のスキルに戻る。
const GROWTH_SKILL_SLOTS: String = "slots"
# stats: 10軸（GAME_DESIGN.md 8-1）。並びは 8-1 の表と同じ順。
# 実数6本（hp/atk/mag/def/mdef/spd）＋％系4本（atkspd/haste/crit_rate/crit_dmg）。
#
# ％系は int で持つ（crit_rate: 25 ＝ 25%）。float だとセーブに 25.0 と書かれる。
# 実数も％も同じ stats 辞書に入れる（別バケットにしない。PLAN_STATS_AND_FORMULAS.md 1章）。
const STAT_HP: String = "hp"
const STAT_ATK: String = "atk"
const STAT_MAG: String = "mag"
const STAT_DEF: String = "def"
const STAT_MDEF: String = "mdef"
const STAT_ATKSPD: String = "atkspd"
const STAT_HASTE: String = "haste"
const STAT_CRIT_RATE: String = "crit_rate"
const STAT_CRIT_DMG: String = "crit_dmg"
const STAT_SPD: String = "spd"
# equipment スロット名
const EQUIP_WEAPON: String = "weapon"
const EQUIP_ARMOR: String = "armor"
const EQUIP_ACCESSORY: String = "accessory"

# RESEARCH_TREE: {node_id: {unlocked, effect_type, effect_value, prerequisites}}
const NODE_UNLOCKED: String = "unlocked"
const NODE_EFFECT_TYPE: String = "effect_type"
const NODE_EFFECT_VALUE: String = "effect_value"
const NODE_PREREQUISITES: String = "prerequisites"
const NODE_TARGET_STAT: String = "target_stat"
# effect_type に入る値
const EFFECT_LEVEL_CAP_UNLOCK: String = "level_cap_unlock"
const EFFECT_STAT_BOOST_ALL: String = "stat_boost_all"

# CRAFTING_QUEUE: [{queue_id, recipe_id, recipe_type, started_at, duration_sec, status, output_item_id}]
const CRAFT_QUEUE_ID: String = "queue_id"
const CRAFT_RECIPE_ID: String = "recipe_id"
const CRAFT_RECIPE_TYPE: String = "recipe_type"
const CRAFT_STARTED_AT: String = "started_at"
const CRAFT_DURATION_SEC: String = "duration_sec"
const CRAFT_STATUS: String = "status"
const CRAFT_OUTPUT_ITEM_ID: String = "output_item_id"
# status に入る値
const CRAFT_STATUS_IN_PROGRESS: String = "in_progress"
const CRAFT_STATUS_COMPLETED: String = "completed"
const CRAFT_STATUS_COLLECTED: String = "collected"

# ショップ種別（get_shop_lineup 等の引数）
const SHOP_TYPE_DAILY: String = "daily"
const SHOP_TYPE_WEEKLY: String = "weekly"
const SHOP_TYPE_MONTHLY: String = "monthly"

# ============================================================
# 画面ID（UNLOCKED_SCREENS のキー、および画面遷移の識別子）
# initial_state_config.tres の initially_unlocked_screens と綴りを一致させること。
# ============================================================

const SCREEN_GUILD: String = "guild"
const SCREEN_ADVENTURE_SELECT: String = "adventure_select"
const SCREEN_POMODORO: String = "pomodoro"
const SCREEN_SETTINGS: String = "settings"
const SCREEN_SCENARIO: String = "scenario"

# ============================================================
# 加護の種類
# ============================================================

const PROTECTION_LIGHT: String = "light"
const PROTECTION_MIDDLE: String = "middle"
const PROTECTION_HARD: String = "hard"

# ============================================================
# 宝箱の種類（chest_type）と入手元（source）
# ============================================================

const CHEST_TYPE_GENERIC: String = "generic"
const CHEST_TYPE_BONUS_SMALL: String = "bonus_small"
const CHEST_TYPE_BONUS_MEDIUM: String = "bonus_medium"
const CHEST_TYPE_BONUS_LARGE: String = "bonus_large"

const CHEST_SOURCE_POMODORO: String = "pomodoro"

# スタミナポーション
const POTION_FOCUS_REMAINDER: String = "potion_focus_remainder"
const ITEM_STAMINA_POTION: String = "stamina_potion"

# ============================================================
# ステージ種別（BattleSession.stage_type / 冒険選択画面で使用）
# ============================================================

const STAGE_TYPE_STORY: String = "story"
const STAGE_TYPE_TRAINING: String = "training"
# 検証用ステージの別枠。stage_order.json の "debug" 列を引くためだけに使う。
# ⚠ BattleSession.stage_type にはこれを入れない（入れるのは training）。
#   スタミナ・報酬・クリア記録の分岐は「story かどうか」で見るため。
# ⚠ リリース前にこの行と "debug" の列を消す（宿題16）。
const STAGE_TYPE_DEBUG: String = "debug"

# ============================================================
# 装備の個体管理（第2弾）
# ============================================================

# トップレベル
const EQUIPMENT_INSTANCES: String = "equipment_instances"
const NEXT_EQUIPMENT_INSTANCE_ID: String = "next_equipment_instance_id"

# equipment_instances の各エントリ: {item_id, grade, parts}
const INSTANCE_ITEM_ID: String = "item_id"
const INSTANCE_GRADE: String = "grade"
const INSTANCE_PARTS: String = "parts"

# equipment スロット名の追加ぶん。
# EQUIP_WEAPON / EQUIP_ARMOR / EQUIP_ACCESSORY は既に上にある。
# armor は「上半身」の内部キー。改名しない（既存セーブのキーが変わるため）。
const EQUIP_HEAD: String = "head"
const EQUIP_LEGS: String = "legs"

# 鍛冶の素材。第1弾は1種だけだが、あとで _2 / _3 を足せるよう最初から連番にしている。
# リリース後に改名できないため、ここを "forging_material" にしないこと。
const ITEM_FORGING_MATERIAL_1: String = "forging_material_1"
