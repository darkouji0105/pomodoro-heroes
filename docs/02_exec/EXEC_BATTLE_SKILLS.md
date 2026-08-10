# 【実行指示書】戦闘画面 フェーズ2（スキルとボス）

`PLAN_BATTLE_SCREEN.md` のフェーズ2に対応する第3層。フェーズ1（`EXEC_BATTLE_CORE.md`）が完了し、コミット済みであることが前提。

**本書はパーティを3人・スキル6つに変更した版。** 旧版（2人・3スキル）は破棄する。

---

## §0 作業の進め方（厳守）

| 禁止 | 理由 |
|---|---|
| `edit_file` | このプロジェクトでは動作しない |
| `create_file` に150行を超える本文 | トークン上限で失敗する。`cat >>` で分割する |
| `cat >` での上書き | 既存の内容が消える |
| `sed` / `awk` | シェル依存で動作が保証されない |
| 補助スクリプト（`.py` 等）の作成 | 誤字修正のために作り始めて止まらなくなる |
| 書き終わったあとの読み返し・誤字修正 | 同上。誤字は人間が直す |
| `.tres` ファイルの編集 | 人間がInspectorで行う |
| `autoload/` 配下の編集 | 人間が行う |
| `project.godot` の変更 | 人間が行う |

**例外**：既存ファイルに追記した直後だけ `read` で開き、編集前の内容が残っていること・重複行がないことを確認すること。破壊チェックなので必ず行う。

**追記の前に重複を確認すること。**

`class_name` が認識されないエラーが出たら、型指定を `Node` に落として `call()` で回避しないこと。Godotエディタの再起動で解消する。

**今回は既存ファイルの途中を書き換える作業が含まれる。** 該当箇所は §1・§2・§6 に明示してある。それ以外の既存コードには触らないこと。

---

## 前提・参照ドキュメント

- `AGENTS.md`
- `PLAN_BATTLE_SCREEN.md`（第2層。本書はそのフェーズ2）
- `EXEC_BATTLE_CORE.md`（フェーズ1。実装済み）
- `DATA_SCHEMA.md` 3-1「スキル定義」

### 既存の実装状況（実コードで確認済みの事実）

| 事実 | 場所 |
|---|---|
| `BattleUnit` に `skills` フィールドは**存在しない**（フェーズ1で意図的に省いた） | `scripts/systems/unit.gd` |
| `BattleUnit` は `take_damage()` / `heal()` / `is_alive()` を持つ | 同上 |
| `_spawn_current_wave_enemies()` は `enemy_type_id` / `count` / `is_boss` のみ読む。**`stat_overrides` は未実装** | `scenes/adventure/battle_controller.gd` |
| `_compute_damage(attacker, target)` が `max(1, floor(atk * atk_multiplier) - def)` を返す | 同上 |
| `_pop_damage(target, amount)` がダメージ数値を表示する | 同上 |
| `_views_by_unit_id` に `unit_id → UnitView` の対応がある | 同上 |
| 味方の初期X座標は `_party_start_x(index)` = `200 + index * 100` | 同上 |
| `BattleSession.get_alive_units(team)` で生存者配列が取れる | `scripts/systems/battle_session.gd` |
| `UnitView` は `is_boss` のとき紫（`COLOR_BOSS`）で表示する。**色分けは実装済み** | `scenes/adventure/unit_view.gd` |
| `UnitView.pop_damage(amount)` は親コンテナにラベルを乗せる | 同上 |
| `MasterDataLoader` は `get_character` / `get_enemy` / `get_party` / `get_stage` を持つ | `scripts/systems/master_data_loader.gd` |
| `BattleDebugPanel` は F3 で表示切替、1〜4 で速度、K/L/J/V/B の操作を持つ | `scenes/adventure/battle_debug_panel.gd` |
| `battle.tscn` の `HUD` 配下には `WaveLabel` のみ | `scenes/adventure/battle.tscn` |

---

## 今回のタスク

### やること

1. 3人目のキャラクター（僧侶）の追加
2. `skills.json` の追加と `MasterDataLoader.get_skill()` の追加
3. `BattleUnit` に `skill_ids` / `skill_cooldowns` とクールダウン処理を追加
4. `SkillResolver`（スキル効果の適用を集約する新規クラス）
5. スキルボタンUI（6つ・クールダウン表示・`disabled` 制御）
6. `stat_overrides` の適用（フェーズ1の積み残し）
7. ボスの見た目の強調
8. デバッグパネルにクールダウンリセットを追加

