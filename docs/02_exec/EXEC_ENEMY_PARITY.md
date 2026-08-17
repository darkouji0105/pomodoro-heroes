# EXEC — **敵の管理を味方と同じにする**（敵がスキルを持ち、自分で撃つ）

⚠ **これはスキルのPLANの軸ではない。** 段階3の後半②（＝条件）の**前**に入れる回。
**目的は「敵にも同じ仕組みが載ること」の確認。** バランス調整はしない。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-17）

| 決めたこと | 内容 |
|---|---|
| **敵スキルの置き場所** | `resources/balance/master/**enemies/**<enemy_id>/skills.json`。`characters/` と同じ階層・同じ形。⚠ **フォルダ新設は人間が承認済み**。綴りは**複数形 `enemies/`**（`characters/` と `enemies.json` に揃える） |
| **撃つ条件** | **クールダウンが空いたら撃つ、だけ。** 射程内に相手が居ることは既存の判定を使い回す。⚠ HP依存・オーラは②＝条件の担当。**前借りしない** |
| **どの敵に持たせるか** | **検証用の敵をたくさん作り、1体につきスキル1つ。** 本編の3体（`enemy_slime` / `enemy_wolf` / `boss_slime_king`）は**素のまま**（仕組みは効くが、載せるのは検証用だけ） |

### 0-1. 設計役が置いた前提（**違ったら言ってください**）

- **検証用の敵は6体**（§2 の表）。「1体1スキル」を守り、**6体で購読・状態・DoT・回復・投射物・敵視点の `team` を全部踏む**構成にした
- **出し方は `stage_order.json` の1行差し替え。** `"stage_1"` を `"stage_dbg"` に替えて再起動すると、検証用ステージが一覧の先頭（常に解放）に出る。戻すときは1行戻すだけ。⚠ **`parties.json` の `members` 差し替えと同じ「戻し忘れ注意」の運用**
- **本編の `stage_1` 〜 `stage_3` は1文字も触らない**

---

## 1. いま何が足りないか（**実コードで確認済み**）

| | 味方 | 敵 |
|---|---|---|
| 通常攻撃 | `characters.json` の `basic_attack` にインライン | `enemies.json` の `basic_attack` にインライン。**⚠ 既に同じ形** |
| スキルの定義 | `characters/<id>/skills.json` | **無い** |
| 戦闘で持つスキル | `GameManager.get_battle_skills()`（プレイヤーが選んだ2枠） | **無い**（`unit.skill_ids` が空） |
| 撃つきっかけ | プレイヤーのボタン | **無い** |
| クールダウン | `_process()` が `party_units` だけ回す（`battle_controller.gd:365`） | **進まない** |

⚠ **足りないのは「置き場所」「割り当て」「撃つ主体」「CDを回すこと」の4つ。** 通常攻撃の書き方は既に揃っている。

---

## 2. 検証用の敵6体（**1体につきスキル1つ**）

| 敵ID | スキル | 何が検証できるか |
|---|---|---|
| `enemy_dbg_react` | 反射（`react` / `took_damage` → `damage`） | **敵でも購読が動くか。** `target.team: "source"` が敵視点で味方を指すか |
| `enemy_dbg_followup` | 追撃（`react` / `dealt_damage` → `damage`） | **10-2 の印が敵側でも効くか**（反応から生まれた行動が反応を呼ばない＝無限ループしない） |
| `enemy_dbg_buff` | 自己バフ（`buff` / `host: unit` / `atk`） | 敵の `status_add` と補正の組み直し（`_rebuild_unit_mods`） |
| `enemy_dbg_dot` | 毒（`dot` を味方に付ける） | 敵起点の DoT。⚠ **宿題17（DoT で購読が発火しない）が敵でも同じか** |
| `enemy_dbg_heal` | 仲間を回復（`heal` / `target.team: "ally"`） | ⚠ **敵視点の `team` 解決。`ally` が「敵の仲間」を指すか。今まで一度も通っていない経路**（味方しかスキルを撃たなかったため） |
| `enemy_dbg_ranged` | 投射物（`delivery` ＋ `trigger: "event:hit"`） | **敵からの投射物が飛ぶか**（今まで敵は `melee` だけ） |

