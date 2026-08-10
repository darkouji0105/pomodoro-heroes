# 【実行指示書】戦闘画面 フェーズ1（骨格）

`PLAN_BATTLE_SCREEN.md` のフェーズ1に対応する第3層。この指示書だけを見て実装できるように書いてある。

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

**例外**：既存ファイルに追記した直後だけ `read` で開き、編集前の内容が残っていること・重複行がないことを確認すること。これは誤字チェックではなく破壊チェックなので必ず行う。

**追記の前に `grep` で重複を確認すること。**

`class_name` が認識されないエラーが出たら、型指定を `Node` に落として `call()` で回避しないこと。Godotエディタの再起動で解消する。

---

## 前提・参照ドキュメント

- `AGENTS.md`（プロジェクト共通ルール）
- `PLAN_BATTLE_SCREEN.md`（第2層。本書はそのフェーズ1）
- `DATA_SCHEMA.md` 3-1（戦闘画面のデータ構造）

### 既存の実装状況（実コードで確認済みの事実）

**推測で補わないこと。以下は実ファイルを読んで確認した事実である。**

| 事実 | 場所 |
|---|---|
| `GameManager.apply_battle_rewards(result_data)` は `rewards` の `gold` と `materials` のみ反映し、末尾で `SignalBus.battle_finished.emit(result_data)` する | `autoload/game_manager.gd` |
| `rewards` の `gems` / `stamina` / `inventory` は無視される | 同上 |
| `GameManager.get_character_growth(id)` は現状 `{}` を返す（育成データ未実装） | 同上 |
| `GameManager.mark_stage_cleared(stage_id, stars)` は**人間が追記済み**。呼んでよい | 同上 |
| `SceneManager.consume_transfer_data()` は取り出すと同時に空になる。**2回呼ぶと2回目は `{}`** | `autoload/scene_manager.gd` |
| `SceneManager.change_scene(path)` で遷移する。`get_tree().change_scene_to_file()` を直接呼ばない | 同上 |
| `TransferKeys.STAGE_ID` / `PARTY_ID` / `STAGE_TYPE` は**人間が追記済み**。使ってよい | `scripts/utils/transfer_keys.gd` |
| `GameStateKeys.BATTLE_VICTORY` / `BATTLE_WAVES_CLEARED` / `BATTLE_REWARDS` は定義済み | `scripts/utils/state_keys.gd` |
| `PrimaryButton`（`scenes/ui/components/primary_button.tscn`）は `label_key` に翻訳キーを入れると `tr()` を通して `text` に反映する | `primary_button.gd` |
| `ResourceDisplay` は `Icon` と `ValueLabel` しか持たない。**名前を表示する手段が無い** | `resource_display.tscn` |
| `Balance` は Autoload。`Balance.pomodoro` 等で各Configを参照する | `autoload/balance.gd` |

**`ResourceDisplay` は本タスクでは使わない。** 報酬表示には素の `Label` を使う。

---

## 今回のタスク

### やること

1. マスターデータのJSON 4ファイルを作る
2. `MasterDataLoader`（JSONを読んでIDで引く静的クラス）
3. `Unit`（`RefCounted`）と `BattleSession`（`RefCounted`）
4. `UnitView`（表示）
5. `BattleController` と `battle.tscn`（オートバトル・ウェーブ進行・勝敗・結果表示）

### やらないこと

- **スキル**（フェーズ2）
- **ボスの見た目の区別**（フェーズ2。`is_boss` は読み込むだけ）
- **スタミナ消費**（冒険選択画面のスコープ）
- パーティ選択・冒険選択画面
- 演出・アニメーション・効果音
- ステージ2以降のデータ

### 人間が対応済み（触らないこと）

- `transfer_keys.gd` への `STAGE_ID` / `PARTY_ID` / `STAGE_TYPE` の追記
- `state_keys.gd` への `STAGE_TYPE_STORY` / `STAGE_TYPE_TRAINING` の追記
- `game_manager.gd` 末尾への `mark_stage_cleared()` の追記
- `base_screen.gd` の `SCREEN_SCENES` の差し替え
- `initial_state_config.tres` の `initially_unlocked_screens` への `adventure_select` 追加
- `ja.csv` への翻訳キー追記（§8に一覧を出すが、**追記するのは人間**）

---

