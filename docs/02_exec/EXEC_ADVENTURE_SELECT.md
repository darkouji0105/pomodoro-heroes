# 【実行指示書】冒険選択画面

`PLAN_ADVENTURE_SELECT.md` に対応する第3層。

---

## §0 作業の進め方（厳守）

| 禁止 | 理由 |
|---|---|
| `edit_file` | このプロジェクトでは動作しない |
| `create_file` に150行を超える本文 | トークン上限で失敗する。`cat >>` で分割する |
| `cat >` での既存ファイルの上書き | 既存の内容が消える |
| `sed` / `awk` | シェル依存で動作が保証されない |
| 補助スクリプト（`.py` 等）の作成 | 誤字修正のために作り始めて止まらなくなる |
| 書き終わったあとの読み返し・誤字修正 | 誤字は人間が直す |
| `.tres` ファイルの編集 | 人間がInspectorで行う |
| `autoload/` 配下の編集 | 人間が行う |
| `ja.csv` の編集 | 人間が行う |
| `project.godot` の変更 | 人間が行う |
| 中間ファイルを経由した書き換え | 編集先を取り違える |

**例外**：既存ファイルに追記した直後だけ `read` で開き、編集前の内容が残っていること・重複行がないことを確認すること。破壊チェックなので必ず行う。

### 止まってよい・止まるべき条件

**1つのファイルへの書き込みが2回失敗したら、そのファイルは諦めて報告すること。**

方法を変えても回数は増える。`cat >>` で失敗して Python を試すのは2回目。キャッシュ削除・エディタ再起動・ファイルを消して作り直すのも1回に数える。

「編集したのに反映されない」と感じたら、環境の問題だと判断する前に、**編集したファイルのパスが実際に読み込まれているファイルと同じか**を確認すること。

### 未実装と書いてよい

実装できなかったファイルは「未実装」と正直に書いてよい。埋めなくてよい。**指示書の一覧に無いファイルを作らないこと。**

---

## 前提・参照ドキュメント

- `AGENTS.md`
- `PLAN_ADVENTURE_SELECT.md`

### 既存の実装状況（実コードで確認済みの事実）

**推測で補わないこと。**

| 事実 | 場所 |
|---|---|
| `GameManager.spend_stamina(amount)` は不足時に `false` を返す。成功時は `resource_changed(STAMINA, current)` を発火 | `autoload/game_manager.gd` |
| `GameManager.is_stage_cleared(stage_id)` が `bool` を返す | 同上 |
| `GameManager.refund_stamina(amount)` が**人間により追加済み**（この画面では使わない） | 同上 |
| **`resource_changed` が `STAMINA` で発火するとき、第2引数は `current` のみで `max` を含まない。** `max` が必要なら `get_state()` から読み直す | 同上 |
| `SceneManager.change_scene_with_data(path, data)` / `change_scene(path)` / `consume_transfer_data()` | `autoload/scene_manager.gd` |
| `consume_transfer_data()` は取り出すと同時に空になる。**2回呼ぶと2回目は `{}`** | 同上 |
| `TransferKeys.STAGE_ID` / `PARTY_ID` / `STAGE_TYPE` / `SCREEN_ID` | `scripts/utils/transfer_keys.gd` |
| `GameStateKeys.SCREEN_ADVENTURE_SELECT` / `STAGE_TYPE_STORY` / `STAGE_TYPE_TRAINING` / `STAMINA` / `STAMINA_CURRENT` / `STAMINA_MAX` | `scripts/utils/state_keys.gd` |
| `MasterDataLoader` は `get_character` / `get_enemy` / `get_party` / `get_stage` / `get_skill` を持つ。すべて `static` | `scripts/systems/master_data_loader.gd` |
| `MasterDataLoader.DIR_PATH` は `"res://resources/balance/master/"` | 同上 |
| `MasterDataLoader._load_json(path)` は `load()` 方式を試し、駄目なら `FileAccess` にフォールバックする | 同上 |
| `PrimaryButton`（`scenes/ui/components/primary_button.tscn`）は `label_key` に翻訳キーを入れると `tr()` を通す | `primary_button.gd` |
| `ResourceDisplay`（`scenes/ui/components/resource_display.tscn`）は `Icon` と `ValueLabel` のみ。**名前を出す手段が無い**。`set_value(v)` と `set_value_with_max(v, max)` を持つ | `resource_display.tscn` / `base_screen.gd` の使用例 |
| `placeholder_screen.tscn` は `TransferKeys.SCREEN_ID` を受け取って見出しを出す | `scenes/ui/placeholder_screen.gd` |
| `Balance.adventure`（`AdventureConfig`）は**人間により追加済み**。`Balance.adventure.stamina_cost_per_stage` で読める | `autoload/balance.gd` |

