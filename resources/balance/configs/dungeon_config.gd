class_name DungeonConfig
extends Resource

# 難ダンジョン（段階17-a・PLAN_HARD_DUNGEON.md）のバランス数値。
#
# Balance に登録し、Balance.dungeon.bag_initial_slots のように参照する。
#
# 【なぜ FloorConfig と分けたか】
# FloorConfig はシナリオ（floor_1..5）のつまみ。難ダンジョンは別枠の遊びで、
# 台帳も別（PLAN_HARD_DUNGEON.md ／ PLAN_SCENARIO_MAP.md）。同居させると
# 「どちらの数値を触っているのか」が Inspector の1画面から読めなくなる
# （AGENTS.md「1つのConfigに別領域の数値を混ぜない」）。
#
# 【何をここに置き、何を dungeon.json に残すか】
#   ここ           … 全ダンジョン共通の「調整つまみ」。1次元の配列と数値だけ
#   dungeon.json  … ダンジョンごとの「形と中身」。層のノード数・battle_pool・
#                   boss・ノード種ごとの戦利品表・通貨の額
# ⚠ 同じ数値を2箇所に書かない。迷ったら「ダンジョンを1本増やしたときに
#   書き足すことになるか」で決める。書き足すなら dungeon.json。
#
# ⚠⚠ ここの数値は全部「仮置き」（決定14・§6-B）。
#   ⚠ 遊ぶ前に当てられるものは1つも無い。遊んでから測って直す（段階17-g）。

# --- 層のノード出現比（段階17-a） ---
#
# ⚠ 添字が層番号 − 1。⚠ 配列の長さがそのまま層数になる。
# ⚠ 3本とも同じ長さにすること（E133 が見張る）。
# ⚠ shop の欄は無い。ショップはボスを倒した先だけ（決定15・§5-0）。
#   ⚠ 層に shop を置かないこと。置くと「潜るか降りるか」の決断の場所が2つになる。
#
# 層1 … 入口。必ず戦闘（合流点が1ノードなので、ここで分岐は作れない）
# ⚠ rest を厚くしすぎないこと。休憩は「その層の戦闘・レリック・宝箱を諦める」
#   ことがコスト（§4-9-1）なので、選び放題だとコストが消える。
@export var layer_weight_battle: Array[int] = [100, 65, 55, 60, 50, 60]
@export var layer_weight_relic: Array[int] = [0, 25, 25, 20, 25, 15]
@export var layer_weight_rest: Array[int] = [0, 10, 20, 20, 25, 25]

# --- 戦利品（§5-2・決定：宝箱は「ノード種」に紐づける） ---
#
# ⚠⚠ シナリオ側（FloorConfig.chest_chance_pct）と作りが違う。あちらは「移動」に
#   紐づくので、層構造だと歩数がどのルートでも同じ＝どの分岐を選んでも報酬の総量が
#   動かない（FLOOR_GAMEPLAY_CURRENT.md §2-B・実測 1.99 個/周）。
#   ⚠ こちらは最初からノード種に紐づける。⚠ 移動に紐づけ直さないこと。
#     戻すと休憩場所のコストも、たいまつを買う理由も同時に効かなくなる。
#
# ⚠ 添字はノード種ではなく「そのノードで抽選する確率（％）」。
#   実際に何が出るかは dungeon.json の loot[kind]。
@export var loot_chance_battle_pct: int = 100
@export var loot_chance_relic_pct: int = 0
@export var loot_chance_rest_pct: int = 0
@export var loot_chance_boss_pct: int = 100

# --- 鞄（§4-1） ---
#
# ⚠ 個数制限方式（コンセプト文書）。ポーションも鍵も戦利品も一律1枠。
#   ⚠ 重み付けを入れないこと（タルコフの煩雑さを持ち込まないという決定）。
# ⚠ 溢れたぶんは拾えない（＝床に置く）。⚠ 自動で捨てる先を作らないこと。

## 鞄の初期枠。⚠ 8 は仮置き（未決5。コンセプト文書自身が「テストプレイで実測」と書いている）。
@export var bag_initial_slots: int = 8

