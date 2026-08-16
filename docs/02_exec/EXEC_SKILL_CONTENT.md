# EXEC_SKILL_CONTENT.md — スキルの中身12個（3人 × 残り4個）

**第3層。決定台帳は `docs/01_plan/PLAN_SKILL_CONTENT.md`。器の正は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`。**

**このタスクは `.gd` を1行も触らない。** マスターデータ（JSON）と `ja.csv` だけ。

**完了条件は「挙動が増えるが、既存6件の数字は1つも変わらない」。**

---

## 1. 人間による決定事項（2026-08-16・**本文と矛盾する場合こちらが優先**）

### 1-1.【体制】設計役が全部書く。MiniMax（実装役）は使わない

**直近5タスク（育成・研究・ショップ・スキルの器・これ）と同じ。PRE_PLAN も IMPL_LOG も作らない。**

⚠ **ただしこのタスクは実装役の適性が高い**（`.gd` 変更ゼロ／JSONの追記が本体／`ja.csv` は末尾寄りへの挿入）。**渡す判断に切り替える場合は §11 の A章だけを渡し、B章は「転記だけして検証しない」と明示すること。**

### 1-2.【決定】段階2（実行中のスキル層と `trigger`）より**先**にこのタスクをやる

**理由は `PLAN_SKILL_CONTENT.md` 1章。** 段階1で足した受け口が**実機で1度も通っていない**まま段を積まないため。

⚠ **段階2・段階3が入ったら、この12個は書き直してよい。** セーブはスキルIDしか持たないので壊れない。**IDだけは改名しない**（`CLAUDE.md` 4番）。

### 1-3.【決定】`target.range` は12件とも書かない

座標定数が未決のため（`PLAN_SKILL_CONTENT.md` 5-1）。**18件まとめて入れるのは座標定数を決める回。**

### 1-4.【決定】`skill_reckless_strike` の自死は止めない

**残HPが最大HPの12%未満で撃つと使用者が死ぬ。仕様。** `SkillActivation` に条件を足さない。

### 1-5.【決定】倍率と `weight` は仮

**バランス調整は別枠。** このタスクが保証するのは「桁が壊れていない」だけ。

---

## 2. 触るファイルと担当

| ファイル | 何をする | 誰が |
|---|---|---|
| `resources/balance/master/skills.json` | **全文差し替え**（6件 → 18件） | AI |
| `resources/balance/master/characters.json` | **3行だけ差し替え**（`"skills": [...]`） | AI |
| `localization/ja.csv` | **12行を100行目の直後に挿入** | AI |
| `ja.csv` の**再インポート** | Godot で行う | ⚠ **人間** |
| 実機確認（§11-B） | | ⚠ **人間** |

**`.gd` は1つも触らない。`.tscn` も `.tres` も触らない。**

---

## 3. 着手前に確認した実コード（2026-08-16・`grep` 済み）

| | 事実 |
|---|---|
| ロード時検証 | `MasterDataLoader._validate_all_skills()`（391行）。**育成画面か戦闘画面に入って初めて走る** |
| そのログ | `[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings`（422行）。⚠ **これが唯一の `print`** |
| 射程のクロス検証 | 409〜419行。⚠ **`target.range` を書いたときだけ走る。** 書かなければ通る |
| `team: self` の制約 | `skill_schema.gd` 227〜230行（E10）。⚠ **`mode` / `sort` / `count` を書くと赤** |
| `effects[].target` の制約 | 同 322〜327行。⚠ **`range` を書くと赤**（E16） |
| `heal` の制約 | 同 285〜287行。⚠ **`attack_type` を書くと赤**（E21） |
| `scale_from` は必須 | 同 290〜291行（E27）。`damage` / `heal` に無いと赤 |
| `mode` は必須 | 同 233〜235行（E11）。⚠ **`team: self` 以外は省略できない** |
| 知らない欄 | 同 203〜205行（E26）。**typo は赤で落ちる** |
| ダメージ式 | `BattleFormula.damage()`：`floor(power × multiplier × 100 / (100 + defense))`。**最低1** |
| `attack_type: "true"` | `skill_resolver.gd` 247〜249行。**防御を 0 として扱う** |
| 回復 | 同 305〜319行。⚠ **全対象に同じ数値**／⚠ **`of: "target"` は必ず 0.0**（`target` を渡していない） |
| `distance` | 同 372〜375行。⚠ **`of` を読まない**。`user` と対象の距離 |
| `hp` という変数 | `unit.gd` 101行で `max_hp = get_stat("hp")`。⚠ **`scale_from` の `"hp"` は最大HP。現在HPは `hp_current`** |
| 候補一覧 | `characters.json` の `skills[]`。⚠ **配列の順序が画面の並び順**（`game_manager.gd` 68行） |
| 解放判定 | `game_manager.gd` 1931〜1934行。`unlock_level > level` なら弾く |
| グレー表示 | `skill_select_screen.gd` 150〜153行 → `tr("ui_skill_select_locked") % 解放レベル`。✅ **キーは既にある** |
| レベル上限 | `base_level_cap` **10** ＋ `research.json` の `level_cap_unlock` **5 × 4** ＝ **最大30** |

---

## 4. `resources/balance/master/skills.json`（**全文差し替え**）

⚠ **インデントはタブ。** 既存ファイルがタブなので合わせる（`CLAUDE.md` 7番）。

```json
{
	"skill_power_slash": {
		"name_key": "ui_battle_skill_power_slash",
		"user_character_id": "char_swordsman",
		"unlock_level": 1,
		"cooldown_sec": 6.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 2.0, "attack_type": "physical", "scale_from": "atk" }
		]
	},
	"skill_wide_sweep": {
		"name_key": "ui_battle_skill_wide_sweep",
		"user_character_id": "char_swordsman",
		"unlock_level": 1,
		"cooldown_sec": 8.0,
		"activation": "charge",
		"charge": {
			"just_sec": 1.0,
			"just_window_sec": 0.15,
			"min_ratio": 0.5,
			"just_bonus": 1.3
		},
		"target": { "team": "enemy", "mode": "select", "sort": "all" },
		"effects": [
			{ "type": "damage", "multiplier": 0.9, "attack_type": "physical", "scale_from": "atk" }
		]
	},
	"skill_reckless_strike": {
		"name_key": "ui_battle_skill_reckless_strike",
		"user_character_id": "char_swordsman",
		"unlock_level": 5,
		"cooldown_sec": 10.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 3.4, "attack_type": "physical", "scale_from": "atk" },
			{
				"type": "damage",
				"target": { "team": "self" },
				"attack_type": "true",
				"multiplier": 0.12,
				"scale_from": [ { "source": "hp", "of": "user", "weight": 1.0 } ]
			}
		]
	},
	"skill_last_stand": {
		"name_key": "ui_battle_skill_last_stand",
		"user_character_id": "char_swordsman",
		"unlock_level": 10,
		"cooldown_sec": 9.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{
				"type": "damage",
				"attack_type": "physical",
				"multiplier": 1.6,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 1.2 },
					{ "source": "hp_lost", "of": "user", "weight": 0.15 }
				]
			}
		]
	},
	"skill_shield_bash": {
		"name_key": "ui_battle_skill_shield_bash",
		"user_character_id": "char_swordsman",
		"unlock_level": 15,
		"cooldown_sec": 7.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{
				"type": "damage",
				"attack_type": "physical",
				"multiplier": 1.5,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 0.8 },
					{ "source": "def", "of": "user", "weight": 2.0 }
				]
			}
		]
	},
	"skill_helm_splitter": {
		"name_key": "ui_battle_skill_helm_splitter",
		"user_character_id": "char_swordsman",
		"unlock_level": 20,
		"cooldown_sec": 14.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "highest_hp", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 2.2, "attack_type": "true", "scale_from": "atk" }
		]
	},
	"skill_snipe": {
		"name_key": "ui_battle_skill_snipe",
		"user_character_id": "char_archer",
		"unlock_level": 1,
		"cooldown_sec": 11.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 2.6, "attack_type": "physical", "scale_from": "atk" }
		]
	},
	"skill_arrow_rain": {
		"name_key": "ui_battle_skill_arrow_rain",
		"user_character_id": "char_archer",
		"unlock_level": 1,
		"cooldown_sec": 9.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "all" },
		"effects": [
			{ "type": "damage", "multiplier": 1.2, "attack_type": "physical", "scale_from": "atk" }
		]
	},
	"skill_finisher": {
		"name_key": "ui_battle_skill_finisher",
		"user_character_id": "char_archer",
		"unlock_level": 5,
		"cooldown_sec": 7.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "lowest_hp", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 3.0, "attack_type": "physical", "scale_from": "atk" }
		]
	},
	"skill_long_shot": {
		"name_key": "ui_battle_skill_long_shot",
		"user_character_id": "char_archer",
		"unlock_level": 10,
		"cooldown_sec": 10.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{
				"type": "damage",
				"attack_type": "physical",
				"multiplier": 2.0,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 1.0 },
					{ "source": "distance", "weight": 0.08 }
				]
			}
		]
	},
	"skill_rapid_volley": {
		"name_key": "ui_battle_skill_rapid_volley",
		"user_character_id": "char_archer",
		"unlock_level": 15,
		"cooldown_sec": 8.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 2 },
		"effects": [
			{
				"type": "damage",
				"attack_type": "physical",
				"multiplier": 1.3,
				"scale_from": [
					{ "source": "atk", "of": "user", "weight": 1.0 },
					{ "source": "atkspd", "of": "user", "weight": 1.5 }
				]
			}
		]
	},
	"skill_piercing_arrow": {
		"name_key": "ui_battle_skill_piercing_arrow",
		"user_character_id": "char_archer",
		"unlock_level": 20,
		"cooldown_sec": 13.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "farthest", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 2.4, "attack_type": "true", "scale_from": "atk" }
		]
	},
	"skill_healing_light": {
		"name_key": "ui_battle_skill_healing_light",
		"user_character_id": "char_priest",
		"unlock_level": 1,
		"cooldown_sec": 8.0,
		"activation": "instant",
		"target": { "team": "ally", "mode": "select", "sort": "all" },
		"effects": [
			{ "type": "heal", "multiplier": 1.0, "scale_from": "mag" }
		]
	},
	"skill_holy_ray": {
		"name_key": "ui_battle_skill_holy_ray",
		"user_character_id": "char_priest",
		"unlock_level": 1,
		"cooldown_sec": 12.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "all" },
		"effects": [
			{ "type": "damage", "multiplier": 1.0, "attack_type": "magic", "scale_from": "mag" }
		]
	},
	"skill_mend": {
		"name_key": "ui_battle_skill_mend",
		"user_character_id": "char_priest",
		"unlock_level": 5,
		"cooldown_sec": 6.0,
		"activation": "instant",
		"target": { "team": "ally", "mode": "select", "sort": "lowest_hp", "count": 1 },
		"effects": [
			{ "type": "heal", "multiplier": 2.2, "scale_from": "mag" }
		]
	},
	"skill_drain_life": {
		"name_key": "ui_battle_skill_drain_life",
		"user_character_id": "char_priest",
		"unlock_level": 10,
		"cooldown_sec": 9.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{ "type": "damage", "multiplier": 1.6, "attack_type": "magic", "scale_from": "mag" },
			{
				"type": "heal",
				"target": { "team": "self" },
				"multiplier": 0.8,
				"scale_from": "mag"
			}
		]
	},
	"skill_purge_wave": {
		"name_key": "ui_battle_skill_purge_wave",
		"user_character_id": "char_priest",
		"unlock_level": 15,
		"cooldown_sec": 12.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "all" },
		"effects": [
			{
				"type": "damage",
				"attack_type": "magic",
				"multiplier": 1.0,
				"scale_from": [
					{ "source": "mag", "of": "user", "weight": 0.7 },
					{ "source": "mdef", "of": "user", "weight": 1.5 }
				]
			}
		]
	},
	"skill_judgement": {
		"name_key": "ui_battle_skill_judgement",
		"user_character_id": "char_priest",
		"unlock_level": 20,
		"cooldown_sec": 14.0,
		"activation": "instant",
		"target": { "team": "enemy", "mode": "select", "sort": "nearest", "count": 1 },
		"effects": [
			{
				"type": "damage",
				"attack_type": "magic",
				"multiplier": 1.4,
				"scale_from": [
					{ "source": "mag", "of": "user", "weight": 1.2 },
					{ "source": "hp_ratio", "of": "target", "weight": 40.0 }
				]
			}
		]
	}
}
```

### 4-1. ⚠ 書き間違えると**赤で落ちる**もの（ロード時検証が捕まえる）

| やってはいけないこと | 出る検証 |
|---|---|
| `{ "team": "self" }` に `mode` / `sort` / `count` を書く | E10 |
| `effects[].target` に `range` を書く | E16 |
| `heal` に `attack_type` を書く | E21 |
| `scale_from` を書き忘れる | E27 |
| `team: self` 以外で `mode` を省く | E11 |
| 欄名の typo | E26 |

### 4-2. ⚠ 書き間違えても**黙って動く**もの（検証が捕まえない）

| やってはいけないこと | 何が起きるか |
|---|---|
| `heal` の `scale_from` に `of: "target"` | **必ず 0.0**。回復量が `multiplier × 0` になる。⚠ **赤も黄も出ない** |
| `distance` に `of` を書く | **無視される**（`skill_resolver.gd` 372行が `of` を読む前に返す） |
| `scale_from` の `"hp"` を「現在HP」のつもりで書く | **最大HP**が入る。現在HPは `hp_current` |
| `sort: "all"` に `count` を書く | **無視される** |

---

## 5. `resources/balance/master/characters.json`（**3行だけ差し替え**）

⚠ **`"skills"` の行だけを差し替える。他の行に触らない。**
⚠ **このファイルはインデントが行によって違う**（`"char_swordsman"` の行だけ半角スペース2、中身はタブ）。**`"skills"` の行の頭のタブを保つこと。**

⚠ **配列の順序が画面の並び順**（`game_manager.gd` 68行）。**`unlock_level` の昇順に並べる。**

```
	"skills": ["skill_power_slash", "skill_wide_sweep", "skill_reckless_strike", "skill_last_stand", "skill_shield_bash", "skill_helm_splitter"],