---

## 今回のタスク

### やること

1. `stages.json` に `name_key` を追加し、`stage_2` / `stage_3` を追加する
2. `stage_order.json` を新規作成する
3. `MasterDataLoader` に `get_stage_order()` を**末尾追記**する
4. `adventure_select.tscn` と `adventure_select.gd` を作る

### やらないこと

- **パーティ選択画面**（パーティは `stages.json` の `party_id` 固定）
- **トレーニングモードの中身**（ボタンは置くが `placeholder_screen` へ飛ばすだけ）
- **戦闘画面側の変更**（スタミナ返却・リトライ時の再消費）。`battle_controller.gd` は200行を超えるため、**人間が全文を差し替える**
- 新しい敵の追加。`stage_2` / `stage_3` は既存の敵を `stat_overrides` で強くするだけ
- 星（`stars`）の扱い。常に `0`
- ステージのプレビュー・敵一覧の表示（拒否仕様「戦闘プレビュー画面」に抵触する）

### 人間が対応済み（触らないこと）

- `autoload/game_manager.gd` への `refund_stamina()` / `_add_stamina_uncapped()` の追加
- `autoload/balance.gd` への `@export var adventure: AdventureConfig` の追加
- `adventure_config.gd`（`class_name AdventureConfig`）と `adventure_config.tres` の作成・値の入力
- `scenes/base/base_screen.gd` の `SCREEN_SCENES` の差し替え
- `localization/ja.csv` への翻訳キー追記（§6に一覧）
- `scenes/adventure/battle_controller.gd` の全文差し替え

---

## §1 `stages.json`

**既存ファイルを書き換える。** `stage_1` の `waves` と `rewards` は**一字も変えないこと**。`name_key` の追加のみ。

書き換えたあと `read` で開き、`stage_1` の中身が保たれていることを確認すること。

```json
{
  "stage_1": {
    "name_key": "ui_stage_1",
    "party_id": "party_default",
    "rewards": { "gold": 50, "materials": { "construction_material": 3 } },
    "waves": [
      { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 } ] },
      { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 3 } ] },
      { "wave_index": 3, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 4, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 }, { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 5, "enemies": [ { "enemy_type_id": "boss_slime_king", "count": 1, "is_boss": true, "stat_overrides": { "atk": 26 } } ] }
    ]
  },
  "stage_2": {
    "name_key": "ui_stage_2",
    "party_id": "party_default",
    "rewards": { "gold": 80, "materials": { "construction_material": 5 } },
    "waves": [
      { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 }, { "enemy_type_id": "enemy_wolf", "count": 2 } ] },
      { "wave_index": 3, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 3 } ] },
      { "wave_index": 4, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 4, "stat_overrides": { "hp": 55 } } ] },
      { "wave_index": 5, "enemies": [ { "enemy_type_id": "boss_slime_king", "count": 1, "is_boss": true, "stat_overrides": { "hp": 400, "atk": 30 } }, { "enemy_type_id": "enemy_slime", "count": 2 } ] }
    ]
  },
  "stage_3": {
    "name_key": "ui_stage_3",
    "party_id": "party_default",
    "rewards": { "gold": 120, "materials": { "construction_material": 8 } },
    "waves": [
      { "wave_index": 1, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 3 } ] },
      { "wave_index": 2, "enemies": [ { "enemy_type_id": "enemy_slime", "count": 3, "stat_overrides": { "hp": 60, "def": 4 } } ] },
      { "wave_index": 3, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 3, "stat_overrides": { "atk": 15 } } ] },
      { "wave_index": 4, "enemies": [ { "enemy_type_id": "enemy_wolf", "count": 2 }, { "enemy_type_id": "enemy_slime", "count": 3, "stat_overrides": { "hp": 60 } } ] },
      { "wave_index": 5, "enemies": [ { "enemy_type_id": "boss_slime_king", "count": 1, "is_boss": true, "stat_overrides": { "hp": 550, "atk": 34, "def": 12 } }, { "enemy_type_id": "enemy_wolf", "count": 2 } ] }
    ]
  }
}
```

