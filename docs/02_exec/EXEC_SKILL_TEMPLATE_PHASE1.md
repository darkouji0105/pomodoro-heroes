# EXEC_SKILL_TEMPLATE_PHASE1.md — スキルの器の付け替え（段階1）

**第3層（実行指示書）。第2層は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`（決定台帳）。着手の起点は `NEXT_STEPS.md`。**

**このタスクの正体は「器の付け替え」。新しい機能は1つも足さない。**
足すものはほぼ全部、**段階1時点では利用者がゼロの受け口**。

⚠ **例外は `scale_from` だけ**（決定1-5で**必須**にしたので6件とも書く）。**ただし書く値は「今そのスキルが実際に見ている軸」なので、数字は変わらない。**

⚠ **完了条件は「挙動が1件も変わらないこと」**（PLAN 17-1）。§11 を先に読むこと。

---

## 1. 人間による決定事項（2026-08-16・**本文と矛盾する場合こちらが優先**）

| # | 決めたこと | 内容 |
|---|---|---|
| 1-1 | **`sort` は5値すべて段階1で動かす** | `nearest` / `farthest` / `lowest_hp` / `highest_hp` / `all`。並べ替えは1関数の中の分岐なので、「未実装として `push_warning` で飛ばす」より**書く量が少ない**。既存6件は `nearest` と `all` しか使わないので挙動不変は保たれる |
| 1-2 | **`count` に上限を設けない** | ロード時検証は「**1以上の整数**」だけ見る。生存者が `count` に満たなければ居る分だけに当てる（PLAN 4-2 で決定済み）ので、ウェーブの敵数が増えても壊れない |
| 1-3 | **リソース（マナ・スタック）は作らない** | 発動可否を「**撃てない理由を返す1関数**」にしておき、後から条件を1行足せる形にするだけ。マナの器はスタック＝状態のカウンター（段階3）と絡むため、今作ると段階3で作り直しになる |
| 1-4 | **遮蔽は発動可否に入れない** | 座標は `x` の1次元だけで、壁・地形は PLAN 2章の「取らない」列。入れても常に「遮蔽なし」を返す空の条件にしかならない |
| 1-5 | ⚠ **`scale_from` を省略させない** | `damage` と `heal` は **`scale_from` を必ず書く**。**既定値を作らない。** 書いていなければロード時に赤（§5-4 E27）。⚠ **これで PLAN 5-2 の「省略時＝`atk`」との食い違いが消える**（§12-1） |
| 1-6 | ⚠ **対象がいなければ発動しない** | 対象指定スキルは、対象が0体なら**発動せず、クールダウンも回らない**（`REASON_NO_TARGET`・§7）。⚠ **今のコードは対象0体でもCDを回している。ここは意図して変える**（§12-2） |
| 1-7 | **通常攻撃は今回触らない** | 「キャラによって変える」は将来やるが、**今は近距離と遠距離の区別だけでよい**。それは `unit.attack_range`（マスターの値）で**既に区別されている**。⚠ **通常攻撃を `effects[]` に乗せるのは PLAN 21章の担当外**（§13） |
| 1-8 | ⚠ **実装役（MiniMax）を使わない** | **設計役が全部書く。PRE_PLAN も IMPL_LOG も作らない**（§2）。`WORKFLOW.md`【3】〜【7】を飛ばし、【2】から【8】実機確認へ直行する |

> **1-1 の補足（人間からの質問への回答）**：`sort` の値は**後から増やしやすい**。PLAN 2-1 の「拡張しやすい＝**値を1個足す**」に当たる。`highest_atk` を足したいときに触るのは、`SkillSchema` の値の一覧と、`SkillResolver` の並べ替えの分岐**1本ずつ**。スキーマも resolver の構造も変わらない。

---

## 2. 触るファイルと担当

⚠ **決定1-8：このタスクは実装役（MiniMax）を使わない。設計役が全部書く。**

| ファイル | 何をするか | 章 |
|---|---|---|
| `resources/balance/master/skills.json` | **全文差し替え**（6件を新しい形へ） | §4（全文あり） |
| `scripts/systems/skill_schema.gd` | **新規**。語彙の定数とロード時検証 | §5 |
| `scripts/systems/skill_resolver.gd` | **作り直し**（109行） | §6 |
| `scripts/systems/skill_activation.gd` | **新規**。発動可否を1箇所に | §7 |
| `scripts/systems/master_data_loader.gd` | 末尾追記2本 ＋ **`_ensure_loaded()` に1行** | §8 |
| `scenes/adventure/battle_controller.gd` | 3箇所の差し替え（912行） | §9 |
| `docs/00_concept/DATA_SCHEMA.md` 3-1 | スキル定義ブロックの差し替え | §10（全文あり） |

**PRE_PLAN も IMPL_LOG も作らない**（実装役がいないため。`WORKFLOW.md`【3】〜【7】を飛ばし、【2】から【8】実機確認へ直行する）。**直近3タスク（育成・研究・ショップ）と同じ体制で、3回連続で事故ゼロ。**

⚠ **判断の根拠**：完了条件が「挙動が1件も変わらないこと」だけで、**事故点が仕様ではなく書き方の細部にある**（`roll_crit()` を振る回数と順番・安定ソート・`BattleFormula.damage()` の引数）。**どれが落ちても赤は出ず、数字だけが静かに変わる。** 仕様文から復元させる形に向かない。

**新しいフォルダは作らない。** 新規2ファイルはどちらも既存の `scripts/systems/` に置く。

⚠ **`autoload/` は触らない。** ロード時検証は `MasterDataLoader` の中で完結させる（§8-3）。

---

## 3. 着手前に確認した実コード（2026-08-16・`grep` 済み）

**ドキュメントの「実装済み」を信じないこと**（`CLAUDE.md` 1番）。下は実際に読んで確かめた事実。

| 場所 | 事実 |
|---|---|
| `skill_resolver.gd` | 109行。`resolve()` が `type` で `match` する形。動くのは `single` / `aoe` / `heal` の3つ |
| 同 39〜41行 | `buff` / `dot` / `projectile` は `push_warning` して**空配列を返す**（配列の他の効果も落ちる） |
| 同 51〜66行 | `_resolve_single` は `TEAM_ENEMY` **定数直書き** ＋ `abs(t.x - user.x)` の最小 |
| 同 71〜78行 | `_resolve_aoe` は `TEAM_ENEMY` 全員固定 |
| 同 83〜94行 | `_resolve_heal` は `TEAM_PARTY` 全員固定・**使用者を含む**・常に `mag` 参照・**会心を振らない**・`atk_multiplier` を掛けない |
| 同 99〜109行 | `_apply_damage` は `roll_crit()` → `BattleFormula.damage(get_power, get_defense, multiplier * atk_multiplier, crit_dmg, is_crit)` → `take_damage` |
| `SkillResolver` の呼び出し元 | **1箇所だけ**（`battle_controller.gd` 603行） |
| `battle_controller.gd` 493〜498行 | **`charge` 欄の有無**で `pressed` と `button_down/up` を出し分けている |
| 同 466〜476行 | ゲージも **`charge` 欄の有無**で出し分けている |
| 同 600〜601行 | `effective["multiplier"] = 素の値 × power_ratio`（チャージの畳み込み） |
| 同 610〜614行 | CD は `resolve()` の**あと**に必ず開始する（対象0体でも開始される。§9-3で変わる） |
| `unit.gd`（`BattleUnit`・185行） | `get_stat(String)` は**文字列キーの汎用アクセサ**（120行）。未定義キーは `push_error` して0 |
| 同 128〜138行 | `get_power(at)` は physical→`atk` / magic→`mag`、`get_defense(at)` は physical→`def` / magic→`mdef` |
| 同 48行 | `attack_range` は**実在する**（マスターから90行で読む） |
| `battle_formula.gd` | 67行・static4本。`damage()` は `max(1, floor(power * multiplier * (crit) * 100 / (100 + def)))` |
| `battle_session.gd` 64行 | `get_alive_units(team)` は**チーム単位だけ**。距離順・HP順は無い |
| `master_data_loader.gd` | `_ensure_loaded()`（66〜74行）が5ファイルをまとめて読む。**`skills.json` を読んでも何も print しない** |
| 同 319行 | `print("[MasterDataLoader] loaded %d entries from %s")` は **`_index_by()` の中だけ**（items / recipes）。skills は通らない |
| `game_manager.gd` 1057行 | `get_stat_keys()` が10軸の唯一の正 |
| デバッグパネル 134〜141行 | 2行目に出る `dmg` は**通常攻撃の非会心ダメージ**。スキルの数字は出ない（頭上のポップで見る） |
| `unit_view.gd` 71〜75行 | `pop_damage` は会心だけ**色とフォントサイズが違う**。非会心は白 |

---

## 4. `skills.json`（**全文差し替え**）

**PLAN 17章の移行表そのまま。** `name_key` / `user_character_id` / `unlock_level` / `cooldown_sec` / `charge{}` は**1文字も変えない**。

⚠ **インデントはタブ。** 現行ファイルは**エントリ行だけ半角2スペース**という混在になっている（`skills.json` 2行目）。差し替えで**全部タブに統一する**。

⚠ **`range` は書かない。** 座標定数（味方200・敵900 → 最短500）とセットで後決め（PLAN 4-5）。**数値を入れないこと。**

⚠ **`scale_from` は6件とも書く**（決定1-5。**省略は赤**）。⚠ **書く値は「今そのスキルが実際に見ている軸」。** `physical` は `atk`、`magic` は `mag`、回復は `mag`。**ここを間違えると数字が変わり、完了条件が崩れる。**

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
	}
}
```