⚠ **`enemy_dbg_heal` が一番の当たり所。** ここが壊れていると、敵の回復が味方を回復する（またはその逆）。**ログの `heal` 行の `dst` を見れば一発で分かる。**

---

## 3. 実装（ファイル別）

### 3-1. `scripts/systems/master_data_loader.gd`（556行）— **設計役**

`characters/` と同じ形で `enemies/` を読む。

- `DIR_ENEMIES: String = DIR_PATH + "enemies/"` を足す
- `ENEMY_DIRS_REQUIRED: Array[String] = []`（**今は空**。本編の敵にスキルを載せたらここに1行足す。⚠ 宿題13と同じ罠）
- `ENEMY_DIRS_OPTIONAL` に検証用6体のフォルダ。⚠ **「無いのが正常」**（リリース前にフォルダごと消す）
- `_load_character_files()` は**名前を変えず**、敵のフォルダも回すようにする（マージの本体 `_merge_id_map()` は既に汎用）。⚠ **同じ形のマージを2本書かないこと**（関数の ⚠ コメントがそう言っている）
- スキルIDは**味方と同じ1つの辞書**に入る。⚠ **IDが重複したら赤で弾かれる**（既存の挙動）。`skill_edbg_` を接頭辞にして衝突を避ける

⚠ `_validate_all_skills()` は `_cache_characters` を見て射程を突き合わせている。**敵のスキルは `_cache_enemies` の `attack_range` と突き合わせる必要がある**が、⚠ **宿題11（`target.range` が39件とも未設定）でこのクロス検証は今どこにも効いていない。** この回では**触らない**（黄が増えないことだけ確認する）。

### 3-2. `scenes/adventure/battle_controller.gd`（1157行）— **設計役**

| 場所 | やること |
|---|---|
| `_spawn_current_wave_enemies()` の `BattleUnit.create()` の直後 | **スキルの割り当て。** `enemies.json` の `"skills"` 配列を読んで `unit.skill_ids` と `unit.skill_cooldowns` を埋める。⚠ **味方の `get_battle_skills()` を通さない**（プレイヤーが選ぶ2枠は敵に無い・§4-3） |
| `battle_controller.gd:206` のコメント | 「敵には設定しない」を**実態に合わせて書き換える** |
| `_process()` の `tick_cooldowns`（365行） | **`enemy_units` も回す。** ⚠ これが無いと敵は最初の1回しか撃てない |
| `_step_unit()` | **スキルを撃つ受け口を1本足す。** 通常攻撃より**先**に見る（下記） |

**撃ち方（`_step_unit()` の中・敵だけ）**：

```
1. 撃てるスキルを探す … SkillActivation.blocked_reason() が REASON_OK のものだけ
2. 見つかったら cast() して、そのフレームは通常攻撃をしない
3. 無ければ今まで通り通常攻撃
```

⚠ **判定を自分で書かない。`SkillActivation.blocked_reason()` を呼ぶ**（PLAN 12章。「今撃てるか」に答える場所は1つ）。
⚠ **`cast_enemy()` を作らない**（PLAN 6-5）。味方と同じ `SkillRuntime.cast()` から入る。
⚠ **クールダウンを回すのは呼び出し側**（`blocked_reason()` は状態を変えない）。撃ったら `unit.skill_cooldowns[id]` を設定する。**味方が同じことをしている箇所と同じ書き方にすること。**
⚠ **候補が複数あるとき何を選ぶか**：**`skill_ids` の先頭から最初に撃てるもの**。乱数を入れない（ログの再現性が落ちる）。