---

## §2 `stage_order.json`（新規）

出力先：`res://resources/balance/master/stage_order.json`

```json
{
  "story": ["stage_1", "stage_2", "stage_3"]
}
```

**一覧の並び順はこのファイルが決める。** `stages.json` は `Dictionary` なのでキーの順序が保証されない。

---

## §3 `MasterDataLoader.get_stage_order()`

**ファイルの末尾に追記する。既存の関数・定数・`static var` に一切触らないこと。**

上部の `const` ブロックや `_ensure_loaded()` を編集する必要はない。**GDScriptは `static var` の宣言を関数のあとに書けるため、末尾追記だけで完結する。**

追記する内容：

- `static var _cache_stage_order: Dictionary = {}` と `static var _stage_order_loaded: bool = false` を宣言する
- `static func get_stage_order(mode: String) -> Array` を作る
  - 初回のみ `_load_json(DIR_PATH + "stage_order.json")` で読み込み、キャッシュする（既存の `_load_json` をそのまま使う）
  - `mode` が無ければ `push_error` を出して空の `Array` を返す
  - 返す値は `duplicate(true)` する
- `mode` には `GameStateKeys.STAGE_TYPE_STORY`（= `"story"`）が渡される

`_ensure_loaded()` には手を加えないこと。この関数だけが独立して遅延読み込みする形でよい。

---

## §4 `adventure_select.tscn`

出力先：`res://scenes/adventure/adventure_select.tscn`

```
AdventureSelect (Control)  ← adventure_select.gd
├─ Background (ColorRect)          全画面
└─ Layout (VBoxContainer)          全画面・余白あり
    ├─ Header (HBoxContainer)
    │   ├─ TitleLabel (Label)      text = "ui_adventure_title"
    │   ├─ Spacer (Control)        size_flags_horizontal = EXPAND_FILL
    │   ├─ StaminaNameLabel (Label) text = "ui_res_stamina"
    │   └─ StaminaValue            resource_display.tscn のインスタンス
    ├─ MessageLabel (Label)        初期は空文字
    ├─ StageList (VBoxContainer)   中身はコードで生成
    ├─ Spacer2 (Control)           size_flags_vertical = EXPAND_FILL
    └─ Footer (HBoxContainer)
        ├─ TrainingButton          primary_button.tscn。label_key = "ui_adventure_training"
        └─ BackButton              primary_button.tscn。label_key = "ui_adventure_back"
```

`StaminaValue` に `ResourceDisplay` を使う。**名前は隣の `StaminaNameLabel` で出す**（`ResourceDisplay` に名前を出す手段が無いため）。

`Label` の `text` に翻訳キーをそのまま入れる（`base_screen.tscn` と同じやり方。Godotの自動翻訳が効く）。

---

## §5 `adventure_select.gd`

出力先：`res://scenes/adventure/adventure_select.gd`

### §5-1 起動時

`_ready()` で `SceneManager.consume_transfer_data()` を**1回だけ呼び、戻り値は使わず捨てる。**

拠点から `{SCREEN_ID: "adventure_select"}` が渡ってくるが、この画面では使わない。**呼ばないと次の遷移に前回のデータが残る**ため、必ず呼ぶこと。

そのあと：

1. スタミナ表示を初期化する
2. ステージ一覧を生成する
3. `GameManager.resource_changed` を購読する
4. `TrainingButton` / `BackButton` を接続する
5. `MessageLabel.text` を空文字にする

### §5-2 スタミナ表示

```gdscript
var state: Dictionary = GameManager.get_state()
var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
stamina_value.set_value_with_max(
    int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
    int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
)
```

`resource_changed` のハンドラでは、**`STAMINA` のときだけ**更新する。**第2引数に `max` が入っていないので、`get_state()` から読み直すこと。** `set_value_with_max(new_value, 0)` と書くと `20 / 0` と表示される。

