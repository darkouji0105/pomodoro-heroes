# 【実行指示書】ステータス10軸（**器だけ。式は次回**）

**状態：未着手。**

第3層。対応する第2層は`PLAN_STATS_AND_FORMULAS.md`（**実コードと突き合わせ済み。ズレは§2に列挙した**）。軸と式の正は`GAME_DESIGN.md` 8章。

**このタスクは実装役を使わない。** 触る既存ファイルのうち`game_manager.gd`が2280行、`equipment_screen.gd`が283行、`state_keys.gd`が225行＝200行超のため、`WORKFLOW.md`「実装役に渡してよい仕事」により設計役が書く。残り2ファイルも同じ会話で書いたほうが軸の並びが揃う。

| 誰 | 担当 |
|---|---|
| **人間** | `initial_state_config.tres`の`save_version` / `ja.csv`の再インポート / 実機確認 / ドキュメント更新 / コミット |
| **設計役** | `state_keys.gd` / `game_manager.gd` / `save_manager.gd` / `training_screen.gd` / `equipment_screen.gd` / `characters.json` / `enemies.json` / `ja.csv`（本文） |
| **実装役** | なし |

---

## 1. このタスクで実現すること

**ステータスの軸を4本から10本にする。器だけ。**

到達点は「**育成画面と装備画面に10軸が並ぶ。戦闘は今まで通り動く**」。

**戦闘の式は含まない。** `def`の除算化・クリティカル抽選・`atkspd`・`haste`・物理／魔法の出し分け・`BattleUnit`の拡張は次回（同じ2番の後半）。

### なぜ2回に分けたか

1回で通すと、実機で壊れたときに「軸追加が悪いのか式が悪いのか」を切り分けられない。さらに`def`を減算→除算にすると既存の敵HP・`atk`の数値の意味が全部変わる（`GAME_DESIGN.md` 14章が「敵HP・スキル倍率は10軸が入ってから」と保留している）。**式まで一度に入れると、実機確認が「合っているか分からない」状態になる。**

---

## 2. PLANと実コードのズレ（**着手前に確認済み。もう`grep`し直さなくてよい**）

### 2-1. 「`_stat_keys()`に足せば全部追従する」は半分しか本当ではない

`PLAN_STATS_AND_FORMULAS.md` 1章と`GAME_DESIGN.md` 15章の前提が、ここで破れる。

**追従する（触らない）：** `get_effective_stats()` / `get_instance_stats()` / `get_equipment_bonus()` / `_default_growth_for()` / `_recalc_stats()` / `load_state()`の`int()`正規化（`game_manager.gd` 2153行）。

**追従しない：**

| 場所 | 中身 | 今回 |
|---|---|---|
| `training_screen.gd` 112〜115行 | 4行ベタ書き | **直す** |
| `equipment_screen.gd` 238〜244行 | `_stat_labels()`という**もう1本の4軸配列** | **直す** |
| `battle_controller.gd` 152〜168行 | 4変数を取り出して`BattleUnit.new()`へ | **触らない（次回）** |

### 2-2. 研究の`boost_all`が％軸にも乗る（**PLANにも`GAME_DESIGN.md`にも記述が無い**）

`game_manager.gd` 916行が`boost_all`を**全キーに無条件で加算**している。10軸にすると研究の「全ステータス+3」が`crit_rate +3%` `haste +3%`にも乗る。**§5-2で直す。**

### 2-3. `attack_interval_sec`と`cooldown_sec`は直読みだった（`PROJECT_STATUS.md` 329行の懸念は当たり）

- `battle_controller.gd` 165行 … `char_data.get("attack_interval_sec")`。**すぐ上の150行で`get_effective_stats()`を取っているのに、攻撃間隔だけマスターから読んでいる**
- 同 477行・599行 … `skill_data.get("cooldown_sec")`をskills.jsonから直読み。`haste`が入る場所が無い

**今回は直さない（式の回）。** §9でドキュメントに「確認済み」と書く。

### 2-4. ダメージ経路は2箇所ある

`battle_controller.gd` 397行と`skill_resolver.gd` 91行（`static`の別ファイル）。どちらも`atk - def`の減算。**PLAN 5章は1箇所前提で書かれている。次回は2箇所に当てる。**

### 2-5. `skills.json`に参照欄は無い（PLAN 4章「見て、無ければ追加」→ 無い）

