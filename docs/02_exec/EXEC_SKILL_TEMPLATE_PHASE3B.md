# EXEC — 段階3の後半①：**購読（外の出来事に反応する）**

対象：`PLAN_SKILL_TEMPLATE.md` 10章。前提は `docs/NEXT_STEPS.md`（2026-08-17時点）。

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**）

| 決めたこと | 決定 |
|---|---|
| 欄の名前 | **`react`**（`trigger` と字面・語感とも被らない。10-2の「反応から生まれた行動」と用語が一致する） |
| 初回に出す出来事 | **「攻撃した」＋「ダメージを与えた／受けた」の2系統**（撃破・状態付与・進入はやらない） |
| 検証用スキルの置き場所 | **既存の debug 3キャラに7件目を足す**（フォルダ新設なし・`parties.json` の差し替えも現状のまま） |

---

## 1. ⚠ 着手前の報告：NEXT_STEPS の「どこで出せるか」を1点変える

`NEXT_STEPS.md` §2 の表は、「ダメージを与えた／受けた」の出せる場所を
**`SkillResolver._apply_damage()` の第2段** と書いている。

**観測点としては正しいが、そこから発火はできない。**

- `SkillResolver` は **static クラス**で、待ち行列も器も持たない（PLAN 7-3：時間を持たない・次のフレームを知らない）
- ここから購読を発火させると `SkillResolver` → `SkillRuntime` の参照が要る。
  `skill_resolver.gd` 188行が「`StatusRegistry` を名指しすると Cyclic reference のパースエラーを踏みうる」と
  警告しているのと**同じ形**になる

**→ この EXEC では「観測は第2段のまま・発火は `SkillRuntime`」に分ける。**

| | 誰が |
|---|---|
| 観測（何が起きたか記録する） | `_apply_damage()` 第2段。**結果の辞書にキーを足すだけ** |
| 配布（誰が購読しているか探す） | `SkillRuntime._fire()` が `resolve()` の戻り値を見て配る |
| 発火 | **`SkillRuntime.cast()` → `_fire()`**（既存の1本道。§3-1を守る） |

**PLAN 側は直していない**（勝手に直さない）。PLAN 10章に注記が要るなら人間が入れる。

---

## 2. 書ける形（JSON）

### 2-1. 新しい効果の種類 `react`

購読は**状態として器に残る**（`host: unit`）。`buff` / `dot` と同じ場所に、3つ目の種類として入る。

```json
{
	"type": "react",
	"host": "unit",
	"status_id": "status_dbg_react_thorns",
	"stack": "refresh",
	"duration_sec": 12,
	"react": {
		"event": "took_damage",
		"effects": [
			{
				"type": "damage",
				"multiplier": 0.6,
				"attack_type": "magic",
				"scale_from": "mag",
				"target": { "team": "source" }
			}
		]
	}
}
```

- **`react` は `trigger` と別の欄**（PLAN 10章・⚠ 同じ欄にしない）。形は同じ（きっかけ → `effects[]`）
- `react.effects[]` の中身は **`effects[]` と同じ検証を通す**（＝2本目の語彙を作らない）
- `host` は **`unit` のみ**。`point`（罠）は座標の規則が要るのでこの回はやらない（W9の黄はそのまま）
- 寿命・重ねがけ・同一性は **`buff` / `dot` と完全に同じ規則**（器の既存コードを使う）

### 2-2. 出来事の名前（3つ）

| 名前 | いつ出るか | 誰に配るか | `team: source` が指す相手 |
|---|---|---|---|
| `attacked` | `type: damage` の効果が発火した | 攻撃者 | **その効果の対象の1体目**（0体なら source 無し＝空振り） |
| `dealt_damage` | ダメージが1件確定した | 攻撃者 | **殴られた相手** |
| `took_damage` | ダメージが1件確定した | 被害者 | **殴ってきた相手** |

⚠ **`attacked` と `dealt_damage` を1つにしないこと**（NEXT_STEPS §2）。
空振り（対象0体）では `attacked` だけが出て、`dealt_damage` は出ない。

⚠ **`attacked` は効果ごとに1回**。多段（`effects[]` が2件）なら2回出る。
⚠ **`dealt_damage` / `took_damage` は対象1体につき1回**。全体攻撃で3体なら3回ずつ。
⚠ **回復では出ない**（`is_heal` の結果は配らない）。