- **`type` は1件も残さない**（旧欄。残っていたらロード時検証が `push_error` する・§5-4）
- `skill_healing_light` に `attack_type` は**書かない**（PLAN 5-2。回復が攻撃力依存だった事故の再発防止）。⚠ **`scale_from: "mag"` は書く**（決定1-5）。**「書かない欄」と「必ず書く欄」が隣り合っているので混同しないこと**
- **`scale_from` の文字列は省略形**（`"atk"` ＝ `[{ "source": "atk", "of": "user", "weight": 1.0 }]`）。**省略形は「明示」に含まれる**（禁じたのは**欄ごと書かないこと**）
- ⚠ **上の6件の `scale_from` は、今そのスキルが実際に見ている軸と同じ。** `physical` は `user.get_power("physical")` ＝ `atk`、`magic` は `mag`、回復は `mag`（`skill_resolver.gd` 89・102行）。**だから挙動は変わらない**
- `skill_wide_sweep` の `charge{}` は**中身も位置も変えない**

---

## 5. 新規：`scripts/systems/skill_schema.gd`

**役割は2つだけ。**

1. **器の語彙（値の一覧）を1箇所に持つ**
2. **スキル1件ぶんの構造を検証する**（`MasterDataLoader` が全件回す・§8）

```gdscript
class_name SkillSchema
extends RefCounted
```

⚠ **このファイルは `MasterDataLoader` を参照しない。** 参照すると `MasterDataLoader → SkillSchema → MasterDataLoader` の循環になる。
**`characters.json` と突き合わせる検証（射程）だけは `MasterDataLoader` 側に置く**（§8-4）。

### 5-1. 定数（**語彙の唯一の正**）

| 定数 | 値 |
|---|---|
| `ACTIVATION_INSTANT` / `ACTIVATION_CHARGE` | `"instant"` / `"charge"` |
| `ACTIVATION_RECAST` / `ACTIVATION_TOGGLE` | `"recast"` / `"toggle"`（**器に載せるだけ。段階5以降**） |
| `TEAM_ENEMY` / `TEAM_ALLY` / `TEAM_SELF` / `TEAM_SOURCE` | `"enemy"` / `"ally"` / `"self"` / `"source"` |
| `MODE_SELECT` / `MODE_AREA` | `"select"` / `"area"`（`area` は段階4） |
| `SORT_NEAREST` / `SORT_FARTHEST` / `SORT_LOWEST_HP` / `SORT_HIGHEST_HP` / `SORT_ALL` | `"nearest"` / `"farthest"` / `"lowest_hp"` / `"highest_hp"` / `"all"` |
| `EFFECT_DAMAGE` / `EFFECT_HEAL` | `"damage"` / `"heal"` |
| `EFFECT_TYPES_KNOWN` | 上2つ ＋ `buff` `dot` `dispel` `cancel` `transform` `move` `summon` |
| `EFFECT_TYPES_IMPLEMENTED` | `[EFFECT_DAMAGE, EFFECT_HEAL]` |
| `ATTACK_TYPE_TRUE` | `"true"`（**確定ダメージ**） |
| `HOST_NONE` / `HOST_UNIT` / `HOST_POINT` / `HOST_BATTLE` / `HOST_SPAWN` | `"none"` / `"unit"` / `"point"` / `"battle"` / `"spawn"` |
| `TRIGGER_CAST` | `"cast"` |
| `SCALE_OF_USER` / `SCALE_OF_TARGET` / `SCALE_OF_SOURCE` | `"user"` / `"target"` / `"source"` |
| `SCALE_HP_CURRENT` / `SCALE_HP_LOST` / `SCALE_HP_RATIO` / `SCALE_HP_LOST_RATIO` | `"hp_current"` / `"hp_lost"` / `"hp_ratio"` / `"hp_lost_ratio"` |
| `SCALE_DISTANCE` | `"distance"` |

