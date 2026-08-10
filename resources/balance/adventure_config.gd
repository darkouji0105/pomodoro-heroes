class_name AdventureConfig
extends Resource

# 冒険選択画面まわりの数値調整用Config。
# Balance に登録し、Balance.adventure.stamina_cost_per_stage のように参照する。
#
# 【スタミナの扱い（PLAN_ADVENTURE_SELECT.md §3-3）】
# ルールは1本。「勝ったときだけ消費する」。
#   挑戦するとき     → stamina_cost_per_stage を払う
#   敗北したとき     → 同額を戻す（GameManager.refund_stamina）
#   戦闘内の「もう一度」→ 改めて払う
# 結果として、プレイヤーは勝った1回分だけを払うことになる。
#
# 消費と返却の両方がこの値を読む。片方だけ別の場所から読ませないこと。

## 1ステージに挑むのに必要なスタミナ。
## 敗北時に返却される額でもある。
## 初期値の目安：5（スタミナ初期値20に対して4回挑める）
@export var stamina_cost_per_stage: int = 5