`atk`/`mag`の参照欄も物理／魔法の種別欄も無い。加えて**`skill_resolver.gd` 80行の回復量が`user.atk`参照**。僧侶の回復が攻撃力依存になっている。**次回の判断材料。今回は触らない。**

### 2-6. `SAVE_VERSION`を上げるだけでは旧セーブを捨てられない

`save_manager.gd` 56〜57行が不一致を`push_warning`するだけで`continuing`している。**§5-5で直す。**

### 2-7. チャージスキルのCD衝突は起きない（PLAN 7章のチェック結果）

チャージ持ちは`skill_wide_sweep`のみ・CD 8.0秒。`haste`100%でも4.0秒で、ジャストの1.0秒を大きく上回る。最短CDは`skill_power_slash`の6.0秒。**次回も問題なし。**

---

## 3. 事故りやすい箇所（先に読むこと）

### 3-1. `save_version`の出どころが**3箇所ある**

| 場所 | 現在 | 誰が直すか |
|---|---|---|
| `save_manager.gd` 5行 `CURRENT_SAVE_VERSION` | 1 | 設計役（§5-5） |
| `game_manager.gd` 197行 `_empty_state_template()` | 1（ベタ書き） | 設計役（§5-4） |
| `initial_state_config.tres` 16行 `save_version` | 1（**書き出されている**） | **人間（§4-1）** |

**新規開始は`_init_from_config()`が`.tres`の値で上書きするため、`.tres`が実際に効く。** 3つとも2にしないと、**新規開始したセーブが次回起動で自分に弾かれる無限ループになる。**

### 3-2. ％系は`int`で持つ

`crit_rate: 25` ＝ 25%。`float`だとセーブに`"crit_rate": 25.0`と書かれる（`CLAUDE.md` 3番）。`_default_growth_for()`と`_recalc_stats()`は既に`int()`で包んであるので、`_stat_keys()`に足せば追従する。**JSONに`25.0`と書かないこと。**

### 3-3. `ja.csv`はUTF-8（BOMなし）

BOMが付くと1行目が`﻿keys`になり全滅する。**編集後のGodotでの再インポートは人間の作業**（§4-2）。

### 3-4. 状態にマスターデータを複製しない

今回増えるのは`stats`のキーだけ。**上限値・％の意味・軸の分類を`stats`に持たせない。** `_percent_stat_keys()`はコード側の分類であって、セーブには出ない。

### 3-5. `equip_stats`（items.json）は今回書き足さない

`get_instance_stats()`が`.get(stat_key, 0)`で読むため、JSONに無い軸は0になる。装備一覧の`_stats_text()`は**0の軸を行に出さない**ので、表示も伸びない。**装備に新軸を載せるのは装飾（6番）と等級10（4番）の回。**

---

## 4. 人間がやる作業

### 4-1. `initial_state_config.tres`の`save_version`を2にする（**設計役の作業より先でも後でもよいが、実機確認より前に必ず**）

`res://resources/balance/initial_state_config.tres`をInspectorで開き、`Save Version`を`1` → `2`。

> **これを忘れると、新規開始したセーブが次回起動で「バージョン不一致」として弾かれ続ける。** 症状は「毎回タイトルで読み込み失敗のモーダルが出て、進捗が残らない」。

### 4-2. `ja.csv`を再インポート

設計役が本文を書く。**保存後、FileSystemパネルで`ja.csv`を右クリック → 再インポート（またはGodot再起動）。** これをしないと画面にキー名（`ui_training_stat_mag`）がそのまま出る。

### 4-3. 旧セーブを消すかどうかを決める（§8-4を見てから）

弾いたあとも`user://saves/save_slot_0.json`は残る。次回起動でも同じモーダルが出る。**タイトル画面の「セーブを削除」で自分で消せる。** 自動削除は入れない（取り返しがつかないため。§11）。

### 4-4. ドキュメントを更新する（実装が通ってから）

- `PROJECT_STATUS.md` … 「同じ形の見落としが`attack_interval_sec`と`cooldown_sec`にある可能性が高い」の箇所を**「確認済み。直読みだった（`battle_controller.gd` 165 / 477 / 599行）。式の回で直す」**に更新
- `AGENTS.md` 「GameManagerの状態構造」の表 … `stats: {hp, atk, def, spd}` → 10軸に
- `NEXT_STEPS.md` … 次のタスク（式の反映）に書き換える
- `PLAN_STATS_AND_FORMULAS.md` … **直さない。** ズレは本ファイル§2が持つ（`CLAUDE.md`「ドキュメントが間違っていたら報告する。勝手に直さない」）