⚠ **`physical` / `magic` は `BattleUnit.ATTACK_TYPE_PHYSICAL` / `ATTACK_TYPE_MAGIC` を参照する。ここに書き直さないこと**（2本目の一覧を作ると、片方だけ直して事故る。`unit.gd` 92〜94行に同じ戒めがある）。

### 5-2. `static func scale_sources() -> Array`

**スケール変数表の名前を返す**（PLAN 5-5-2 の段階1ぶん）。

```
GameManager.get_stat_keys()   ← 10軸。ここに軸名を並べた2本目の配列を作らない
  ＋ hp_current / hp_lost / hp_ratio / hp_lost_ratio
  ＋ distance
```

⚠ **`height` / `height_ratio` / `elapsed_sec` / `stack:<id>` などは入れない**（段階3以降。2次元化待ちのものもある）。

### 5-3. `static func validate(skill_id: String, data: Dictionary) -> Array`

**戻り値は `{ "level": "error" or "warning", "message": String }` の配列。** 空配列＝問題なし。

⚠ **ここで `push_error` / `push_warning` を呼ばない。** 呼ぶのは `MasterDataLoader` 側（§8-3）。検証結果の件数を数えたいのと、呼ぶ場所を1箇所にするため。

`message` には**必ず `skill_id` を含める**（どのスキルが壊れているか分からないと直せない）。
例：`"skill_snipe: target.sort が不明: 'nearset'"`

### 5-4. 検証する項目

**`error` にするもの（＝赤。直すまで壊れている）**

| # | 条件 |
|---|---|
| E1 | `data` が Dictionary でない／空 |
| E2 | **`type` 欄が残っている**（旧形式の残骸。「移行し忘れ」を確実に捕まえる） |
| E3 | `name_key` / `user_character_id` が空文字 |
| E4 | `unlock_level` / `cooldown_sec` が数値でない |
| E5 | `activation` が `ACTIVATION_*` の4値以外 |
| E6 | `activation: charge` なのに `charge{}` が無い／`just_sec` `just_window_sec` `min_ratio` `just_bonus` が数値でない |
| E7 | `activation` が `charge` **以外**なのに `charge{}` がある |
| E8 | `target` が無い／Dictionary でない |
| E9 | `target.team` が4値以外 |
| E10 | **`team: self` に `mode` / `sort` / `count` が書かれている**（PLAN 21章の決定。`mode` を読むかが `team` で決まる逆流を作らない） |
| E11 | `team` が `self` 以外で `mode` が無い／`select` `area` 以外 |
| E12 | `mode: select` で `sort` が5値以外（**省略は許す＝`nearest`**） |
| E13 | `sort` が `all` 以外で `count` が**1以上の整数でない**（省略は許す＝1）。⚠ 上限は見ない（決定1-2） |
| E14 | `range` が書かれていて、数値でない／0以下 |
| E15 | `mode: area` で `radius` が無い／数値でない／0以下 |
| E16 | **`effects[].target` に `range` が書かれている**（射程はスキルの母集団を絞るもの。効果ごとに変えられる欄ではない・PLAN 5-4） |
| E17 | `effects` が無い／配列でない／空 |
| E18 | 効果に `type` が無い、または `EFFECT_TYPES_KNOWN` に無い |
| E19 | `type: damage` / `heal` で `multiplier` が数値でない |
| E20 | `type: damage` の `attack_type` が `physical` / `magic` / `true` 以外（**省略は許す＝`physical`**） |
| E21 | **`type: heal` に `attack_type` が書かれている**（PLAN 5-2。欄を作らないという決定を検証で守る） |
| E22 | `scale_from` が文字列でも配列でもない／配列の要素に `source` が無い／`source` が `scale_sources()` に無い／`of` が3値以外（省略は許す＝`user`）／`weight` が数値でない |
| **E27** | ⚠ **`type: damage` / `heal` に `scale_from` が無い**（決定1-5。**既定値を作らない**）。⚠ **`buff` などの他の型には要らない**（`stat` / `value` を持つため） |
| E23 | `chance` / `charge_scales` の型が違う（`chance`＝数値・`charge_scales`＝bool） |
| E24 | `trigger` の形が `cast` / `event:◯◯` / `delay:<数値>` / `charge_start` のどれでもない |
| E25 | `host` が5値以外 |
| E26 | スキル直下に**知らない欄**がある（許すのは `name_key` `user_character_id` `unlock_level` `cooldown_sec` `activation` `charge` `target` `effects` `phases`）。⚠ **typo を黙って既定値にしないための最後の砦** |

**`warning` にするもの（＝黄。書けるが段階1では動かない）**

| # | 条件 |
|---|---|
| W1 | `activation` が `recast` / `toggle`（段階5以降） |
| W2 | `mode: area`（段階4） |
| W3 | `team: source`（段階3） |
| W4 | 効果の `type` が `EFFECT_TYPES_IMPLEMENTED` 以外の既知の値（段階3以降） |
| W5 | `trigger` が `cast` 以外（段階2） |
| W6 | `host` が `none` 以外（段階3） |
| W7 | `phases` がある（段階5） |
| W8 | `chance` が 1.0 未満（段階1は必ず当たる扱い） |

⚠ **黙って既定値になるのが一番悪い**（PLAN 5-4）。**「読まない欄」を見つけたら必ず何か出す。**

⚠ **段階1の6件は、error も warning も1件も出ない**（§4の形が正しいことの確認になる）。

---

## 6. 作り直し：`scripts/systems/skill_resolver.gd`

**契約は変えない**（PLAN 7-3）。

> **1回ぶんの、確定したスキルデータを解く。時間を持たず、次のフレームを知らず、ノードを触らない。**

⚠ **入口が2つになる。** ここが段階1で分けておく理由（射程と投射物が同じ要求を出した・PLAN 4-4/4-5）。

### 6-1. 公開する関数（3本）

| 関数 | 役割 |
|---|---|
| `static func select_targets(target_def: Dictionary, user: BattleUnit, session: BattleSession) -> Array` | **入口1。対象を選ぶ。** 戻り値は **`unit_id`（String）の配列** |
| `static func resolve(skill_data: Dictionary, user: BattleUnit, session: BattleSession) -> Array` | **入口2。効果を当てる。** 戻り値は**今と同じ形**：`{ "unit_id": String, "amount": int, "is_heal": bool, "is_crit": bool }` の配列 |
| `static func fold_charge_ratio(skill_data: Dictionary, power_ratio: float) -> Dictionary` | チャージ倍率を `effects[].multiplier` に畳み込んだ**実効スキルデータ**を返す |

⚠ **`select_targets` が返すのは参照ではなく ID**（PLAN 4-4）。段階2で「発動時に対象を確定し、あとで発火する」形になるため、**今から ID で返す**。

⚠ **`resolve()` の戻り値の形は絶対に変えない。** `battle_controller.gd` 604〜608行がそのまま読む。

### 6-2. `select_targets()` の中身

