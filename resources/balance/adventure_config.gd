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

# --- 頭上に浮かぶ数値の見た目（EXEC_DAMAGE_POP_COLOR.md） ---
#
# 【なぜ色が「数値調整用Config」に居るのか】
# AGENTS.md「Themeの扱い」は「個別シーンで色を直接指定しない」と言っている。
# だが main_theme.tres は Control の基本スタイル（ボタン・ラベル）を持つ場所で、
# ここで要るのは「毒＝この色」という意味の対応表であり、しかも動的生成した
# Label への add_theme_color_override なので、Theme 経由にすると
# カスタム型（theme_type_variation）を人間が作る作業が発生する。
# → Inspector から触れる形を優先し、Balance 側に置く（人間の決定・2026-08-17）。
#
# 【なぜ新しい Config を作らないか】上の「ステータスの上限」と同じ理由。
# AdventureConfig は既に Balance に配線済みで、割り当て漏れの事故が起きない。
#
# ⚠ .tres は @export の既定値を書き出さないので、ここに欄を足すだけで
#   Inspector に既定値付きで出る。adventure_config.tres を作り直す必要は無い。
# ⚠ 種類で分ける（量では分けない）。毒の 2 と通常の 4 は量がほぼ同じなので、
#   量で分けても見分けられない。量による色分けは段階4。

## 通常のダメージ。
@export var pop_damage_color: Color = Color(1.0, 0.85, 0.3)
@export var pop_damage_font_size: int = 22

## 会心。通常より大きく・強い色にする（「会心」という文字は出さない）。
@export var pop_crit_color: Color = Color(1.0, 0.55, 0.25)
@export var pop_crit_font_size: int = 32

## DoT（毒などの周期ダメージ）。
## 通常のダメージと同じ画面に並ぶので、黄〜橙の系統から最も遠い色にする。
## ⚠ UnitView の COLOR_BOSS（紫・スクリプト内定数のまま）と系統が近い。
## 通常より少し小さくして「軽い一撃」に見せる。
@export var pop_dot_color: Color = Color(0.75, 0.45, 0.95)
@export var pop_dot_font_size: int = 18

## 回復。⚠ 大きさは通常のダメージと同じにする。見落とすと困る種類なので小さくしない。
@export var pop_heal_color: Color = Color(0.4, 0.95, 0.5)
@export var pop_heal_font_size: int = 22

## チャージのジャスト成功。⚠ これだけ数値ではなく文字（ui_battle_just）が出る。
@export var pop_just_color: Color = Color(1.0, 0.95, 0.55)
@export var pop_just_font_size: int = 30

## 浮かんで消えるまでの動き。種類で変えない（変えると読む速さが揃わない）。
@export var pop_rise_px: float = 48.0
@export var pop_duration_sec: float = 0.6

# --- 状態のマス（EXEC_STATUS_UI.md） ---
#
# ⚠ 色は3つだけ（人間の決定・2026-08-22）。器に「良い状態か悪い状態か」の欄が
#   無いため、攻撃力ダウンも防御ダウンも青で出る。分けるなら器に欄が要る。
# ⚠ ここに欄を足すだけで既定値付きで Inspector に出る（.tres は触らない）。

## 周期ダメージ（dot・heals: false）。頭上に浮かぶ毒の数値（紫）とは別物。
## マスは 16px 角の中に漢字が1文字入るので、文字が読める濃さにする。
@export var status_chip_dot_color: Color = Color(0.8, 0.2, 0.2)

## 周期回復（dot・heals: true）。
@export var status_chip_heal_color: Color = Color(0.2, 0.7, 0.35)

## 補正と購読（buff / react）。⚠ react も青（決定4「色は3つだけ」）。
@export var status_chip_buff_color: Color = Color(0.25, 0.45, 0.9)

## マスの中の漢字の色。
@export var status_chip_text_color: Color = Color(1.0, 1.0, 1.0)

## 条件が偽の状態（active: false）の不透明度。
## ⚠ 0.0 にしないこと。消すと「条件で切れた」のか「寿命で消えた」のかが
##   画面から区別できなくなる。
@export var status_chip_inactive_alpha: float = 0.4

## マスの辺の長さ（px）。件数で3段に切り替える（人間の指示・2026-08-22）。
## 上限は件数ではなく「置ける場所の大きさ」で決まる。
## 1〜4件は large、5〜8件は medium、9件以上は small。
@export var status_chip_size_large_px: int = 16
@export var status_chip_size_medium_px: int = 12
@export var status_chip_size_small_px: int = 8

## マス同士の間隔（px）。
@export var status_chip_separation_px: int = 2

## 味方の帯（スキルボタンの左・縦並び）に使ってよい高さ（px）。
## これを超えるぶんは最後のマスが「＋N」になる。
@export var status_chip_party_max_px: float = 120.0

## 敵の帯（HPバーの上・横並び）に使ってよい幅（px）。
## ⚠ UnitView の Body は 64px。2倍まで許す。
@export var status_chip_enemy_max_px: float = 128.0
