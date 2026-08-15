# 【実行指示書】ステータス10軸の**後半（式を戦闘に反映する）**

前半（器）は`EXEC_STATS_10_AXES.md`。**そちらは完了している。もう一度やらないこと。**

この指示書は**その続き**であり、前半で調べた事実（同 §2）を前提に書いてある。**`grep`し直さなくてよい。**

---

## 1. このタスクで実現すること

**`mag` / `mdef` / `atkspd` / `haste` / `crit_rate` / `crit_dmg` を戦闘で効かせる。** 現在この6本はセーブにも育成画面にも出るが、戦闘では何もしていない。

| 今 | 後 |
|---|---|
| ダメージ = `atk - def`（減算） | 物理 = `atk × 100 / (100 + def)`／魔法 = `mag × 100 / (100 + mdef)` |
| 攻撃間隔は`characters.json`から直読み | `atkspd`で短縮し、秒数の下限でクランプ |
| CDは`skills.json`から直読み | `haste`で短縮（上限100%） |
| クリティカルが無い | `crit_rate`で抽選し、`crit_dmg`倍 |
| 物理／魔法の区別が無い | `attack_type`で分岐。`mdef`が生きる |
| 回復量が`atk`参照 | `mag`参照 |

**式の本文は`GAME_DESIGN.md` 8-2が正。この指示書に式を書き写さない。**

### スコープ

**`NEXT_STEPS.md` §6の候補Cを1回でやる**（A/Bに分けない）。理由：A→B→Cの差分は`BattleFormula`に関数を足す程度で、分けると`unit.gd`と2つのダメージ経路を3回なでることになるため。

---

## 2. 人間が決めたこと（**この指示書の他の記述より優先する**）

| # | 決定 |
|---|---|
| 1 | `BattleUnit`は`stats: Dictionary`1本 ＋ `static create()` ＋ `get_stat()`。位置引数を全廃する |
| 2 | 式は`res://scripts/systems/battle_formula.gd`（**新規1ファイル**）に集約する |
| 3 | スコープはC（全部） |
| 4 | **`crit_rate`の100%超過分は捨てる。`crit_dmg`に変換しない** |
| 5 | 回復は`mag`参照に移す |
| 6 | 上限値は1箇所・`.tres`から触れる形にする。**`AdventureConfig`に3つ足す**（新しいConfigを作らない） |
| 7 | 実装役（MiniMax）は使わない |
| 8 | `min_attack_interval_sec` = **0.4秒**（`.tres`で変えられる） |

### ⚠ 決定4は`GAME_DESIGN.md`と食い違う

`GAME_DESIGN.md` 8-2に「**`crit_rate`が100%を超えた分は`crit_dmg`に変換する**」と書かれており、14章の未決リストにも「`crit_rate`の超過分を`crit_dmg`に変換するレート」が残っている。**今回の決定はこれを取り消すもの。** §4-3で人間が直す。

---

## 3. 設計の要点（**なぜこの形か**）

### 3-1. `BattleFormula`は`BattleUnit`を参照しない

**相互参照（`BattleUnit` ⇄ `BattleFormula`）にすると、Godotでパースエラー（Cyclic reference）を踏む可能性がある。設計役は起動して確かめられない。**

そこで依存を一方向にする。

```
BattleUnit  ──依存──▶  BattleFormula（何にも依存しない。引数は数値だけ）
```

- **軸の対応付け**（物理→`atk`/`def`、魔法→`mag`/`mdef`）は`BattleUnit.get_power()` / `get_defense()`に置く。ステータスを持っているのが`BattleUnit`だから
- **算術**（除算・クランプ・抽選）は`BattleFormula`に置く

**式が2箇所に散る問題（`EXEC_STATS_10_AXES.md` §2-4）は、これで構造的に潰れる。** 通常攻撃・スキル・デバッグ表示の3経路が同じ関数を呼ぶ。

### 3-2. `ATTACK_TYPE_*`の定数は`BattleUnit`に置く

`TEAM_PARTY` / `TEAM_ENEMY`と同じ「データの語彙」なので隣に置く。`BattleFormula`側に置くと3-1の依存が逆流する。

### 3-3. 派生値は生成時に一度だけ計算する

`max_hp` / `attack_interval_sec` / `speed`は`create()`の中で確定させる。**戦闘中にステータスが変わる仕組みは今は無い。**

`_process()`から`get_stat()`を何度も引かないため。将来バフを入れるときは、ここを再計算する関数を足す。

### 3-4. 会心の抽選と、ダメージの計算を分ける

`roll_crit()`と`damage()`を別関数にする。**デバッグパネルが「会心でないときのダメージ」を乱数なしで表示できるようにするため。** 1つの関数に混ぜると、表示のために式をもう1本書くことになる。

---

## 4. 人間がやる作業

### 4-1. `adventure_config.tres`に3つの値を入力する（**実機確認より前に必ず**）

**⚠ `.tres`は`@export`の既定値を書き出さない。** 現に`adventure_config.tres`は`[resource]`の下が**空**で、`stamina_cost_per_stage = 5`は`.gd`側にしか無い。`character_config.tres`も`stat_growth_formula`と`base_level_cap`の行が無い。**このプロジェクトはこの罠で既に2件死んでいる。**

`.gd`の既定値のままでも動くが、**Inspectorから調整できる状態にするには一度入力して保存する必要がある。**

1. FileSystemで`res://resources/balance/adventure_config.tres`を選ぶ
2. Inspectorに以下の3つが増えているので、**既定値と同じ値を一度入力し直して保存する**（値を変えなくても、触れば`.tres`に行が書かれる）

| 項目 | 入れる値 |
|---|---|
| Min Attack Interval Sec | `0.4` |
| Max Haste | `100` |
| Max Crit Rate | `100` |

3. `adventure_config.tres`をテキストエディタで開き、**3行が書かれていることを確認する**

### 4-2. 再インポートは不要

**`ja.csv`は今回変更しない。** 新しい表示テキストが無いため（会心は色と文字サイズで表す）。

### 4-3. `GAME_DESIGN.md`を2箇所直す（**設計役は触らない**）