1. **チームを相対で解く**（PLAN 4-2・**後から変えられない7つの1つ**）
   - `enemy` … `user.team` の反対（`user.team == BattleUnit.TEAM_PARTY` なら `TEAM_ENEMY`、でなければ `TEAM_PARTY`）
   - `ally` … `user.team` と同じ
   - `self` … **`[user.unit_id]` を返して終わり**（`mode` / `sort` / `count` / `range` を読まない）
   - `source` … 段階3。`push_warning` して**空配列**
   - ⚠ **`TEAM_ENEMY` / `TEAM_PARTY` の直書きをしない。** 現行の51・72・84行がやっている。**「誰でも撃てる」の前提が消える**
2. `session.get_alive_units(team)` で母集団を取る（**死者は入らない**）
3. **`range` で絞る**（PLAN 4-5）
   - 欄が無ければ**絞らない**（＝無制限）
   - あれば `abs(t.x - user.x) <= range` だけ残す
   - ⚠ **絞った結果が0体なら空配列。** 発動可否はこれを見る（§7）。**別々に距離を測らないこと**
4. `mode` で分岐
   - `select` … 5 へ
   - `area` … 段階4。`push_warning` して**空配列**
5. **並べ替えて `count` 件取る**

| `sort` | 並べ方 |
|---|---|
| `all` | 並べ替えない。**`count` を読まない。全員返す** |
| `nearest` | `abs(t.x - user.x)` の**昇順** |
| `farthest` | 同**降順** |
| `lowest_hp` | `float(hp) / float(max_hp)` の**昇順**（⚠ **割合で比べる**・PLAN 4-2） |
| `highest_hp` | 同**降順** |

⚠ **同率のときは元の配列の先頭を採る**（PLAN 4-2。並び順は `parties.json`）。
**Godot の `Array.sort_custom()` は安定ソートではない。** 元の位置を持たせて、**キーが同じときは元の位置が小さいほうを前にする**こと。これをやらないと、同じ距離の敵が2体いるときに**撃つたびに対象が入れ替わる**（無音でぶれる）。

6. `count` は `int(target_def.get("count", 1))`。⚠ **`MasterDataLoader` は数値を `float` で返す。`int()` 必須**（`CLAUDE.md` 3番）
7. **生存者が `count` に満たなければ、いる分だけ返す**（空振りにしない）

### 6-3. `resolve()` の中身

```
skill_data.effects を先頭から順に処理する
  trigger が "cast" 以外          → push_warning して【その効果だけ】飛ばす（段階2）
  host が "none" 以外             → push_warning して【その効果だけ】飛ばす（段階3）
  chance が 1.0 未満              → push_warning。段階1は必ず当てる
  効果の target = effect.target があればそれ、無ければ skill_data.target
  select_targets() で unit_id を取り、session から BattleUnit を引き直す
  type == "damage" → 対象ごとに §6-4
  type == "heal"   → 対象ごとに §6-5
  既知だが未実装   → push_warning して【その効果だけ】飛ばす
  未知             → push_error して【その効果だけ】飛ばす
```

⚠ **今の `resolve()` は未実装の型に当たると `return []` で全部捨てる**（39〜41行）。**配列の他の効果は適用すること**（PLAN 19章）。**壊れ方を小さくするのが段階1の狙いの1つ。**

⚠ **`unit_id` から `BattleUnit` を引き直す関数が要る。** `BattleSession` には無いので `SkillResolver` の中に private で持つ（`session.party_units + session.enemy_units` を走査。`battle_controller.gd` 358〜366行と同じ形）。**`BattleSession` に足さない**（セッションは器のまま保つ・PLAN 4-2）。

### 6-4. ダメージ ——**2段構え**（PLAN 11-0・⚠ **後から変えられない**）

> **不変条件：ダメージは1回だけ計算され、以降は「確定した数値」として持ち回される。式を2回評価しない。**

**【第1段】数値を確定させる。** 1つの Dictionary（以下 `ctx`）を作り、**順番に加工して**最後に金額を確定する。

| `ctx` のキー | 段階1での値 |
|---|---|
| `user_id` / `target_id` | 使用者と対象の `unit_id` |
| `attack_type` | `physical` / `magic` / `true` |
| `power` | §6-6 のスケール計算の結果（float） |
| `multiplier` | `float(effect.multiplier) * user.atk_multiplier` |
| `defense` | `attack_type == "true"` なら **0**、でなければ `target.get_defense(attack_type)` |
| `crit_dmg` | `user.get_stat(GameStateKeys.STAT_CRIT_DMG)` |
| `is_crit` | `BattleFormula.roll_crit(user.get_stat(GameStateKeys.STAT_CRIT_RATE))` |
| `amount` | 最後に確定する |

**加工の流れ（＝介入点）。段階1は全部素通しの空関数にする。**

```
_step_crit_override(ctx)   # 確定クリティカルの受け口（段階3）。is_crit を上書きできる位置
_step_reduction(ctx)       # 軽減% / 貫通% の受け口（段階3）。defense と multiplier を触れる位置
ctx["amount"] = BattleFormula.damage(...)   ← ここで確定。二度と再計算しない
```

⚠ **`_step_*` を「1本の固定式」にまとめないこと**（PLAN 11-0-1）。**割り込む位置が増えるたびに式を書き換えることになり、途中の値（「シールドが80吸収」）も取り出せなくなる。**
⚠ **`is_crit` を上書きできる位置は、`roll_crit()` の**あと**・`BattleFormula.damage()` の**前**。ここを外すと確定クリティカルが後から足せない**（PLAN 11-2）。

**確定の行は、今と1文字も変わらない結果になること。**

```gdscript
ctx["amount"] = BattleFormula.damage(
	int(ctx["power"]),
	int(ctx["defense"]),
	float(ctx["multiplier"]),
	int(ctx["crit_dmg"]),
	bool(ctx["is_crit"])
)
```

**【第2段】確定した数値を消費する。**

```
（シールドが吸う受け口 … 段階3。ここだけが amount を減らせる）
target.take_damage(int(ctx["amount"]))
（反射の受け口 … 段階3。ctx["amount"] を【読むだけ】。式を再評価しない）
results.append({ "unit_id": ..., "amount": int(ctx["amount"]), "is_heal": false, "is_crit": ... })
```

⚠ **`roll_crit()` は対象1体につき1回。** 今と同じ（`_apply_damage` が対象ごとに呼んでいる）。**乱数を振る回数と順番を変えないこと。** 変えると全体攻撃の数字が変わり、「挙動不変」の判定ができなくなる。

### 6-5. 回復

**今の1行をそのまま使う。**

```gdscript
var amount: int = int(floor(_scale_value_sum(effect, user, null) * multiplier))
```

