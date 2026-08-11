class_name CharacterConfig
extends Resource

# 育成関連の数値調整用Config。
# 実際の値は res://resources/balance/character_config.tres を Inspector で編集する。

# --- レベルアップに必要な素材 ---
@export var level_up_material_id: String
@export var base_level_up_cost: int
@export var cost_growth_per_level: float

# --- 研究が未実装の間のレベル上限 ---
# 実効上限 = base_level_cap + 解放済み level_cap_unlock ノードの effect_value 合計。
# 研究ツリーが空でも 0 にならないようにするための下駄。
@export var base_level_cap: int = 10

# --- 成長・コストの計算式 ---
# GrowthFormula が Expression で評価する。式そのものを Inspector から差し替えられる。
#
# stat_growth_formula で使える変数:
#   base   … characters.json の基本値（hp / atk / def / spd のいずれか）
#   growth … characters.json の growth_per_level の該当値
#   level  … 計算対象のレベル
#
# level_up_cost_formula で使える変数:
#   base   … base_level_up_cost
#   growth … cost_growth_per_level
#   level  … 現在のレベル（このレベルから1つ上げるのに必要な数）
#
# 空文字にすると線形（base + growth * (level - 1)）にフォールバックする。
@export var stat_growth_formula: String = "base + growth * (level - 1)"
@export var level_up_cost_formula: String = "base + growth * (level - 1)"