## §1 マスターデータ（JSON 4ファイル）

出力先：`res://resources/balance/master/`

**以下の内容をそのまま書くこと。** 値を変えたり、キャラや敵を足したりしないこと。数値の調整は人間が後から行う。

### §1-1 `characters.json`

```json
{
  "char_swordsman": {
    "name_key": "ui_battle_char_swordsman",
    "hp": 120, "atk": 18, "def": 6, "spd": 60,
    "attack_range": 60, "attack_interval_sec": 1.2
  },
  "char_archer": {
    "name_key": "ui_battle_char_archer",
    "hp": 80, "atk": 14, "def": 3, "spd": 70,
    "attack_range": 300, "attack_interval_sec": 1.5
  }
}
```

### §1-2 `enemies.json`

```json
{
  "enemy_slime": {
    "name_key": "ui_battle_enemy_slime",
    "hp": 40, "atk": 8, "def": 2, "spd": 40,
    "attack_range": 50, "attack_interval_sec": 1.5
  },
  "enemy_wolf": {
    "name_key": "ui_battle_enemy_wolf",
    "hp": 55, "atk": 12, "def": 3, "spd": 80,
    "attack_range": 50, "attack_interval_sec": 1.0
  },
  "boss_slime_king": {
    "name_key": "ui_battle_enemy_slime_king",
    "hp": 300, "atk": 20, "def": 8, "spd": 30,
    "attack_range": 70, "attack_interval_sec": 1.8
  }
}
```

### §1-3 `parties.json`

```json
{
  "party_default": { "members": ["char_swordsman", "char_archer"] }
}
```

### §1-4 `stages.json`

```json
{
  "stage_1": {
    "party_id": "party_default",
    "rewards": { "gold": 50, "materials": { "construction_material": 3 } },
    "waves": [
      { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 } ] },
      { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 3 } ] },
      { "wave_index": 3, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 4, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 }, { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 5, "enemies": [ { "enemy_type_id": "boss_slime_king", "count": 1, "is_boss": true } ] }
    ]
  }
}
```

`rewards` に `gems` / `stamina` / `inventory` を書かないこと。`GameManager` が無視するため、書くと「入れたのに反映されない」という誤解のもとになる。

---

## §2 `MasterDataLoader`

出力先：`res://scripts/systems/master_data_loader.gd`

```gdscript
class_name MasterDataLoader
extends RefCounted
```

**Autoloadにしないこと。** Autoloadは5つに固定するルール（`AGENTS.md`）。静的関数として実装し、`BattleController` から `MasterDataLoader.get_stage("stage_1")` のように呼ぶ。

### 読み込み方式

**まず `load()` 方式を試すこと。** Godot 4 は `.json` を `JSON` リソースとしてインポートするため、以下で `Dictionary` が取れる。

```gdscript
var res: JSON = load(path) as JSON
var data: Dictionary = res.data as Dictionary
```

**これが動かない場合のみ**、`FileAccess.open(path, FileAccess.READ)` + `JSON.parse_string()` に切り替えること。

**どちらの方式で動いたかを IMPL_LOG に必ず書くこと。** `FileAccess` 方式になった場合、エクスポート時に `.json` が含まれるようフィルタ設定が必要になるため、人間が対応する必要がある。

### 実装内容

- 4ファイルそれぞれに対応する静的変数でキャッシュする。初回アクセス時のみ読み込む
- 公開関数：`get_character(id)` / `get_enemy(id)` / `get_party(id)` / `get_stage(id)`。いずれも `Dictionary` を返す
- **IDが存在しない場合は `push_error` を出して空の `Dictionary` を返す。** 黙って握りつぶさないこと
- ファイルが無い、またはパースに失敗した場合も `push_error` を出す
- 返す `Dictionary` は `duplicate(true)` したものにする。呼び出し側がマスターデータを書き換えられないようにするため

---

## §3 `Unit`

出力先：`res://scripts/systems/unit.gd`

```gdscript
class_name BattleUnit
extends RefCounted
```

**`class_name` は `Unit` ではなく `BattleUnit` にすること。** `Unit` は将来ほかの用途と衝突しやすく、Godot組み込みの名前とも紛らわしいため。

### フィールド