- ⚠ **スケール元は `scale_from` から引く。既定値を持たない**（決定1-5）。`skills.json` 側に `"scale_from": "mag"` と書いてある
- ⚠ **会心を振らない。`atk_multiplier` を掛けない。介入点も通さない**（回復の介入点は段階3）
- ⚠ **`attack_type` を読まない。** 欄自体が存在しない（`skills.json` にも書かない・§4）
- `t.heal(amount)` して `{ "unit_id": ..., "amount": amount, "is_heal": true, "is_crit": false }` を積む
- **今と同じく、全対象に同じ数値を配る**（対象ごとに計算し直さない）

### 6-6. `scale_from` と変数表（PLAN 5-5）

```
power ＝ Σ( weight × 変数 )
```

**書き方は2通り。⚠ 「書かない」は無い**（決定1-5）。

| `scale_from` | 意味 |
|---|---|
| 文字列（`"atk"`） | `[{ "source": "atk", "of": "user", "weight": 1.0 }]` の省略形 |
| 配列 | `{ "source", "of", "weight" }` の合成 |
| **欄が無い** | ⚠ **エラー。**§6-7 |

**変数の値**

| `source` | 値 |
|---|---|
| 10軸（`GameManager.get_stat_keys()`） | `u.get_stat(source)` |
| `hp_current` | `u.hp` |
| `hp_lost` | `u.max_hp - u.hp` |
| `hp_ratio` | `float(u.hp) / float(u.max_hp)`（⚠ `max_hp` が0なら0.0） |
| `hp_lost_ratio` | `1.0 - hp_ratio` |
| `distance` | `abs(target.x - user.x)`。⚠ **`of` を読まない**（2者の間の値のため）。**対象が無い場合（回復・`self`）は 0.0** |

- `of` … `user` → 使用者、`target` → その対象、`source` → 段階3（`push_warning` して 0.0）
- 変数表に無い名前 → **`push_error` して 0.0**（ロード時検証でも捕まえる。二重に守る）
- ⚠ **評価は「発火時」**（PLAN 5-5-3）。段階1は cast と発火が同時なので**差は出ない**。`resolve()` の中で毎回読むこと。**`fold_charge_ratio()` の時点で読まない**

### 6-7. ⚠ 既定値を作らない（決定1-5）

**`damage` と `heal` は `scale_from` を必ず持つ。** ロード時検証（E27）が赤で弾くので、正しい `skills.json` なら**欄が無い状態で resolver に来ることはない。**

**それでも resolver 側の防御は残す**（PLAN 5-4「resolver 側の防御は残すが、主戦場はロード時」）。

| 状況 | resolver の振る舞い |
|---|---|
| `scale_from` が無い | **`push_error`** した上で、`damage` は `user.get_power(attack_type)`、`heal` は `mag` を使って**続行する** |

⚠ **フォールバックの値を 0 にしないこと。** 0 にすると `BattleFormula.damage()` が必ず 1 を返し、**「なぜか1ダメージ」**になって原因を追いにくい。**赤は出ているので「黙って既定値」にはならない。**

⚠ **このフォールバックを「既定値」と読み替えて `skills.json` の `scale_from` を省くのは禁止。** 省いた時点で赤が出る。

> **なぜ既定値を作らないか**：既定を「常に `atk`」にすると `skill_holy_ray`（`magic`）が `mag` を見なくなって数字が変わる。既定を「`attack_type` が指す軸」にすると、**`attack_type` が「防御の参照先だけ」に純化したはずなのに、攻撃側の意味がこっそり残る**（PLAN 5-2-1 が治した病気の出戻り）。**書かせるのが一番安い。**

### 6-8. `fold_charge_ratio()`

```
skill_data を duplicate(true) し、effects[] の各要素について
  charge_scales が false → 触らない
  それ以外              → multiplier = float(multiplier) * power_ratio
```

- ⚠ **`skills.json` に書ける欄しか触らない**（PLAN 7-3 の歯止め）。`multiplier` は書ける欄なので通る
- ⚠ **`multiplier` は1つのまま。** `scale_from` の `weight` には掛けない（PLAN 5-5-1）
- `power_ratio` が 1.0 のときも同じ経路を通してよい（分岐を増やさない）

---

## 7. 新規：`scripts/systems/skill_activation.gd`（**発動可否は1箇所**）

```gdscript
class_name SkillActivation
extends RefCounted

# 撃てるかを1箇所で答える。撃てない理由を返し、撃てるなら "" を返す。
# battle_controller に条件を散らさないこと（PLAN 12章）。
static func blocked_reason(
		user: BattleUnit, skill_id: String, skill_data: Dictionary, session: BattleSession
) -> String
```

**理由は定数で持つ**（文字列リテラルを散らさない）。

| 定数 | 値 | 判定 |
|---|---|---|
| `REASON_OK` | `""` | 撃てる |
| `REASON_NO_SESSION` | `"no_session"` | `session == null` |
| `REASON_NOT_ACTIVE` | `"not_active"` | `session.state != STATE_BATTLE_ACTIVE` |
| `REASON_USER_DEAD` | `"user_dead"` | `user == null` または `not user.is_alive()` |
| `REASON_SKILL_NOT_FOUND` | `"skill_not_found"` | `skill_data.is_empty()` |
| `REASON_COOLDOWN` | `"cooldown"` | `not user.is_skill_ready(skill_id)` |
| `REASON_NO_TARGET` | `"no_target"` | `SkillResolver.select_targets(skill_data.target, ...)` が**空**（＝射程・PLAN 4-5）。⚠ **決定1-6。対象がいなければ発動せず、CDも回らない**（§12-2） |

⚠ **判定の順番は上の表のとおり。** `no_target` を最後にするのは、`select_targets()` が一番重いため。
⚠ **この関数は状態を1つも変えない**（`CLAUDE.md` 6番）。CD を回すのは呼び出し側。
⚠ **将来ここに足すもの**：リソース（決定1-3で今回は作らない）／発動者（召喚が死んでいる）／遮蔽（決定1-4で今回は入れない）。**足すときは行を1本足すだけで済む形にしておくこと。**

⚠ **効果ごとの `target` 上書きは見ない。** 射程が絞るのは**スキルの母集団**（PLAN 4-5）。吸血の「自分に回復」で発動可否が変わるのは誤り。

---

## 8. `scripts/systems/master_data_loader.gd`（ロード時に全件検証）

⚠ **resolver 側だけの防御にしない。** 実戦で撃つまで壊れていることが分からない（PLAN 5-4）。

### 8-1. 末尾に追記する

```gdscript
static func get_all_skills() -> Dictionary
```
`_ensure_loaded()` を呼び、`_cache_skills.duplicate(true)` を返す。`get_all_research_nodes()` と同じ形。

### 8-2. 検証本体（**末尾に追記**）

```gdscript
static func _validate_all_skills() -> void
```