### 3-3. `scripts/systems/battle_log.gd` — **触らない**

敵の `cast` / `damage` / `react` は**今のまま何もしなくてもログに出る**（`SkillRuntime.cast()` に差してあるため、撃つのが誰でも出る）。⚠ **敵用のログを足さないこと。**

---

## 4. ⚠ 事故りやすい箇所

| | 内容 |
|---|---|
| 4-1 | **撃つ経路を2本にしない。** 敵専用の cast を作らない |
| 4-2 | **`_fire_basic_attack()` を触らない。** 「式をここに書かない」「対象を選び直さない」「`SkillActivation` を通さない」の3つの ⚠ が付いている |
| 4-3 | **`characters.json` の `"skills"` は候補一覧であって装備枠ではない。** 敵にプレイヤーは居ないので、この2段を真似ない（`enemies.json` の `"skills"` は**そのまま装備枠**） |
| 4-4 | **関数を足す前に `grep -n "func <名前>"` をする**（前回、既存の `_exit_tree()` を見ずに2本目を宣言してパースエラーを出した） |
| 4-5 | **敵が増えるとログの行数が跳ねる。** `cast` は発動1回につき1行 |
| 4-6 | ⚠ **`stage_order.json` を戻し忘れない。** 戻さないと本編の1面が検証用ステージのままになる |

---

## 5. Ziva に渡せる部分（**JSON と `ja.csv` だけ**）

⚠ **`.gd` は1行も触らないこと。** `.gd` 側（§3）は**すでに書き終わっている。**
⚠ **考えて書かない。この章のブロックをそのまま貼る。** 倍率・寿命・IDは決定済みで、**`status_id` はあとから改名できない**（`CLAUDE.md` 4番）。
⚠ **インデントはタブ。** ⚠ **既存の3体・3ステージを1文字も変えない。**

### 5-0. ⚠ `user_character_id` に敵IDを書く（**間違いではない**）

スキルの欄の名前は `user_character_id` だが、**敵のスキルには敵のIDを書く。**
欄が空だと赤（`skill_schema.gd:271`）。敵IDを書いても、射程のクロス検証は
`_cache_characters` に無いIDなので**黙って飛ばされる**（`master_data_loader.gd:575`）。**欄名を変えないこと。**

### 5-1. `resources/balance/master/enemies.json` に6体

**末尾の `}` の手前に**、6体ぶんを足す（最後の既存エントリの `}` に `,` を付ける）。
⚠ 能力値は検証用なので弱い。**本編の3体の数値と揃えようとしないこと。**

```json
	"enemy_dbg_react": {
		"name_key": "ui_battle_enemy_dbg_react",
		"hp": 80,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 50,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_react"]
	},
	"enemy_dbg_followup": {
		"name_key": "ui_battle_enemy_dbg_followup",
		"hp": 80,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 50,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_followup"]
	},
	"enemy_dbg_buff": {
		"name_key": "ui_battle_enemy_dbg_buff",
		"hp": 80,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 50,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_buff"]
	},
	"enemy_dbg_dot": {
		"name_key": "ui_battle_enemy_dbg_dot",
		"hp": 80,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 50,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_dot"]
	},
	"enemy_dbg_heal": {
		"name_key": "ui_battle_enemy_dbg_heal",
		"hp": 80,
		"atk": 5,
		"mag": 20,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 50,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_heal"]
	},
	"enemy_dbg_ranged": {
		"name_key": "ui_battle_enemy_dbg_ranged",
		"hp": 80,
		"atk": 5,
		"mag": 5,
		"def": 0,
		"mdef": 0,
		"spd": 40,
		"atkspd": 0,
		"haste": 0,
		"crit_rate": 0,
		"crit_dmg": 150,
		"attack_type": "physical",
		"attack_range": 300,
		"attack_interval_sec": 2.0,
		"basic_attack": {
			"effects": [
				{
					"type": "damage",
					"delivery": "melee",
					"multiplier": 1.0,
					"attack_type": "physical",
					"scale_from": "atk"
				}
			]
		},
		"skills": ["skill_edbg_ranged"]
	}
```