| 名前 | 型 | 備考 |
|---|---|---|
| `unit_id` | String | 生成時に一意に振る |
| `team` | String | `"party"` または `"enemy"` |
| `unit_name_key` | String | 翻訳キー |
| `hp` / `max_hp` | int | |
| `atk` / `def` | int | |
| `atk_multiplier` | float | 本フェーズでは常に `1.0` |
| `attack_range` | float | |
| `attack_interval_sec` | float | |
| `speed` | float | 秒あたりの移動px |
| `x` | float | **1次元。y方向の移動はしない** |
| `target_unit_id` | String | 未設定は `""`。**`null` を入れないこと**（型が揺れる） |
| `attack_timer` | float | |
| `is_boss` | bool | |

`team` の値は `"party"` / `"enemy"` の文字列リテラルを直書きせず、このクラス内に `const TEAM_PARTY: String = "party"` / `const TEAM_ENEMY: String = "enemy"` として定義し、そちらを使うこと。

### メソッド

- `take_damage(amount: int) -> void`：`hp` を減らす。**0未満にしない**
- `heal(amount: int) -> void`：`hp` を増やす。**`max_hp` を超えない**
- `is_alive() -> bool`：`hp > 0`

**`hp` を外から直接書き換えないこと。** 必ずこの2メソッドを経由する。

---

## §4 `BattleSession`

出力先：`res://scripts/systems/battle_session.gd`

```gdscript
class_name BattleSession
extends RefCounted
```

### フィールド

| 名前 | 型 | 備考 |
|---|---|---|
| `stage_id` | String | |
| `stage_type` | String | `GameStateKeys.STAGE_TYPE_STORY` |
| `party_id` | String | |
| `state` | String | 下記5状態 |
| `current_wave` | int | 1始まり |
| `total_waves` | int | `stages.json` の `waves` の要素数から取る。**5をハードコードしないこと** |
| `party_units` | Array | `BattleUnit` の配列 |
| `enemy_units` | Array | `BattleUnit` の配列 |
| `result` | Dictionary | `{victory, waves_cleared, rewards}` |

### 状態

`STATE_WAVE_INTRO` / `STATE_BATTLE_ACTIVE` / `STATE_WAVE_CLEAR` / `STATE_VICTORY` / `STATE_DEFEAT` を `const` として定義し、文字列リテラルを直書きしないこと。

### 責務

`BattleSession` が持つのは**データと状態の判定だけ**。`_process` を持たない（`RefCounted` のため持てない）。ループは `BattleController` が回す。

判定用の関数を持たせる：

- `is_wave_cleared() -> bool`：`enemy_units` に生存者がいない
- `is_party_wiped() -> bool`：`party_units` に生存者がいない
- `is_final_wave() -> bool`：`current_wave >= total_waves`
- `get_alive_units(team: String) -> Array`

---

## §5 `UnitView`

出力先：`res://scenes/adventure/unit_view.tscn` と `unit_view.gd`

**`scenes/ui/components/` に置かないこと。** 戦闘画面でしか使わないため（`AGENTS.md` UIパーツの置き場所ルール）。

```
UnitView (Node2D)
├─ Body (ColorRect)      64x64
├─ HpBar (ProgressBar)   幅64・高さ8。Bodyの上に配置
└─ NameLabel (Label)     Bodyの下に配置
```

### 実装内容

- `setup(unit: BattleUnit) -> void` で対象を受け取り、`NameLabel.text = tr(unit.unit_name_key)` と `Body.color` を設定する
- `_process(delta)` で `position.x = unit.x` と `HpBar.value` を毎フレーム更新する
- `unit.is_alive()` が `false` になったら `hide()` する（ノードは消さない。参照が残るため）

### 色

| 対象 | 色 |
|---|---|
| 味方 | `Color(0.3, 0.5, 0.9)` 青 |
| 敵 | `Color(0.9, 0.35, 0.3)` 赤 |
| ボス（`is_boss`） | `Color(0.6, 0.3, 0.8)` 紫 |

**この3色は `unit_view.gd` 内に `const` で持ってよい。** `main_theme.tres` に対応する概念が無いため、本タスク限定の例外とする。他の箇所で色を直書きしないこと。

### 書き換え禁止

**`UnitView` は `BattleUnit` の値を読むだけ。書き換えないこと。** HP変動は `BattleController` が `take_damage()` を呼ぶ形で行う。

---

## §6 `BattleController` と `battle.tscn`