決定4（`crit_rate`超過分を捨てる）に合わせる。

- **8-2** … 「`crit_rate`が100%を超えた分は`crit_dmg`に変換する（無駄になる強化を作らない）」の行を、決定に合わせて書き換える
- **14章「数値」** … 「`crit_rate`の超過分を`crit_dmg`に変換するレート」の行を消す。代わりに「`min_attack_interval_sec`の具体値」は**0.4で確定**したので、これも消せる

### 4-4. ドキュメントを更新する（実装が通ってから）

- `PROJECT_STATUS.md` … 10軸が戦闘に反映済みになったこと。宿題は§12
- `NEXT_STEPS.md` … 次のタスク（`PLAN_IMPLEMENTATION.md` 3章の3番＝レベルの役割転換）に書き換える
- `PLAN_STATS_AND_FORMULAS.md` … 5章「ダメージ確定の直前」が1箇所前提のままなので、2箇所→`BattleFormula`に集約されたことを反映する
- `AGENTS.md` … `CHARACTER_GROWTH`の行にある「（戦闘と画面は追従しない）」の注記を更新する。**画面と戦闘は追従するようになった**が、`BattleUnit.create()`が`GameManager.get_stat_keys()`を読む形になったことを書く

---

## 5. 設計役が書くもの

### 5-1. `res://resources/balance/adventure_config.gd`（末尾に追記）

冒頭コメントの「冒険選択画面まわりの数値調整用Config」を「**冒険・戦闘まわりの数値調整用Config**」に直したうえで、末尾に追記する。

```gdscript
# --- ステータスの上限（GAME_DESIGN.md 8-2-2） ---
#
# 【なぜ StatConfig を新設せず、ここに置くか】
# .tres は @export の既定値を書き出さない。新しい Config を作ると
# 「.gd を作る → .tres を作る → Balance の @export に足す → Inspector で割り当てる」
# の4手が要り、割り当てを1つ落とすと Balance.stat が null になって戦闘が起動しない。
# AdventureConfig は既に Balance に配線済みで、その事故が起きない。
# 上限が戦闘の外にも広がったら StatConfig に分ける（Balance.adventure.x → Balance.stat.x の置換だけで済む）。

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
```

### 5-2. `res://scripts/systems/battle_formula.gd`（**新規**）

```gdscript
class_name BattleFormula
extends RefCounted

# 戦闘の計算式を集約する静的クラス。
# SkillResolver と同じスタイル（Autoload にしない・状態を持たない）。
#
# 【なぜ1ファイルに集めるか】
# 10軸の前半で調べた結果、ダメージ計算が battle_controller.gd と
# skill_resolver.gd の2箇所に別々に書かれていた（EXEC_STATS_10_AXES.md §2-4）。
# 式を足すたびに両方へ同じものを書く形になっていたので、ここへ一本化する。
# 戦闘の式を直すときは、まずこのファイルを見ること。
#
# 【依存の向き】このファイルは何にも依存しない。引数はすべて数値。
# BattleUnit を参照しないこと。BattleUnit 側がこのファイルを参照するため、
# 相互参照になるとパースエラー（Cyclic reference）を踏む。
# 「どの軸を使うか」（物理→atk/def、魔法→mag/mdef）は BattleUnit.get_power() /
# get_defense() が持つ。ここに置くのは算術だけ。
#
# 【式の出典】GAME_DESIGN.md 8-2。式の本文をここに書き写さない。
# 【上限値】Balance.adventure（AdventureConfig）から引く。const で持たない。


# 実際の攻撃間隔（秒）。atkspd が高いほど短くなる。
#
# 上限は「％の上限」ではなく「秒数の下限」で持つ（GAME_DESIGN.md 8-2-2）。
# base_sec が 0 のデータでも下限が効くので、毎フレーム攻撃にはならない。
static func attack_interval(base_sec: float, atkspd: int) -> float:
	var denom: float = 1.0 + float(max(0, atkspd)) / 100.0
	return maxf(base_sec / denom, Balance.adventure.min_attack_interval_sec)


# 実際のクールダウン（秒）。haste が高いほど短くなる。
# haste は max_haste で頭打ちにする（超過分は捨てる）。
static func cooldown(base_sec: float, haste: int) -> float:
	var h: int = clampi(haste, 0, Balance.adventure.max_haste)
	return base_sec / (1.0 + float(h) / 100.0)


# 会心の抽選。damage() から分けてある。
#
# 分けている理由：デバッグパネルが「会心でないときのダメージ」を
# 乱数なしで出せるようにするため。混ぜると表示用にもう1本式を書くことになる。
#
# crit_rate は max_crit_rate で頭打ちにする。超過分は捨てる（crit_dmg に変換しない）。
static func roll_crit(crit_rate: int) -> bool:
	var rate: int = clampi(crit_rate, 0, Balance.adventure.max_crit_rate)
	if rate <= 0:
		return false
	return randf() * 100.0 < float(rate)


# 1発分のダメージ。必ず 1 以上を返す。
#
# power        … 物理なら atk、魔法なら mag（BattleUnit.get_power() が選ぶ）
# defense      … 物理なら def、魔法なら mdef（BattleUnit.get_defense() が選ぶ）
# multiplier   … スキル倍率 × チャージ倍率 × atk_multiplier を畳んだもの
# crit_dmg_percent … 150 なら 1.5 倍
# is_crit      … 呼び出し側が roll_crit() で決めて渡す。ここでは抽選しない
#
# 防御は除算。減算にしない（GAME_DESIGN.md 8-2-1）。
# 負の防御が入っても 100 + defense が 0 以下にならないよう 0 で切る。
static func damage(power: int, defense: int, multiplier: float, crit_dmg_percent: int, is_crit: bool) -> int:
	var value: float = float(power) * multiplier
	if is_crit:
		value = value * float(crit_dmg_percent) / 100.0
	var d: float = float(max(0, defense))
	return max(1, int(floor(value * 100.0 / (100.0 + d))))
```

### 5-3. `res://scripts/systems/unit.gd`（**全面書き換え**）