### やらないこと

- `buff` / `dot` / `projectile` の3タイプ（`PLAN` で対象外と決定済み。`SkillResolver` に分岐だけ用意して `push_warning` を出す）
- スキルの習得・選択（育成画面のスコープ。今回は固定）
- スキルのアニメーション・エフェクト
- スタミナ消費・冒険選択画面
- **敵の数値の調整**（味方が1人増えるため戦闘が短くなる可能性があるが、遊んでから人間が決める）

### 人間が対応済み（触らないこと）

- `ja.csv` への翻訳キー追記（§8に一覧を出すが、追記するのは人間）
- `resources/balance/` 配下の `.tres` 全般
- `base_screen.gd`

---

## §1 マスターデータ

### §1-1 `characters.json` に僧侶を追加し、全員に `skills` を足す

**既存ファイルを書き換える。** 既存の `hp` / `atk` などの値は変えないこと。追加するのは各キャラの `skills` 配列と、`char_priest` のブロック全体。

書き換えたあと `read` で開き、既存の値が消えていないことを必ず確認すること。

```json
{
  "char_swordsman": {
    "name_key": "ui_battle_char_swordsman",
    "hp": 120, "atk": 18, "def": 6, "spd": 60,
    "attack_range": 60, "attack_interval_sec": 1.2,
    "skills": ["skill_power_slash", "skill_wide_sweep"]
  },
  "char_archer": {
    "name_key": "ui_battle_char_archer",
    "hp": 80, "atk": 14, "def": 3, "spd": 70,
    "attack_range": 300, "attack_interval_sec": 1.5,
    "skills": ["skill_snipe", "skill_arrow_rain"]
  },
  "char_priest": {
    "name_key": "ui_battle_char_priest",
    "hp": 70, "atk": 10, "def": 3, "spd": 65,
    "attack_range": 250, "attack_interval_sec": 1.6,
    "skills": ["skill_healing_light", "skill_holy_ray"]
  }
}
```

### §1-2 `parties.json` を3人に変更する

```json
{
  "party_default": { "members": ["char_swordsman", "char_archer", "char_priest"] }
}
```

**並び順を変えないこと。** 味方の初期X座標は配列の順番で決まる（剣士200・弓兵300・僧侶400）。前衛が最も左から出る形になっている。

### §1-3 `skills.json`（新規）

出力先：`res://resources/balance/master/skills.json`

**以下をそのまま書くこと。** 値を変えたりスキルを足したりしないこと。

```json
{
  "skill_power_slash": {
    "name_key": "ui_battle_skill_power_slash",
    "type": "single",
    "multiplier": 2.0,
    "cooldown_sec": 6.0,
    "user_character_id": "char_swordsman"
  },
  "skill_wide_sweep": {
    "name_key": "ui_battle_skill_wide_sweep",
    "type": "aoe",
    "multiplier": 0.9,
    "cooldown_sec": 8.0,
    "user_character_id": "char_swordsman"
  },
  "skill_snipe": {
    "name_key": "ui_battle_skill_snipe",
    "type": "single",
    "multiplier": 2.6,
    "cooldown_sec": 11.0,
    "user_character_id": "char_archer"
  },
  "skill_arrow_rain": {
    "name_key": "ui_battle_skill_arrow_rain",
    "type": "aoe",
    "multiplier": 1.2,
    "cooldown_sec": 9.0,
    "user_character_id": "char_archer"
  },
  "skill_healing_light": {
    "name_key": "ui_battle_skill_healing_light",
    "type": "heal",
    "multiplier": 1.0,
    "cooldown_sec": 8.0,
    "user_character_id": "char_priest"
  },
  "skill_holy_ray": {
    "name_key": "ui_battle_skill_holy_ray",
    "type": "aoe",
    "multiplier": 1.0,
    "cooldown_sec": 12.0,
    "user_character_id": "char_priest"
  }
}
```

**スキルは6つ。ボタンも6つ並ぶ。** `PLAN` の完了条件にある「スキルボタンが味方の数だけ表示され」は本書で上書きする。

`user_character_id` は誰のスキルかを人間が読むための情報であり、**実装では使わない。** 所持関係は `characters.json` の `skills` 配列が正。

---

## §2 `MasterDataLoader.get_skill()`

**既存ファイルの末尾に追記する。** 既存の関数を書き換えないこと。

