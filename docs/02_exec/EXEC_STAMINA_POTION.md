# 【実行指示書】スタミナポーション

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

ポモドーロ報酬を「スタミナの直接付与」から「スタミナポーション」に変更し、拠点画面で所持数の確認と使用ができるようにする。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・状態構造の表・数値管理ルール・開発ルール
- `DATA_SCHEMA.md` 1章「スタミナとポーション（決定済み）」
- `PLAN_POMODORO_CORE_LOOP.md` 6-2 / 6-2-1

### 既存の実装状況（実コードで確認済み・推測しないこと）

| 対象 | 実際の状態 |
|---|---|
| `GameManager.add_to_inventory(item_id, count, item_type)` | 実装済み。`item_type`は`GameStateKeys.ITEM_TYPE_*`の定数を渡す。初出の`item_id`なら図鑑の`discovered`も自動で立つ。`inventory_changed(item_id)`を発火 |
| `GameManager.add_stamina(amount)` | 実装済み。**`max`で切り捨てる。** ポーション使用時はこれを使わない（下記4-2） |
| `GameManager.get_state()` | `duplicate(true)`のスナップショットを返す |
| `GameManager.inventory_changed` | `(item_id: String)` |
| `INVENTORY`の構造 | `{item_id: {count, type, slot_position: {x, y}, properties}}`。個数は`GameStateKeys.ITEM_COUNT` |
| `res://scenes/pomodoro/pomodoro.gd` | **人間が書き換え済み。** `_return_to_base()`が`stamina_per_focus_minute`でスタミナを直接付与している。今回ここを変更する |
| `res://scenes/base/base_screen.gd` | 実装済み。`ResourceRow`に`GoldEntry` / `StaminaEntry` / `MaterialsDisplay` / `Spacer` / `ChestBadge` / `SaveButton` / `BackToTitleButton`が並ぶ |
| `ResourceDisplay`（共通パーツ） | `HBoxContainer`。子は`Icon`と`ValueLabel`のみ。`set_value(int)` / `set_value_with_max(current, max)` |
| `PrimaryButton`（共通パーツ） | `Button`。`@export var label_key: String` |
| `res://localization/ja.csv` | 実装済み。UTF-8（BOMなし）。編集後は再インポートが必要 |

---

## 0. 人間による決定事項（最優先・§1以降と矛盾する場合はここを優先）

### 0-1.【確定】スタミナは加護で差をつけない

ポーションの獲得数は**作業分にのみ比例**し、加護（light / middle / hard）による差を一切つけない。

理由：スタミナは「その日に遊べる時間」に直結する。加護で差をつけると「長く働かないと遊べない」設計になり、`CONCEPT.md`の「やって後悔したと思わせない」に反する。加護による差は宝箱の中身だけでつける。

### 0-2.【確定】獲得レートと端数の持ち越し

| 項目 | 値 |
|---|---|
| ポーション獲得 | **作業25分につき1個** |
| 端数 | 25分に満たないぶんは`potion_focus_remainder`として**次回へ持ち越す** |
| 端数のリセット | **しない。** 日付が変わってもリセットしない |

例：60分やったら2個（50分ぶん）、残り10分は次回へ。次回に40分やったら合計50分で2個、残り0分。

### 0-3.【確定】ポーションは上限を超えて回復できる

- ポーション1個の回復量：**50**
- **`max`を超えてよい**（例：`current = 60`のときに飲むと`110`になる）
- 理由：`max`は自然回復の上限であり、自分で貯めたポーションを飲んだぶんは超えてよい。上限で切り捨てると「満タン近くで飲むと損」が頻繁に起き、原則に反する
- **`add_stamina()`は変更しないこと。** 自然回復やその他の付与は従来どおり`max`で切り捨てる。ポーション使用は専用の関数を新設する

### 0-4.【確定】所持数の表示場所は拠点画面の下部（暫定）

倉庫画面がまだ無いため、当面は拠点画面の`ResourceRow`にポーションの所持数と「使う」ボタンを置く。倉庫が実装されたらそちらへ移す。

---

## 今回のタスク