### 2-3. `target.team: "source"`

```json
"target": { "team": "source" }
```

- **きっかけのユニットIDをそのまま使う**（⚠ §3-4：`sort` を通さない）
- **`mode` / `sort` / `count` / `range` は書けない**（赤で弾く。`team: self` と同じ扱い）。
  書ける形にすると「選び直さない」という決定が JSON 側から破れる
- そのユニットが**死んでいる／居ない**なら**対象0体**（空振りは正常系。警告を出さない）

### 2-4. この回でやらないこと

- `scale_from` の `of: "source"`（`_scale_variable()` 443行の黄）… **未実装のまま残す**。
  反射の威力は「反射する側の `mag`」（`of: user`）で書けるため、この回に要らない
- **DoT の周期ダメージでは合図を出さない**（§4-5）
- `expire` / 条件 / 介入点3種 / 撃破 / 状態付与 / 罠

---

## 3. 実装（ファイル別）

### 3-1. `scripts/systems/skill_schema.gd`（語彙と検証・**唯一の正**）

**足すもの**

```gdscript
const EFFECT_REACT: String = "react"

const EVENT_ATTACKED: String = "attacked"
const EVENT_DEALT_DAMAGE: String = "dealt_damage"
const EVENT_TOOK_DAMAGE: String = "took_damage"
const EVENTS_KNOWN: Array = [EVENT_ATTACKED, EVENT_DEALT_DAMAGE, EVENT_TOOK_DAMAGE]
```

- `EFFECT_TYPES_KNOWN` / `EFFECT_TYPES_IMPLEMENTED` / `EFFECT_TYPES_STATUS` に `EFFECT_REACT` を足す
- ⚠ `EVENT_HIT`（`trigger: "event:hit"` の合図）と **別の一覧にする**。
  演出シーンの合図と外の出来事は別物。混ぜると `trigger: "event:took_damage"` が書けてしまう

**検証（新規 E/W）**

| 番号 | 内容 | 色 |
|---|---|---|
| E46 | `react` に `react{}` が無い／Dictionary でない | 赤 |
| E47 | `react.event` が `EVENTS_KNOWN` に無い | 赤 |
| E48 | `react.effects` が無い／配列でない／空 | 赤 |
| E49 | `react.effects[]` の要素が Dictionary でない | 赤 |
| E50 | `react` 以外の効果に `react{}` が書いてある | 赤 |
| E51 | `react` の `host` が `unit` 以外 | 赤（`point` は座標の規則待ち） |
| E52 | `team: source` に `mode` / `sort` / `count` / `range` が書いてある | 赤 |
| E53 | `react.effects[]` の中の効果に `react{}` が書いてある（**購読の入れ子**） | 赤 |

- `react.effects[]` の各要素は **`_validate_effect()` を再帰で呼ぶ**（`where` は `"effects[0].react.effects[1]"` の形）。
  ⚠ 再帰の深さは1段まで。E53 が2段目を弾くので無限にならない
- **W3（`team: source` は段階3）を消す。** 実装したので黄を出す理由が無くなる
- `_validate_status_effect()` は `react` も通す（`status_id` / `stack` / 寿命の規則は共通）。
  ⚠ ただし `buff` の `stat` / `value`、`dot` の `interval_sec` は `react` に要求しないこと

### 3-2. `scripts/systems/status_registry.gd`（器・567行）

- `const KIND_REACT: String = "react"` を足す
- `add()` の「--- 2. 種類 ---」に `EFFECT_REACT` → `KIND_REACT` の枝を足す
- `_make_entry()` の返す辞書に `"react": {}` を足す（**1箇所しかない要素の形を2箇所に書かない**）
- `_fill_react(entry, effect) -> bool` を足す。`react.event` と `react.effects` を確認し、
  `entry["react"] = { "event": ..., "effects": [...] }` に**複製して**持つ（⚠ `duplicate(true)`。
  マスターの辞書を参照で握らない）
- ⚠ `_rebuild_unit_mods()` / `stat_mod()` は `KIND_BUFF` だけを見ているので**触らない**。
  `react` が能力値に混ざらないことをここで担保する
- ⚠ `tick()` の寿命・宿主の死亡による破棄は `kind` を見ていない＝**そのまま効く**（確認すること）

**器は購読を発火させない。** 器は「購読を1件持っている」だけ。探して撃つのは `SkillRuntime`。