```gdscript
class_name BattleUnit
extends RefCounted

# 戦闘中ユニット 1 体分のデータと振る舞い。
# RefCounted 派生（Node を継承しない）。表示は UnitView が行う。
# hp は外部から直接書き換えない。必ず take_damage() / heal() 経由。
#
# 【10軸化で作り直した（EXEC_STATS_10_AXES_FORMULA.md）】
# 以前は hp / atk / def を個別のフィールドで持ち、_init() が10個の位置引数を
# 取っていた。軸が10本になると16個になり、呼び出し側で順番を間違えても
# 型が同じなら通ってしまう。そこで：
#
#   ・能力値は _stats: Dictionary 1本にまとめ、get_stat() 経由で読む
#   ・生成は static create() だけを入口にする（_init() は引数を取らない）
#
# 軸を増やすときにこのファイルを直す必要はない。
# GameManager.get_stat_keys() に足せば create() が拾う。

# team の値。文字列リテラル直書きを避けるため const 経由で参照する。
const TEAM_PARTY: String = "party"
const TEAM_ENEMY: String = "enemy"

# 攻撃の種別。characters.json / enemies.json / skills.json の "attack_type" に入る値。
#
# 種別と参照ステータスは連動する（物理は atk と def、魔法は mag と mdef）。
# 「魔力参照だが物理ダメージ」のような組み合わせを作れないよう、欄は1つにしてある。
# BattleFormula 側ではなくここに置くのは、BattleFormula が BattleUnit に
# 依存してはいけないため（battle_formula.gd の冒頭コメント）。
const ATTACK_TYPE_PHYSICAL: String = "physical"
const ATTACK_TYPE_MAGIC: String = "magic"

# --- 識別（生成後に変わらない） ---
var unit_id: String = ""
var team: String = ""
var unit_name_key: String = ""
var is_boss: bool = false

# --- 能力値（10軸） ---
# GameStateKeys.STAT_* をキーに int を持つ。
# 直接読まないこと。Dictionary は存在しないキーを読んでも null を返すだけで
# エラーにならないため、必ず get_stat() を通す（AGENTS.md「キー名を推測して書かない」）。
var _stats: Dictionary = {}

# --- 生成時に一度だけ計算する派生値 ---
# 戦闘中に能力値が変わる仕組みは今は無い。
# バフを入れるときは、ここを計算し直す関数を足すこと。
var max_hp: int = 0
var attack_range: float = 0.0
# atkspd を適用し、下限でクランプ済みの実効値。マスターの base ではない。
var attack_interval_sec: float = 0.0
var speed: float = 0.0
# 通常攻撃の種別（ATTACK_TYPE_*）
var attack_type: String = ATTACK_TYPE_PHYSICAL

# --- 戦闘中に変わる状態 ---
var hp: int = 0
var atk_multiplier: float = 1.0
var attack_timer: float = 0.0
var x: float = 0.0
# 未設定は ""。null を入れない（型が揺れる）。
var target_unit_id: String = ""
# 所持スキルID（順序を保つため配列で持つ。ボタンの並び順になる）
var skill_ids: Array = []
# skill_id -> cooldown_remaining(float)
var skill_cooldowns: Dictionary = {}


# 生成の唯一の入口。BattleUnit.new() を直接呼ばないこと。
#
# p_source … characters.json / enemies.json のエントリ。
#            name_key / attack_range / attack_interval_sec / attack_type を読む。
# p_stats  … 10軸の辞書。
#            味方は GameManager.get_effective_stats()（研究と装備が乗った最終値）、
#            敵はマスターのエントリそのもの（敵は p_source と同じ辞書を渡す）。
#
# 味方で p_source と p_stats が別物なのは、能力値だけが育成で変わり、
# attack_range と attack_interval_sec の base はマスターにしか無いため。
static func create(
		p_unit_id: String,
		p_team: String,
		p_source: Dictionary,
		p_stats: Dictionary,
		p_is_boss: bool = false
) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = p_unit_id
	unit.team = p_team
	unit.is_boss = p_is_boss
	unit.unit_name_key = str(p_source.get("name_key", ""))
	unit.attack_range = float(p_source.get("attack_range", 0))

	# 軸の一覧は GameManager が持つものを唯一の正とする。
	# ここに軸名を並べた2本目の配列を作らないこと（前半で equipment_screen.gd の
	# _stat_labels() が2本目の配列になっていて事故の元だった）。
	for stat_key in GameManager.get_stat_keys():
		if not p_stats.has(stat_key):
			push_warning("[BattleUnit] stats に %s が無い (unit_id=%s)" % [stat_key, p_unit_id])
		# MasterDataLoader は JSON の数値を float で返す。int() で包む。
		unit._stats[stat_key] = int(p_stats.get(stat_key, 0))

	unit.max_hp = unit.get_stat(GameStateKeys.STAT_HP)
	unit.hp = unit.max_hp
	unit.speed = float(unit.get_stat(GameStateKeys.STAT_SPD))
	unit.attack_interval_sec = BattleFormula.attack_interval(
		float(p_source.get("attack_interval_sec", 0)),
		unit.get_stat(GameStateKeys.STAT_ATKSPD)
	)

	var raw_type: String = str(p_source.get("attack_type", ATTACK_TYPE_PHYSICAL))
	if raw_type != ATTACK_TYPE_PHYSICAL and raw_type != ATTACK_TYPE_MAGIC:
		push_error("[BattleUnit] 不明な attack_type: %s (unit_id=%s)" % [raw_type, p_unit_id])
		raw_type = ATTACK_TYPE_PHYSICAL
	unit.attack_type = raw_type

	return unit


# 能力値を引く。未定義のキーは push_error して 0 を返す。
# 静かに null や 0 が返ると、式が黙って壊れて実機で気づけないため。
func get_stat(stat_key: String) -> int:
	if not _stats.has(stat_key):
		push_error("[BattleUnit] 未定義のステータス軸: %s (unit_id=%s)" % [stat_key, unit_id])
		return 0
	return int(_stats[stat_key])


# 攻撃側が使う軸。物理なら atk、魔法なら mag。
func get_power(p_attack_type: String) -> int:
	if p_attack_type == ATTACK_TYPE_MAGIC:
		return get_stat(GameStateKeys.STAT_MAG)
	return get_stat(GameStateKeys.STAT_ATK)


# 防御側が使う軸。物理なら def、魔法なら mdef。
func get_defense(p_attack_type: String) -> int:
	if p_attack_type == ATTACK_TYPE_MAGIC:
		return get_stat(GameStateKeys.STAT_MDEF)
	return get_stat(GameStateKeys.STAT_DEF)


# hp を減らす。0 未満にしない。
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = max(0, hp - amount)


# hp を増やす。max_hp を超えない。
func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = min(max_hp, hp + amount)


func is_alive() -> bool:
	return hp > 0


# ========================================================================
# スキル関連
# ========================================================================

# 全スキルの残り時間を delta だけ減らす。0.0 を下限とする。
func tick_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] = max(0.0, float(skill_cooldowns[skill_id]) - delta)


# skill_id が skill_ids に無い場合は false を返す（含まれていないスキルを発動可能と誤判定しない）。
func is_skill_ready(skill_id: String) -> bool:
	if not (skill_id in skill_ids):
		return false
	return float(skill_cooldowns.get(skill_id, 0.0)) <= 0.0


# クールダウン残り時間をセットする。skill_ids 外の ID は何もしない。
# 渡す秒数は haste 適用済みの実効値（BattleFormula.cooldown() を通したもの）。
func start_cooldown(skill_id: String, sec: float) -> void:
	if not (skill_id in skill_ids):
		return
	skill_cooldowns[skill_id] = sec


# クールダウン残り時間を返す。未登録の ID は 0.0。
func get_cooldown(skill_id: String) -> float:
	return float(skill_cooldowns.get(skill_id, 0.0))
```