1. `_cache_skills` を全件回し、`SkillSchema.validate(skill_id, entry)` を呼ぶ
2. `level` が `error` なら `push_error`、`warning` なら `push_warning`。**接頭辞は `[MasterDataLoader] skills.json `**
3. §8-4 のクロス検証を行う
4. **最後に必ず1行 print する**

```gdscript
print("[MasterDataLoader] skills validated: %d entries, %d errors, %d warnings" % [
	_cache_skills.size(), error_count, warning_count
])
```

⚠ **この print が完了条件（§11-A）になる。** `_load_json()` は成功時に何も出さないので、**これが唯一の「読めた」の合図**。

### 8-3. `_ensure_loaded()` に1行足す

**66〜74行を、下の全文に差し替える。** 足すのは最終行の1本だけ。

```gdscript
static func _ensure_loaded() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	_cache_characters = _load_json(PATH_CHARACTERS)
	_cache_enemies = _load_json(PATH_ENEMIES)
	_cache_parties = _load_json(PATH_PARTIES)
	_cache_stages = _load_json(PATH_STAGES)
	_cache_skills = _load_json(PATH_SKILLS)
	# skills.json は自由度が高いぶん「書けるが壊れている」組み合わせが増えた。
	# resolver 側だけで防ぐと実戦で撃つまで気づけないので、読んだ直後に全件見る
	# （PLAN_SKILL_TEMPLATE.md 5-4）。characters.json も読み終わっているので、
	# 射程と attack_range のクロス検証もここでできる。
	_validate_all_skills()
```

⚠ **`_validate_all_skills()` は `_cache_characters` を読む。だから `_ensure_loaded()` の最終行でなければならない**（順番を変えないこと）。

⚠ **検証が走るのは「最初にマスターデータを引いたとき」であって、ゲームの起動直後ではない。** `GameManager._ready()` は `research.json` / `shop.json` / `recipes.json` の別キャッシュしか触らないため、`_ensure_loaded()` は**育成画面か戦闘画面に入って初めて動く**。**完了条件の文言もそう書く**（§11-A）。

### 8-4. クロス検証（**射程 × 攻撃射程**・PLAN 4-5）

`target.range` が書かれているスキルについてのみ：

```
cid = data.user_character_id
attack_range = float(_cache_characters[cid].attack_range)
range < attack_range なら push_error
```

理由：**スキル射程が通常攻撃の射程より短いと、足が止まって永久に撃てない**（移動AIは `attack_range` まで近づいたら止まる・`battle_controller.gd` 379/390行）。**無音で死ぬので、必ずロード時に赤で出す。**

⚠ **段階1では6件とも `range` を書かないので、この検証は1件も発火しない。** 受け口だけ作る。

---

## 9. `scenes/adventure/battle_controller.gd`（⚠ **912行。触るのは3箇所だけ**）

**触るのは3箇所だけ。** 他の行に触らないこと。

### 9-1. ゲージの出し分け（466行の `if not charge.is_empty():`）

`activation` を見る形に変える。**`charge{}` の有無で分岐しない**（PLAN 8章）。

`_build_skill_buttons()` のループ内、`var charge: Dictionary = {}` の直後に `activation` を読む行を足し、
ゲージ生成の条件を `if activation == SkillSchema.ACTIVATION_CHARGE:` に変える。

### 9-2. ボタンの接続（493〜498行）

```gdscript
if activation == SkillSchema.ACTIVATION_CHARGE:
	# チャージスキルは押した瞬間ではなく離した瞬間に発動する
	button.button_down.connect(_on_charge_button_down.bind(entry))
	button.button_up.connect(_on_charge_button_up.bind(entry))
else:
	button.pressed.connect(_on_skill_button_pressed.bind(unit, skill_id))
```

⚠ **条件の向きが今と逆になる。** 今は `if charge.is_empty():` が `pressed` 側。**入れ替え忘れると、全スキルが「押しっぱなしで発動」になる**（しかもエラーは出ない）。

⚠ **`entry` の `"charge"` は今までどおり入れておく。** `_is_just()` / `_charge_power_ratio()` / `_update_charge_gauge()` が読む。
⚠ **`activation` が `charge` なのに `charge{}` が空だったときは、`push_error` して `instant` として繋ぐ**（押しても離しても反応しないボタンを作らない）。ロード時検証（E6）でも捕まえる。

### 9-3. `_fire_skill()`（583〜614行）

**新しい形（設計役が全文を書く）。**

```gdscript
func _fire_skill(user: BattleUnit, skill_id: String, power_ratio: float) -> void:
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)

	# 撃てるかの判定は SkillActivation に集約してある。
	# ここに条件を書き足さないこと（PLAN_SKILL_TEMPLATE.md 12章）。
	# 撃てなかったらクールダウンは回さない。押せなかっただけ。
	var reason: String = SkillActivation.blocked_reason(user, skill_id, skill_data, _session)
	if reason != SkillActivation.REASON_OK:
		return

	# チャージ倍率は effects[].multiplier に畳み込んでから渡す。
	# こうすると SkillResolver 側は「倍率が違うスキル」を解くだけでよく、
	# チャージという概念を知らずに済む。
	var effective: Dictionary = SkillResolver.fold_charge_ratio(skill_data, power_ratio)

	var results: Array = SkillResolver.resolve(effective, user, _session)
	for r in results:
		if not (r is Dictionary):
			continue
		var target: BattleUnit = _find_unit_by_id(str(r.get("unit_id", "")))
		_pop_damage(target, int(r.get("amount", 0)), bool(r.get("is_crit", false)))

	# skills.json の cooldown_sec は base。haste を通してから渡す。
	user.start_cooldown(skill_id, BattleFormula.cooldown(
		float(skill_data.get("cooldown_sec", 0.0)),
		user.get_stat(GameStateKeys.STAT_HASTE)
	))
```

⚠ **`_fire_skill` の先頭にあった5つの判定（session null / state / user 生存 / `is_skill_ready` / `skill_data` 空）は全部消して `blocked_reason()` に移す。** 両方に残すと二重管理になる。

⚠ **`_on_charge_button_down()`（621〜632行）の判定は残す。** あれは「**チャージを始めてよいか**」であって発動可否ではない。⚠ ただし**中身を書き換えない**こと（触るのは §9-1〜9-3 の3箇所だけ）。

### 9-4. ボタンの活性条件は**変えない**

`_update_skill_buttons()`（501〜534行）は**1行も触らない。**

PLAN 4-5 の「射程外のボタンを暗くする」は、**`range` に数値が入ってから**（座標定数とセットで後決め）。段階1で毎フレーム `select_targets()` を回す理由が無い。

---

## 10. `docs/00_concept/DATA_SCHEMA.md` 3-1 の差し替え

**389〜404行の「スキル定義（マスターデータ・参照専用）」を、下の全文に差し替える。**

~~~
### スキル定義（マスターデータ・参照専用）