---

## 5. 設計役が書くもの

### 5-1. `res://scripts/utils/state_keys.gd`（125〜129行を差し替え）

**並びは`GAME_DESIGN.md` 8-1の表と同じ順にする。** 順番を自分で決めない。

```gdscript
# stats: 10軸（GAME_DESIGN.md 8-1）。並びは 8-1 の表と同じ順。
# 実数6本（hp/atk/mag/def/mdef/spd）＋％系4本（atkspd/haste/crit_rate/crit_dmg）。
#
# ％系は int で持つ（crit_rate: 25 ＝ 25%）。float だとセーブに 25.0 と書かれる。
# 実数も％も同じ stats 辞書に入れる（別バケットにしない。PLAN_STATS_AND_FORMULAS.md 1章）。
const STAT_HP: String = "hp"
const STAT_ATK: String = "atk"
const STAT_MAG: String = "mag"
const STAT_DEF: String = "def"
const STAT_MDEF: String = "mdef"
const STAT_ATKSPD: String = "atkspd"
const STAT_HASTE: String = "haste"
const STAT_CRIT_RATE: String = "crit_rate"
const STAT_CRIT_DMG: String = "crit_dmg"
const STAT_SPD: String = "spd"
```

### 5-2. `res://autoload/game_manager.gd`（3箇所）

#### 変更1：`_stat_keys()`を10本にし、公開getterと％軸の分類を足す（998行付近）

```gdscript
# stats のキー10本（GAME_DESIGN.md 8-1）。並びは 8-1 の表と同じ順。
# 順序を固定したいので配列で持つ。
#
# ここに足すと追従するもの：
#   get_effective_stats() / get_instance_stats() / get_equipment_bonus()
#   _default_growth_for() / _recalc_stats() / load_state() の int() 正規化
#
# 追従しないもの（別のファイルを直す必要がある）：
#   battle_controller.gd の BattleUnit.new()（引数がベタ書き。式の回で作り直す）
func _stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_HP,
		GameStateKeys.STAT_ATK,
		GameStateKeys.STAT_MAG,
		GameStateKeys.STAT_DEF,
		GameStateKeys.STAT_MDEF,
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
		GameStateKeys.STAT_SPD,
	]

# 画面がステータスをこの順で並べるために公開する（get_equip_slots() と同じ形）。
# 画面側に軸の配列を複製させないこと。以前 equipment_screen.gd に
# _stat_labels() という2本目の4軸配列があり、片方だけ直す事故の元になっていた。
func get_stat_keys() -> Array[String]:
	return _stat_keys()

# ％で持つ軸（GAME_DESIGN.md 8-1）。実数軸と同じ stats 辞書に入るが、扱いが2箇所だけ違う。
#
#  1. 研究の「全ステータス+N」（stat_boost_all の target_stat = "all"）の対象にしない
#  2. 画面に "%" を付けて出す
#
# 1 を守らないと、研究ノード1つで crit_rate と haste が同時に上がる。
# ％系は装備と装飾だけで動かす前提（PLAN_STATS_AND_FORMULAS.md 4章）なので、
# 研究で上がると装飾を刺す理由が消える。
#
# なお target_stat で名指しされた加算（boosts.get(stat_key)）は％軸にも効かせる。
# 「会心率を上げる研究ノード」を将来置けるようにするため。
func _percent_stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
	]

# 画面が "%" を付けるかどうかの判定に使う。
func is_percent_stat(stat_key: String) -> bool:
	return stat_key in _percent_stat_keys()
```

#### 変更2：`get_effective_stats()`の`boost_all`を実数軸だけに限る（911〜919行）

**差し替える範囲は`var result: Dictionary = {}`から`return result`まで。** その上の`growth` / `raw` / `boosts` / `boost_all` / `equip`の5行は触らない。

```gdscript
	var result: Dictionary = {}
	var percent_keys: Array[String] = _percent_stat_keys()
	for stat_key: String in _stat_keys():
		# 研究の「全ステータス+N」は実数軸だけに乗せる。
		# ％軸に乗せると1ノードで会心率とCD短縮が同時に上がる（_percent_stat_keys()）。
		var all_bonus: int = 0 if stat_key in percent_keys else boost_all
		result[stat_key] = (
			int(raw.get(stat_key, 0))
			+ int(boosts.get(stat_key, 0))
			+ all_bonus
			+ int(equip.get(stat_key, 0))
		)
	return result
```

