class_name AdventureConfig
extends Resource

# 冒険・戦闘まわりの数値調整用Config。
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

# --- ステータスの上限（GAME_DESIGN.md 8-2-2） ---
#
# 【なぜ StatConfig を新設せず、ここに置くか】
# .tres は @export の既定値を書き出さない。新しい Config を作ると
# 「.gd を作る → .tres を作る → Balance の @export に足す → Inspector で割り当てる」
# の4手が要り、割り当てを1つ落とすと Balance.stat が null になって戦闘が起動しない。
# AdventureConfig は既に Balance に配線済みで、その事故が起きない。
# 上限が戦闘の外にも広がったら StatConfig に分ける
# （Balance.adventure.x → Balance.stat.x の置換だけで済む）。

## 攻撃間隔の下限（秒）。atkspd をいくら積んでもこれより短くならない。
##
## ％の上限ではなく秒数の下限で持つ（GAME_DESIGN.md 8-2-2）。
## ％で揃えると、攻撃間隔 2.0 秒のキャラと 0.6 秒のキャラで壊れ方が変わる。
## 目安：0.4（現在いちばん速いのは敵 enemy_wolf の 1.0 秒）
@export var min_attack_interval_sec: float = 0.4

## haste（CD短縮）の上限（％）。超過分は捨てる。
## 100 にすると最短でも元の CD の半分までになる。
@export var max_haste: int = 100

## crit_rate（会心率）の上限（％）。超過分は捨てる。
## GAME_DESIGN.md 8-2 は超過分を crit_dmg に変換する案だったが、変換しない決定になった。
@export var max_crit_rate: int = 100

## 投射物（delivery: projectile）の速度。1秒あたりのピクセル。
##
## ⚠ JSONに弾速を書かない決定（PLAN_SKILL_TEMPLATE.md 6-7）。弾速も弧も
## 「いつ当たるか」の言い換えでしかなく、スキルごとに書けると
## 「当たるまでの時間」がデータの2箇所に散る。速度はここ1箇所で持つ。
##
## 目安：味方 200 と敵 900 の間は最大 700px。1200 なら 0.6 秒弱で届く。
@export var projectile_speed_px_sec: float = 1200.0

## 魔法弾（delivery: magic）の速度。1秒あたりのピクセル。
## 矢より少し遅くして、見た目で送り方の違いが分かるようにしている。
@export var magic_speed_px_sec: float = 800.0

## 投射物が対象に「着いた」とみなす距離（ピクセル）。
## ⚠ 0 にしないこと。対象が動き続けると永久に追いつけない。
@export var projectile_hit_distance_px: float = 12.0
