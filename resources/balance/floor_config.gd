class_name FloorConfig
extends Resource

# フロア探索（シナリオ）のバランス数値。段階14・PLAN_SCENARIO_MAP.md。
#
# Balance に登録し、Balance.floor.floor_chest_chance_pct のように参照する。
#
# 【なぜ AdventureConfig から分けたか（人間の決定・2026-08-28）】
# AdventureConfig は「1ステージに挑むコスト」「ステータスの上限」「ダメージ数値の色」
# 「状態マスの大きさ」を既に抱えている。そこへフロアの経済を足すと、
# バランスを見たい人が色の設定を読み飛ばしながら探すことになる。
# フロアのバランスだけが1画面に並ぶ状態を作るのがこの Config の目的。
#
# 【代償】新しい Config なので Balance への割り当てが要る。
# 割り当てを落とすと Balance.floor が null になり、フロアに入った瞬間に落ちる。
# ⚠ balance.tscn の floor 欄が埋まっていることを、触ったら必ず確かめること
#   （scenario=floor が起動時に見張る＝E131）。
#
# 【何をここに置き、何を stages.json に残すか】
#   ここ          … 全フロア共通の「調整つまみ」。1次元の配列と数値だけ
#   stages.json  … フロアごとの「形と中身」。層のノード数・報酬の表・
#                  battle_pool・boss・chest_ids・unlocks
# ⚠ 同じ数値を2箇所に書かない。迷ったら「フロアを1本増やしたときに
#   書き足すことになるか」で決める。書き足すなら stages.json。

# --- 層のノード出現比（段階14-h で全フロア共通の1枚に揃えた） ---
#
# ⚠ 添字が層番号 − 1。⚠ 配列の長さがそのまま層数になる。
# ⚠ 4本とも同じ長さにすること（E131 が見張る）。
# ⚠ 各層の合計が 100 になるように保つ（合計が変わっても動くが、読めなくなる）。
# ⚠ stages.json の layers は node_count だけを持つ。重みはここが唯一の置き場。
#
# 層1 … 入口。必ず戦闘（合流点が1ノードなので、ここで分岐は作れない）
# 層4 … ⚠ ショップの合流点。⚠ shop だけ 100 にしてあるので、
#        stages.json 側で node_count が何個でも必ずショップになる
#        （PLAN_SCENARIO_MAP.md §10-2-C）。ここを崩すと
#        「ショップは在るのに行けない周」が戻る。
@export var layer_weight_battle: Array[int] = [100, 70, 60, 0, 55, 65]
@export var layer_weight_relic: Array[int] = [0, 30, 20, 0, 25, 0]
@export var layer_weight_rest: Array[int] = [0, 0, 20, 0, 20, 35]
@export var layer_weight_shop: Array[int] = [0, 0, 0, 100, 0, 0]

# --- 宝箱（段階14-b・PLAN_SCENARIO_MAP.md §4） ---
#
# ⚠ 宝箱は「ノード」ではなく「移動」に紐づく。移動するたびに確率で出る。
# ⚠ 抽選のハズレ枠は廃止した。出ると決まったら必ず中身がある。
#   → 量を絞る栓は「出現率 × 移動回数」だけ。移動回数＝層数なので、
#     上の配列を伸ばすとここも一緒に動く。片方だけ触らないこと。
#   → 1周の期待値は scenario=economy が式で出す（ズレ44）。
#     実測は scenario=floor の「1周あたりの宝箱」（100周）。

## 移動1回あたり宝箱が出る確率（％）。
## 目安：30（6層のフロアで 6回移動 → 1周あたり 1.92 個。保証込み）
@export var chest_chance_pct: int = 30

# レアリティの重み。⚠ 添字は「着いたノードの層 − 1」。
# ⚠ 配列より深い層に着いたら末尾を使う（ボスは層 L+1 なので必ず末尾）。
# ⚠ 各層の合計が 100 になるように保つ。
# ⚠ 「奥ほど良い物が出やすい」はプレイヤーに明示する決定なので、
#   ここの傾きを変えたら画面の説明文も直すこと（PLAN_SCENARIO_MAP.md §4-5）。
@export var chest_weight_common: Array[int] = [70, 60, 50, 42, 35, 30]
@export var chest_weight_rare: Array[int] = [25, 30, 33, 34, 35, 35]
@export var chest_weight_epic: Array[int] = [5, 9, 14, 19, 22, 25]
@export var chest_weight_legendary: Array[int] = [0, 1, 3, 5, 8, 10]

# --- 休憩ノード（段階14-c） ---
#
# ⚠ ここに欄は無い。AdventureConfig の floor_rest_full_heal を持ってこなかった。
#   ⚠ あれは誰も読まない欄だった（2026-08-28 に発見＝ズレ46）。
#     rest_at_node() は Balance を1行も見ずに常に満タンにしている。
#   ⚠ 割合回復にするなら rest_heal_pct（shop_heal_pct と同じ形）を足し、
#     rest_at_node() が hp_carry を書き換える形にする＝宿題64。
#     ⚠ 実装せずに欄だけ足さないこと。同じ死に欄をもう1本作ることになる。

# --- たいまつ（段階14-e・PLAN_SCENARIO_MAP.md §5） ---
#
# ⚠ たいまつはアイテムではなくフロア内の状態（人間の決定3）。持つのはグレード番号1つだけ。
# ⚠ フロアごとにリセットされる。クリアでも敗北でも、次のフロアは grade 0 から。
# ⚠ 層構造なので視界は「半径」ではなく「何層先まで中身が見えるか」。
#   ⚠ ボスの位置だけは常に見える（たいまつに関係なく）。

## グレードごとに「何層先まで中身が見えるか」。⚠ 添字がグレード番号。
## ⚠ 配列の長さがそのまま上限グレード＋1。
@export var torch_reveal_layers: Array[int] = [1, 2, 3, 5]

## グレードを1つ上げるのに払うゴールド。⚠ 添字は「上げたあとのグレード」。
## ⚠ [0] は使わない（grade 0 は最初から持っている）。
## ⚠ 桁の基準は「1周のゴールド」（stages.json の rewards が 50〜130 G）。
##   ⚠ フロアを降りると消えるので、拠点ショップの恒久の品（最安 300 G）より
##     明確に安くないと絶対に買われない（段階14-h で 300/800/2000 から下げた）。
@export var torch_prices: Array[int] = [0, 50, 150, 400]

# --- フロア内ショップ（段階14-e） ---
#
# ⚠ 持ち帰れない（フロア専用）。⚠ 買うとその場で効く。
#   「持ち物として買って後で使う」形にしていない（消耗品を使う汎用の口が無いため）。
# ⚠ 休憩ノードが無料で満タンにするので、回復はそれより明確に安くないと押されない。

@export var shop_heal_price: int = 60
@export var shop_heal_pct: int = 50