#### 変更3：`_empty_state_template()`の`SAVE_VERSION`（197行）

```gdscript
		# ⚠ save_version の出どころは3箇所ある。上げるときは3つとも上げること。
		#   1. ここ（Balance.initial_state が無いときのフォールバック）
		#   2. save_manager.gd の CURRENT_SAVE_VERSION
		#   3. initial_state_config.tres の save_version（新規開始で実際に効くのはこれ）
		GameStateKeys.SAVE_VERSION: 2,
```

> **`SaveManager.CURRENT_SAVE_VERSION`を参照しないこと。** `GameManager`はAutoload 2番目、`SaveManager`は3番目。`_ready()`の時点でまだ初期化されていない（`AGENTS.md`「Autoloadの登録順」）。

### 5-3. `res://autoload/save_manager.gd`（2箇所）

#### 変更1：5行目

```gdscript
# 10軸化で character_growth.stats のキーが4本から10本に増えたため2へ。
# 旧バージョンは読み込まず捨てる（GAME_DESIGN.md 14章）。移行処理は書かない。
const CURRENT_SAVE_VERSION: int = 2
```

#### 変更2：55〜57行目

```gdscript
	var loaded_version: int = int(data[GameStateKeys.SAVE_VERSION])
	if loaded_version != CURRENT_SAVE_VERSION:
		# 読み込まずに false を返す。以前は warning を出して続行していたが、
		# それだと4軸のセーブが10軸のコードに流れ込み、新6軸が 0 のまま
		# 「バグなのか仕様なのか」判別できない状態になる。
		# ファイルは消さない。消すのはタイトル画面の「セーブを削除」だけ。
		push_warning("[SaveManager] load_game: version mismatch (have=%d, expected=%d) - refusing to load" % [loaded_version, CURRENT_SAVE_VERSION])
		return false
```

### 5-4. `res://scenes/guild/training_screen.gd`（111〜116行の差し替え＋ヘルパー1本）

```gdscript
	var lines: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		lines.append("%s  %s" % [
			tr("ui_training_stat_" + stat_key),
			_stat_value_text(stat_key, int(stats.get(stat_key, 0))),
		])
	stats_label.text = "\n".join(lines)
```

同ファイルの末尾に追記：

```gdscript
# ％系は "25%" と出す。実数はそのまま。
# 翻訳キーは "ui_training_stat_" + stat_key で機械的に引く（AGENTS.md 翻訳キーの運用）。
# 軸を足したら ja.csv に1行足すだけで、この画面は直さなくてよい。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
```

> **`"%d%%"`の`%%`を`%`1つにしないこと。** `%`はフォーマット指定子なので、1つだとエスケープされず出力が壊れる。

### 5-5. `res://scenes/guild/equipment_screen.gd`（3箇所）

#### 変更1：`_stat_labels()`（238〜244行）を**削除**し、`_stat_value_text()`に置き換える

```gdscript
# ％系は "25%" と出す。実数はそのまま（training_screen.gd と同じ形）。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
```

#### 変更2：`_update_header()`のステータス行（88〜97行）

```gdscript
	var lines: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var label: String = tr("ui_training_stat_" + stat_key)
		var value: int = int(stats.get(stat_key, 0))
		var added: int = int(bonus.get(stat_key, 0))
		if added > 0:
			lines.append("%s  %s  (+%s)" % [
				label, _stat_value_text(stat_key, value), _stat_value_text(stat_key, added)
			])
		else:
			lines.append("%s  %s" % [label, _stat_value_text(stat_key, value)])
	stats_label.text = "\n".join(lines)
```

#### 変更3：`_stats_text()`（218〜226行）

**0の軸を出さない挙動は変えない。** 装備一覧の1行が10軸ぶんに伸びると読めなくなる。

```gdscript
func _stats_text(stats: Variant) -> String:
	if not (stats is Dictionary):
		return ""
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int((stats as Dictionary).get(stat_key, 0))
		# 0 の軸は出さない。10軸ぶん並べると1行が読めなくなる。
		if value == 0:
			continue
		var sign_text: String = "+" if value > 0 else ""
		parts.append("%s %s%s" % [
			tr("ui_training_stat_" + stat_key), sign_text, _stat_value_text(stat_key, value)
		])
	return "  ".join(parts)
```