### 3-3. `scripts/systems/skill_resolver.gd`（519行）

**(a) `select_targets()` に第4引数**

```gdscript
static func select_targets(
		target_def: Dictionary, user: BattleUnit, session: BattleSession,
		source_unit_id: String = ""
) -> Array:
```

- `SkillSchema.TEAM_SOURCE` の枝（現48行の `push_warning`）を差し替える：
  - `source_unit_id` が空 → 空配列（**警告なし**。空振りは正常系）
  - 引いたユニットが `null` または死亡 → 空配列（**警告なし**）
  - それ以外 → `[source_unit_id]` を返す。⚠ **`_sorted_units()` を通さない**（§3-4）
- ⚠ 既定値を `""` にするのは、`skill_activation.gd` からの呼び出しを変えないため

**(b) `_apply_damage()` の第2段に**キーを2つ足す

```gdscript
results.append({
	"unit_id": target.unit_id,
	"amount": int(ctx["amount"]),
	"is_heal": false,
	"is_crit": bool(ctx["is_crit"]),
	"source_unit_id": user.unit_id,      # 追加
	"attack_type": attack_type,          # 追加
})
```

- ⚠ **既存の4キーの名前も意味も変えない**（`battle_controller._on_skill_effects_applied()` がそのまま読む）
- ⚠ `_apply_heal()` 側には足さない（回復では合図を出さない）
- ⚠ **第2段でやること以外はしない。** 式を再評価しない

### 3-4. `scripts/systems/skill_runtime.gd`（407行・**この回の本体**）

**(a) `cast()` に第6引数 `react_ctx: Dictionary = {}`**

```gdscript
func cast(
		user: BattleUnit, skill_id: String, skill_data: Dictionary, power_ratio: float,
		fixed_target_ids: Array = [], react_ctx: Dictionary = {}
) -> void:
```

`react_ctx` の形：`{ "source_unit_id": String, "from_reaction": true }`

⚠ **入口を増やさない**（§3-1）。購読の発火も `cast()` から入り、`_fire()` へ出る。
`fire_reaction()` のような専用関数を作らないこと。

**(b) 待ち行列の要素に2つ足す**（`_entry_dict()` の1箇所）

```gdscript
"source_unit_id": ...,   # team: source が指す相手
"from_reaction": ...,    # 10-2 の印
```

- `_make_entry()` は `select_targets()` に `source_unit_id` を渡す
- ⚠ `fixed_target_ids` が来ている枝（通常攻撃）でも、印と `source_unit_id` は同じように載せる。
  **`_entry_dict()` を通る道は1本なので、ここで漏れない**

**(c) 印（10-2）— `_fire()` の末尾に1箇所だけ**

```gdscript
func _fire(entry: Dictionary) -> void:
	...
	var results: Array = SkillResolver.resolve(...)
	# ⚠ 印が付いていたら合図を出さない（PLAN 10-2）。
	#   反射の無限ループ・追撃の発散・コンボの水増しが、この1行で同時に止まる。
	if not bool(entry.get("from_reaction", false)):
		_dispatch_events(entry, results)
	if results.is_empty():
		return
	effects_applied.emit(results)
```

⚠ **判定は「合図を出す直前」の1箇所だけ。** 購読を探す側・撃つ側に印の判定を散らさないこと。
⚠ **`results.is_empty()` の early return より前に置く**（空振りでも `attacked` は出る）。

**(d) 合図を配る `_dispatch_events(entry, results)`**

1. `type: damage` の効果なら、攻撃者に `attacked` を1回
   （`source_unit_id` ＝ `entry["target_ids"]` の1体目。0体なら `""`）
2. `results` の各要素で `is_heal` が false のものについて：
   - 攻撃者へ `dealt_damage`（source ＝ `r["unit_id"]`）
   - 被害者（`r["unit_id"]`）へ `took_damage`（source ＝ `r["source_unit_id"]`）

⚠ **`print` を書かないこと**（§3-5・毎フレーム大量に起きる正常系）。

**(e) 購読を探して撃つ `_notify(event_name, host_unit_id, source_unit_id)`**

```gdscript
# 1. 取り出す（⚠ 回しながら撃たない。§3-2）
var subs: Array = _registry.query({ "kind": StatusRegistry.KIND_REACT, "host_unit_id": host_unit_id })
if subs.is_empty():
	return   # ⚠ 購読が無いのは正常系。警告も print も出さない
# 2. event が一致するものだけ、印を付けて cast() へ
```