- `get_skill(skill_id: String) -> Dictionary` を追加する
- 読み込み対象に `skills.json` を追加する。キャッシュの持ち方・エラー時の挙動は既存4ファイルと完全に同じにすること
- IDが無ければ `push_error` を出して空の `Dictionary` を返す
- 返す値は `duplicate(true)` する

---

## §3 `BattleUnit` へのスキル追加

**既存ファイルの末尾に追記する。** 既存のフィールド・メソッドを書き換えないこと。

### 追加するフィールド

```gdscript
# 所持スキルID（順序を保つため配列で持つ。ボタンの並び順になる）
var skill_ids: Array = []
# skill_id -> cooldown_remaining(float)
var skill_cooldowns: Dictionary = {}
```

`DATA_SCHEMA.md` は `skills: [{skill_id, cooldown_remaining}]` という配列形式だが、**配列だと発動のたびにIDで線形探索することになる。** 順序（ボタンの並び）と残り時間を分けて持つほうが素直なので、この形にする。

### 追加するメソッド

| メソッド | 内容 |
|---|---|
| `tick_cooldowns(delta: float) -> void` | 全スキルの残り時間を `delta` 減らす。**0未満にしない** |
| `is_skill_ready(skill_id: String) -> bool` | 残り時間が0以下 |
| `start_cooldown(skill_id: String, sec: float) -> void` | 残り時間をセット |
| `get_cooldown(skill_id: String) -> float` | 残り時間 |

`skill_ids` に無いIDを渡された場合、`is_skill_ready` は `false` を返すこと（`true` を返すと存在しないスキルが撃てる）。

### 味方生成時の設定

`BattleController._init_party_units()` で、`characters.json` の `skills` 配列を `skill_ids` に入れ、`skill_cooldowns` を全て `0.0` で初期化すること。**敵には設定しない**（敵はスキルを使わない）。

---

## §4 `SkillResolver`

出力先：`res://scripts/systems/skill_resolver.gd`

```gdscript
class_name SkillResolver
extends RefCounted
```

**スキル効果の計算はすべてここに置く。** `BattleUnit` にも `BattleController` にも計算式を書かないこと（`Unit` を純粋なデータに保つため。`PLAN` §7）。

Autoloadにしないこと。静的関数として実装する。

### 公開関数

```gdscript
static func resolve(skill_data: Dictionary, user: BattleUnit, session: BattleSession) -> Array
```

**戻り値は「誰にいくつ適用したか」の配列。** 各要素は次の形の `Dictionary`。

```
{ "unit_id": String, "amount": int, "is_heal": bool }
```

`BattleController` はこれを受け取って数値表示に使う。**`SkillResolver` は表示に一切関与しない。**

### タイプごとの処理

| type | 対象 | 計算 |
|---|---|---|
| `single` | 敵の生存者のうち `user` に最も `x` が近い1体 | `max(1, floor(user.atk * multiplier) - target.def)` を `take_damage` |
| `aoe` | 敵の生存者すべて | 同上を各対象に個別計算して `take_damage` |
| `heal` | 味方の生存者すべて | `floor(user.atk * multiplier)` を `heal`。`is_heal: true` |
| `buff` / `dot` / `projectile` | — | 何もせず `push_warning("[SkillResolver] 未実装のスキルタイプ: " + type)` を出し、空配列を返す |

- **ダメージは通常攻撃と同じく `max(1, ...)` を通すこと。** 防御力が高い敵に撃って0や負になると、通常攻撃より弱くなる
- **回復は `max_hp` を超えない**（`BattleUnit.heal()` が担保しているので必ず経由すること）
- **死亡した味方は回復対象に含めない。** 蘇生は仕様にない
- **回復は使用者自身も対象に含む**（対象は「味方の生存者すべて」であり、僧侶も味方である）
- 対象が1体もいない場合は空配列を返す。エラーにしないこと

---

## §5 スキルボタンUI

### §5-1 シーンへのノード追加

`battle.tscn` の `HUD`（CanvasLayer）配下に `SkillButtons`（`HBoxContainer`）を追加する。画面下部に配置すること。

**ボタン自体はコードで生成する。** スキルの数が変われば増減するため、シーンに固定で置かないこと。

**6つ並ぶことを前提に幅を確保すること。**

### §5-2 ボタンの生成

`BattleController._ready()` の中で、味方ユニットの生成後に行う。