> 元は`"%s %+d"`で符号を付けていた。`_stat_value_text()`が`%`を足す都合で`%+d`が使えないため、符号を手で作る。

### 5-6. `res://resources/balance/master/characters.json`

**既存の4軸と`growth_per_level`は変えない。** 6軸を足すだけ。

```json
{
  "char_swordsman": {
	"name_key": "ui_battle_char_swordsman",
	"hp": 120, "atk": 18, "mag": 4, "def": 6, "mdef": 4, "spd": 60,
	"atkspd": 0, "haste": 0, "crit_rate": 5, "crit_dmg": 150,
	"attack_range": 60, "attack_interval_sec": 1.2,
	"skills": ["skill_power_slash", "skill_wide_sweep"],
	"growth_per_level": { "hp": 8, "atk": 2, "def": 1, "spd": 1 }
  },
  "char_archer": {
	"name_key": "ui_battle_char_archer",
	"hp": 80, "atk": 14, "mag": 6, "def": 3, "mdef": 3, "spd": 70,
	"atkspd": 0, "haste": 0, "crit_rate": 10, "crit_dmg": 150,
	"attack_range": 300, "attack_interval_sec": 1.5,
	"skills": ["skill_snipe", "skill_arrow_rain"],
	"growth_per_level": { "hp": 5, "atk": 2, "def": 1, "spd": 1 }
  },
  "char_priest": {
	"name_key": "ui_battle_char_priest",
	"hp": 70, "atk": 10, "mag": 16, "def": 3, "mdef": 6, "spd": 65,
	"atkspd": 0, "haste": 0, "crit_rate": 5, "crit_dmg": 150,
	"attack_range": 250, "attack_interval_sec": 1.6,
	"skills": ["skill_healing_light", "skill_holy_ray"],
	"growth_per_level": { "hp": 4, "atk": 1, "def": 1, "spd": 1 }
  }
}
```

**この数値は仮**（`GAME_DESIGN.md` 14章で未決）。**今回は式が入っていないので戦闘に一切影響しない。** 決めた根拠だけ残す：

| | 根拠 |
|---|---|
| 剣士の`mag`を4にした（0にしない） | 0にすると`mag`参照スキルが1つ付いた瞬間に破綻する（PLAN 4章）。「魔法屋ではない」は`allocatable_stats`で表現する |
| 僧侶の`mag`を16にした | 回復が`user.atk`参照のまま放置されている（§2-5）。次回`mag`へ移すときに、僧侶の回復量が跳ねないよう`atk`10に近い帯に置いた |
| `crit_dmg`を150にした | **0にしてはいけない。** 式の回で会心が「ダメージ0」になる。150＝会心で1.5倍 |
| `crit_rate`に基礎値を持たせた | 0だと会心が一生出ず、式が入っても動いているか分からない。**PLAN 4章の「％系は装備と装飾だけで動かす」は`growth_per_level`の話であって、基礎値の話ではない** |
| `atkspd` / `haste`を0にした | ここは装備と装飾だけで動かす（PLAN 4章）。基礎値を持たせる理由が無い |
| `growth_per_level`に％系を足さない | レベル100で勝手に100%に達する（PLAN 4章） |

### 5-7. `res://resources/balance/master/enemies.json`

**`mag`と`mdef`だけ足す。** ％系（`atkspd` / `haste` / `crit_*`）は敵に足さない — 敵は`get_effective_stats()`を通らずマスター直読みで、式の回に構造ごと決めるため（§11）。

```json
{
  "enemy_slime": {
	"name_key": "ui_battle_enemy_slime",
	"hp": 40, "atk": 8, "mag": 2, "def": 2, "mdef": 2, "spd": 40,
	"attack_range": 50, "attack_interval_sec": 1.5
  },
  "enemy_wolf": {
	"name_key": "ui_battle_enemy_wolf",
	"hp": 55, "atk": 12, "mag": 2, "def": 3, "mdef": 1, "spd": 80,
	"attack_range": 50, "attack_interval_sec": 1.0
  },
  "boss_slime_king": {
	"name_key": "ui_battle_enemy_slime_king",
	"hp": 300, "atk": 20, "mag": 12, "def": 8, "mdef": 6, "spd": 30,
	"attack_range": 70, "attack_interval_sec": 1.8
  }
}
```