**器の決定台帳は `docs/01_plan/PLAN_SKILL_TEMPLATE.md`。ここには複製しない。**
下は「セーブとの関係」を見るための形だけ。

```json
{
  "skill_id": {
    "name_key": "string",
    "user_character_id": "string",
    "unlock_level": 1,
    "cooldown_sec": 8.0,

    "activation": "instant | charge | recast | toggle",
    "charge": { "just_sec": 1.0, "just_window_sec": 0.15, "min_ratio": 0.5, "just_bonus": 1.3 },

    "target": {
      "team": "enemy | ally | self | source",
      "mode": "select | area",
      "sort": "nearest | farthest | lowest_hp | highest_hp | all",
      "count": 1,
      "range": 500.0
    },
    "effects": [
      { "type": "damage", "multiplier": 2.0, "attack_type": "physical | magic | true", "scale_from": "atk" }
    ]
  }
}
```

- **`type`（旧欄）は廃止した。** `single` / `aoe` / `heal` は `target` と `effects[]` に割れた
- **ネストは3階層まで**（skill → phase → effect）。`phases` は省略できる（省略＝1段）
- `activation: charge` のときだけ `charge{}` を読む。**`charge` 欄の有無で分岐しない**
- `range` は**対象の母集団を絞る**。絞った結果が0体なら発動しない（発動可否と一本化）
- `attack_type` は「**どの防御で受けるか**」だけを決める。攻撃側の参照元は `scale_from`
- ⚠ **`scale_from` は `damage` / `heal` で必須。既定値は無い**（書かないとロード時に赤）。文字列（`"atk"`）は `[{ "source": "atk", "of": "user", "weight": 1.0 }]` の省略形
- **`heal` に `attack_type` の欄は作らない**（回復が攻撃力依存だった事故の再発防止）
- **`unlock_level`**：そのスキルが候補に出るレベル。**`int()` で包んで読む**（JSONから `1.0` で来る）。現在は6件とも `1`
- ⚠ **`MasterDataLoader` が返す数値は `float`。`count` は `int()` 必須**
- **セーブが持つのはスキルIDだけ**（4-3）。**欄の名前を変えてもセーブは壊れない。改名できないのはスキルID**
- 起動後に最初にマスターデータを引いた時点で**全件検証**が走る（`MasterDataLoader._validate_all_skills()`）
~~~

⚠ **ダメージ計算の式（402行の `max(1, 攻撃力 - 防御力)`）も古い**（実際は除算・`battle_formula.gd` 62〜67行）。**このタスクでは直さない。§13 の宿題に送る。**

---

## 11. 完了条件

⚠ **セーブファイルの章は無い。** このタスクはセーブに1バイトも触らない（セーブが持つのはスキルIDだけ・PLAN 18章）。**「`save_slot_0.json` を開く」項目を作らないこと。**

### 11-A. ログ（Godotの出力パネル）

**確認するのは、育成画面か戦闘画面に入ったあと。** 起動直後には出ない（§8-3）。

- [ ] A-1. `[MasterDataLoader] skills validated: 6 entries, 0 errors, 0 warnings` が**1回だけ**出る
- [ ] A-2. 出力パネルに**赤（`push_error`）が1件も無い**
- [ ] A-3. 出力パネルに**黄（`push_warning`）がスキル関係で1件も無い**

⚠ **A-1 の数字が `6 entries` でなければ `skills.json` の構文が壊れている**（JSONのパースに失敗すると空で返るため）。

### 11-B. 画面（実機で操作する）

⚠ **先に「変更前の数字」を控えること。** 控えずに差し替えると、比較対象が無くなって完了判定ができない。

**変更前（今のコード）でやる準備**

1. 戦闘に入り、`F3` でデバッグパネルを出す
2. `S`（CDリセット）を押しながら、**6つのスキルを1つずつ撃つ**
3. 頭上に出た数値を控える。⚠ **会心は色とフォントが違う。白い数字（非会心）だけを控える**
4. `skill_healing_light` は味方のHPが減っていないと回復量が見えない。`J`（味方全員に物理の一撃）で削ってから撃つ
5. `skill_wide_sweep` は**ジャストで1回・ためずに離して1回**の2通りを控える

**差し替え後にやること**

- [ ] B-1. `skill_power_slash` … **最も近い敵1体**にだけ数字が出て、値が変更前と同じ
- [ ] B-2. `skill_snipe` … 同上
- [ ] B-3. `skill_arrow_rain` … **敵全員**に数字が出て、値が変更前と同じ
- [ ] B-4. `skill_holy_ray` … 敵全員。**値が変更前と同じ**（⚠ **魔法。ここがズレたら既定のスケール元を間違えている**・§6-7）
- [ ] B-5. `skill_wide_sweep` … 敵全員。**ジャスト時とためない時の両方**が変更前と同じ
- [ ] B-6. `skill_wide_sweep` のボタンが**押しっぱなしでためられ、離すと発動する**（ゲージが伸びて JUST が出る）
- [ ] B-7. **他の5つは押した瞬間に発動する**（ためられない）
- [ ] B-8. `skill_healing_light` … **味方全員**（使用者を含む）が回復し、量が変更前と同じ
- [ ] B-9. 6つとも、撃ったあとにボタンが灰色になり、残り秒数が減っていく
- [ ] B-10. 敵を全滅させてウェーブが進み、勝利まで到達できる

### 11-C. 将来コードを変えたときに見る項目（⚠ **人間の確認項目ではない**）

**UIから到達できない。** ここは「後でこの器を触るときに、壊れていないか確かめる方法」の記録。

- C-1. `skills.json` の1件の `sort` を `nearset` と書き間違えると、赤が1件出て件数が `1 errors` になる
- C-2. `type: "single"` を書き戻すと、E2（旧欄の残骸）で赤が出る
- C-2b. **`scale_from` を1件から消すと、E27 で赤が1件出る**（決定1-5。既定値で黙って動かない）
- C-3. `effects[]` に `{"type": "buff", ...}` を足すと、**黄が1件出て、同じ配列の `damage` は今までどおり当たる**（今のコードは全部捨てる）
- C-4. `target.range` に `100.0` を入れると、剣士の `attack_range` より短いため赤が出る（§8-4）
- C-5. `sort: lowest_hp` / `farthest` / `highest_hp` は、使うスキルが無いので**この回では画面で確認できない**

---

## 12. ⚠ PLAN とのズレ（**勝手に直していない。人間が判断すること**）

### 12-1. `scale_from` の省略（PLAN 5-2 の表・**決定1-5 で解決済み**）

PLAN 5-2 の表は `scale_from` の省略時を **「damage＝`atk` / heal＝`mag`」** と書いている。

**これをそのまま実装すると `skill_holy_ray`（`attack_type: magic`）が `mag` ではなく `atk` を見るようになり、数字が変わる。** PLAN 17章の移行表は「6件とも `scale_from` を書かない」「この6件の付け替え自体は挙動を変えない」と書いているので、**2つの記述が食い違っていた。**