**⚠ 書き換えたら`grep -n "func create" scripts/systems/unit.gd`と`grep -n "get_power" scripts/systems/unit.gd`が0件でないことを確認する。**

### 5-4. `res://scripts/systems/skill_resolver.gd`（3箇所）

#### 変更1：`resolve()`に`attack_type`の取り出しと検証を足す（22〜39行）

```gdscript
	var skill_type: String = str(skill_data.get("type", ""))
	var multiplier: float = float(skill_data.get("multiplier", 0.0))

	# 攻撃の種別。skills.json の "attack_type"。欄が無ければ物理。
	# 不正な値は物理に落として push_error する（黙って物理になると気づけない）。
	var attack_type: String = str(skill_data.get("attack_type", BattleUnit.ATTACK_TYPE_PHYSICAL))
	if attack_type != BattleUnit.ATTACK_TYPE_PHYSICAL and attack_type != BattleUnit.ATTACK_TYPE_MAGIC:
		push_error("[SkillResolver] 不明な attack_type: " + attack_type)
		attack_type = BattleUnit.ATTACK_TYPE_PHYSICAL

	match skill_type:
		"single":
			_resolve_single(user, session, multiplier, attack_type, results)
		"aoe":
			_resolve_aoe(user, session, multiplier, attack_type, results)
		"heal":
			_resolve_heal(user, session, multiplier, results)
```

`_resolve_single()` / `_resolve_aoe()` / `_apply_damage()` の引数に`attack_type: String`を足して素通しする。`_resolve_heal()`には渡さない（回復は常に`mag`参照）。

#### 変更2：`_resolve_heal()`の参照を`mag`に変える（80行）

```gdscript
	# 回復量は mag 参照。以前は atk を見ていたため、僧侶の回復が攻撃力依存だった。
	# 回復に attack_type は無い（常に mag）。skills.json 側にも欄を作らない。
	var amount: int = int(floor(float(user.get_stat(GameStateKeys.STAT_MAG)) * multiplier))
```

#### 変更3：`_apply_damage()`を`BattleFormula`に寄せる（88〜94行）

```gdscript
# 1体へのダメージ計算と take_damage 適用。
# 式は書かない。BattleFormula に集約してある（通常攻撃と同じ関数を通す）。
static func _apply_damage(target: BattleUnit, user: BattleUnit, multiplier: float, attack_type: String, results: Array) -> void:
	var is_crit: bool = BattleFormula.roll_crit(user.get_stat(GameStateKeys.STAT_CRIT_RATE))
	var dmg: int = BattleFormula.damage(
		user.get_power(attack_type),
		target.get_defense(attack_type),
		multiplier * user.atk_multiplier,
		user.get_stat(GameStateKeys.STAT_CRIT_DMG),
		is_crit
	)
	target.take_damage(dmg)
	results.append({ "unit_id": target.unit_id, "amount": dmg, "is_heal": false, "is_crit": is_crit })
```

**`_resolve_heal()`が積む結果にも`"is_crit": false`を足す**（呼び出し側が毎回`get()`の既定値に頼らないで済むように、キーの形を揃える）。

**⚠ 変更後、`grep -n "atk\b" scripts/systems/skill_resolver.gd`が0件になることを確認する**（`user.atk`が残っていないこと）。

### 5-5. `res://scenes/adventure/battle_controller.gd`（6箇所）

#### 変更1：味方の生成（150〜168行）

```gdscript
		# レベル・研究・装備を合成した最終値。get_character_growth() の生の stats を
		# 直接読まないこと（研究の stat_boost_all と装備の加算が乗らない）。
		# エントリが無いキャラでも characters.json の既定値から組み立てて返るため、
		# has_growth のフォールバック分岐は要らない。
		var stats: Dictionary = GameManager.get_effective_stats(character_id)

		# 軸をここで1本ずつ取り出さないこと。10軸を辞書のまま create() に渡す。
		# 軸が増えてもこの行は直さなくてよい。
		var unit: BattleUnit = BattleUnit.create(
			"party_%d" % i,
			BattleUnit.TEAM_PARTY,
			char_data,
			stats,
			false
		)
		unit.x = _party_start_x(i)
```

**`hp` / `atk` / `def` / `spd`のローカル変数4本は削除する。**

#### 変更2：敵の生成（254〜266行）