### やること
- `GameStateKeys`に定数追加
- `PomodoroConfig`に獲得レートと回復量を追加、`.tres`に値を入れる
- `GameManager`にポーション関連の関数を追加
- `pomodoro.gd`の`_return_to_base()`をポーション付与に変更
- 拠点画面にポーションの所持数表示と「使う」ボタンを追加
- `ja.csv`への追加

### やらないこと
- 倉庫画面の実装
- ポーション以外の消費アイテム
- `add_stamina()`の挙動変更（`max`切り捨てのまま）
- `initial_state_config.tres`の変更（`max: 100` / `current: 20`のまま）
- 自然回復（時間経過でスタミナが戻る仕組み）。未設計
- ポーション獲得時・使用時のアニメーション演出
- `res://autoload/`のうち`game_manager.gd`以外の変更

---

## 1. `GameStateKeys` への追加

`res://scripts/utils/state_keys.gd` の**末尾に追記**する。

> **【厳守】既存の定数を削除・改名しないこと。追記のみ。** ファイル全体を書き直さないこと。過去に既存定数が消えて全画面が起動不能になった事故がある。編集後は`read`で開き、編集前の定数がすべて残っていることを確認すること。

```gdscript
# スタミナポーション
const POTION_FOCUS_REMAINDER: String = "potion_focus_remainder"
const ITEM_STAMINA_POTION: String = "stamina_potion"
```

`ITEM_STAMINA_POTION`は`INVENTORY`の`item_id`として使う値。

---

## 2. `PomodoroConfig` と `.tres`

### 2-1. `res://resources/balance/pomodoro_config.gd` へ追記

末尾に追加する。既存フィールドは変更しない。

```gdscript
@export var potion_focus_minutes_per_unit: int = 25
@export var stamina_potion_recovery: int = 50
```

### 2-2. `res://resources/balance/pomodoro_config.tres`

`[resource]`セクションの末尾に2行追加する。

```
potion_focus_minutes_per_unit = 25
stamina_potion_recovery = 50
```

- **既存の行を消さないこと。** `presets` / `chest_contents` / `protection_*`の参照はそのまま残す
- `stamina_per_focus_minute`は**0.0に変更する**（ポーション方式に移行するため。フィールド自体は残す）
- `.tres`を編集したらGodotで開いてInspectorから値を確認すること

---

## 3. `GameManager` への追加

`res://autoload/game_manager.gd` に追加する。**既存の関数のシグネチャを変更しないこと。**

### 3-1. 状態テンプレートへの追加

`_empty_state_template()` に追加する。

```gdscript
GameStateKeys.POTION_FOCUS_REMAINDER: 0,
```

### 3-2. 追加する関数

```gdscript
# 作業分からポーションを算出して付与する。
# 前回の端数を足してから計算し、新しい端数を保存する。
# 付与した個数を返す（0個のこともある）。
func grant_stamina_potions(focus_minutes: int) -> int

# スタミナポーションの所持数を取得する
func get_stamina_potion_count() -> int

# ポーションを1個使ってスタミナを回復する。
# 所持していなければ何もせず false を返す。
func use_stamina_potion() -> bool
```

### 3-3. `grant_stamina_potions()` の実装

1. `合計分 = focus_minutes + _state[POTION_FOCUS_REMAINDER]`
2. `個数 = 合計分 / Balance.pomodoro.potion_focus_minutes_per_unit`（整数除算・切り捨て）
3. `新しい端数 = 合計分 % potion_focus_minutes_per_unit`
4. `_state[POTION_FOCUS_REMAINDER]` を新しい端数で更新する
5. 個数が1以上なら `add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, 個数, GameStateKeys.ITEM_TYPE_CONSUMABLE)` を呼ぶ
6. 個数を返す

- **`potion_focus_minutes_per_unit`が0以下の場合は`push_warning`を出して0を返す**（ゼロ除算を避けるため）
- `item_type`は必ず`ITEM_TYPE_CONSUMABLE`を渡す。省略しないこと

### 3-4. `use_stamina_potion()` の実装

1. `get_stamina_potion_count()` が0以下なら、何もせず`false`を返す
2. `INVENTORY`を`_copy_dict`で複製し、該当エントリの`ITEM_COUNT`を1減らして`_state`へ代入し直す
   - 0個になったエントリを削除するかどうかは実装者の判断でよいが、**削除する場合は図鑑の`discovered`が消えないことを確認すること**（`CODEX`は別のキーなので影響しないはず）
