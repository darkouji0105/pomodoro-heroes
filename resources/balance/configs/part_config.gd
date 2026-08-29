class_name PartConfig
extends Resource

# 装飾（宝石・護符・紋章）の数値調整用Config。
# 実際の値は res://resources/balance/configs/part_config.tres を Inspector で編集する。
#
# ⚠ .tres は @export の既定値を書き出さないため、値を変えていない項目は
#   part_config.tres に行が現れない。実際に効いているのはここの既定値
#   （equipment_config.gd と同じ罠）。
#
# ⚠ 装飾1件ごとの性能（part_base / part_roll_max）はここに置かない。
#   items.json の欄で持つ（36件ぶんある。Config に持つと配列が5本並ぶ）。
#   ここに置くのは「段階の仕組み」に関わる数値だけ。

# --- 枠が開く等級（GAME_DESIGN.md 6-4）---
# 添字が枠の位置。位置が枠を表す（PLAN_CHARACTER_GROWTH_LOOP.md 2-2 の [x]）。
#
#   0: 等級3 宝石枠1        4: 等級6 護符枠1
#   1: 等級4 宝石枠2        5: 等級7 護符枠2
#   2: 等級5 特別枠1        6: 等級8 紋章枠1
#   3: 等級5 特別枠2        7: 等級9 紋章枠2
#
# ⚠ 特別枠は部位で中身が変わる（武器＝ルーン×1 / 防具＝ワイルド×1 / アクセサリー＝ルーン×2）。
#   「どの種類が刺さるか」は数値ではないので game_manager.gd の表が持つ。ここは等級だけ。
# ⚠ 長さは GameManager.PART_SLOT_COUNT と揃えること。合わないと赤が出る。
# ⚠ 等級10 では枠が開かない。開くのは「部位固有のパッシブ」で、これは別の仕組み
#   （GAME_DESIGN.md 6-4。この回では実装していない）。
@export var part_slot_min_grades: Array[int] = [3, 4, 5, 5, 6, 7, 8, 9]

# --- 段階 ---
# 装飾の段階の上限。items.json の part_tier が取りうる最大値。
#
# ⚠ GAME_DESIGN.md 7-1 は「装飾は5等級」と書いているが、装飾素材
#   （decor_material_1..4）と1:1にするため4にしている（EXEC_DECORATION.md §0-3 の7）。
#   ⚠ 5に伸ばすときは、この値と下の配列2本と items.json の36件を足すだけでよい。
#   ⚠ 段階の数を .gd に直書きしないこと（画面もここから引く）。
@export var max_part_tier: int = 4

# --- 段階上げ（分解方式・GAME_DESIGN.md 7-1） ---
# 添字 0 が「段階1 → 2 に上げるのに要る decor_material_1 の数」。
# 長さは max_part_tier - 1。
#
# ⚠ 段階 n → n+1 に払うのは decor_material_<n>。上げた先の段階ではなく、
#   いま持っている段階の素材を払う（装備の鍛冶と向きが違う点に注意）。
#
# ⚠ 数値は勘（EXEC_DECORATION.md §0-3 の13）。バランスの実測が来たらここを直す。
@export var upgrade_cost_by_tier: Array[int] = [10, 20, 40]

# --- 壊す（外したとき・在庫で壊したとき） ---
# 添字 0 が「段階1 の装飾を壊したときに返る decor_material_1 の数」。
# 長さは max_part_tier。
#
# ⚠ 上げるのに 10 払って壊すと 5 しか返らない。必ず損する形にしてある。
#   ⚠ 上げてすぐ壊すと素材が増える、という経路を作らないこと
#   （装備の分解で切り捨てにしたのと同じ理由）。
@export var dismantle_by_tier: Array[int] = [3, 5, 10, 20]

# --- ルーン（GAME_DESIGN.md 7-7・EXEC_RUNES.md §3-C） ---
#
# ⚠ ルーンだけ段階の上限が違う。装飾（宝石・護符・紋章）は装飾素材と1:1で4段階、
#   ルーンは 7-7 が「5段階まで」と書いている。max_part_tier と揃えないこと。
# ⚠ ルーンは分解方式では上がらない（素材を払わない）。同じものを重ねる。
@export var max_rune_tier: int = 5

# 同じ段階のルーンを何個消して次の段階1個にするか。
# ⚠ 段階5では重ねられない（超えたぶんは「ルーンのかけら」になる仕様だが、
#   かけらは今回作っていない。人間の決定3・2026-08-24）。
@export var rune_merge_count: int = 2

# 移動系ルーンで動かしたあと、自動移動を止めておく秒数（人間の決定・2026-08-24）。
#
# ⚠ 止まるのは移動だけ。攻撃の拍は止めない。
# ⚠ 0 にすると後退した瞬間に歩き直すので、後退のルーンが無意味になる
#   （GAME_DESIGN.md 7-5 の ⚠ が名指ししている挙動）。
@export var rune_move_lock_sec: float = 1.2