⚠ **`enemy_dbg_ranged` だけ `attack_range` が 300。** 遠くから撃つ敵。
⚠ **`enemy_dbg_heal` だけ `mag` が 20。** 回復量が0だと検証にならないため。

### 5-2. `resources/balance/master/enemies/<enemy_id>/skills.json` を**6ファイル**

⚠ **フォルダ6つを新規作成する**（人間が承認済み）。**1ファイルにスキル1件。**

**`enemies/enemy_dbg_react/skills.json`**

```json
{
	"skill_edbg_react": {
		"name_key": "ui_battle_skill_edbg_react",
		"user_character_id": "enemy_dbg_react",
		"unlock_level": 1,
		"cooldown_sec": 20.0,
		"activation": "instant",
		"target": {
			"team": "self"
		},
		"effects": [
			{
				"type": "react",
				"host": "unit",
				"status_id": "status_edbg_react",
				"stack": "refresh",
				"duration_sec": 15.0,
				"react": {
					"event": "took_damage",
					"effects": [
						{
							"type": "damage",
							"multiplier": 1.0,
							"attack_type": "magic",
							"scale_from": "mag",
							"target": {
								"team": "source"
							}
						}
					]
				}
			}
		]
	}
}
```

**`enemies/enemy_dbg_followup/skills.json`**

```json
{
	"skill_edbg_followup": {
		"name_key": "ui_battle_skill_edbg_followup",
		"user_character_id": "enemy_dbg_followup",
		"unlock_level": 1,
		"cooldown_sec": 20.0,
		"activation": "instant",
		"target": {
			"team": "self"
		},
		"effects": [
			{
				"type": "react",
				"host": "unit",
				"status_id": "status_edbg_followup",
				"stack": "refresh",
				"duration_sec": 15.0,
				"react": {
					"event": "dealt_damage",
					"effects": [
						{
							"type": "damage",
							"multiplier": 0.5,
							"attack_type": "magic",
							"scale_from": "mag",
							"target": {
								"team": "source"
							}
						}
					]
				}
			}
		]
	}
}
```

**`enemies/enemy_dbg_buff/skills.json`**

```json
{
	"skill_edbg_buff": {
		"name_key": "ui_battle_skill_edbg_buff",
		"user_character_id": "enemy_dbg_buff",
		"unlock_level": 1,
		"cooldown_sec": 8.0,
		"activation": "instant",
		"target": {
			"team": "self"
		},
		"effects": [
			{
				"type": "buff",
				"host": "unit",
				"target": {
					"team": "self"
				},
				"status_id": "status_edbg_buff_atk",
				"stat": "atk",
				"value": 20,
				"duration_sec": 6.0,
				"stack": "refresh"
			}
		]
	}
}
```

⚠ **寿命6秒・クールダウン8秒。** わざと切らしてある（`status_end` の `why: "expire"` を出すため）。

**`enemies/enemy_dbg_dot/skills.json`**

```json
{
	"skill_edbg_dot": {
		"name_key": "ui_battle_skill_edbg_dot",
		"user_character_id": "enemy_dbg_dot",
		"unlock_level": 1,
		"cooldown_sec": 12.0,
		"activation": "instant",
		"target": {
			"team": "enemy",
			"mode": "select",
			"sort": "nearest",
			"count": 1
		},
		"effects": [
			{
				"type": "dot",
				"host": "unit",
				"status_id": "status_edbg_dot",
				"multiplier": 0.5,
				"attack_type": "physical",
				"scale_from": "atk",
				"duration_sec": 8.0,
				"interval_sec": 2.0,
				"stack": "independent"
			}
		]
	}
}
```