- 撃つときは
  `cast(host_unit, skill_id, { "target": ..., "effects": <react.effects> }, 1.0, [], { "source_unit_id": ..., "from_reaction": true })`
- `skill_id` は `"<status_id>#react:<event>"` の形にする（**ログとタイムアウト警告で出どころが分かるように**）
- ⚠ `query()` は**器の辞書を参照で返す**（`status_registry.gd` 465行）。**書き換えないこと**
- ⚠ 発火中に器の要素が増減しても `subs` は別の配列なので安全（＝「取り出してから発火する」形）

**(f) ログ（1本だけ）**

購読が**実際に発火したときだけ** `print` する。稀なので埋まらない。

```
[SkillRuntime] react: status_dbg_react_thorns (took_damage) unit=ally_0 source=enemy_0 effects=1
```

### 3-5. `scenes/adventure/battle_controller.gd`（1129行）

**変更なし。** `_on_skill_effects_applied()` は既存の4キーだけを読む（足したキーは無視される）。

⚠ **触らないこと。** 触る必要が出たら、それは設計が漏れている合図。

---

## 4. ⚠ 事故りやすい箇所（NEXT_STEPS §3 への回答）

| | どう守ったか |
|---|---|
| 3-1 発火の経路を増やさない | 購読も `cast()` → `_fire()`。専用の発火関数を作らない |
| 3-2 同じフレームでの再入 | `query()` の戻り値を**先に配列で受けてから**回す。印で2段目が止まるので深さは1 |
| 3-3 反射で生んだダメージにも印 | 印は `entry` に載り、`_entry_dict()` は1本道。**反射のダメージも同じ道を通る** |
| 3-4 `team: source` は選び直さない | `_sorted_units()` を通さない。`mode`/`sort`/`count` は **E52 で赤**にして書けなくする |
| 3-5 正常系に警告を付けない | 購読ゼロ・空振り・死んだ source … **全部無音**。`print` は発火したときの1本だけ |

### 4-5. ⚠ DoT のダメージでは合図を出さない（**この回の決定**）

`StatusRegistry` は `SkillResolver.resolve()` を**直接**呼ぶ（`status_registry.gd` 372行）。
この経路は `SkillRuntime` を通らないため、合図が出ない。

**器 → 待ち行列 の参照を作れば出せるが、この回はやらない。** 経路が2本になり、
「発火は `_fire()` の1本」という決定（PLAN 6-5）が形骸化する。

**→ 宿題に送る**（毒のダメージでは反射もカウンターも動かない）。

---

## 5. Ziva に渡せる部分（**JSON と `ja.csv` だけ**）

⚠ **§3 のコード（`.gd` 4ファイル）が入ってから渡すこと。** 先に渡すと
ロード時検証が「知らない効果 `react`」で赤を出す。

⚠ **命名は既存に合わせてある**（実物を確認済み）。
`name_key` は `ui_battle_skill_dbg_*`（`ui_skill_dbg_*` ではない）／`status_id` は `status_dbg_*`／
数値は `1.0` の形で書く。

### 5-1. `char_debug_mix/skills.json` に7件目（**反射**）

```json
	"skill_dbg_react_thorns": {
		"name_key": "ui_battle_skill_dbg_react_thorns",
		"user_character_id": "char_debug_mix",
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
				"status_id": "status_dbg_react_thorns",
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
```

### 5-2. `char_debug_status/skills.json` に7件目（**追撃＝印の本命の検証**）

```json
	"skill_dbg_react_followup": {
		"name_key": "ui_battle_skill_dbg_react_followup",
		"user_character_id": "char_debug_status",
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
				"status_id": "status_dbg_react_followup",
				"stack": "refresh",
				"duration_sec": 15.0,
				"react": {
					"event": "dealt_damage",
					"effects": [
						{
							"type": "damage",
							"multiplier": 0.5,
							"attack_type": "physical",
							"scale_from": "atk",
							"target": {
								"team": "source"
							}
						}
					]
				}
			}
		]
	}
```

⚠ **これが 10-2 の印の本命の検証。** 印が無ければ、追撃のダメージがまた `dealt_damage` を出し、
**その場で無限に再帰する**（1体で再現できる）。

### 5-3. `char_debug_life/skills.json` に7件目（**空振りの検証**）

