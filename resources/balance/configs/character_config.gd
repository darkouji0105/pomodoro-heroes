class_name CharacterConfig
extends Resource

# 育成関連の数値調整用Config。
# 実際の値は res://resources/balance/configs/character_config.tres を Inspector で編集する。

# --- レベルアップに必要な素材 ---
@export var level_up_material_id: String
@export var base_level_up_cost: int
@export var cost_growth_per_level: float

# --- 研究が未実装の間のレベル上限 ---
# 実効上限 = base_level_cap + 解放済み level_cap_unlock ノードの effect_value 合計。
# 研究ツリーが空でも 0 にならないようにするための下駄。
#
# ⚠ 20 + research.json の res_cap_1..4（各 20）= ちょうど 100 で
#   max_character_level と一致する（人間の決定・2026-08-25）。
#   パッシブが Lv20/40/60/80/100 で解放されるので、100 に届かないと
#   5個中4個が誰にも見られない（GAME_DESIGN 5-4 / EXEC_CHARACTER_PASSIVES §4-3）。
# ⚠ 片方だけ変えると 100 からずれる。research.json とセットで直すこと。
@export var base_level_cap: int = 20

# --- 設計上の最大レベル ---
# get_effective_level_cap() が返す「今このセーブで上げられる上限」とは別物。
# こちらは GAME_DESIGN.md 5-2 が定める天井（100）で、
# 「最大レベル到達時のみ割り振りポイントが1点多く入る」判定に使う。
#
# ⚠ .tres は @export の既定値を書き出さないため、character_config.tres に
# この行は現れない。実際に効いているのはここの 100（CLAUDE.md 6番の罠）。
@export var max_character_level: int = 100

# --- 成長・コストの計算式 ---
# GrowthFormula が Expression で評価する。式そのものを Inspector から差し替えられる。
#
# stat_growth_formula で使える変数:
#   base   … characters.json の基本値（10軸のいずれか）
#   growth … characters.json の growth_per_level の該当値
#   level  … 計算対象のレベル
#
# ⚠ stat_growth_formula は "base"（レベルで伸びない）。
# GAME_DESIGN.md 5-2「レベルアップでステータスは自動で上がらない」。
# レベルで増えるのは割り振りポイントで、ステータスはノードを解放して伸ばす。
#
# そのため characters.json の growth_per_level は現在どこにも効いていない。
# 消していないのは、式を戻したときに全キャラ伸びなくなるため
# （EXEC_LEVEL_ROLE_SHIFT.md §12 の宿題）。
#
# level_up_cost_formula で使える変数:
#   base   … base_level_up_cost
#   growth … cost_growth_per_level
#   level  … 現在のレベル（このレベルから1つ上げるのに必要な数）
#
# 空文字にすると線形（base + growth * (level - 1)）にフォールバックする。
#
# ⚠ level_up_cost_formula は character_config.tres に行が無い。
#   効いているのはここの既定値（.tres は @export の既定値を書き出さない）。
#   ⚠ .tres に行があるのは level_up_material_id / base_level_up_cost /
#     cost_growth_per_level の3行だけ（EXEC_BALANCE_TUNE.md §0-2）。
#
# ⚠ 2026-08-25：線形 "base + growth * (level - 1)" から二次へ差し替えた。
#   GAME_DESIGN.md 5-2「立ち上がりを寝かせて後半を跳ねさせる式に差し替える」。
#   Lv1→100 の合計が 1キャラ 5,148 個 → 1,595 個（3キャラ 15,444 → 4,785）。
#   stage_2 を回す前提で 集中 160.9 時間 → 39.9 時間（人間の決定：目安40時間）。
#   1回あたりは Lv1 で 3 個・Lv20 で 4 個・Lv60 で 17 個・Lv99 で 42 個。
#
# ⚠ 245.0 と小数で書くこと。245 と書くと、渡し方が変わったときに
#   整数割りになって黙って壊れる（今は float(level) で渡っている）。
@export var stat_growth_formula: String = "base"
@export var level_up_cost_formula: String = "base + growth * (level - 1) * (level - 1) / 245.0"