`GOLD` / `GEMS` が来たときは何もしない（この画面では表示していない）。

### §5-3 ステージ一覧の生成

`MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)` で並び順を取り、順に処理する。

各ステージについて `MasterDataLoader.get_stage(stage_id)` を引く。**空が返ったら `push_error` を出してその行は作らない**（並び順にあるのにデータが無い状態）。

行は**コードで組み立てる。** 専用の `.tscn` を作らないこと（1画面でしか使わず構造も単純なため）。

```
StageRow (HBoxContainer)
├─ NameLabel (Label)      ステージ名 + 状態マーク
├─ Spacer (Control)       EXPAND_FILL
├─ CostLabel (Label)      消費スタミナの数値
└─ ChallengeButton        primary_button.tscn
```

### §5-4 3つの状態

解放判定は **`GameManager.is_stage_cleared()` から都度計算する。** 解放状態を保存しないこと。

```
先頭のステージ           → 常に挑戦可能
2つ目以降のステージ      → 1つ前が cleared なら挑戦可能
```

**「1つ前」は `stage_order.json` の並びで決める。** ステージIDから数字を切り出して `stage_(N-1)` を組み立てるような書き方をしないこと。並びを入れ替えたときに壊れる。

| 状態 | `NameLabel` | ボタン | 押したとき |
|---|---|---|---|
| クリア済み | ステージ名 + `" ✓"` | 有効 | 挑戦できる（周回可能） |
| 挑戦可能 | ステージ名 | 有効 | 挑戦できる |
| 未解放 | ステージ名 + `" 🔒"` | 有効のまま | 何も起きず、`MessageLabel` に `ui_adventure_locked` を出す |

**未解放でもボタンを `disabled` にしないこと。** 押せなくすると理由が分からない。押したときにメッセージで理由を伝える。

未解放の行は `NameLabel.modulate` を暗くする（`Color(0.5, 0.5, 0.5)`）。

`CostLabel` は `Balance.adventure.stamina_cost_per_stage` の値を出す。**数値のみなので `tr()` を通さない。**

### §5-5 挑戦したとき（この画面の核心）

```
1. 未解放なら、MessageLabel に ui_adventure_locked を出して終了
2. cost = Balance.adventure.stamina_cost_per_stage
3. GameManager.spend_stamina(cost) を呼ぶ
4. false が返ったら、MessageLabel に「足りない」旨と必要量・現在値を出して終了
   （遷移しない。スタミナは減っていない）
5. true が返ったら change_scene_with_data で戦闘へ
```

**スタミナの消費はこの画面でのみ行う。戦闘画面では消費しない。** 消費の責任を1箇所に集めるため。

遷移するときに渡すもの：

```gdscript
SceneManager.change_scene_with_data("res://scenes/adventure/battle.tscn", {
    TransferKeys.STAGE_ID: stage_id,
    TransferKeys.STAGE_TYPE: GameStateKeys.STAGE_TYPE_STORY,
})
```

**`PARTY_ID` は渡さない。** 戦闘画面は `stages.json` の `party_id` を読む実装になっている。

### §5-6 メッセージ表示

スタミナ不足のときは、翻訳文のあとに必要量と現在値を数値で付ける。

```gdscript
message_label.text = tr("ui_adventure_stamina_short") + " (%d / %d)" % [cost, current]
```

**「あといくつ足りないか」が分かる形にすること。** 理由だけでは次に何をすればいいか分からない。

メッセージは**次にボタンが押されるまで残す。** タイマーで消さないこと（消えるタイミングを制御すると読めないうちに消える事故が起きる）。

### §5-7 フッター

| ボタン | 挙動 |
|---|---|
| `TrainingButton` | `change_scene_with_data(placeholder_screen.tscn, {SCREEN_ID: GameStateKeys.SCREEN_ADVENTURE_SELECT})` |
| `BackButton` | `change_scene("res://scenes/base/base_screen.tscn")` |

`SceneManager.go_back()` は履歴がダミー実装のため使わない。

パスは `base_screen.gd` と同じく `const` で持つこと。

---

## §6 翻訳キー（人間が `ja.csv` に追記する）

**実装役はこのファイルを編集しないこと。**