```json
	"skill_dbg_react_warcry": {
		"name_key": "ui_battle_skill_dbg_react_warcry",
		"user_character_id": "char_debug_life",
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
				"status_id": "status_dbg_react_warcry",
				"stack": "refresh",
				"duration_sec": 20.0,
				"react": {
					"event": "attacked",
					"effects": [
						{
							"type": "buff",
							"host": "unit",
							"status_id": "status_dbg_react_warcry_atk",
							"stat": "atk",
							"value": 3,
							"duration_sec": 6.0,
							"stack": "refresh",
							"target": {
								"team": "self"
							}
						}
					]
				}
			}
		]
	}
```

⚠ **`attacked` は対象0体でも出る**ので、射程外へ空振りしてもバフが乗る。`dealt_damage` との違いはここ。

### 5-3-2. ⚠ `resources/balance/master/characters.json` に3件（**初稿で抜けていた**）

⚠ **`skills.json` に足しただけでは画面の候補に出ない。**
候補の一覧と並び順を決めているのは **`characters.json` の各キャラの `"skills"` 配列**
（`game_manager.gd:1745`／`skill_select_screen.gd:10`）。`skills.json` は性能の定義であって候補一覧ではない。

⚠ **ロード時検証（`skills validated: 39 entries`）は `skills.json` しか見ないので、
ここを忘れてもログは正常に見える。** 症状は「スキル選択画面に7件目が出ない」だけ。

| キャラ | `"skills"` 配列の末尾に足す |
|---|---|
| `char_debug_status` | `"skill_dbg_react_followup"` |
| `char_debug_life` | `"skill_dbg_react_warcry"` |
| `char_debug_mix` | `"skill_dbg_react_thorns"` |

⚠ **直前の行に `,` を足すのを忘れない**（JSON が壊れるとそのキャラが丸ごと消える）。

### 5-4. `localization/ja.csv` に3行

```
ui_battle_skill_dbg_react_thorns,とげの鎧（反射）
ui_battle_skill_dbg_react_followup,追い討ち（追撃）
ui_battle_skill_dbg_react_warcry,鬨の声（攻撃時バフ）
```

⚠ **UTF-8（BOMなし）。** 追記後、Godot で再インポート（人間の作業）。
⚠ **追記前に `grep` で同じキーが無いことを確認する。**

### 5-5. 差し込み方（⚠ `edit_file` は使えない）

3ファイルとも末尾が `\t}` ＋ `}` の2行で終わっている。**最終行を削り、手前の `\t}` に `,` を足してから追記する。**

```bash
cd d:/pomodoro-heroes
f=resources/balance/master/characters/char_debug_mix/skills.json
sed -i '$ d' "$f"
sed -i '$ s/^\t}$/\t},/' "$f"
cat >> "$f" << 'EOF'
（ここに 5-1 のブロックをそのまま貼る）
}
EOF
```

⚠ **最後の `}`（ファイル全体の閉じ）を戻し忘れないこと。** JSON が壊れると、
そのキャラのスキルが**全部**無音で消える。

### 5-6. Ziva への注意

- ⚠ **`.gd` を1文字も触らない**（このタスクの `.gd` は設計役が書き終えている）
- ⚠ **`.json` はタブインデント**（既存ファイルに合わせる）
- ⚠ **既存の6件を消さない・並べ替えない**
- ⚠ **`status_id` は改名できない**（CLAUDE.md 4番）。付けたら変えない
- ⚠ **Godot を起動して確かめようとしない。** 完了条件 §6-C は人間が実機で見る
- 書き終えたら `IMPL_LOG_SKILL_TEMPLATE_PHASE3B.md` を `docs/03_log/` に生成する

---

## 6. 完了条件

### 6-A. ログ（Godot の出力パネル）

**画面で分かることはここに書かない。**