**`mag`を全員に入れたのは、片方だけだと`mdef`が死に軸になるため**（PLAN 7章）。ボスを`mag` 12・`mdef` 6の魔法寄りにして、`mdef`が最初から機能する相手を1体だけ作った（`GAME_DESIGN.md` 8-1「敵にも`mag`を持たせ、魔法を使う敵を用意する」）。狼は`mdef` 1で魔法に弱い物理型。

### 5-8. `res://localization/ja.csv`（**2行を修正・6行を追加**）

既存4行のうち2行を直す。**`def`と`mdef`、`spd`と`atkspd`が並ぶと区別できないため。**

| キー | 現在 | 変更後 |
|---|---|---|
| `ui_training_stat_def` | 防御 | **物理防御** |
| `ui_training_stat_spd` | 速さ | **移動速度** |

追加する6行（既存4行の直後）：

```
ui_training_stat_mag,魔力
ui_training_stat_mdef,魔法防御
ui_training_stat_atkspd,攻撃速度
ui_training_stat_haste,CD短縮
ui_training_stat_crit_rate,会心率
ui_training_stat_crit_dmg,会心倍率
```

**`ui_training_stat_hp`と`ui_training_stat_atk`は変えない。** これらのキーは`equipment_screen.gd`と`training_screen.gd`の両方が使うが、`"ui_training_stat_" + stat_key`で機械的に引く形になるため、**軸を足すときは今後ここに1行足すだけで済む。**

---

## 6. 作業の順番

1. **設計役**：5-1（`state_keys.gd`）
2. **設計役**：5-2（`game_manager.gd` 3箇所）
3. **設計役**：5-3（`save_manager.gd` 2箇所）
4. **設計役**：5-4・5-5（画面2本）
5. **設計役**：5-6・5-7（JSON 2本）・5-8（`ja.csv`）
6. **人間**：4-1（`initial_state_config.tres`を2に）→ 4-2（`ja.csv`再インポート）
7. **人間**：§7〜§9で確認する
8. **人間**：4-4（ドキュメント更新）→ コミット

**1より前に4をやらない。** `GameStateKeys.STAT_MAG`が無い状態で画面が参照すると、識別子が見つからずパースエラーになる。

**6を飛ばして7に行かない。** `.tres`が1のままだと新規セーブが次回起動で弾かれ、原因が「バージョンを上げたせい」なのか「軸を足したせい」なのか切り分けられなくなる。

---

## 7. 完了条件：画面（人間が実機で確かめる）

**旧セーブがある状態から始めること。** 4-3の判断材料になる。

1. タイトルで「つづきから」を押すと**読み込み失敗のモーダルが出て、閉じると新規開始になる**（拠点画面に入り、ゴールドが初期値に戻っている）
2. ギルド → 育成 で、ステータスが**10行**並ぶ
3. その並びが`GAME_DESIGN.md` 8-1の表と同じ順（HP／攻撃／魔力／物理防御／魔法防御／攻撃速度／CD短縮／会心率／会心倍率／移動速度）
4. **`ui_training_stat_mag`のようなキー名がそのまま出ていない**（出ていたら4-2の再インポート漏れ）
5. **`%`が付くのは攻撃速度・CD短縮・会心率・会心倍率の4行だけ**
6. 装備画面のステータス表示も同じ10行になっている
7. 装備を1つ着けると、その軸だけ`(+N)`が付く（**着けていない軸に`(+0)`が出ていない**）
8. 装備一覧の1行が**長くなっていない**（0の軸は出ない）
9. **戦闘のダメージの数字が今まで通り**（式は次回なので、ここが変わっていたら間違い）
10. 研究の「全ステータス+3」を解放した状態で、**会心率とCD短縮に+3が乗っていない**（HP・攻撃・魔力・物理防御・魔法防御・移動速度にだけ乗る）

> 10は研究ノードを解放していないと確認できない。**解放済みでなければ§10（人間は確認しない）に落として構わない。**

---

## 8. 完了条件：ログ（Godotの出力パネル）