- 味方ユニットを順に走査し、その `skill_ids` を順に走査して、スキル1つにつきボタンを1つ作る（剣士2 → 弓兵2 → 僧侶2 の順に6つ並ぶ）
- ボタンは `res://scenes/ui/components/primary_button.tscn` をインスタンス化する
- `label_key` は使わない（テキストにクールダウン残り時間を混ぜるため）。`text` を直接セットする
- どのユニットのどのスキルかを保持し、押されたときに引けるようにする

### §5-3 表示内容

```
発動可能：       tr(name_key)
クールダウン中： tr(name_key) + " (3.2)"
```

数値部分は `tr()` を通さない（`AGENTS.md`）。

### §5-4 状態の更新

`_process` の中で毎フレーム更新する。以下のいずれかのとき `disabled = true` にすること。

- クールダウンが残っている
- 使用者が死亡している
- `session.state` が `STATE_BATTLE_ACTIVE` でない

**3つ目を忘れないこと。** これが無いと、結果画面が出たあとや、ウェーブ間の0.5秒の待機中にもスキルが撃てる。撃った先の敵がまだ存在しないので、何も起きないまま**クールダウンだけが消費される。** 見た目には何も起こらないので、報告されにくいバグになる。

### §5-5 発動処理

ボタンが押されたとき、`BattleController` が次の順で行う。

```
1. session.state が STATE_BATTLE_ACTIVE でなければ何もしない
2. 使用者が死亡していれば何もしない
3. is_skill_ready() が false なら何もしない
4. MasterDataLoader.get_skill(skill_id) で定義を引く
5. SkillResolver.resolve(...) を呼ぶ
6. 戻り値の配列を回して _pop_damage() で数値を表示する
7. start_cooldown(skill_id, cooldown_sec) を呼ぶ
```

**クールダウンの開始は必ず最後に行うこと。** 先に開始してから `resolve` で対象なしと分かると、何も起きていないのにクールダウンだけ入る。

**勝敗判定はここで行わないこと。** スキルで敵が全滅した場合も、次の `_process` が通常どおり `is_wave_cleared()` を見て進める。ここで判定を足すと勝敗確定の経路が2本になり、フェーズ1で潰した報酬の二重適用が別ルートから復活する。

### §5-6 クールダウンの進行

`BattleController._process()` の中で、`STATE_BATTLE_ACTIVE` のときのみ全味方の `tick_cooldowns(delta)` を呼ぶ。

**ウェーブ間でクールダウンをリセットしないこと**（連戦。完了条件で検証する）。`_reset_party_positions()` に手を入れないこと。

**「もう一度」（リトライ）では味方ユニットごと作り直されるため、クールダウンも初期化される。** これは仕様。

---

## §6 `stat_overrides` とボス表示

### §6-1 `stat_overrides` の適用（フェーズ1の積み残し）

`_spawn_current_wave_enemies()` は現在 `stat_overrides` を読んでいない。**追加すること。**

- ウェーブデータの各エントリに `stat_overrides` があれば、`enemies.json` の基本値をそのキーで上書きする
- 対応するキーは `hp` / `atk` / `def` / `spd` / `attack_range` / `attack_interval_sec`
- `hp` を上書きした場合、`max_hp` も同じ値になること（HPバーが最初から満タンでなくなる）
- `stat_overrides` が無い場合は従来どおり基本値を使う

`stages.json` のウェーブ5のボスのエントリに、動作確認用として `"stat_overrides": { "atk": 26 }` を追加すること。基本値は `atk 20` なので、上書きが効いていれば26になる。

### §6-2 ボスの見た目

色分け（紫）はフェーズ1で実装済み。**追加するのは大きさだけ。**

`UnitView.setup()` で `unit.is_boss` が `true` のとき、`Body` と `HpBar` の幅・高さを1.5倍にすること。色の定数は既存のものをそのまま使う。

**新しい色を足さないこと。** 色の直書きはフェーズ1で認めた例外の範囲を超えない。

---

## §7 デバッグパネルへの追加

`battle_debug_panel.gd` と `battle_controller.gd` に以下を足す。

| キー | 動作 |
|---|---|
| `S` | 全味方のスキルクールダウンを0にする |

`BattleController.debug_reset_cooldowns()` を追加し、パネルの `_unhandled_input` に `KEY_S` の分岐と、ヘルプ表示の行を足すこと。

**既存のキー割り当てを変えないこと。**