```gdscript
		for n: int in range(count):
			# 敵はマスターのエントリがそのまま能力値なので、
			# p_source と p_stats に同じ辞書を渡す。
			var unit: BattleUnit = BattleUnit.create(
				"enemy_%d_%d" % [_session.current_wave, local_index],
				BattleUnit.TEAM_ENEMY,
				enemy_data,
				enemy_data,
				is_boss
			)
			unit.x = ENEMY_BASE_X + local_index * ENEMY_STEP_X
			_session.enemy_units.append(unit)
```

#### 変更3：通常攻撃（383〜388行）

```gdscript
	if distance <= unit.attack_range:
		unit.attack_timer += delta
		if unit.attack_timer >= unit.attack_interval_sec:
			var is_crit: bool = BattleFormula.roll_crit(unit.get_stat(GameStateKeys.STAT_CRIT_RATE))
			var dmg: int = _compute_damage(unit, target, is_crit)
			target.take_damage(dmg)
			_pop_damage(target, dmg, is_crit)
			unit.attack_timer = 0.0
```

`unit.attack_interval_sec`は`create()`の時点で`atkspd`適用済みなので、**この行は変えない**（マスターからの直読みが消えている）。

#### 変更4：`_compute_damage()`（394〜398行）

```gdscript
# 通常攻撃のダメージ計算。式そのものは BattleFormula にある。
# ここに式を書き戻さないこと（スキル側と2箇所に分かれるため）。
# 会心の抽選は呼び出し側で行い、結果を受け取る（表示の色を変えるのに要る）。
func _compute_damage(attacker: BattleUnit, target: BattleUnit, is_crit: bool) -> int:
	var t: String = attacker.attack_type
	return BattleFormula.damage(
		attacker.get_power(t),
		target.get_defense(t),
		attacker.atk_multiplier,
		attacker.get_stat(GameStateKeys.STAT_CRIT_DMG),
		is_crit
	)
```

#### 変更5：`_pop_damage()`（401〜409行）

```gdscript
func _pop_damage(target: BattleUnit, amount: int, is_crit: bool = false) -> void:
	if target == null:
		return
	if not _views_by_unit_id.has(target.unit_id):
		return
	var view: Node = _views_by_unit_id[target.unit_id]
	if is_instance_valid(view) and view.has_method("pop_damage"):
		view.pop_damage(amount, is_crit)
```

スキル結果を回す箇所（600〜604行付近）も`is_crit`を渡す。

```gdscript
	for r in results:
		if not (r is Dictionary):
			continue
		var target: BattleUnit = _find_unit_by_id(str(r.get("unit_id", "")))
		_pop_damage(target, int(r.get("amount", 0)), bool(r.get("is_crit", false)))
```

#### 変更6：クールダウンに`haste`を効かせる（477行・599行）

477行（スキルボタンの`entry`を作るところ）：

```gdscript
			var entry: Dictionary = {
				"button": button,
				"gauge": gauge,
				"user": unit,
				"skill_id": skill_id,
				"name_key": str(skill_data.get("name_key", "")),
				# haste 適用済みの実効 CD。base を入れないこと（表示に使うときにずれる）。
				"cooldown_sec": BattleFormula.cooldown(
					float(skill_data.get("cooldown_sec", 0.0)),
					unit.get_stat(GameStateKeys.STAT_HASTE)
				),
				"charge": charge,
			}
```

599行（発動時にCDを開始するところ）：

```gdscript
	# skills.json の cooldown_sec は base。haste を通してから渡す。
	user.start_cooldown(skill_id, BattleFormula.cooldown(
		float(skill_data.get("cooldown_sec", 0.0)),
		user.get_stat(GameStateKeys.STAT_HASTE)
	))
```

**⚠ 変更後、`grep -n "attacker.atk\|target.def\|\.atk \* \|- target.def" scenes/adventure/battle_controller.gd`が0件になることを確認する。**

### 5-6. `res://scenes/adventure/unit_view.gd`（2箇所）

#### 変更1：会心用の色とサイズを足す（13〜16行の下）

```gdscript
# 会心の表示。通常のダメージより大きく・強い色にする。
# 「会心」という文字は出さない（ja.csv に増やさない。数字が大きく跳ねるほうが読める）。
const CRIT_COLOR: Color = Color(1.0, 0.55, 0.25)
const CRIT_FONT_SIZE: int = 32
```

#### 変更2：`pop_damage()`（65〜66行）

```gdscript
# 被弾した数値を頭上に浮かべて消す。
# is_crit の既定値を false にしてあるので、既存の呼び出し（もしあれば）は壊れない。
func pop_damage(amount: int, is_crit: bool = false) -> void:
	if is_crit:
		pop_label(str(amount), CRIT_COLOR, CRIT_FONT_SIZE)
	else:
		pop_label(str(amount), DAMAGE_COLOR, DAMAGE_FONT_SIZE)
```

### 5-7. `res://scenes/adventure/battle_debug_panel.gd`（`_format_unit()`を2行構成にする）

**除算式が効いているかを確かめる主な手段。** 10軸と実効攻撃間隔、そして**現在の対象への非会心ダメージ**を出す。