出力先：`res://scenes/adventure/battle.tscn` と `battle_controller.gd`

### シーン階層

```
Battle (Node2D)  ← battle_controller.gd
├─ Background (ColorRect)     全画面・暗い色
├─ PartyUnitsContainer (Node2D)
├─ EnemyUnitsContainer (Node2D)
├─ HUD (CanvasLayer)
│   └─ WaveLabel (Label)      左上
└─ ResultView (Control)       全画面・初期状態は非表示
    ├─ ResultLabel (Label)
    ├─ RewardLabel (Label)
    ├─ RetryButton (PrimaryButton インスタンス)
    └─ BackButton (PrimaryButton インスタンス)
```

`RetryButton` / `BackButton` は `res://scenes/ui/components/primary_button.tscn` をインスタンス化し、`label_key` に `ui_battle_retry` / `ui_battle_back` を設定する。

### §6-1 起動時

`_ready()` で `SceneManager.consume_transfer_data()` を**1回だけ**呼ぶ。

**2回呼ぶと2回目は空になる。** 取得した `Dictionary` を変数に入れて使い回すこと。

```
stage_id = data.get(TransferKeys.STAGE_ID, "")
stage_id が "" なら:
    push_warning("[Battle] stage_id が渡されていないため stage_1 で開始する")
    stage_id = "stage_1"
```

**このフォールバックは暫定導線のために必要。** 拠点の冒険ボタンは `{TransferKeys.SCREEN_ID: screen_id}` しか渡さないため、`stage_id` は入ってこない。冒険選択画面ができたら渡されるようになる。

`party_id` は `stages.json` の `party_id` から取る（転送データからは取らない）。

### §6-2 味方Unitの生成（重要）

**`character_growth` は現状すべて空だが、以下の優先順で書くこと。** 育成画面ができたときにコードを変えずに繋がるようにするため。

```
1. GameManager.get_character_growth(character_id) を呼ぶ
2. 戻り値が空でなく GROWTH_STATS を持つなら、その hp/atk/def/spd を使う
3. そうでなければ characters.json の値を使う
```

`attack_range` / `attack_interval_sec` / `name_key` は育成データに存在しないため、**常に `characters.json` から取る。**

`atk_multiplier` は常に `1.0` を入れる（装備が未実装のため）。

`unit_id` は `"party_0"` `"party_1"` のように連番で振る。

初期配置：`x = 100 + index * 80`

### §6-3 敵Unitの生成

各ウェーブの `enemies` 配列を順に処理する。

- `count` の数だけ生成する。`count` が無ければ1体
- `enemy_type_id` で `enemies.json` を引く
- `stat_overrides` があれば、その値で上書きする（無い場合が普通）
- `is_boss` があればそれを入れる。無ければ `false`
- `unit_id` は `"enemy_%d_%d" % [wave_index, 連番]`

初期配置：`x = 900 + index * 80`

### §6-4 戦闘ループ

`_process(delta)` の中で、`state` が `STATE_BATTLE_ACTIVE` のときだけ以下を行う。

生存中の全ユニット（味方→敵の順）について：

1. `target_unit_id` が空、または対象が死んでいるなら、**`x` の差が最小の敵対チームの生存ユニット**を選び直す。敵対チームに生存者がいなければ何もしない
2. 対象との距離（`abs(self.x - target.x)`）が `attack_range` 以内なら：
   - `attack_timer += delta`
   - `attack_timer >= attack_interval_sec` になったら攻撃し、`attack_timer = 0.0` に戻す
3. 範囲外なら、`x` を対象の方向へ `speed * delta` 動かす

### §6-5 ダメージ計算（今回いちばん間違えやすい箇所）

```
最終ダメージ = max(1, floor(攻撃側のatk * 攻撃側のatk_multiplier) - 対象のdef)
```

**`max(1, ...)` を必ず入れること。** これが無いと、防御力が攻撃力以上のときダメージが0または負になり、どちらのチームも減らないまま戦闘が永久に続く。ゲームが固まったように見えるが、エラーは1つも出ないので原因が分かりにくい。

完了条件でも実測させる。

### §6-6 ウェーブ進行