```

```
	"skills": ["skill_snipe", "skill_arrow_rain", "skill_finisher", "skill_long_shot", "skill_rapid_volley", "skill_piercing_arrow"],
```

```
	"skills": ["skill_healing_light", "skill_holy_ray", "skill_mend", "skill_drain_life", "skill_purge_wave", "skill_judgement"],
```

**上から順に `char_swordsman`（8行目）／`char_archer`（18行目）／`char_priest`（28行目）。**

---

## 6. `localization/ja.csv`（**12行を挿入**）

⚠ **UTF-8（BOMなし）。** BOMが付くと1行目が `﻿keys` になり全滅する（`CLAUDE.md`）。

**`ui_battle_skill_holy_ray,聖光`（100行目）の直後**に挿入する。既存のスキル名6行と並べるため。

```
ui_battle_skill_reckless_strike,捨て身の一撃
ui_battle_skill_last_stand,背水の刃
ui_battle_skill_shield_bash,盾撃
ui_battle_skill_helm_splitter,兜割り
ui_battle_skill_finisher,追い討ち
ui_battle_skill_long_shot,遠矢
ui_battle_skill_rapid_volley,速射
ui_battle_skill_piercing_arrow,貫きの矢
ui_battle_skill_mend,集中治療
ui_battle_skill_drain_life,吸命
ui_battle_skill_purge_wave,浄化の波動
ui_battle_skill_judgement,裁きの雷
```

⚠ **編集後、Godot での再インポートが要る（人間の作業）。** 再インポート前は**スキル名がキー文字列のまま表示される**（これは異常ではない）。

---

## 7. 期待される数値（**実機で突き合わせる用**）

**素の能力値（Lv1・研究も装備も無し）での目安。** ⚠ **育成が乗ると変わる。「だいたいこの桁」を見るためのもの。**

`ダメージ = floor( Σ(weight × 変数) × multiplier × 100 / (100 + 防御) )`

| スキル | 素の power | 防御を 0 とした素の値 |
|---|---|---|
| `skill_reckless_strike` ①（剣士 `atk18`） | 18 | `18 × 3.4` ＝ **61** |
| `skill_reckless_strike` ②（自傷・`hp120`） | 120 | `120 × 0.12` ＝ **14**（⚠ **確定ダメージなので防御を無視**） |
| `skill_last_stand`（無傷のとき `hp_lost` は 0） | 21.6 | `21.6 × 1.6` ＝ **34**。⚠ **HPが減るほど伸びる** |
| `skill_shield_bash`（`atk18 def6`） | 26.4 | `26.4 × 1.5` ＝ **39** |
| `skill_helm_splitter`（確定） | 18 | `18 × 2.2` ＝ **39** |
| `skill_finisher`（弓兵 `atk14`） | 14 | `14 × 3.0` ＝ **42** |
| `skill_long_shot`（距離 700 のとき） | 70 | `70 × 2.0` ＝ **140**。⚠ **距離 0 なら 28** |
| `skill_rapid_volley`（`atkspd 0`） | 14 | `14 × 1.3` ＝ **18**（×2体）。⚠ **`atkspd` に振ると伸びる** |
| `skill_piercing_arrow`（確定） | 14 | `14 × 2.4` ＝ **33** |
| `skill_mend`（僧侶 `mag16`） | 16 | 回復 `16 × 2.2` ＝ **35** |
| `skill_drain_life` ①／② | 16 | ダメージ `16 × 1.6` ＝ **25** ／ 自己回復 **12** |
| `skill_purge_wave`（`mag16 mdef6`） | 20.2 | `20.2 × 1.0` ＝ **20** |
| `skill_judgement`（対象が満タン） | 59.2 | `59.2 × 1.4` ＝ **82**。⚠ **対象が瀕死なら 26 まで落ちる** |

⚠ **会心が出ると `crit_dmg`（150）が乗って1.5倍になる。** 数字が合わないときは、まず会心を疑う（`unit_view.gd` が会心だけ色とフォントを変えている）。

---

## 8. このタスクでやらないこと

- **`.gd` の変更**（1行も）
- **`target.range`**（決定1-3）
- **段階2**（実行中のスキル層・`trigger` の `delay` / `event` / `charge_start`）
- **段階3**（`buff` / `dot` / 購読 / 条件 / パッシブ）
- **バランス調整**（決定1-5）
- **敵にスキルを持たせること**
- **ルーン・演出・アニメーション**
- **`DATA_SCHEMA.md` の更新**（4-3 の `stats` が4軸のままなのは既存の宿題）

---

## 9. 宿題に送るもの（`PROJECT_STATUS.md` に足す）

1. ⚠ **`scale_from` が「和」しか書けない**（`PLAN_SKILL_CONTENT.md` 5-3）。`atk × (1 + hp_lost_ratio)` が書けず、割合変数は**レベルで伸びない定数項**にしかならない。**器の話なので `PLAN_SKILL_TEMPLATE.md` 側の判断**
2. **`target.range` が18件とも未設定**（座標定数を決める回にまとめて入れる）
3. **倍率と `weight` は仮**。特に `skill_judgement` の `hp_ratio × 40.0`・`skill_long_shot` の `distance × 0.08`・`skill_shield_bash` の `def × 2.0`
4. **`skill_reckless_strike` で自死できる**（決定1-4。止めるなら `SkillActivation` に1行）
5. **段階2・段階3が入ったら12個を見直す**（多段・DoT・バフに書き換える候補）
6. **Lv15 / Lv20 のスキルは、研究でレベル上限を上げないと到達できない**（`base_level_cap` 10）

---

## 10. 事故りやすい箇所（**名指し**）

### 10-1. ⚠ `ja.csv` の BOM

**BOMが付くと1行目が `﻿keys` になって全滅する。** 12行の挿入でエンコーディングを変えないこと。

### 10-2. ⚠ JSON のインデントはタブ

`skills.json` も `characters.json` も既存はタブ。**スペースを混ぜない。**

### 10-3. ⚠ スキルIDを改名しない

**`CLAUDE.md` 4番。** セーブが持つのはスキルIDだけなので、**改名すると選択済みのスキルが黙って外れる。** 12個のIDは今この場で確定させる。

### 10-4. ⚠ `characters.json` の `skills[]` の順序

**配列の順序＝画面の並び順。** `unlock_level` の昇順に並べないと、グレーの行が間に挟まる。

### 10-5. ⚠ 編集したら `grep` で当たったことを確認する

```
grep -c "skill_" resources/balance/master/skills.json        （18件ぶんのIDが居ること）
grep -n "skill_helm_splitter" resources/balance/master/characters.json   （0件でないこと）
grep -n "ui_battle_skill_judgement" localization/ja.csv                  （0件でないこと）
```

**「差し替えたつもりで当たっていない」で1タスク溶かした事故がある**（`CLAUDE.md` 2番）。

### 10-6. ⚠ 「回復が 0 になる」は無音

`heal` の `scale_from` に `of: "target"` を書くと**必ず 0.0** になる。**赤も黄も出ない。** §4-2 の表を必ず見ること。

---

## 11. 完了条件

### 11-A. ログとファイル（**画面を見ないで確かめられる**）

| # | 見るもの | 期待 |
|---|---|---|
| A-1 | タイトル →「つづきから」→ 育成画面か戦闘画面に入ったときの出力パネル | `[MasterDataLoader] skills validated: 18 entries, 0 errors, 0 warnings` |
| A-2 | `resources/balance/master/skills.json` | **18件**。全件に `activation` / `target` / `effects` があり、`type` 欄が1件も無い |
| A-3 | `resources/balance/master/characters.json` | 3キャラとも `skills[]` が**6件**。順序が `unlock_level` 昇順 |
| A-4 | `localization/ja.csv` | `ui_battle_skill_` で始まる行が**18行**。UTF-8（BOMなし） |

⚠ **A-1 が唯一の `print`。** 他のログを完了条件に書かない。
⚠ **ロード時のログはタイトルの「つづきから」でしか出ない**（`NEXT_STEPS.md` 6章）。

### 11-B. 画面（⚠ **人間が実機で操作する**）

**`ja.csv` の再インポートを先に済ませること。** していないとスキル名がキー文字列のまま出る。

| # | どこで | 何を見るか |
|---|---|---|
| B-1 | ギルド → スキル選択画面 | 各キャラの候補が**6行**並ぶ。並び順が §5 のとおり |
| B-2 | 同上（Lv1のキャラ） | 4行目〜6行目が**「Lv5 で解放」「Lv10 で解放」…」でグレー**。⚠ **この表示は今まで一度も出たことがない** |
| B-3 | 同上 | グレーの行は**選べない**（装備できない） |
| B-4 | 育成でレベルを上げたあと | Lv5・Lv10 に達すると該当行が**選べるようになる**。⚠ **Lv15 / Lv20 は研究でレベル上限を上げないと届かない** |
| B-5 | 戦闘（`F3` → `S` でCDリセット） | **既存6件の数字が今までと変わらない** |
| B-6 | 戦闘・`skill_reckless_strike` | 敵に大きい数字、**同時に自分の頭上にも数字が出る**（自傷）。⚠ **HPが1割ちょっとで撃つと自分が死ぬ**（仕様） |
| B-7 | 戦闘・`skill_drain_life` | 敵に数字、**自分のHPバーが増える** |
| B-8 | 戦闘・`skill_mend` | **一番HPの減っている味方**に回復の数字が出る（全員ではない） |
| B-9 | 戦闘・`skill_finisher` | **一番HPの低い敵**に飛ぶ |
| B-10 | 戦闘・`skill_helm_splitter` | **一番HPの高い敵**に飛ぶ |
| B-11 | 戦闘・`skill_piercing_arrow` | **一番遠い敵**に飛ぶ（`J`/`K` で敵のHPを崩してから見ると分かりやすい） |
| B-12 | 戦闘・`skill_rapid_volley` | **2体**に数字が出る |
| B-13 | 戦闘・`skill_long_shot` | **近づく前に撃つと大きく、密着して撃つと小さい** |
| B-14 | 戦闘・`skill_last_stand` | **HPが減っているほど数字が大きい**（`J` で味方を削ってから撃つ） |
| B-15 | 戦闘・`skill_judgement` | **満タンの敵に大きく、瀕死の敵に小さい** |
| B-16 | 出力パネル | 上のどれを撃っても**赤も黄も出ない** |

⚠ **B-6 の自傷と B-16 は両立する。** 自傷は正常系なので警告は出ない。

### 11-C. 将来コードを変えたときに見る項目（⚠ **人間の確認項目ではない**）

- `skill_shield_bash` は剣士の `def` に振らないと弱い。**割り振り画面から `def` に振れることが前提**
- `skill_rapid_volley` は `atkspd` が 0 のあいだ `atk × 1.3` の2体攻撃にすぎない
- `attack_type: "true"` の3件は、**貫通%を足したときに no-op になるのが正しい**（`PLAN_SKILL_TEMPLATE.md` 11-2）

---

## 12. ⚠ PLAN とのズレ（**勝手に直していない。人間が判断すること**）

### 12-1. `scale_from` は積を書けない（`PLAN_SKILL_TEMPLATE.md` 5-5-1）

**器の穴。** 詳細は `PLAN_SKILL_CONTENT.md` 5-3。**このEXECでは回避策（生値の `hp_lost` を使う）だけを採り、器は直していない。**

### 12-2. `PLAN_SKILL_TEMPLATE.md` 5-5-2 の「想定レンジ 50〜500」が実データと合わない

**10軸の想定レンジは 50〜500 と書いてあるが、Lv1 の実データは `atk 14〜18` / `mag 16` / `def 3〜6`。** よって「`hp_ratio` の `weight` は数百」という指針をそのまま使うと**割合の項が式を支配する。**

**このEXECは実データに合わせて `weight` を下げている**（`hp_ratio × 40.0`）。**PLAN 側の想定レンジは直していない。**

### 12-3. `PLAN_SKILL_TEMPLATE.md` 21章の未確定4件

**`NEXT_STEPS.md` 8章のとおり、段階1のEXECで既に決着している**（`sort` 5値を全部実装／リソースは作らない／遮蔽は入れない／`count` の上限は設けない）。**PLAN 側は未確定のまま残っている。**

---

## 13. コミットメッセージ

```
feat(skill): 3人ぶんの残り12スキルを追加（Lv5/10/15/20 解放）
```