**`enemies/enemy_dbg_heal/skills.json`**

```json
{
	"skill_edbg_heal": {
		"name_key": "ui_battle_skill_edbg_heal",
		"user_character_id": "enemy_dbg_heal",
		"unlock_level": 1,
		"cooldown_sec": 6.0,
		"activation": "instant",
		"target": {
			"team": "ally",
			"mode": "select",
			"sort": "all"
		},
		"effects": [
			{
				"type": "heal",
				"multiplier": 1.0,
				"scale_from": "mag"
			}
		]
	}
}
```

⚠ **`sort: "all"` にしてある。** 仲間全員（自分を含む）に飛ぶので、**`heal` の行が複数出て `dst` を確かめやすい。**

**`enemies/enemy_dbg_ranged/skills.json`**

```json
{
	"skill_edbg_ranged": {
		"name_key": "ui_battle_skill_edbg_ranged",
		"user_character_id": "enemy_dbg_ranged",
		"unlock_level": 1,
		"cooldown_sec": 6.0,
		"activation": "instant",
		"target": {
			"team": "enemy",
			"mode": "select",
			"sort": "nearest",
			"count": 1
		},
		"effects": [
			{
				"type": "damage",
				"delivery": "projectile",
				"multiplier": 1.5,
				"attack_type": "physical",
				"scale_from": "atk",
				"trigger": "event:hit"
			}
		]
	}
}
```

### 5-3. `resources/balance/master/stages.json` に `stage_dbg` を1件

⚠ **このファイルだけ、トップレベルが半角スペース2つ・中がタブという書き方になっている。** 既存の `stage_3` の書き方に合わせること。
**末尾の `}` の手前に**足す（`stage_3` の `}` に `,` を付ける）。

```json
  "stage_dbg": {
	"name_key": "ui_stage_dbg",
	"party_id": "party_default",
	"rewards": { "gold": 1 },
	"waves": [
	  { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_dbg_react", "count": 1 } ] },
	  { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_dbg_followup", "count": 1 } ] },
	  { "wave_index": 3, "enemies": [ { "enemy_type_id": "enemy_dbg_buff", "count": 1 }, { "enemy_type_id": "enemy_dbg_heal", "count": 1 } ] },
	  { "wave_index": 4, "enemies": [ { "enemy_type_id": "enemy_dbg_dot", "count": 1 } ] },
	  { "wave_index": 5, "enemies": [ { "enemy_type_id": "enemy_dbg_ranged", "count": 1 } ] }
	]
  }
```

⚠ **3波目だけ2体。** 回復する敵に回復する相手が要るため。

### 5-4. `resources/balance/master/stage_order.json`

⚠ **初稿は「人間が `"stage_1"` を差し替えて、あとで戻す」だったが、やめた**（§9）。
`"debug"` の列を**常設**したので、**差し替えも戻しも要らない。**

```json
{
  "story": ["stage_1", "stage_2", "stage_3"],
  "debug": ["stage_dbg_enemy_skill"]
}
```

### 5-5. `localization/ja.csv` に**12行**

⚠ **UTF-8（BOMなし）。編集後は人間が再インポート。**
⚠ スキル名は敵のボタンが無いので画面には出ないが、**キーだけ書いて翻訳表に足さない状態を作らない**（`AGENTS.md`）。

```
ui_battle_enemy_dbg_react,検証・反射
ui_battle_enemy_dbg_followup,検証・追撃
ui_battle_enemy_dbg_buff,検証・自己強化
ui_battle_enemy_dbg_dot,検証・毒
ui_battle_enemy_dbg_heal,検証・回復役
ui_battle_enemy_dbg_ranged,検証・遠距離
ui_battle_skill_edbg_react,棘の守り（敵）
ui_battle_skill_edbg_followup,追い討ち（敵）
ui_battle_skill_edbg_buff,咆哮（敵）
ui_battle_skill_edbg_dot,毒の牙（敵）
ui_battle_skill_edbg_heal,癒しの唱和（敵）
ui_battle_skill_edbg_ranged,遠矢（敵）
```