```
STATE_WAVE_INTRO
  → 0.5秒待つ（await get_tree().create_timer(0.5).timeout）
  → そのウェーブの敵を生成
  → STATE_BATTLE_ACTIVE

STATE_BATTLE_ACTIVE
  → is_party_wiped() なら STATE_DEFEAT
  → is_wave_cleared() なら STATE_WAVE_CLEAR

STATE_WAVE_CLEAR
  → is_final_wave() なら STATE_VICTORY
  → そうでなければ current_wave += 1 して STATE_WAVE_INTRO
```

**敗北判定を勝利判定より先に行うこと。** 相打ちで両チームが全滅した場合、勝利にすると「全滅したのに勝った」ことになる。

**ウェーブが切り替わるとき、`party_units` を作り直さないこと。** HPを引き継ぐ（連戦）。作り直すとHPが満タンに戻る。これも事故りやすい。死亡した味方も `party_units` から削除せず、`is_alive()` が `false` のまま残す。

`WaveLabel.text` は `"%d / %d" % [current_wave, total_waves]`。数値のみなので `tr()` を通さない（`AGENTS.md`）。

---

## §7 結果処理（今回いちばん事故が起きる箇所）

### §7-1 報酬は1回だけ

`_process` の中で勝敗を判定するため、**ガードを入れないと毎フレーム報酬が加算される。**

`var _result_applied: bool = false` を持ち、以下の順で行うこと。

```
1. _result_applied が true なら即 return
2. _result_applied = true にする
3. state を STATE_VICTORY にする
4. GameManager.apply_battle_rewards(...) を呼ぶ
5. GameManager.mark_stage_cleared(stage_id, 0) を呼ぶ
6. ResultView を表示する
```

**フラグを立てるのを報酬の呼び出しより後にしないこと。** `await` を挟むと、その間に次のフレームが走って二重に呼ばれる。

完了条件で「`apply_battle_rewards` の print が1回だけ」を実測させる。

### §7-2 渡す `result_data`

```gdscript
GameManager.apply_battle_rewards({
    GameStateKeys.BATTLE_VICTORY: true,
    GameStateKeys.BATTLE_WAVES_CLEARED: session.total_waves,
    GameStateKeys.BATTLE_REWARDS: stage_data.get("rewards", {}),
})
```

キーは必ず `GameStateKeys` の定数を使う。文字列リテラルを書かないこと。

### §7-3 `SignalBus` を戦闘画面から発火しない

**`SignalBus.battle_finished.emit()` を `battle_controller.gd` に書かないこと。** `apply_battle_rewards()` の内部で発火する（実コードで確認済み）。両方から出すと二重発火になる。

### §7-4 敗北時

- `apply_battle_rewards()` を**呼ばない**
- `mark_stage_cleared()` も**呼ばない**
- `ResultLabel.text = tr("ui_battle_defeat")`
- `RetryButton` を表示する

### §7-5 ボタンの挙動

| ボタン | 挙動 |
|---|---|
| `RetryButton` | `BattleSession` を作り直し、ウェーブ1から再開する。`_result_applied` を `false` に戻す。**敗北時のみ表示**（勝利時は `hide()`） |
| `BackButton` | `SceneManager.change_scene("res://scenes/base/base_screen.tscn")` |

`go_back()` は履歴がダミー実装のため使わないこと。

**「もう一度」では味方のHPが満タンに戻る**（`BattleUnit` を作り直すため）。これは仕様。

### §7-6 報酬の表示

`RewardLabel` に獲得内容を出す。`ResourceDisplay` は名前を表示できないため使わない。素の `Label` に、翻訳キーと数値を組み立てて入れること。

```
tr("ui_battle_reward_gold") + ": 50"
```

素材名は `"ui_res_" + material_id` で引く（`AGENTS.md` 翻訳キーの運用）。

---

## §8 翻訳キー（人間が `ja.csv` に追記する）

**実装役はこのファイルを編集しないこと。** 以下は人間の作業分。参考のため列挙する。

| キー | 日本語 |
|---|---|
| `ui_battle_victory` | 勝利 |
| `ui_battle_defeat` | 敗北 |
| `ui_battle_retry` | もう一度 |
| `ui_battle_back` | 拠点へ戻る |
| `ui_battle_reward_gold` | ゴールド |
| `ui_battle_char_swordsman` | 剣士 |
| `ui_battle_char_archer` | 弓兵 |
| `ui_battle_enemy_slime` | スライム |
| `ui_battle_enemy_wolf` | ウルフ |
| `ui_battle_enemy_slime_king` | スライムキング |

