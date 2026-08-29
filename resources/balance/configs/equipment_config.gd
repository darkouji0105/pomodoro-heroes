class_name EquipmentConfig
extends Resource

# 装備（等級・鍛冶・分解）の数値調整用Config。
# 実際の値は res://resources/balance/configs/equipment_config.tres を Inspector で編集する。
#
# ⚠ .tres は @export の既定値を書き出さないため、値を変えていない項目は
#   equipment_config.tres に行が現れない。実際に効いているのはここの既定値
#   （CLAUDE.md 6番の罠。character_config.gd の max_character_level と同じ）。

# --- 等級 ---
# GAME_DESIGN.md 6-2。第1弾は 3 で止めていた（game_manager.gd の定数）。
@export var max_equipment_grade: int = 10

# --- 等級帯 → 要求する鍛冶素材の段階 ---
# 「等級10を4分割（刻みは調整）」（GAME_DESIGN.md 2章）。
# i 番目の値は「段階 i+1 が要求され始める等級」。
# [1, 4, 7, 10] なら 2〜3→段階1 / 4〜6→段階2 / 7〜9→段階3 / 10→段階4。
#
# ⚠ 引くのは「上げた先の等級」。等級1へ上げることは無いので、
#   実際に使われるのは 2〜max_equipment_grade。
@export var forge_material_tier_min_grades: Array[int] = [1, 4, 7, 10]

# --- 鍛冶のコスト ---
# 添字 0 が「等級2へ上げるのに要る数」。長さは max_equipment_grade - 1。
#
# ⚠ 式にしていないのは人間の決定（EXEC_MATERIAL_TIERS.md 決定E）。
#   「1個だけ直したい」が式では書けないため。
#
# ⚠ 先頭2つ（8 / 12）は、この回より前の FORGE_COST_PER_GRADE * (grade + 1)
#   （= 4*2, 4*3）と同じ値。等級1〜3の挙動が変わっていないことを測るための足場。
#
# ⚠ 3番目以降（等級4〜10）は勘。バランスの実測が来たときにここを直す
#   （game_manager.gd に「勘で置くと全部やり直しになる」と書かれていた警告への答え。
#    数値がこの1行に集まっているので、やり直しはこの行だけで済む）。
@export var forge_cost_by_grade: Array[int] = [8, 12, 16, 20, 24, 28, 32, 36, 40]

# --- 分解 ---
# 等級1の装備を素材に戻したときの基礎量（返却率を掛ける前）。
@export var dismantle_refund_base: int = 3

# 払った量のうち、何割が戻るか。切り捨て。
#
# ⚠ この回より前は「基礎＋払った全額」で完全に元に戻っていた（＝無損失）。
#   等級10まで伸ばすと「上げて分解して付け替える」がノーリスクになるため、
#   半分だけ返す（EXEC_MATERIAL_TIERS.md 決定F）。
#
# ⚠ 切り上げにしないこと。1つ上げてすぐ分解すると素材が増える経路ができる。
@export var dismantle_refund_ratio: float = 0.5