# --- 1ラン（決定15・§5-0） ---
#
# ⚠ フロアを何枚まで潜れるかの上限は置いていない（未決1-c・上限なしから始める）。
#   ⚠ 目減り量（未決4）が効くなら自然に止まるはず。⚠ 止まらなかったらここに欄を足す。
#   ⚠ 欄だけ先に足さないこと（AGENTS.md「欄だけ足して実装しない」）。

## フロアが1枚深くなるごとに、一時通貨の入手が何％増えるか。
## ⚠ 「深く潜る＝より良い戦利品」（§2 の表）を数値にしたもの。
@export var currency_growth_pct_per_floor: int = 25

# --- ポーションと休憩（段階17-c・§4-3 / §4-9・決定19） ---
#
# ⚠⚠ 基準は全部「素の MAX HP」（`get_effective_stats().hp`）。
#   ⚠ 「戦闘時 MAX HP」を基準にしないこと。⚠ 削れているほど戻る量も減って坂が急になり、
#     脱落したキャラは 0 の何％でも 0 のままで永久に戻らない（決定13 と同じ理由）。
# ⚠ 効き方は GameManager の1本（use_dungeon_item / apply_dungeon_rest）だけが読む。
#   ⚠ 画面側（17-d）でここを読んで計算し直さないこと。

## 回復ポーション1個で、戦闘時 MAX HP を素の MAX HP の何％ぶん戻すか。
## ⚠ 決定19（HP回復と MAX HP回復を1件に統合した）の 30%。⚠ 仮置き。
## ⚠ 素の MAX HP を超えては戻らない。
@export var potion_heal_pct: int = 30

## 蘇生したとき、戦闘時 MAX HP を素の MAX HP の何％にするか（決定13）。
@export var revive_max_hp_pct: int = 50

## 蘇生したときの HP を、上の戦闘時 MAX HP の何％にするか（決定13。素の 25% になる）。
## ⚠ ここだけ HP ＜ 上限になる。⚠ 復帰直後は弱者狙いAI（§4-5）に狙われる位置＝意図どおり。
@export var revive_hp_pct: int = 50

## 休憩ノードで、戦闘時 MAX HP を素の MAX HP の何％ぶん戻すか。
## ⚠ ポーションより強くしてある。⚠ 休憩は「その層の戦闘・レリック・戦利品を諦める」のがコスト（§4-9-1）。
@export var rest_heal_pct: int = 40

## 休憩ノードで、脱落したキャラを何人まで戻すか（§4-9 の蘇生2本目）。
## ⚠ 0 にすると休憩から蘇生の口が消える。⚠ 消すならポーション以外の蘇生手段が無くなる。
@export var rest_revive_count: int = 1

# --- たいまつ（§4-7・段階17-e） ---
#
# ⚠ 読む側（GameManager.get_dungeon_reveal_layers / is_dungeon_node_revealed）と
#   同じ回に入れた（AGENTS.md「欄だけ足して実装しない」）。
# ⚠⚠ 値段は dungeon.json の shop に書く（⚠ 表＝JSON・つまみ＝Config）。
#   ⚠ ここに値段を置かないこと（⚠ シナリオ側の FloorConfig.torch_prices とは作りが違う）。

## たいまつの等級ごとに「何層先まで中身が見えるか」。
## ⚠ 添字が等級（0 から）。⚠ 配列の長さ − 1 がそのまま上限の等級。
## ⚠ シナリオ側（FloorConfig.torch_reveal_layers）と同じ数字だが、⚠ 別の欄にしてある
##   （⚠ 器が別。⚠ 片方を調整したときにもう片方が黙って動かないため）。
@export var torch_reveal_layers: Array[int] = [1, 2, 3, 5]

# --- レリック（段階17-e-2・人間の決定：⚠ 表はシナリオ側と共有する） ---
#
# ⚠ 中身（`relics.json` の12件）は共有する。⚠ ここに置くのは「何件から選ぶか」だけ。
# ⚠ 候補はノードごとに固定（⚠ 種で引く。⚠ GameManager.get_dungeon_relic_choices）。

## レリックのマスで何件から選ぶか。
@export var relic_choice_count: int = 3
