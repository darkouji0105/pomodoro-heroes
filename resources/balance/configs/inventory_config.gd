class_name InventoryConfig
extends Resource

# 持ち物のマス目（段階18-b・PLAN_INVENTORY.md）のバランス数値。
#
# Balance に登録し、Balance.inventory.initial_slots のように参照する。
#
# 【なぜ他の Config に混ぜないか】
# AGENTS.md「1つのConfigに別領域の数値を混ぜない」。ここは「持ち物が何マス入るか」
# だけの領域で、拠点・冒険・フロア・ダンジョンのどれとも別。
#
# 【マスの数え方】⚠ 1マス＝1個（人間の決定3。重ねない）。
#   ⚠ 汎用素材は並ばない（人間の決定5）。⚠ 数える口は
#     GameManager.get_inventory_slots_used() の1本。⚠ ここに2本目の数え方を書かない。
#
# ⚠⚠ 数値は「仮置き」。⚠ 実測は scenario=inventory が出す。
#   ⚠ 2026-09-03 の実測：装飾61種を5個ずつ持つと 315 マス（重ねれば 67 マス）。
#   ⚠ つまり作業場のくじを回し続けると、どんな枠でも必ず埋まる（＝未決7）。

## 拠点の倉庫の初期のマス数（人間の決定8・2026-09-03）。
## ⚠ 500 ＝ 100 マス（20列 × 5行）× 5 ページ。⚠ 未決7 の裁きは「案②＝数百マス」。
## ⚠ 拡張ぶんは 18-e で状態に持つ。⚠ ここに「拡張後の上限」を書かないこと。
@export var initial_slots: int = 500

# --- ページ（人間の決定8） ---
#
# ⚠ 1ページ ＝ columns × rows_per_page。⚠ 掛け算をする場所は
#   GameManager.get_inventory_slots_per_page() の1本だけ（画面で掛け直さない）。
# ⚠ 画面の幅に効く：⚠ 20列 × 48px ＝ 960px（⚠ 基準は 1280）。
#   ⚠ 列を増やすときは scenario=layout で最小幅を測り直すこと。

## 1行に並べるマスの数。
@export var columns: int = 20

## 1ページの行数。
@export var rows_per_page: int = 5

# --- 枠の拡張（段階18-e・設計役の決め。⚠ 人間が覆してよい） ---
#
# ⚠ 対価はゴールド。⚠ 研究にしなかったのは、⚠ 研究＝戦闘の強化 に別の意味が混ざるため。
# ⚠ 1回で1ページ（＝columns × rows_per_page）増える。⚠ 「6ページ目が開く」で分かる形。
# ⚠ 上限を置く。⚠ 無限に買えると「有限である」意味が消える（台帳 §3）。
# ⚠⚠ 数値は全部仮置き。⚠ 1周のゴールドは 50〜130 G（`FLOOR_GAMEPLAY_CURRENT.md`）なので、
#   ⚠ 2000 G は「20〜40周ぶん」。⚠ 遊んでから測る。

## 1回の拡張で増えるページ数。
@export var expand_pages_per_purchase: int = 1

## 1回目の拡張の値段（ゴールド）。
@export var expand_cost_gold_base: int = 2000

## 2回目以降、1回ごとに上がる額。⚠ n 回目 = base + step × (n - 1)。
@export var expand_cost_gold_step: int = 2000

## 拡張したあとの最大ページ数（初期の5ページを含む）。
@export var max_pages: int = 10