```gdscript
# 1ユニットにつき2行出す。
# 1行目 … 位置・HP・ターゲット・攻撃タイマー（実効攻撃間隔つき）
# 2行目 … 10軸と、いま狙っている相手に通る非会心ダメージ
#
# ダメージの式はここに書かない。BattleFormula.damage() をそのまま呼ぶ。
# 会心は抽選せず必ず false を渡すので、表示はフレームごとにぶれない。
func _format_unit(unit: BattleUnit) -> String:
	if unit == null:
		return "  (null)"
	var mark: String = " " if unit.is_alive() else "x"
	var target: String = unit.target_unit_id if unit.target_unit_id != "" else "-"
	var line1: String = "%s %-12s hp %4d/%-4d x %6.1f tgt %-12s t %.2f/%.2f" % [
		mark, unit.unit_id, unit.hp, unit.max_hp, unit.x,
		target, unit.attack_timer, unit.attack_interval_sec
	]
	var line2: String = "    %-8s atk %3d mag %3d def %3d mdef %3d | as %3d%% ha %3d%% cr %3d%% cd %3d%% spd %3d | dmg %s" % [
		unit.attack_type,
		unit.get_stat(GameStateKeys.STAT_ATK), unit.get_stat(GameStateKeys.STAT_MAG),
		unit.get_stat(GameStateKeys.STAT_DEF), unit.get_stat(GameStateKeys.STAT_MDEF),
		unit.get_stat(GameStateKeys.STAT_ATKSPD), unit.get_stat(GameStateKeys.STAT_HASTE),
		unit.get_stat(GameStateKeys.STAT_CRIT_RATE), unit.get_stat(GameStateKeys.STAT_CRIT_DMG),
		unit.get_stat(GameStateKeys.STAT_SPD),
		_format_damage_to_target(unit)
	]
	return line1 + "\n" + line2


# いま狙っている相手に通る非会心ダメージ。対象がいなければ "-"。
func _format_damage_to_target(unit: BattleUnit) -> String:
	if _controller == null or unit.target_unit_id == "":
		return "-"
	var session: BattleSession = _controller.get_session()
	if session == null:
		return "-"
	var target: BattleUnit = null
	for u in session.party_units + session.enemy_units:
		if u is BattleUnit and u.unit_id == unit.target_unit_id:
			target = u
			break
	if target == null:
		return "-"
	var t: String = unit.attack_type
	return str(BattleFormula.damage(
		unit.get_power(t),
		target.get_defense(t),
		unit.atk_multiplier,
		unit.get_stat(GameStateKeys.STAT_CRIT_DMG),
		false
	))
```

ヘルプ行（55〜62行）にも1行足す。

```gdscript
		"※ 2行目の dmg は非会心のダメージ（会心分は含まない）",
```

#### 追加（人間の指示で後から入れた3点）

**1. パネルを右上に移す。** 左上（`8, 8`）だと味方ユニットに重なる。

`CanvasLayer`は`Control`ではないので**子のアンカー（`PRESET_TOP_RIGHT`）は効かない**（`EXEC_STATS_10_AXES.md` §13-4）。`debug_overlay.gd`と同じく、ビューポート幅から位置を計算する`_place_top_right()`を持たせ、`_process()`と`size_changed`の両方から呼ぶ（**表示する行の幅が毎フレーム変わるため、生成時の1回では足りない**）。

⚠ **右上は`debug_overlay.gd`（`0`キー）も使っている。両方開くと重なる。** 戦闘中に資源を配る用事は少ないので、重なったらオーバーレイを`0`で閉じる。

**2. `J`（味方全員に10ダメージ）を物理／魔法の2つに割る。**

| キー | 効果 |
|---|---|
| `J` | 味方全員に**物理**の一撃（威力10 → 各自の`def`で割る） |
| `M` | 味方全員に**魔法**の一撃（威力10 → 各自の`mdef`で割る） |

**`take_damage(10)`を直接呼ばないこと。** `BattleFormula.damage()`を通す。そうしないと「除算が効いているか」「`mdef`が生きているか」をこのボタンで確かめられない。**会心はしない**（毎回同じ値が出ないと比較にならない）。

`battle_controller.gd`の`debug_damage_party()`は`(power: int, attack_type: String)`の2引数になる。

**3. `_call_controller()`を`callv`にする。** 従来は「引数1個か0個か」を`null`で分岐していて、2個を渡せない。

```gdscript
func _call_controller(method: String, args: Array = []) -> void:
	...
	_controller.callv(method, args)
```

### 5-8. `res://resources/balance/master/characters.json`（3キャラに`attack_type`）

各キャラの`"attack_range"`の行の直前に足す。

| キャラ | 値 | 理由 |
|---|---|---|
| `char_swordsman` | `"physical"` | `atk` 18 / `mag` 4 |
| `char_archer` | `"physical"` | `atk` 14 / `mag` 6 |
| `char_priest` | `"magic"` | `mag` 16 / `atk` 10。**僧侶の通常攻撃が敵の`mdef`を叩く経路になる** |

```json
	"attack_type": "physical",
```

**インデントはタブ。既存の行に合わせる。**

### 5-9. `res://resources/balance/master/enemies.json`（3体に4軸＋`attack_type`）

前半で`mag`と`mdef`は入ったが、**`atkspd` / `haste` / `crit_rate` / `crit_dmg`が無い。** 無いと`create()`が`push_warning`を出し続ける。

```json
{
  "enemy_slime": {
	"name_key": "ui_battle_enemy_slime",
	"hp": 40, "atk": 8, "mag": 2, "def": 2, "mdef": 2, "spd": 40,
	"atkspd": 0, "haste": 0, "crit_rate": 0, "crit_dmg": 150,
	"attack_type": "physical",
	"attack_range": 50, "attack_interval_sec": 1.5
  },
  "enemy_wolf": {
	"name_key": "ui_battle_enemy_wolf",
	"hp": 55, "atk": 12, "mag": 2, "def": 3, "mdef": 1, "spd": 80,
	"atkspd": 0, "haste": 0, "crit_rate": 0, "crit_dmg": 150,
	"attack_type": "physical",
	"attack_range": 50, "attack_interval_sec": 1.0
  },
  "boss_slime_king": {
	"name_key": "ui_battle_enemy_slime_king",
	"hp": 300, "atk": 20, "mag": 12, "def": 8, "mdef": 6, "spd": 30,
	"atkspd": 0, "haste": 0, "crit_rate": 0, "crit_dmg": 150,
	"attack_type": "magic",
	"attack_range": 70, "attack_interval_sec": 1.8
  }
}
```

**⚠ ボスを`magic`にしたのは、味方の`mdef`が効いていることを実機で確かめられる敵が他に無いため。** ボスの攻撃は`atk` 20 ではなく`mag` 12 を見るようになり、弱くなる。**バランス調整の回（`PLAN_IMPLEMENTATION.md` 3章の12番）で、魔法型の敵を別に作って戻すか決める。** 気に入らなければJSONの1語を`physical`に戻すだけでよい。

`crit_rate`を敵で0にしているのは、**乱数で「たまに固い」が起きると除算式の検証が難しくなるため。**

### 5-10. `res://resources/balance/master/skills.json`（5スキルに`attack_type`）