| キー | 日本語 |
|---|---|
| `ui_adventure_title` | 冒険 |
| `ui_adventure_stamina_short` | スタミナが足りません |
| `ui_adventure_locked` | 前のステージをクリアすると解放されます |
| `ui_adventure_training` | トレーニング |
| `ui_adventure_back` | 拠点へ戻る |
| `ui_stage_1` | 1. 草原のスライム |
| `ui_stage_2` | 2. 荒野の群れ |
| `ui_stage_3` | 3. 森の主 |

---

## 動作確認手順（完了条件）

**この14項目を、項目番号と文言をそのまま IMPL_LOG に転記すること。** 要約したり作り直したりしないこと。

**書き方**：`[ ] 項目N：（EXECの文言をそのまま）` を先に書き、**改行してから**検証結果を書くこと。1つの文にまとめないこと。

「何をしたら何と表示されたか」を書くこと。実際に動かせなかった項目は `[x]` を付けず、「実機未検証」と正直に書いてよい。

1. [ ] 拠点の冒険ボタンから冒険選択画面に遷移し、ステージが3行並ぶ
2. [ ] 画面右上にスタミナが「20 / 100」の形で表示される（`20 / 0` になっていないこと）
3. [ ] 各行に消費スタミナの数値（5）が表示されている
4. [ ] 初回起動時、`stage_1` は通常表示で、`stage_2` と `stage_3` は暗く表示され鍵マークが付く
5. [ ] `stage_2` を押しても遷移せず、メッセージ欄に「前のステージをクリアすると解放されます」と出る
6. [ ] そのとき `spend_stamina` は呼ばれておらず、スタミナが減っていない
7. [ ] `stage_1` を押すとスタミナが 20 から 15 に減り、戦闘画面に遷移する
8. [ ] 戦闘画面の起動時に `[Battle] stage_id が渡されていないため stage_1 で開始する` の警告が**出ない**
9. [ ] スタミナを5未満（例：3）にした状態で `stage_1` を押すと、遷移せずメッセージ欄に「スタミナが足りません (5 / 3)」と出る
10. [ ] そのときスタミナが 3 のまま減っていない
11. [ ] `stage_1` をクリアした状態で冒険選択画面を開くと、`stage_1` に `✓` が付き、`stage_2` が通常表示になって挑戦できる
12. [ ] クリア済みの `stage_1` に再挑戦でき、スタミナがさらに5減る
13. [ ] `adventure_config.tres` の `stamina_cost_per_stage` を 5 から 1 に変えて再実行すると、行の表示も実際の消費も 1 になる
14. [ ] `stage_order.json` の `story` の並びを `["stage_2", "stage_1", "stage_3"]` に変えて再実行すると、一覧の並び順が変わり、先頭に来た `stage_2` が挑戦可能になる

項目13・14では設定ファイルを一時的に書き換える。**確認後、必ず元に戻すこと。**

**項目11は `stage_1` を実際にクリアする必要がある。** 戦闘画面のデバッグパネル（F3で表示、`V` で強制勝利）を使ってよい。

---

## 最後に必ず報告すること

変更・作成したすべてのファイルについて、次の表を出すこと。

| パス | 新規/変更/未実装 | 行数 |

行数は `read` で開いて数えた実際の値を書くこと。**この指示書の一覧に無いパスがこの表にあってはいけない。**

そのうえで `IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_ADVENTURE_SELECT.md` を生成すること。「5. 指示書からの逸脱・迷った判断」を空欄にしないこと。

---

## 遵守事項（`AGENTS.md` より再掲）

- ファイル名は snake_case。`class_name` とノード名は PascalCase
- 表示テキストは `tr()` を通す。数値のみの表示と `print` / `push_warning` は除く
- 状態の変更は必ず `GameManager` の専用関数を経由する
- キーは `GameStateKeys` / `TransferKeys` の定数経由。文字列リテラルを書かない
- 画面遷移は `SceneManager` 経由。`change_scene_to_file()` を直接呼ばない
- バランス数値をスクリプトにハードコードしない（消費量は `Balance.adventure` から読む）
- `class_name` が認識されないエラーが出たら Godot を再起動する。型指定を `Node` に落として `call()` で回避しない