`ja.csv` に無いキーは、キー文字列がそのまま画面に出る。**これは意図した挙動なのでフォールバック処理を入れないこと。**

---

## 動作確認手順（完了条件）

**この19項目を、項目番号と文言をそのまま IMPL_LOG に転記すること。** 要約したり作り直したりしないこと。1項目ずつ実際に動かして確認し、「何をしたら何と表示されたか」を書くこと。

実際に動かせなかった項目は `[x]` を付けず、「実機未検証」と正直に書いてよい。埋めなくてよい。

1. [ ] 拠点の冒険ボタンから `battle.tscn` に遷移し、味方2体と敵2体が表示される
2. [ ] `stage_id` が渡されないため `push_warning` が出た上で、`stage_1` として開始される
3. [ ] 味方が敵に向かって移動し、`attack_range` 内に入ると自動で攻撃が始まる
4. [ ] `char_archer`（`attack_range` 300）が `char_swordsman`（60）より手前で攻撃を開始する
5. [ ] ダメージが `max(1, atk - def)` で計算されている（`char_swordsman` の `atk 18` が `enemy_slime` の `def 2` に当たり、16ダメージになる）
6. [ ] `enemies.json` の `enemy_slime` の `def` を一時的に `30` に書き換えて実行すると、ダメージが `1` になり、戦闘が終了する（0や負にならず、固まらない）
7. [ ] ウェーブ1の敵を全滅させると、0.5秒後にウェーブ2が始まり `WaveLabel` が `2 / 5` になる
8. [ ] ウェーブ2開始時、味方のHPがウェーブ1終了時の値のままである（満タンに戻らない）
9. [ ] 味方1体が死亡した次のウェーブで、その1体が復活していない
10. [ ] 5ウェーブすべてクリアすると `ResultView` が表示され、勝利と表示される
11. [ ] 勝利時、`[GameManager] apply_battle_rewards` の print が**1回だけ**出る（毎フレーム出ていないこと）
12. [ ] 勝利時、`SignalBus.battle_finished` が発火し、`result_data` の `waves_cleared` が `5` である
13. [ ] `battle_controller.gd` に `SignalBus.battle_finished.emit` が1箇所も書かれていないことをコードレビューで確認する
14. [ ] 勝利後に拠点へ戻ると、goldが50増え、建築素材が3増えている
15. [ ] 勝利時に `mark_stage_cleared` の print が出て、`GameManager.get_state()` の `story.stages.stage_1.cleared` が `true` になっている
16. [ ] 味方が全滅すると敗北と表示され、goldも素材も増えていない（`apply_battle_rewards` の print が出ない）
17. [ ] 敗北時の「もう一度」でウェーブ1から再開し、味方のHPが満タンに戻っている。その後もう一度勝利しても報酬が二重に入らない
18. [ ] マスターデータのJSON 4ファイルをすべて読み込めている。`load()` 方式と `FileAccess` 方式のどちらで動いたかを IMPL_LOG に書く
19. [ ] `enemies.json` の `enemy_slime` の `hp` を40から10に書き換えて再実行すると明らかに早く倒せる（数値がJSONから効いていることの確認）

項目6と項目19では JSON を一時的に書き換える。**確認後、必ず元の値に戻すこと。**

---

## 遵守事項（`AGENTS.md` より再掲）

- ファイル名は snake_case。`class_name` とノード名は PascalCase
- 表示テキストは `tr()` を通す。数値のみの表示と `print` / `push_warning` は除く
- 状態の変更は必ず `GameManager` の専用関数を経由する。`get_state()` の戻り値を書き換えても内部状態は変わらない
- キーは `GameStateKeys` / `TransferKeys` の定数経由。文字列リテラルを書かない
- 画面遷移は `SceneManager` 経由。`change_scene_to_file()` を直接呼ばない
- バランス数値をスクリプトにハードコードしない（本タスクでは JSON に置く）
- **同じ箇所を3回以上直しても直らない場合は、実装を止めて人間に報告すること。** 設計側に無理があるサイン
- 実装完了後、`IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_BATTLE_CORE.md` を生成すること。「5. 指示書からの逸脱・迷った判断」を空欄にしないこと