| スキル | 値 |
|---|---|
| `skill_power_slash` | `"physical"` |
| `skill_wide_sweep` | `"physical"` |
| `skill_snipe` | `"physical"` |
| `skill_arrow_rain` | `"physical"` |
| `skill_holy_ray` | `"magic"` |
| `skill_healing_light` | **足さない**（`type: "heal"`は常に`mag`参照。欄を作ると2つの指定が食い違える） |

`"cooldown_sec"`の行の直後に足す。**インデントはタブ。**

### 5-11. `res://autoload/game_manager.gd`（コメント1箇所）

`_stat_keys()`（1006〜1016行付近）のコメントが古くなる。

```gdscript
# 追従しないもの（別のファイルを直す必要がある）：
#   battle_controller.gd の BattleUnit.new()（引数がベタ書き。式の回で作り直す）
```

を、次に差し替える。

```gdscript
# 戦闘も追従する（EXEC_STATS_10_AXES_FORMULA.md）：
#   BattleUnit.create() が get_stat_keys() を回して 10軸を取り込む。
#   ただし式（どの軸をどう使うか）は BattleFormula と BattleUnit.get_power() /
#   get_defense() にあるので、新しい軸を「効かせる」にはそちらも直すこと。
```

---

## 6. 作業の順番

**依存の下から書く。** 途中でエディタを開くと未定義参照でエラーが出る順番があるため。

1. `adventure_config.gd`（上限値の置き場） … 他が参照する
2. `battle_formula.gd`（新規） … `Balance.adventure`を参照
3. `unit.gd`（全面書き換え） … `BattleFormula`と`GameManager.get_stat_keys()`を参照
4. `characters.json` / `enemies.json` / `skills.json` … データを先に揃える（`create()`の警告が出ないように）
5. `skill_resolver.gd`
6. `battle_controller.gd`
7. `unit_view.gd`
8. `battle_debug_panel.gd`
9. `game_manager.gd`（コメントのみ）
10. **人間**：§4-1（`adventure_config.tres`に3値を入力）
11. **人間**：実機確認（§7〜§9）

---

## 7. 完了条件：画面（人間が実機で確かめる）

**先にデバッグオーバーレイ（`0`キー）で「装備を全種類 1個ずつ」と「研究を全部解放」を押しておくと、軸が動いた状態で見られる。**

1. 戦闘画面に入り、**エラーなく開始できる**（パースエラー・`Cyclic reference`が出ないこと）
2. `F3`でデバッグパネルを開く。**画面の右上**に出る（左上ではない）。**1ユニットにつき2行**出ており、2行目に`atk` `mag` `def` `mdef` `as` `ha` `cr` `cd` `spd`と`dmg`が並んでいる
   - ウィンドウの大きさを変えても右上に貼り付いたままになる
2-2. **`J`（物理の一撃）と`M`（魔法の一撃）で、同じ味方でもダメージが違う。** 威力はどちらも10。剣士（`def` 6 / `mdef` 4）なら物理 `10×100/106 = 9`、魔法 `10×100/104 = 9`。**装備で片方だけ上げると差が開く。** ログにも「`party_0 に physical 威力10 → 9 ダメージ（防御 6）`」と出る
3. **2行目の`dmg`の値と、実際に頭上に出るダメージ数値が一致する**（会心が出たときを除く）
4. **`dmg`が`atk - def`より大きい。** 例：`enemy_slime`（`def` 2）に剣士（`atk` 18）が殴ると、減算なら16。除算なら `18 × 100 / 102 = 17`。**装備と研究を積むほど差が開く**
5. **僧侶（`char_priest`）の通常攻撃だけ、2行目の`attack_type`が`magic`になっている。** その`dmg`は`mag` 16 と敵の`mdef`から計算されている
6. **ボス（`boss_slime_king`）の`attack_type`が`magic`**で、味方に与えるダメージが味方の`mdef`を見て決まっている
7. **僧侶のスキル`skill_healing_light`で回復する量が増えている**（`atk` 10 参照 → `mag` 16 参照。倍率1.0なので10→16）
8. **`atkspd`が乗った味方の攻撃タイマーの分母（`t 0.55/1.20`の右側）が、`characters.json`の`attack_interval_sec`より小さい。** 装備で`atkspd`が付いていない場合は同じ値でよい
9. **`haste`が乗った味方のスキルボタンのCD表示が、`skills.json`の`cooldown_sec`より短い**（`S`キーでCDをリセットしてから撃つと測りやすい）
10. **会心が出ると、ダメージ数値が大きく・オレンジ寄りの色になる。** 剣士は`crit_rate` 5%、弓は10%なので、8倍速で1ウェーブ回せば数回は出る
11. `V`で強制勝利、`B`で強制敗北が今までどおり動く
12. **チャージスキル（`skill_wide_sweep`）が今までどおり動く**（押しっぱなしでゲージが伸び、離すと発動する）

## 8. 完了条件：ログ（Godotの出力パネル）

**画面で分かることはここに書かない。** ここに残すのは画面に出ない内部の値だけ。

1. 戦闘開始時に **`[BattleUnit] stats に ◯◯ が無い` の警告が1件も出ていない**（味方3人・敵すべてで10軸が揃っている）
2. **`[BattleUnit] 不明な attack_type` のエラーが出ていない**（JSONの綴りミス）
3. **`[BattleUnit] 未定義のステータス軸` のエラーが出ていない**（`get_stat()`にキー名のtypoが無い）
4. **`[SkillResolver] 不明な attack_type` のエラーが出ていない**

## 9. 完了条件：セーブファイル

**今回は確認不要。セーブ構造は変わらない。**

`save_version`も2のまま。10軸は前半で既に入っており、このタスクは戦闘側だけを直すため。

---

## 10. UIから到達できない項目（人間は確認しない）

将来コードを変えたときに見る項目。**今回は確認しなくてよい。**

- `BattleUnit.new()`を直接呼ぶと`_stats`が空になり、`get_stat()`が全キーで`push_error`する（`create()`を通させるための設計。防いでいない）
- `attack_interval_sec`が0のデータでも、下限（0.4秒）でクランプされて毎フレーム攻撃にはならない
- `defense`が負の値でも`100 + defense`が0以下にならない（0で切っている）
- `crit_rate`が100を超えても100として扱われる（超過分は捨てる）