3. `inventory_changed(GameStateKeys.ITEM_STAMINA_POTION)` を発火する
4. **`add_stamina()`を使わずに**、スタミナを回復する
   - `stamina.current += Balance.pomodoro.stamina_potion_recovery`
   - **`max`で切り捨てないこと**（§0-3）
   - `resource_changed(GameStateKeys.STAMINA, 新しいcurrent)` を発火する
5. `true` を返す

**ここが今回いちばん間違えやすい箇所。** `add_stamina()`を呼ぶと`max`で切り捨てられ、満タン近くで飲んだときに回復量が消える。ポーション専用の加算処理を書くこと。

---

## 4. `pomodoro.gd` の変更

`res://scenes/pomodoro/pomodoro.gd` の `_return_to_base()` を変更する。**他の関数は変更しないこと。**

現在の実装：

```gdscript
	var stamina_reward: int = int(session_accumulated_focus_min * Balance.pomodoro.stamina_per_focus_minute)
	var reward_data: Dictionary = {
		GameStateKeys.REWARD_STAMINA: stamina_reward
	}
	GameManager.apply_pomodoro_rewards(reward_data)
	GameManager.claim_pending_chests()
```

変更後：

1. `GameManager.grant_stamina_potions(session_accumulated_focus_min)` を呼び、付与個数を受け取る
2. `apply_pomodoro_rewards({})` を空のDictionaryで呼ぶ
   - スタミナ・gold・素材はここでは付与しない
   - `total_pomodoro_completed`の加算と`SignalBus.pomodoro_session_completed`の発火は引き続きここで行われる
3. `GameManager.claim_pending_chests()` を呼ぶ（変更なし）
4. 付与個数と受け取った宝箱の件数を`print`に出す
5. `SceneManager.change_scene(BASE_PATH)`（変更なし）

- **完走・途中終了の分岐を作らないこと。** `_return_to_base()`は両方から呼ばれる単一の口である
- `session_accumulated_focus_min`が0でも`grant_stamina_potions(0)`を呼んでよい（端数の計算だけが走り、0個が返る）

---

## 5. 拠点画面への追加

`res://scenes/base/base_screen.tscn` / `.gd` を変更する。

### 5-1. シーン階層への追加

`ResourceRow` の中、`MaterialsDisplay` と `Spacer` の**あいだ**に追加する。

```
ResourceRow (HBoxContainer)
├─ GoldEntry
├─ StaminaEntry
├─ MaterialsDisplay
├─ PotionEntry (HBoxContainer)          ← 追加
│   ├─ NameLabel (Label)                 # text = "ui_res_stamina_potion"
│   ├─ Value (resource_display.tscn のインスタンス)
│   └─ UseButton (primary_button.tscn)   # label_key = "ui_base_use_potion"
├─ Spacer
├─ ChestBadge
├─ SaveButton
└─ BackToTitleButton
```

- `NameLabel`の`text`には翻訳キーをそのまま入れる（`auto_translate`が効く）
- 既存のノードを削除・改名しないこと

### 5-2. スクリプトへの追加

- `_ready()` で `GameManager.get_stamina_potion_count()` を読み、`Value.set_value()` に流す
- `GameManager.inventory_changed(item_id)` を購読し、`item_id == GameStateKeys.ITEM_STAMINA_POTION` のときだけ所持数を更新する
  - **他のアイテムのシグナルで所持数を書き換えないこと**
- `UseButton` 押下 → `GameManager.use_stamina_potion()` を呼ぶ
  - 戻り値が`false`（所持なし）のときは何もしない
  - 成功時、所持数とスタミナ表示は**それぞれのシグナル経由で自動更新される**。ボタンのハンドラから直接ラベルを書き換えないこと
- **所持数が0のときは `UseButton` を `disabled` にする**（押しても何も起きないボタンを押させないため）

### 5-3. 既存のstamina表示について

`StaminaEntry` は `resource_changed(STAMINA, current)` を購読して `set_value_with_max(current, max)` を呼んでいる。**この処理は変更しないこと。**

ポーションで`max`を超えた場合、`110/100` のように表示される。**これは意図した挙動であり、表示を`100/100`に丸めないこと。**