> **人間の決定（1-5）で、この食い違いは消えた。`scale_from` を必須にし、既定値そのものを作らない。**
> 6件には**今そのスキルが見ている軸**（`atk` / `atk` / `atk` / `atk` / `mag` / `mag`）を明示的に書く。**挙動は変わらない。**

⚠ **残るのは PLAN 側の表記だけ。** PLAN 5-2 の表の「省略時」の列と、17章の「6件とも書かない」の1文が、**実装と食い違ったまま残る。**

> **PLAN を直すかどうかは人間が決める**（合意なしに PLAN 本文を書き換えない）。直す場合の文言案：
> - 5-2 の表：`scale_from` の省略時 → **「省略不可。`damage` / `heal` は必ず書く」**
> - 17章：「**今の6件は書かない**（既定：damage＝`atk` / heal＝`mag`）」 → 「**今の6件にも書く**（`atk` ×4 / `mag` ×2）。**移行表の他の列は変わらない**」

### 12-2. 対象0体のときのクールダウン（**意図した挙動差**・決定1-6）

**今のコードは、対象が0体でもクールダウンを開始する**（`battle_controller.gd` 610〜614行。**ただし593行のコメントは「開始されない」と書いてある**＝コメントと実装がズレている）。

**人間の決定（1-6）により、`REASON_NO_TARGET` で弾いた場合は CD を回さない**（PLAN 12-1「撃てなかったらCDは回らない」）。**押せなかっただけ、という扱いにする。**

**この差が画面に出る条件**：`range` を書いていない段階1では、**敵が0体のときだけ**。敵が全滅した瞬間に `_enter_wave_clear()` が状態を変えてボタンが灰色になるため、**その間の1フレームにクリックが刺さらないと再現しない。**

> **実質到達不能だが、挙動差はゼロではない。** 「1件も変わらない」の**唯一の例外**として、ここに明記しておく。

⚠ **`range` に数値が入る回（段階1より後）から、この挙動が本番になる。** 射程外で押しても何も起きずCDだけ減る、が起きなくなる。

### 12-3. 通常攻撃は今回触らない（決定1-7）

**「対象がいなければ発動しない」は通常攻撃でも同じ**だが、**そこは既にそうなっている。**

| | 現状 |
|---|---|
| 対象がいない／死んでいる | `_step_unit()` が `return`（`battle_controller.gd` 373〜377行）。**攻撃タイマーも進まない** |
| 射程外 | 攻撃せず**近づく**（379・390〜391行） |
| 近距離と遠距離の区別 | ✅ **`unit.attack_range`（マスターの値）で既にできている**（`unit.gd` 48・90行） |

**よって今回は1行も触らない。** 「キャラによって通常攻撃を変える」（`effects[]` に乗せる・攻撃の合図を出す）は **PLAN 21章の担当外**で、接続点が3つ揃ってから判断する（§13）。

### 12-3. `skills.json` のインデント

現行ファイルは**エントリ行（2行目など）だけ半角2スペース**で、中身はタブという混在。**§4の差し替えで全部タブに揃える。**

---

## 13. このタスクでやらないこと・宿題に送るもの

**やらないこと**（PLAN 19章の段階2以降）

- `trigger`（`delay` / `event:◯◯`）・実行中のスキル層・待ち行列 … **段階2**
- 状態の器・`buff` / `dot`・購読・条件・回復/状態付与/死亡の介入点 … **段階3**
- `mode: area` … 段階4／`phases[]` / `recast` … 段階5／`spawn` … 段階6
- スキル18個の中身・パッシブ・ルーン・戦闘の2次元化・バランス調整
- ⚠ **通常攻撃を `effects[]` に乗せること**（決定1-7・§12-3）。**PLAN 21章の担当外。** 今は `attack_range` による近距離／遠距離の区別だけでよい。接続点は既に2つある（**攻撃射程の数値**・**攻撃した合図**）。**3つ目が出たら乗せる判断をする**

**宿題に送る**（`PROJECT_STATUS.md` に足す）

- `DATA_SCHEMA.md` 3-1 の**ダメージ計算式が古い**（`max(1, 攻撃力 - 防御力)` と書いてあるが、実際は除算）
- `battle_controller.gd` 593行の**コメントが実装とズレている**（「対象なしでCDだけ消費される」を避けたと書いてあるが、実際は消費していた）。§9-3 の差し替えで実装側が追いつくため、**コメントも直す**
- **`sort` の `farthest` / `lowest_hp` / `highest_hp` は、使うスキルが無いので実機で1度も通っていない**（C-5）

---

## 14. 事故りやすい箇所（**名指し**）

1. ⚠ **編集したら `grep` で当たったことを確認する。** 「戦闘だけ反映されない」で1タスク溶かした事故がある（`CLAUDE.md` 2番）
   - `grep -n "fold_charge_ratio" scenes/adventure/battle_controller.gd` … **1件以上**
   - `grep -n "SkillActivation" scenes/adventure/battle_controller.gd` … **1件以上**
   - `grep -n "_validate_all_skills" scripts/systems/master_data_loader.gd` … **2件**（定義と呼び出し）
   - `grep -n "\"type\"" resources/balance/master/skills.json` … **6件**（`effects[]` の中だけ。スキル直下に残っていない）
   - `grep -c "scale_from" resources/balance/master/skills.json` … **6件**（決定1-5。1件でも欠けると赤が出る）
   - `grep -n "TEAM_ENEMY\|TEAM_PARTY" scripts/systems/skill_resolver.gd` … **`user.team` から導く形になっていること**（定数の直書きが残っていない）
2. ⚠ **`int()` の包み忘れ。** ネストが3階層になったぶん増える。**`count` は `int()` 必須**（`multiplier` / `value` / `range` は `float` のままでよい）
3. ⚠ **インデントはタブ。** `.gd` も `.json` も
4. ⚠ **状態を変える前に全部の判定を終える。** `blocked_reason()` が空を返してから初めて `resolve()` と `start_cooldown()` に進む
5. ⚠ **`resolve()` の戻り値の形を変えない**（`battle_controller.gd` 604〜608行が読む）
6. ⚠ **乱数を振る回数と順番を変えない**（対象1体につき `roll_crit()` 1回）
7. ⚠ **並べ替えは安定にする**（同率は元の配列の先頭。§6-2）
8. ⚠ **Godotを起動できない。「動きました」と書かない。** §11-B は人間が確認する
9. ⚠ **1ファイルへの書き込みが2回失敗したら中止して報告する。** 1つの症状に試す方法は2つまで

---

## 15. コミットメッセージ

```
feat(skill): スキルの器を4軸に付け替え（段階1・対象選択と発動可否と介入点の受け口）
```

⚠ **動作確認（§11-B）が終わってからコミットする。**