| | 見るもの | 期待 |
|---|---|---|
| A-1 | 起動時（「つづきから」） | `skills validated: 39 entries, 0 errors, 1 warnings`（36 → **39**。増えた3件は検証用スキル） |
| A-2 | 同上 | ⚠ **黄は1本のまま**（`skill_dbg_dot_odd` の端数）。**W3（`team: source` は段階3）が消えている** |
| A-3 | 同上 | `basic attacks validated: 9 entries, 0 errors, 0 warnings`（**変わらない**） |
| A-4 | 反射持ちが殴られたとき | `[SkillRuntime] react: status_dbg_react_thorns (took_damage) ...` が**殴られた回数だけ**出る |
| A-5 | 追撃持ちが殴ったとき | `[SkillRuntime] react: status_dbg_react_followup (dealt_damage) ...` が**1回の攻撃につき1行**。⚠ **2行以上出たら印が効いていない** |
| A-6 | 誰も購読していない状態で戦闘を1分回す | ⚠ **`react` を含む行が1本も出ない**（正常系に警告を付けていないことの確認） |
| A-7 | 反射を撃った直後に反射持ちが死ぬ | 赤も黄も出ない（`_fire()` の生存確認で無音に落ちる） |

### 6-B. ファイル（テキストエディタで開く）

| | 見るもの | 期待 |
|---|---|---|
| B-1 | `char_debug_mix/skills.json` ほか3ファイル | 7件目が入り、**既存6件が無傷**。タブインデント |
| B-2 | `localization/ja.csv` | 3行が追記され、**1行目が `keys` のまま**（BOM が付いていない） |
| B-3 | `save_slot_0.json` | ⚠ **差分が無い**（購読は戦闘中だけの状態。セーブに出ない） |

### 6-C. 画面（実機で操作する）

⚠ **`parties.json` の `members` を検証用3体に差し替えて再起動。戻し忘れないこと。**
⚠ **装備枠は2つしかない。** 育成画面で7件目を付け替えてから戦闘へ入る。

| | やること | 期待 |
|---|---|---|
| C-1 | `skill_dbg_react_thorns` を付けて発動 → 敵に殴られる | 殴ってきた**その敵**にダメージが出る（⚠ **別の敵に出たら `team: source` が選び直している**） |
| C-2 | C-1 のまま15秒待つ | 15秒後、殴られてもダメージが返らなくなる（寿命が効いている） |
| C-3 | `skill_dbg_react_followup` を付けて発動 → 通常攻撃を1発当てる | ダメージが**2つ**出る（本体＋追撃）。⚠ **3つ以上出たら印が効いていない** |
| C-4 | C-3 のまま戦闘を続ける | 画面が固まらない・数字が延々と出続けない |
| C-5 | `skill_dbg_react_warcry` を付けて発動 → 射程外へ空振りする | F3 パネルの状態一覧に `status_dbg_react_warcry` が乗る（**空振りでも `attacked` は出る**） |
| C-6 | `skill_dbg_react_thorns` を発動した状態で「もう一度」を押す | 前の戦闘の購読が残っていない（`reset()` が効いている） |
| C-7 | 僧侶の範囲通常攻撃（3体に当たる）を追撃持ちで撃つ | 追撃が**3回**出る（対象1体につき1回）。⚠ **1回なら配布が対象ごとになっていない** |

### 6-D. 将来コードを変えたときに見る項目（**人間の確認項目ではない**）

- `react.effects[]` の中に `react{}` を書く（E53 が赤で弾く）
- `team: source` に `sort` を書く（E52 が赤で弾く）
- `react` に `host: battle` を書く（E51 が赤で弾く）
- `_dispatch_events()` の印の判定を消すと C-3 が発散する

---

## 7. この回でやらないこと

- 条件・介入点3種・復活・パッシブ・コンボ（②〜④）
- `expire`（自分が消えるとき）
- 罠（`host: point` の購読）
- **撃破した／死んだ**・**状態が付いた**（②以降。撃破は全滅判定と復活の順序に食い込む＝PLAN 11-1）
- `scale_from` の `of: "source"`
- **DoT の周期ダメージからの合図**（§4-5）
- `bump_counter()` の利用者（N回攻撃ごと＝④）

---

## 8. 宿題に足すもの（`PROJECT_STATUS.md`）

1. ⚠ **DoT の周期ダメージでは購読が発火しない**（§4-5）。器 → 待ち行列の参照が要る
2. ⚠ **`scale_from` の `of: "source"` が未実装のまま**（`_scale_variable()` の黄が残る）
3. ⚠ **購読は `host: unit` のみ**。`host: battle`（コンボ）・`host: point`（罠）はまだ載らない
4. **検証用スキル3件・状態3件はリリース前に消す**（既存の宿題16番に追記）
5. ⚠ **`_find_unit()` が4ファイル目に増えていないか**（既存の宿題9番。増やさないこと）