1. 旧セーブで「つづきから」を押すと`[SaveManager] load_game: version mismatch (have=1, expected=2) - refusing to load`が出る
2. **その後に`[GameManager] load_state success`が出ていない**（弾いた後に読み込みが走っていない）
3. `[GameManager] init complete.`が出て、拠点まで進む
4. 育成画面でレベルアップすると`[GameManager] level_up_character('char_swordsman') -> true (level=2 stats={...})`が出て、**`stats`のキーが10個**ある
5. **その`stats`に`.0`が付いた数値が1つも無い**

---

## 9. 完了条件：セーブファイル（`user://saves/save_slot_0.json`をテキストエディタで開く）

Windowsのパス：`%APPDATA%\Godot\app_userdata\<プロジェクト名>\saves\save_slot_0.json`

1. `"save_version": 2`
2. 育成したキャラの`character_growth.<id>.stats`に**キーが10個**ある
3. **`stats`の中に`.0`が付いた数値が1つも無い**（`"crit_dmg": 150`であって`150.0`ではない）
4. `"mag"` `"mdef"` `"atkspd"` `"haste"` `"crit_rate"` `"crit_dmg"`が揃っている

> **レベル1のキャラはセーブに現れない**（`get_character_growth()`が既定値を`_state`に書き込まない設計）。**2を確認するには、どれか1人をレベルアップさせてから保存すること。**

---

## 10. UIから到達できない項目（人間は確認しない）

**将来コードを変えたときに見る項目。** 画面から実行できないので完了条件にしない。

- `characters.json`に無い軸を`_default_growth_for()`が0で埋める（`push_error`にならない）
- `items.json`の`equip_stats`に無い軸を`get_instance_stats()`が0で返す
- `enemies.json`に`atkspd`等が無くても戦闘が動く（戦闘が読んでいないため）
- `target_stat`に`crit_rate`を指定した研究ノードは％軸にも加算される（そのようなノードはまだ`research.json`に無い）

---

## 11. 併せて直さないもの

### `stat_growth_formula`を`"base"`にしない（**`NEXT_STEPS.md`から意図的に落とした**）

`GAME_DESIGN.md` 15章は`"base + growth * (level - 1)"` → `"base"`に変えると書いている。**今回はやらない。**

理由：**割り振りポイント（`PLAN_IMPLEMENTATION.md` 3章の3番）が入るまでレベルアップが完全に無意味になる。** 素材を消費して何も起きない画面になり、`CONCEPT.md`の「やって後悔したと思わせない」に正面から反する。**この変更はレベルの役割転換と同じ回に入れるべきもので、10軸には要らない**（新6軸は`growth_per_level`を持たないため、式が線形のままでも基礎値から動かない）。

**ただし調査結果は残す：** `stat_growth_formula`は`character_config.tres`に**書き出されていない**。効いているのは`character_config.gd` 31行の`@export`初期値で、**Inspectorには項目が存在しないので人間が開いても直せない。** 変えるときは`.gd`側を直す。（`PLAN_STATS_AND_FORMULAS.md` 2章が警告している罠に、この項目が既に当たっている）

### そのほか

- **戦闘の式**（`def`/`mdef`の除算、クリティカル、`atkspd`、`haste`、物理／魔法）— 次回
- **`BattleUnit`の拡張** — 次回。**現在10個の位置引数。6本足すと16個になるので構造ごと見直す**
- **`skill_resolver.gd`の回復が`atk`参照** — 次回（`mag`へ移すか判断する）
- **`attack_interval_sec` / `cooldown_sec`の直読み** — 次回
- **`StatConfig.tres`（上限値）** — 使う側が無いうちは作らない
- **`items.json`の`equip_stats`に新軸** — 装飾（6番）と等級10（4番）の回
- **敵の％系軸と物理／魔法の種別** — 式の回に`enemies.json`の構造ごと決める（`GAME_DESIGN.md` 14章で未決）
- **旧セーブの自動削除** — 入れない。取り返しがつかない操作をタイトル起動時に走らせない（タイトルの「セーブを削除」は`Modal.confirm()`を挟んでいる）

---

## 12. このタスクで残す宿題

- `save_version`の出どころが3箇所に散っている（今回は3つ揃えるだけ。1本化は別タスク）
- `_percent_stat_keys()`は毎回`Array`を作って`in`で線形探索する。10軸・4本なら問題ないが、毎フレーム呼ぶ場所からは呼ばないこと
- `PLAN_STATS_AND_FORMULAS.md`の1章・5章・`boost_all`の記述が実コードとズレている（§2-1・2-2・2-4）。**直していない**