クールダウン12秒の `skill_holy_ray` を繰り返し試すのに必要になる。

---

## §8 翻訳キー（人間が `ja.csv` に追記する）

**実装役はこのファイルを編集しないこと。**

| キー | 日本語 |
|---|---|
| `ui_battle_char_priest` | 僧侶 |
| `ui_battle_skill_power_slash` | 強撃 |
| `ui_battle_skill_wide_sweep` | 横薙ぎ |
| `ui_battle_skill_snipe` | 狙撃 |
| `ui_battle_skill_arrow_rain` | 矢の雨 |
| `ui_battle_skill_healing_light` | 癒しの光 |
| `ui_battle_skill_holy_ray` | 聖光 |

---

## 動作確認手順（完了条件）

**この17項目を、項目番号と文言をそのまま IMPL_LOG に転記すること。** 要約したり項目を作り直したりしないこと。

**書き方**：`[ ] 項目N：（EXECの文言をそのまま）` を先に書き、**改行してから**検証結果を書くこと。EXECの文言と検証結果を1つの文にまとめないこと。

検証には `BattleDebugPanel` を使ってよい（F3で表示、1〜4で速度、K/L/J/V/B/S）。「何をしたら何と表示されたか」を書くこと。

実際に動かせなかった項目は `[x]` を付けず、「実機未検証」と正直に書いてよい。埋めなくてよい。

1. [ ] 味方が3体（剣士・弓兵・僧侶）表示され、左から剣士・弓兵・僧侶の順に並んでいる
2. [ ] スキルボタンが6つ表示され、左から「強撃」「横薙ぎ」「狙撃」「矢の雨」「癒しの光」「聖光」と表示されている
3. [ ] 「強撃」を押すと敵1体だけがダメージを受け、他の敵のHPは減らない
4. [ ] 「強撃」のダメージが `max(1, floor(18 * 2.0) - 2)` = 34 になっている（対象が `enemy_slime` の場合）
5. [ ] 「狙撃」のダメージが `max(1, floor(14 * 2.6) - 2)` = 34 になっている（対象が `enemy_slime` の場合）
6. [ ] 「矢の雨」を押すと、生存している敵**全員**が同時にダメージを受ける
7. [ ] 発動後、そのボタンが `disabled` になり、テキストに残り秒数が表示され、0になると押せる状態に戻る
8. [ ] クールダウン中に同じボタンを連打しても、スキルが再発動しない
9. [ ] あるスキルを使っても、同じキャラのもう1つのスキルはクールダウンに入らない（「強撃」を撃った直後に「横薙ぎ」が撃てる）
10. [ ] `J` キーで味方のHPを削ってから「癒しの光」を押すと、**3人全員**のHPが回復する（僧侶自身も回復する）
11. [ ] HPが満タンに近い状態で「癒しの光」を押しても、HPが `max_hp` を超えない
12. [ ] 死亡した味方は「癒しの光」で回復しない（HPが0のまま、復活しない）
13. [ ] 味方が死亡すると、そのキャラのスキルボタン2つが `disabled` になる
14. [ ] ウェーブが切り替わったとき、スキルのクールダウンがリセットされていない（`L` で敵を全滅させ、直前に使ったスキルの残り時間が次ウェーブでも減り続けていることを確認する）
15. [ ] 結果画面が表示されている間、スキルボタンが6つとも `disabled` になっている
16. [ ] ウェーブ5の敵が紫色で、他ウェーブの敵より明らかに大きく表示され、デバッグパネルの一覧で `atk` が `stat_overrides` により 26 になっている
17. [ ] `skill_resolver.gd` にのみスキルの計算式があり、`unit.gd` と `battle_controller.gd` に計算式が書かれていない（コードレビューで確認）

---

## 遵守事項（`AGENTS.md` より再掲）

- ファイル名は snake_case。`class_name` とノード名は PascalCase
- 表示テキストは `tr()` を通す。数値のみの表示と `print` / `push_warning` は除く
- キーは `GameStateKeys` / `TransferKeys` の定数経由。文字列リテラルを書かない
- 画面遷移は `SceneManager` 経由
- バランス数値をスクリプトにハードコードしない（今回は JSON に置く）
- **同じ箇所を3回以上直しても直らない場合は、実装を止めて人間に報告すること**
- 実装完了後、`IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_BATTLE_SKILLS.md` を生成すること。「5. 指示書からの逸脱・迷った判断」を空欄にしないこと