---

## 11. 併せて直さないもの

- **バランス調整**（敵HP・スキル倍率）。`PLAN_IMPLEMENTATION.md` 3章の12番。**式が入った直後は数値が壊れて見えるのが正常**
- **`stat_growth_formula`を`"base"`にしない。** 割り振りポイントが無いうちに変えるとレベルアップが無意味になる（3章の3番）
- **`items.json`の`equip_stats`に新軸を足さない**（装飾の回）
- **魔法型の敵を新規に作らない**（§5-9でボスの種別を変えるだけに留める）
- **バフ・デバフ**（`atk_multiplier`は1.0のまま。派生値の再計算も入れない）

---

## 12. このタスクで残す宿題（`PROJECT_STATUS.md`に足す）

1. **敵の`crit_rate`が全部0。** 検証しやすさのために0にしている。敵に会心を持たせるかはバランス調整の回で決める
2. **ボス`boss_slime_king`が`magic`。** 味方の`mdef`を検証するための暫定。魔法型の敵を別に作ったら戻すか決める
3. **`atk_multiplier`が使われていない**（常に1.0）。バフを入れるときに、派生値（`attack_interval_sec`）の再計算とセットで設計する
4. **`char_priest`の通常攻撃が`magic`になった。** 射程250で`mag` 16 を撃つため、僧侶の火力の位置づけが変わる。バランス調整の回で見る
5. **検証用のものはリリース前に消す**（デバッグオーバーレイ・0Gスロット・`weapon_debug_blade`。前半からの継続）

---

## 13. 実施結果（2026-08-15）

**実装役は使わず、設計役（Claude Code）が全ファイルを書いた。** 人間が§7（画面）・§8（ログ）を実機で確認し、コミット済み（`5150135 防御力等変更した`）。

| ファイル | 結果 |
|---|---|
| `scripts/systems/battle_formula.gd` | **新規**（`attack_interval` / `cooldown` / `roll_crit` / `damage`） |
| `scripts/systems/unit.gd` | **全面書き換え**（`_stats`辞書＋`create()`＋`get_stat()` / `get_power()` / `get_defense()`） |
| `scripts/systems/skill_resolver.gd` | 変更（3箇所。`attack_type`の素通し／回復を`mag`参照／ダメージを`BattleFormula`へ） |
| `scenes/adventure/battle_controller.gd` | 変更（6箇所＋`debug_damage_party()`） |
| `scenes/adventure/unit_view.gd` | 変更（会心の色・サイズ、`pop_damage(amount, is_crit)`） |
| `scenes/adventure/battle_debug_panel.gd` | 変更（2行表示・右上へ移動・`J`/`M`・`callv`・日本語名） |
| `resources/balance/adventure_config.gd` | 変更（上限3つを追加） |
| `resources/balance/master/characters.json` | 変更（`attack_type`。僧侶は`magic`） |
| `resources/balance/master/enemies.json` | 変更（不足4軸＋`attack_type`。ボスは`magic`） |
| `resources/balance/master/skills.json` | 変更（5スキルに`attack_type`。回復には付けない） |
| `resources/balance/master/parties.json` | 変更（**指示書に無い**。§13-1の3） |
| `autoload/game_manager.gd` | 変更（コメントのみ） |

### 13-1. 指示書に無い追加（3件・すべて人間の指示）

実装が通ったあとに出た要望。**どれも検証のしやすさが理由。**

1. **`J`（味方全員に10ダメージ）を`J`＝物理／`M`＝魔法に割った。** `take_damage()`直呼びをやめ、`BattleFormula.damage()`を通す形にした。**これが無いと`def`と`mdef`の差をボタンで確かめられない。** 併せて`_call_controller()`を`callv`にした（引数2個を渡せなかった）
2. **`F3`パネルを左上→右上へ移した。** 左上は味方ユニットに重なる。`CanvasLayer`の子はアンカーが効かないため、`debug_overlay.gd`と同じくビューポート幅から座標を計算し、**`_process()`からも置き直す**（行の幅が毎フレーム変わるため）
3. **パーティの並びを`[僧侶, 弓兵, 剣士]`に変えて剣士を最前列（右端）にした。** `parties.json`の1行。**スキルボタンの並びもこの順になる**（画面の左右と一致する）

### 13-2. この指示書の誤り（0件）

§5のコードはそのまま通った。

### 13-3. 設計時に指示書から変えた点（1件・実装前）

**`BattleFormula`が`BattleUnit`を参照しない形にした**（§3-1）。提案時は`damage(attacker, target, ...)`だったが、相互参照でパースエラー（Cyclic reference）を踏む可能性があり、設計役は起動して確かめられないため。軸の対応付けを`BattleUnit.get_power()` / `get_defense()`に置き、`BattleFormula`は数値だけを受け取る。

### 13-4. 未実施（人間の作業。§4）

- **`adventure_config.tres`に3値が書かれていない。** `[resource]`の下が空のまま。**`.gd`の既定値（0.4 / 100 / 100）が効いているので動作に影響は無い**が、Inspectorから調整する前に一度入力が要る
- **`GAME_DESIGN.md`が未修正**（487行の「超過分を`crit_dmg`に変換する」・861行の未決項目）。**決定4と食い違ったまま**

### 13-5. このタスクで確定した、次回に効く事実

- **`BattleUnit`の生成は`create()`1本になった。** 軸を増やしても`GameManager.get_stat_keys()`に足せば戦闘まで届く。ただし**「効かせる」には`BattleFormula`と`get_power()` / `get_defense()`も直す**
- **戦闘の式は`battle_formula.gd`の1ファイルに集約された。** 通常攻撃・スキル・デバッグ表示の3経路が同じ関数を通る
- **`CanvasLayer`の子はアンカーが効かない**（前半の§13-4-3と同じ事実を再確認）。右上・右下に置くならビューポート幅から計算する
- **`F4`は届かないが`J`・`M`・`0`・`F3`は届く**（キーの追加は英字が安全）