⚠ **`ui_stage_dbg,検証用ステージ` も足すこと**（合計13行）。

### 5-6. 差し込み方（⚠ `edit_file` はこのプロジェクトで動かない）

- `enemies.json` と `stages.json` は**末尾の `}` を消し、手前のエントリに `,` を足してから `cat >>` で追記し、最後に `}` を戻す**
- `enemies/<id>/skills.json` は**新規ファイル**なので、フォルダを作って丸ごと書く
- ⚠ **ファイル全体を閉じる最後の `}` を戻し忘れない。** JSON が壊れると起動時に全部のマスターが読めなくなる

### 5-7. Ziva への注意

- **`.gd` を1文字も触らない。** 直す必要があると思ったら、**直さずに報告して止まる**
- **既存の3体・3ステージ・既存のスキル39件を1文字も変えない**
- 書いたら `IMPL_LOG_ENEMY_PARITY.md` を `docs/03_log/` に生成する

---

## 6. 完了条件

### 6-A. ログ（Godot の出力パネル）

1. `skills validated: **45** entries, 0 errors, **1** warnings`（39 ＋ 6。⚠ **黄は `skill_dbg_dot_odd` の1本のまま。増えていたら赤扱い**）
2. `basic attacks validated: **15** entries, 0 errors, 0 warnings`（9 ＋ 6）
3. 起動時に「スキルのファイルが無い」の赤が出ない（`enemies/` は任意扱い）
4. 戦闘中に赤が出ない

### 6-B. ファイル（`battle_last.jsonl` を読む）

5. `ev:"cast"` で `unit` が **`enemy_` で始まる行**が出ている（＝敵が自分で撃った）
6. 同じ敵の `cast` が**1回だけでなく複数回**出ている（＝クールダウンが回っている）
7. **`enemy_dbg_heal`**：`ev:"heal"` の `dst` が **`enemy_` で始まる**（＝敵の回復が敵の仲間に飛んだ）。⚠ **`party_` だったら `team` の解決が敵視点で反転している**
8. **`enemy_dbg_react`**：味方が殴った直後に `ev:"react"` が出て、その `src` が**殴った味方のID**と一致する
9. **`enemy_dbg_followup`**：`#react:dealt_damage` の `cast` が出て、**その直後にさらに `react` が出ていない**（10-2 の印）
10. **`enemy_dbg_dot`**：`ev:"dot"` の `dst` が `party_` で始まる。⚠ **その直後に `react` が出ていないこと**（宿題17の現状確認。**直さない**）
11. **`enemy_dbg_buff`**：`ev:"status_add"` の `unit` が `enemy_` で始まる
12. `status_add` の数 ＝ `status_end` ＋ `status_clear` の `count`（**宿題22の実測もここで済む**）

### 6-C. 画面（実機で操作する）

13. 冒険選択の一覧の**末尾に「▼ 検証用」の見出しと `検証・敵のスキル` の行が出て、押して入れる**（§9）。⚠ **本編3ステージの並びと解放状態が変わっていないこと**
14. **`enemy_dbg_ranged` から投射物が飛ぶ**（味方の弓と同じ見た目で、味方に向かって飛ぶ）
15. 敵のスキルでも**ダメージ数値が出る**（通常攻撃と同じ経路）
16. 本編の `stage_1` を1面通しても、**この回の前と挙動が変わらない**（報酬とクリア記録が今までどおり入る）
17. **検証用ステージを勝っても、スタミナが減らず・ゴールドが増えず・一覧に ✓ が付かない**（§9）

### 6-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `enemies/` のフォルダを丸ごと消しても起動する（任意扱い）
- 味方と敵で同じスキルIDを書くと赤が出る
- 本編の敵にスキルを載せたら `ENEMY_DIRS_REQUIRED` に足す