---

## 6. `ja.csv` への追加

**UTF-8（BOMなし）で保存し、編集後に再インポートすること。** 既存行と重複させないこと。

```
ui_res_stamina_potion,スタミナポーション
ui_base_use_potion,使う
```

- **`cat >` でファイル全体を上書きしないこと。** 必ず `cat >>` で追記する。過去に全体上書きで既存キーが失われた事故がある
- 追記後、`read`で開いて既存の行がすべて残っていることを確認すること

---

## 動作確認手順（完了条件）

以下をすべて満たしたら完了とする。

1. `state_keys.gd` に `POTION_FOCUS_REMAINDER` と `ITEM_STAMINA_POTION` が追加されており、**既存の定数がすべて残っている**ことを`read`で確認できる
2. `pomodoro_config.tres` に `potion_focus_minutes_per_unit = 25` と `stamina_potion_recovery = 50` が入っており、Inspectorで確認できる。**`presets`（3件）と`chest_contents`（4件）が消えていない**
3. `pomodoro_config.tres` の `stamina_per_focus_minute` が `0.0` になっている
4. ポモドーロのデバッグパネルで「分を加算」に `25` を入れて実行し、拠点へ戻ると**ポーションを1個獲得**している
5. 同じ手順で `60` を入れて実行すると**2個獲得**し、端数10分が `potion_focus_remainder` に残ることをprintで確認できる
6. 続けて `40` を入れて実行すると、端数10分と合わせて50分になり**2個獲得**、端数が0になる
7. `10` を入れて実行すると**0個**で、端数だけが増える（ポーションが増えないこと）
8. 拠点画面の下部にポーションの所持数が表示される
9. 「使う」ボタンを押すと所持数が1減り、スタミナが50増える
10. **スタミナが `current = 80` の状態で使うと `130/100` になる**（`100/100` で止まらないこと）
11. 所持数が0のとき「使う」ボタンが `disabled` になっている
12. `GameManager.add_stamina(9999)` を呼ぶと `100/100` で止まる（`add_stamina` の挙動が変わっていないこと）
13. ポモドーロを1セットも振り返り確定せずに終えても、エラーなく拠点へ戻る（`grant_stamina_potions(0)` が安全に動く）
14. 途中で「やめる」から戻った場合も、そこまでの作業分ぶんのポーションを受け取れる
15. `ja.csv` に2行が追加されており、**既存のキーがすべて残っている**ことを`read`で確認できる。画面に `ui_res_stamina_potion` のようなキー名が出ていない
16. `IMPL_LOG_TEMPLATE.md`の型に沿って `res://docs/03_log/IMPL_LOG_STAMINA_POTION.md` が生成されている

### 検証について

項目4〜7は、ポモドーロ画面のデバッグパネル（`OS.is_debug_build()`で表示される左上のパネル）を使うこと。「分を加算」で作業分を積み、「このフェーズを終わらせる」で進めて拠点へ戻る。

**「コードを確認した」「ロジック上正しい」は動作確認ではない。** 実際に動かし、「何をしたら何と表示されたか」を書くこと。

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形にする
- 状態のキーは文字列リテラルではなく `GameStateKeys` の定数を使う（**ネストしたキーも含む**）
- **既存ファイルへの追記は追記のみ。** 既存の定数・関数・キーを削除しない。ファイル全体を `cat >` で上書きしない
- **編集後は `read` で開き、編集前の内容が残っていることを確認する**
- 数値をスクリプトにハードコードしない。獲得レートと回復量は`Balance`経由
- 全ての表示テキストは `tr()`（または`auto_translate`が効く`text`への翻訳キー）を経由する
- 色・フォントは個別シーンにハードコードせず、Theme経由にする
- 画面遷移は必ず `SceneManager` 経由
- **エラー回避のために型指定・命名規則・状態アクセスのルールを緩めない。** `class_name`が認識されない場合はGodotエディタを再起動する
- **完了条件はこのファイルから項目番号ごとそのまま転記し、1項目ずつ実際に動かして検証する**
- `edit_file`は使用しない。追記は`bash`の`cat >> "パス" << 'EOF'`を使う
- Autoloadを追加しない（5つ固定）
- Input Map（`project.godot`の`[input]`）は変更しない
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