---

## 7. この回でやらないこと

- **本編3体にスキルを載せること**（仕組みは効くが、載せない）
- HP依存・オーラ・距離条件（②＝条件）
- 宿題17（DoT で購読が発火しない）の修正
- 敵の**選択AI**（誰を狙うか）。⚠ **今まで通り「一番近い相手」のまま**
- バランスの調整

---

## 8. 宿題に足すもの（`PROJECT_STATUS.md`）

- 宿題16（リリース前に消すもの）に **`enemies/` フォルダごと・`enemies.json` の検証用6体・`stage_dbg_enemy_skill`・`ja.csv` の13行・`MasterDataLoader.ENEMY_DIRS_OPTIONAL`・`stage_order.json` の `"debug"` 列・`adventure_select.gd` の検証用3関数・`GameStateKeys.STAGE_TYPE_DEBUG`** を足す
- 宿題13（フォルダを増やしたら定数に1行）に **敵側（`ENEMY_DIRS_REQUIRED`）も同じ罠がある**ことを足す
- ⚠ **`adventure_select.gd:4` のヘッダコメントが実装と逆**（「スタミナの消費はこの画面でのみ行う」と書いてあるが、実際に減らすのは `battle_controller._consume_stage_stamina()`。この画面は残量を見ているだけ）
- ⚠ **古いセーブに `stage_dbg` のクリア記録が残っている**（改名前に1回クリアしたため）。マスターに無いIDなので実害は無いが、消すなら人間がセーブを編集する

---

## 9. 検証用ステージの別枠（**人間の決定・2026-08-17。初稿からの変更**）

### なぜ変えたか

初稿は「`stage_order.json` の `"stage_1"` を `"stage_dbg"` に差し替えて検証し、あとで戻す」だった。
**これは `parties.json` の `members` 差し替えと同じ「戻し忘れ事故」を1つ増やすだけだった。**
実際に1回目の検証で、`spend_stamina(5)` と `mark_stage_cleared('stage_dbg')` がセーブに入った。

### 形

```json
// stage_order.json … ⚠ "story" は今後いっさい触らない
{
  "story": ["stage_1", "stage_2", "stage_3"],
  "debug": ["stage_dbg_enemy_skill"]
}
```

| 場所 | 内容 |
|---|---|
| `GameStateKeys.STAGE_TYPE_DEBUG` | `"debug"`。⚠ **`stage_order.json` の列を引くためだけ。** `BattleSession.stage_type` には入れない |
| `adventure_select._build_stage_list()` の末尾 | `_build_debug_stage_list()` を呼ぶ |
| `_build_debug_stage_list()` | `OS.is_debug_build()` のときだけ「▼ 検証用」の見出しと行を足す |
| `_add_debug_stage_row()` | ⚠ **`_add_stage_row()` と共通化しない。** あちらは解放判定・クリア印・スタミナ表示を持つ本番の行 |
| `_on_debug_challenge_pressed()` | 解放判定もスタミナ確認もせず、**`STAGE_TYPE_TRAINING`** を渡して戦闘へ |
| `battle_controller._enter_victory()` | ⚠ **`stage_type == story` のときだけ**報酬とクリア記録。結果画面は出す |

### この形の効き目

- **本番の `"story"` 列を二度と触らない**（戻し忘れが起きない）
- **検証でスタミナが減らない・報酬が入らない・セーブにクリア記録が残らない**
- **テストしたいこと1つにつきステージ1本。** 増やすときは `"debug"` 配列に1行足すだけ（②＝条件の回は `stage_dbg_condition`）
- 消すときは `"debug"` の列と `adventure_select.gd` の3関数、`STAGE_TYPE_DEBUG`

⚠ **`_enter_victory()` の分岐は、この回のスコープ外の挙動変更**（将来のトレーニングモードにも効く）。人間が承認済み。
