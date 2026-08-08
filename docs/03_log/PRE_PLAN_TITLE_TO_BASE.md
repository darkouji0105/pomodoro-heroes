# PRE_PLAN：タイトル→拠点（SaveManager実装＋タイトル画面＋拠点仮シーン）

対応するEXEC：`EXEC_TITLE_TO_BASE.md`
本ファイルは実装着手前の計画レビュー用。実装完了後は `IMPL_LOG_TITLE_TO_BASE.md` を別途生成する。

> 補足：EXEC §「前提・参照ドキュメント」には `PLAN_TITLE_TO_BASE.md` への参照が記載されているが、本リポジトリには該当ファイルが存在しない（`docs/01_plan/` 配下に無し、`plan/` にも無し）。そのため本PRE_PLANはEXEC本文を一次仕様として作成する。差異が見つかったら人間に確認する。

---

## 1. 作成・変更するファイル一覧（パスと役割）

### 1-1. 編集する既存ファイル

| パス | 編集内容 |
|---|---|
| `res://autoload/save_manager.gd` | 空実装（`has_save()` 常に `false` / `load_game()` 常に `false` / `save_game()` が `void` の print ダミー）を、**実動作するJSON I/O実装に書き換える**。`save_game()` の戻り値を `void` → `bool` に変更する。`delete_save()` を新規追加する。`SAVE_DIR` / `SAVE_PATH` 定数を追加する |
| `res://autoload/game_manager.gd` | 既存関数は変更せず、`load_state(data: Dictionary) -> bool` と `mark_saved() -> void` の2関数を追加する（EXEC §2 指定）。戻り値・シグナル発火仕様は EXEC §2「実装上の注意」に従う |
| `res://project.godot` | `application/run/main_scene` を `res://scenes/title/title_screen.tscn` に設定する（EXEC §5）。`[input]` セクションは触らない（ユーザー指示厳守）。`[autoload]` も触らない（既に5件登録済み） |

### 1-2. 新規作成するファイル（シーン・スクリプト）

| パス | 役割 |
|---|---|
| `res://scenes/title/title_screen.tscn` | タイトル画面。EXEC §3 の階層どおり。`Background`（ColorRect, `#1A1418`）/ `TitleLabel`（Label, `tr()` 経由の仮タイトル）/ `ButtonContainer`（VBoxContainer）に `StartButton`（`primary_button.tscn` のインスタンス）と `DeleteSaveButton`（同、セーブあり時のみ表示）の2ボタン |
| `res://scenes/title/title_screen.gd` | タイトル画面の制御スクリプト。`extends Control`。`_ready()` で `SaveManager.has_save()` を判定し、`StartButton` の `label_key` を `ui_title_start_new` / `ui_title_start_continue` に切り替え、`DeleteSaveButton` の `visible` を制御する。`StartButton` 押下時はセーブ有無に応じて `SaveManager.load_game()` を呼び、失敗時は画面内 Label に警告表示して続行、いずれも `SceneManager.change_scene("res://scenes/base/base_screen.tscn")` で遷移する。`DeleteSaveButton` 押下時は `SaveManager.delete_save()` を呼んで表示を更新する |
| `res://scenes/base/base_screen.tscn` | 拠点画面の**仮シーン**。EXEC §4 の階層どおり。`Background`（ColorRect, `#1A1418`）/ `PlaceholderLabel`（「拠点画面（仮）」）/ `StateLabel`（GameManager 現在値表示・動作確認用）/ `SaveButton`（`primary_button.tscn` のインスタンス、`SaveManager.save_game()` 呼び出し）/ `BackToTitleButton`（同、タイトルへ戻る）。`ResourceDisplay` コンポーネントは使用しない（EXEC §4 末尾の指定） |
| `res://scenes/base/base_screen.gd` | 拠点仮シーンの制御スクリプト。`extends Control`。`_ready()` で `GameManager.get_state()` から gold/gems/stamina を読み `StateLabel.text` に整形表示する。`SaveButton` 押下時：`SaveManager.save_game()` を呼び、結果（true/false）と `last_saved_at` を `StateLabel` に追記表示する。`BackToTitleButton` 押下時：`SceneManager.change_scene("res://scenes/title/title_screen.tscn")` で戻る。`GameManager.resource_changed` 等のシグナル接続は行わない（仮シーンのため、`_ready()` 時のスナップショット表示のみで完了条件#4 を満たす） |

### 1-3. 新規作成するファイル（ドキュメント）

| パス | 役割 |
|---|---|
| `res://docs/03_log/PRE_PLAN_TITLE_TO_BASE.md` | 本ファイル（実装前の計画レビュー用） |
| `res://docs/03_log/IMPL_LOG_TITLE_TO_BASE.md` | 実装完了後、`IMPL_LOG_TEMPLATE.md` の型に沿って生成する実装ログ（EXEC §完了条件#14） |

### 1-4. 触らないもの

- `res://addons/ziva_agent/` 配下全て（AGENTS.md 遵守）
- `res://docs/` 配下のPLAN/EXECドキュメント（IMPL_LOG・PRE_PLAN を除く）
- `res://theme/main_theme.tres`（既にトマト基調ダークで実装済み）
- `res://autoload/balance.gd` / `balance.tscn` / `game_manager.gd` の既存ロジック（`load_state` / `mark_saved` の追加のみ。`_init_from_config` / `get_state` / `add_gold` 等は変更しない）
- `res://scenes/ui/components/primary_button.tscn` / `.gd`（既存実装をそのまま使う。theme_override 等で個別調整しない）
- `res://localization/`（翻訳ファイルは作らない。`tr()` が呼ばれて原文が返る状態を許容。PRE_PLAN_UI_COMMON §4-3 と同じ方針）

---

## 2. SaveManager / GameManager.load_state() の実装方針

### 2-1. SaveManager（`res://autoload/save_manager.gd`）

#### 定数

```gdscript
const SAVE_DIR: String = "user://saves/"
const SAVE_PATH: String = "user://saves/save_slot_0.json"
const CURRENT_SAVE_VERSION: int = 1   # InitialStateConfig.save_version と一致させる
```

- `CURRENT_SAVE_VERSION` は `GameStateKeys.SAVE_VERSION` の値と一致させる必要がある。`InitialStateConfig.save_version` が `int` で `@export` されているため、ここでは `1` を直書き（ヒューマンリーダブルな値）。将来 Plan でバージョンを上げる際に `Balance.initial_state.save_version` を読む方式に切り替えるかは要検討（本タスクスコープ外）
- `SAVE_DIR` の作成は `DirAccess.make_dir_recursive_absolute(SAVE_DIR)` で `save_game()` / `load_game()` 冒頭に行う（EXEC §1 実装上の注意）

#### `save_game() -> bool`（シグネチャ変更：void → bool）

処理フロー：
1. `SAVE_DIR` を `DirAccess.make_dir_recursive_absolute(SAVE_DIR)` で作成（既存でも冪等）
2. `GameManager.mark_saved()` を呼び、`last_saved_at` を最新化する（EXEC §1 末尾・§2 `mark_saved`）
3. `GameManager.get_state()` でスナップショット取得（既に `duplicate(true)` 済み）
4. `JSON.stringify(snapshot, "\t")` で文字列化（整形付き：人間デバッグ時に読みやすい）
5. `var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)`。`f == null` なら `push_error()` + `return false`
6. `f.store_string(json_text)`
7. `f.close()`（`FileAccess` は参照解放で暗黙 close される。明示的 close は不要だが、ログ出力前に呼ぶ）
8. `print("[SaveManager] save_game -> %s" % SAVE_PATH)` して `return true`

#### `load_game() -> bool`

処理フロー（EXEC §1 の「読み込みは必ずエラー処理を通すこと」を満たす）：
1. `has_save() == false` なら何もせず `return false`（早期リターン）
2. `var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)`。`f == null` なら `push_warning("[SaveManager] load_game: cannot open %s" % SAVE_PATH)` して `return false`
3. `var json_text: String = f.get_as_text()`
4. `f.close()`（同上）
5. `var data: Variant = JSON.parse_string(json_text)`。`data == null` なら `push_warning("[SaveManager] load_game: JSON parse failed")` して `return false`
6. `data is Dictionary` でない（壊れている）場合 → `push_warning` + `return false`
7. `data.has(GameStateKeys.SAVE_VERSION)` が無い → `push_warning` + `return false`（EXEC §1「save_version キーが無い」チェック）
8. `int(data[GameStateKeys.SAVE_VERSION]) != CURRENT_SAVE_VERSION` の場合 → `push_warning("save_version mismatch: have=%s, expected=%d — continuing" % [...])` して**読み込みは続行**（EXEC §1「今回は警告を出して読み込みは続行」）
9. `return GameManager.load_state(data as Dictionary)`（`load_state` 側にさらに `int()` キャストやデフォルトキー補完を任せる）

#### `has_save() -> bool`

- `FileAccess.file_exists(SAVE_PATH)` を返す。I/O を伴わないので軽く、 `_ready()` でも安心して呼べる
- セーブ途中（書込途中で電源断）のファイルは `file_exists` が true だが読込は失敗する想定。読込失敗は `load_game()` 側で `false` を返すので本関数の責務は「ファイルが存在するか」のみ

#### `delete_save() -> bool`

- `DirAccess.remove_absolute(SAVE_PATH)` を試みる。`FileAccess.file_exists(SAVE_PATH) == false` の場合は `return true`（何も消すべきものがない状態も成功扱い：べき等性確保）
- 失敗時は `push_error` して `return false`

### 2-2. GameManager への追加（`res://autoload/game_manager.gd`）

EXEC §2 の指示に従い、**既存関数は変更せず**末尾に2関数を追加する。

#### `load_state(data: Dictionary) -> bool`

処理フロー：
1. `data == null or not (data is Dictionary)` なら `return false`
2. `data.has(GameStateKeys.SAVE_VERSION)` が無い → `push_warning` + `return false`（`_state` を変更しない。EXEC §2「必須キーの存在チェック」）
3. **`data.duplicate(true)` してから `_state` に代入する**（EXEC §2「外部の Dictionary への参照を保持しないため」）。代入は `_state = data_dup` ではなく、**ネストした Dictionary / Array も含めて複製**された新しいオブジェクトにする
4. **デフォルトキーの補完**（EXEC §2「将来キーが増えたとき、古いセーブが読めなくならないようにするため」）：`_init_empty()` を先に呼んで全キーを既定値で初期化してから、保存値で上書きする。実装は `_state = _init_empty_default().duplicate(true)` のように **`_init_empty()` 相当の空 Dictionary を返すヘルパ** を使う（既存 `_init_empty()` は `_state` を上書きするため分離が必要）
5. **`int()` での明示変換**（EXEC §2「JSONは整数を float として復元する」）：`_state` に代入する前に、以下の数値キーを `int()` で変換する：
   - `GOLD` / `GEMS` / `STAMINA_CURRENT` / `STAMINA_MAX` / `PITY_COUNTERS` の各値 / `TOTAL_POMODORO_COMPLETED` / `SCENARIO_CHAPTER` / `BOSS_UNLOCKED`（bool）/ `TRAINING_MODE_UNLOCKED`（bool）/ `SAVE_VERSION`（int）/ `LAST_SAVED_AT`（String のまま）
   - `INVENTORY` 配下の `count`（int）/ `slot_position` 配下の `x` `y`（int）
   - `PENDING_CHESTS` 配下の `opened`（bool）
   - `STORY.current_chapter`（int）/ `STORY.stages[*].cleared`（bool）/ `STORY.stages[*].stars`（int）
   - `MATERIALS` 配下の各 material_id の値（int）
   - `DAILY_SHOP` / `WEEKLY_SHOP` / `MONTHLY_SHOP` 配下の `purchased_count`（int）
   - `CHARACTER_GROWTH` 配下の `level`（int）/ `stats.hp/atk/def/spd`（int）
   - `CRAFTING_QUEUE` 配下の `started_at`（String）/ `duration_sec`（int）/ `status`（String）
6. **シグナル発火**（EXEC §2「復元後、以下のシグナルを発火する」）：
   - `resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])`
   - `resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])`
   - `resource_changed.emit(GameStateKeys.STAMINA, _state[GameStateKeys.STAMINA][GameStateKeys.STAMINA_CURRENT])`（シグネチャは `int` の現在値）
   - 各素材について `material_changed.emit(material_id, amount)` を発火。`_state[GameStateKeys.MATERIALS]` のキー全部を `for` で回す（素材IDの型が String 想定。空 Dictionary ならループせず無発火でOK）
   - `pending_chests_changed.emit(get_pending_chest_count())` を発火（既存ヘルパが件数を返す）
7. その他の `screen_unlocked` / `inventory_changed` は**今回は発火しない**（EXEC §2 記載なし。素材・金・スタミナ・宝箱件数のみで十分。後続タスクの `EXEC_BASE_SCREEN.md` で必要になった時点で追加する）

#### `mark_saved() -> void`

```gdscript
func mark_saved() -> void:
	_state[GameStateKeys.LAST_SAVED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] mark_saved -> last_saved_at=%s" % _state[GameStateKeys.LAST_SAVED_AT])
```

- `_state` 直下の1キーのみ更新。シグナル発火は行わない（必要になったら将来追加）
- `SaveManager.save_game()` の中で `GameManager.mark_saved()` → `get_state()` の順で呼ぶため、`last_saved_at` が保存される

### 2-3. 型・キーの整合性

- `data` の Dictionary は JSON 復元時点で**数値が `float`、bool が `bool`、String が `String`、Dictionary / Array は `Dictionary` / `Array`**。これらは `int()` / `bool()` / `String()` / `.duplicate(true)` で正規化する
- `JSON.parse_string()` は失敗時に `null` を返す（公式仕様）。`null` チェックと `Dictionary` 型チェックの両方を行う
- ネストした Dictionary / Array は JSON 復元時点で既に新しいインスタンス（参照ではない）になっているが、AGENTS.md の方針に従い `.duplicate(true)` して `_state` に格納する。`_state` 内でさらに `_copy_dict()` / `_copy_array()` を使う必要はない（複製済みなので）

---

## 3. 各シーンの階層

### 3-1. `res://scenes/title/title_screen.tscn`

```
TitleScreen (Control)               [script=title_screen.gd, full rect, mouse_filter=Pass]
├─ Background (ColorRect)            color = Color("#1A1418"), full rect, mouse_filter=Ignore
├─ TitleLabel (Label)                text = "Pomodoro Heroes"（仮。tr("ui_title_label") 経由）, 中央上部, anchors_preset = 8
└─ ButtonContainer (VBoxContainer)   中央, anchors_preset = 8, separation = 16
	├─ StartButton (instance of res://scenes/ui/components/primary_button.tscn)
	│       label_key = "ui_title_start_new"（初期値。_ready() でセーブ有無により切替）
	└─ DeleteSaveButton (instance of res://scenes/ui/components/primary_button.tscn)
			label_key = "ui_title_delete_save"
			visible = false（初期値。_ready() でセーブあり時のみ true）
```

- ルートノードは `Control` で `anchors_preset = 15` (full rect)、「TitleScreen」PascalCase
- スクリプト `title_screen.gd` で `_ready()` 時に以下を実装：
  - `SaveManager.has_save()` を呼ぶ
  - true → `StartButton.label_key = "ui_title_start_continue"`、`DeleteSaveButton.visible = true`
  - false → `StartButton.label_key = "ui_title_start_new"`、`DeleteSaveButton.visible = false`
- `StartButton.pressed` シグナル → `_on_start_pressed` ハンドラ：セーブあり時 `SaveManager.load_game()` を呼び、戻り値 `false` の場合は `TitleLabel.text` に警告文（`tr("ui_title_load_failed")` または Label 1個を追加して警告表示）を表示して `SceneManager.change_scene()` で続行。false の場合は `SceneManager.change_scene()` で即遷移
- `DeleteSaveButton.pressed` シグナル → `_on_delete_save_pressed` ハンドラ：`SaveManager.delete_save()` を呼び、結果を `TitleLabel` 領域 or 別 Label に表示して `StartButton` の `label_key` を `ui_title_start_new` に、`DeleteSaveButton.visible` を `false` に更新
- **エラーラベル**（仮）: `ButtonContainer` の下に `ErrorLabel`（Label, 初期 `visible = false`）を追加して、load失敗 / delete失敗時に1行警告を出す。EXEC §3「load_game が失敗したときの警告表示は、Label のテキストを変える程度の最小実装でよい」

### 3-2. `res://scenes/base/base_screen.tscn`（仮シーン）

```
BaseScreen (Control)                [script=base_screen.gd, full rect]
├─ Background (ColorRect)            color = Color("#1A1418"), full rect
├─ Layout (VBoxContainer)            中央, anchors_preset = 8, separation = 16
│   ├─ PlaceholderLabel (Label)      text = "拠点画面（仮）"（tr() 経由: "ui_base_placeholder"）, 中央寄せ
│   ├─ StateLabel (Label)            text = ""（_ready() で GameManager.get_state() から組み立て）
│   ├─ SaveButton (instance of primary_button.tscn)
│   │       label_key = "ui_base_save"
│   └─ BackToTitleButton (instance of primary_button.tscn)
│           label_key = "ui_base_back_to_title"
```

- ルートノード `BaseScreen`（Control, full rect）、PascalCase
- スクリプト `base_screen.gd`：
  - `_ready()` で `GameManager.get_state()` を取得し、`StateLabel.text` に `tr("ui_base_state_format")` 風のフォーマット（または `tr()` を使わない "gold=%d, gems=%d, stamina=%d/%d" のような技術的文字列）で組み立てる
  - `SaveButton.pressed` → `_on_save_pressed`: `var ok: bool = SaveManager.save_game()` を呼び、`StateLabel.text` に追記（`"saved ok=true path=%s" % SaveManager.SAVE_PATH` 等、`tr()` 対象外の技術ログ）
  - `BackToTitleButton.pressed` → `_on_back_to_title_pressed`: `SceneManager.change_scene("res://scenes/title/title_screen.tscn")` で戻る
  - シグナル接続（`resource_changed` / `material_changed` 等）は行わない。EXEC §4「StateLabel には GameManager.get_state() から gold / gems / stamina を読んで表示する」が「_ready() 時のスナップショット表示」を指すと解釈する（リアルタイム更新は `EXEC_BASE_SCREEN.md` のスコープ。後続タスクで再設計する）
- ファイルは `res://scenes/base/base_screen.tscn`（EXEC §4 指示どおり snake_case）

### 3-3. ラベルキー（翻訳テーブル）の扱い

新規に使う翻訳キーは以下（翻訳ファイルは作らないため原文が返る）：

| キー | 想定テキスト（原文） | 用途 |
|---|---|---|
| `ui_title_label` | `Pomodoro Heroes` | TitleLabel |
| `ui_title_start_new` | `はじめから` | StartButton（セーブなし） |
| `ui_title_start_continue` | `つづきから` | StartButton（セーブあり） |
| `ui_title_delete_save` | `セーブを消す` | DeleteSaveButton |
| `ui_title_load_failed` | `セーブを読み込めませんでした。新規開始します。` | load_game 失敗時の警告 |
| `ui_title_delete_done` | `セーブを削除しました。` | delete_save 成功時の表示 |
| `ui_base_placeholder` | `拠点画面（仮）` | PlaceholderLabel |
| `ui_base_save` | `セーブする` | SaveButton |
| `ui_base_back_to_title` | `タイトルへ戻る` | BackToTitleButton |

翻訳テーブル未投入時はこれらがそのまま `tr()` 戻り値として表示される。`title_screen.gd` / `base_screen.gd` 側は `label_key` を切り替えるだけでテキストを切り替えられる。**StateLabel のフォーマット文字列は `tr()` 対象外**（数字を含む技術的ログのため、AGENTS.md「数値のみの表示は対象外」相当の解釈）。EXEC 完了条件#4 は「StateLabel に Balance.initial_state の初期値（gold等）が表示される」ことが要件で、翻訳必須ではない

### 3-4. Project Settings への反映

`project.godot` に以下を `[application]` セクションに追加：

```ini
[application]
run/main_scene="res://scenes/title/title_screen.tscn"
```

- 既存 `[input]` セクション（`pomodoro_pause_toggle` の定義）は変更しない（ユーザー指示厳守）
- 既存 `[autoload]` セクションは変更しない（5件登録済み）
- `update_project_setting` ツールで `application/run/main_scene` を更新する想定

---

## 4. 判断に迷った点（「特になし」は避ける）

1. **EXEC §2 `load_state()` の「_init_empty() の既定値で補う」実装方法** — EXEC §2 に「読み込んだデータに欠けているキーがあれば、_init_empty() の既定値で補う」とあるが、既存 `_init_empty()` は `_state` を直接上書きする副作用関数。`load_state()` の途中で呼ぶと**「保存値で上書き」が競合する**。対応は2案：
   - (a) 既存 `_init_empty()` を `_empty_state_template() -> Dictionary` 形に refactor する（**採用案**）
   - (b) `load_state()` 内で `_init_empty()` を呼んだ直後に保存値を上書きする（順序保証が必要で読みにくい）
   - **(a) 採用**：`_init_empty()` は副作用関数のまま残し（既存テストが依存）、`_empty_state_template() -> Dictionary` を新規追加して「副作用なしで空 Dictionary を返す」版を `load_state()` が使う。`_init_empty()` の本体を `_empty_state_template().duplicate(true)` を `_state` に代入する形に書き換える（差分最小）

2. **EXEC §2 で発火するシグナルの対象範囲** — EXEC §2 末尾に「`resource_changed` を GOLD / GEMS / STAMINA それぞれ」「MATERIALS の各素材について material_changed」「pending_chests_changed を発火」とあるが、`screen_unlocked` / `inventory_changed` は記載なし。**解釈**：タイトル→拠点で再描画が必要なのは金・スタミナ・素材・宝箱件数のみで、画面アンロックやインベントリ変化は拠点仮シーンでそもそも UI 表示していないため発火不要。`EXEC_BASE_SCREEN.md` で必要になった時点で追加する。IMPL_LOG §5 に「screen_unlocked / inventory_changed は発火対象外」と明記

3. **ネストした数値の `int()` キャスト戦略** — EXEC §2「gold 等の数値は int() で明示的に変換する」とあるが、`MATERIALS` 配下や `INVENTORY.count` / `STORY.stages.*.stars` などネストした全箇所を `load_state()` 内でリストアップしてキャストするのは実装が重い。対応は2案：
   - (a) `_state` に代入する前に、ホワイトリスト形式で `int()` キャストする場所を明示する（**採用案**）
   - (b) `add_gold()` 等の getter 側で `int()` キャストする（既存関数を変更することになり、AGENTS.md「既存関数は変更しない」に抵触）
   - **(a) 採用**：§2-2 で列挙したキーを中心にキャスト。**取りこぼしが起きないよう、キャスト関数を `_coerce_loaded_value(key, value)` のようなヘルパに集約**。型が期待と違うときの挙動は「`int()` で変換、失敗したら `0` / `false` / `""` の既定値」

4. **`save_version` 不一致時の扱い** — EXEC §1「`save_version` が現在のバージョンと異なる場合は、今回は警告を出して読み込みは続行する（マイグレーション処理は将来必要になった時点で実装）」。今回は `CURRENT_SAVE_VERSION = 1` 固定で `InitialStateConfig.save_version`（現状 `.tres` で空＝`0`）と一致しない可能性が高い。**警告だけ出して続行**。`.tres` 側の値も `1` に更新するかは §5-2 で扱う

5. **`title_screen.gd` で `SaveManager.has_save()` を `_ready()` で呼ぶタイミング** — Autoload の `_ready()` 順は `Balance → GameManager → SaveManager → SceneManager → SignalBus` なので、タイトル画面（`Control`）の `_ready()` 時点では全 Autoload が初期化済み。問題なし。`SceneManager.change_scene()` を `StartButton.pressed` シグナル内で呼ぶのも、`SceneManager` 初期化後なので安全

6. **`base_screen.gd` の `StateLabel` フォーマット** — EXEC §4「StateLabel には GameManager.get_state() から gold / gems / stamina を読んで表示する」とあるのみで、表示形式は未指定。**解釈**：`"gold: %d\ngems: %d\nstamina: %d/%d\n..."` のように複数行で技術ログ風に表示（`tr()` 対象外、数字のみの表示）。`tr()` を使うかどうかは EXEC §4 には明示なし。AGENTS.md「数値のみの表示は対象外」相当で `tr()` なしで実装

7. **`primary_button.tscn` のインスタンスに対する `label_key` の動的変更** — `primary_button.gd` の `label_key` setter は `is_inside_tree()` チェック付きで `text = tr(label_key)` を実行する。`_ready()` 完了後に `start_button.label_key = "ui_title_start_continue"` のように代入すれば、setter が走ってテキストが即時更新される。**問題なし**（PRE_PLAN_UI_COMMON §3-1 で確認済み）

8. **`title_screen.tscn` の `Background` を ColorRect にするか PanelContainer にするか** — EXEC §3 図では「Background (ColorRect)」。**ColorRect 採用**（`test_ui_common.tscn` の Background は PanelContainer + `theme_override_styles/panel` だが、EXEC §3 図は ColorRect と明記されている）。EXEC §3 図を一次仕様とする

9. **`title_screen.gd` で `DeleteSaveButton` 押下後にボタンを再非表示にするタイミング** — EXEC §3 5「`DeleteSaveButton` 押下時：SaveManager.delete_save() を呼び、ボタン表示を更新する」。**実装**：delete 成功時は `StartButton.label_key` を `"ui_title_start_new"` に切替 + `DeleteSaveButton.visible = false` + `ErrorLabel`（or `TitleLabel` 領域）に `tr("ui_title_delete_done")` を表示。delete 失敗時は `ErrorLabel` に警告表示して状態は変えない

10. **完了条件#10（壊れた JSON）の `user://` パス** — EXEC §完了条件#10「`user://saves/save_slot_0.json` の中身を意図的に壊す（`{{{`等を書き込む）」。Windows での実体パスは `%APPDATA%\Godot\app_userdata\pomodoro-heroes\saves\save_slot_0.json`。Project → Open User Data Folder から開ける。**検証手順**は IMPL_LOG §4 完了条件#10 の欄に明記する

11. **`load_state()` で `_state` への代入を `_state = data_dup` 形式で書くか、`_init_empty()` 後にキー単位でマージするか** — §4-1 で (a) 採用を決めた結果、**`_init_empty()` 相当の空テンプレを `_state` に代入 → 渡された `data` の各キーで上書き**の2段構えにする。`_state = data_dup` だけだと「保存データに存在しない将来のキー」が全部消えるため、EXEC §2「将来キーが増えたとき、古いセーブが読めなくならないようにするため」の要件を満たせない

12. **`SaveManager.save_game()` 内で `GameManager.mark_saved()` を呼ぶ順序** — EXEC §1 末尾「保存直前に `GameManager` の `last_saved_at` を更新する。そのための関数を `GameManager` 側に用意すること」。**順序**：`mark_saved()` → `get_state()` → `JSON.stringify()` → `FileAccess.open(WRITE)`。これにより `last_saved_at` が必ず保存される

---

## 5. 指示書に書かれていないが必要だと思われること

1. **`primary_button` の翻訳キーの最小セットを PRE_PLAN §3-3 に列挙** — EXEC には「`tr()` で囲む」「`label_key` を使う」とは書かれているが、具体的にどの翻訳キーを使うかは指示なし。今回は `ui_title_start_new` / `ui_title_start_continue` 等 8 キーを新規定義し、`.po` ファイルは作らず原文が返る状態で進める（PRE_PLAN_UI_COMMON §4-3 と同じ方針）。将来 `.po` 投入時にキーが揃っていれば一括翻訳可能

2. **`initial_state_config.tres` に初期値を設定** — 現状 `initial_state_config.tres` は空インスタンスで、`save_version = 0`、`starting_gold = 0`、`starting_scenario_chapter = 0` 等。EXEC §完了条件#4「`StateLabel` に `Balance.initial_state` の初期値（gold等）が表示される」を満たすには、最低限の初期値（gold=100, gems=0, stamina=10/10, save_version=1, scenario_chapter=1, unlocked_screens={"base": true}）を入れておく必要がある。**本PRE_PLAN では `initial_state_config.tres` の編集もスコープに含める**（指示書には書かれていないが、完了条件を満たすために必要）。値の内容は人間と相談したいが、暫定として「gold=100, gems=0, stamina={current:10, max:10}, save_version=1, scenario_chapter=1, unlocked_screens=["base"]」を入れる方針を提案する。最終決定は人間に確認

3. **完了条件#12（`change_scene_to_file` の直接呼び出しが無いこと）の検証手順** — EXEC 完了条件#12 の「画面遷移がすべて `SceneManager` 経由で行われている」を担保するため、実装後に `grep -rn "change_scene_to_file" --include="*.gd" --include="*.tscn" res/scenes/ res/autoload/` を実行し、検出される箇所が `scene_manager.gd` の `_record_history` 周辺とコメントのみであることを確認する。IMPL_LOG §4 完了条件#12 の欄に grep 結果を貼る

4. **完了条件#13（`tr()` 経由のラベル）の検証手順** — `title_screen.tscn` / `base_screen.tscn` / `title_screen.gd` / `base_screen.gd` 内で日本語文字列リテラルが含まれていないことを `grep` で確認。検出された箇所は `tr()` で囲むか `label_key` 経由に修正する。StateLabel のフォーマット文字列（数字のみ）は `tr()` 対象外（AGENTS.md「数値のみの表示は対象外」）

5. **`title_screen.gd` / `base_screen.gd` の基底クラス** — EXEC §3 / §4 には「スクリプト」のみ書かれており、基底クラスは未指定。シーングルートのノード型は `Control`（EXEC §3 図の `TitleScreen (Control)` / `BaseScreen (Control)` より明らかなので、`.gd` も `extends Control` にする。`@onready` でインスタンスを取得し、`pressed` シグナルを `connect()` する形。PRE_PLAN_UI_COMMON §5-2 と同じ判断

6. **load_state 後の `resource_changed(STAMINA, ...)` の第2引数の型** — 既存 `add_stamina()` 等の `resource_changed.emit(GameStateKeys.STAMINA, stamina[GameStateKeys.STAMINA_CURRENT])` は `int` を渡している（autoload/game_manager.gd:136）。`load_state()` でも `int` を渡す（`int(_state[GameStateKeys.STAMINA][GameStateKeys.STAMINA_CURRENT])`）。EXEC §2 には「resource_changed を GOLD / GEMS / STAMINA それぞれで発火」とあるのみで型は未指定だが、**既存シグネチャに合わせる**（呼び出し側が `int` 想定で動いている前提）

7. **壊れたセーブのバックアップ** — EXEC §1 実装上の注意には「壊れている場合は push_warning して false。ゲームを止めない」とあるが、**壊れたファイルを消すか残すか**は未指定。**残す**方針（削除するとデバッグ時に証拠が消える）。`load_game()` 失敗時に `OS.move_to_trash()` 相当の処理はしない。`delete_save()` を呼ばない限りファイルは残り続ける

8. **`SaveManager.SAVE_DIR` を公開定数にするか** — EXEC §1 サンプルコードでは `const SAVE_DIR: String = "user://saves/"` で公開。**公開する**（`base_screen.gd` で「保存しました %s」表示のときに `SaveManager.SAVE_DIR` を参照したいため）。`const` なので呼び出し側からは `SaveManager.SAVE_DIR` で参照可能（GDScript の Autoload は名前空間としてアクセス可能）

9. **「メインシーン未設定」状態での `F5` 起動** — 現時点（実装前）で Project Settings のメインシーンが空だと、Godot の `F5` で「シーンが指定されていません」ダイアログが出る。実装完了時点で `application/run/main_scene = res://scenes/title/title_screen.tscn` が設定済みであることを完了条件#1 と一緒に確認する。`update_project_setting` ツールの呼び出しが正常に反映されたか `get_project_info()` で再確認

10. **`IMPL_LOG_TITLE_TO_BASE.md` の生成** — EXEC §完了条件#14。`IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_TITLE_TO_BASE.md` に生成。セクション5（逸脱・迷った判断）は本PRE_PLAN §4 をベースに必ず埋める。セクション4（完了条件チェック）は EXEC §完了条件 1〜14 を1項目ずつ print / grep / playtest ログで検証した結果を貼る

## 6. 人間による承認と決定事項（実装時はここを最優先で従うこと）

本PRE_PLANは人間のレビューを経て承認済み。§1〜§5の方針は基本的にそのまま
実装してよいが、以下の決定事項が §1〜§5 の記述と矛盾する場合は
**この §6 を優先する。**

### 6-1. 【必須】initial_state_config.tres に値を入れる

§5-2 の指摘は正しい。`res://resources/balance/initial_state_config.tres`
が空のままだと完了条件#4 を満たせない。**今回のスコープに含める。**
値は以下で確定（人間が決定済み・変更しないこと）：

| プロパティ | 値 |
|---|---|
| `starting_gold` | `100` |
| `starting_gems` | `0` |
| `starting_stamina_current` | `10` |
| `starting_stamina_max` | `10` |
| `starting_materials` | `{ "construction_material": 5 }` |
| `initially_unlocked_screens` | `["guild", "adventure_select", "pomodoro", "settings", "scenario"]` |
| `starting_scenario_chapter` | `1` |
| `save_version` | `1` |

`initially_unlocked_screens` は `DATA_SCHEMA.md`「1. 拠点（共通データ）」の
`unlocked_screens` に対応させている。**`"base"` は含めない**
（拠点はハブ画面であり、遷移ボタンの対象ではないため）。

`save_version = 1` は `SaveManager.CURRENT_SAVE_VERSION` と一致させること。
これにより §4-4 で懸念されていたバージョン不一致の警告は出なくなる。

### 6-2. 【簡略化】int() キャストの対象を限定する

§2-2 手順5 および §4-3 で、ネストした全数値キーを列挙してキャストする
案が示されているが、**実装が重すぎるため対象を限定する。**

今回 `int()` 変換するのは以下のみ：
- `GameStateKeys.GOLD`
- `GameStateKeys.GEMS`
- `GameStateKeys.STAMINA` 配下の `STAMINA_CURRENT` / `STAMINA_MAX`
- `GameStateKeys.TOTAL_POMODORO_COMPLETED`
- `GameStateKeys.SCENARIO_CHAPTER`
- `GameStateKeys.SAVE_VERSION`
- `GameStateKeys.MATERIALS` 配下の各素材の値

上記以外（`INVENTORY` の `count`、`STORY.stages.*.stars`、
`CHARACTER_GROWTH` の `level` / `stats`、`CRAFTING_QUEUE` の
`duration_sec`、`DAILY_SHOP` 等の `purchased_count`）は**今回は変換しない。**
理由：これらのデータを生成する画面がまだ実装されておらず、
セーブに値が入らないため実害が出ない。
そのデータを実際に使う画面のタスクで対応する。

`_coerce_loaded_value()` のような汎用ヘルパは**今回作らない**
（対象が少なく、直接書いたほうが読みやすいため）。

### 6-3. 【訂正】PLAN_TITLE_TO_BASE.md は存在する

冒頭の補足で「該当ファイルが存在しない」としているが、
`res://docs/01_plan/PLAN_TITLE_TO_BASE.md` に配置されているはず。
見つからない場合は配置漏れであり、EXEC を一次仕様として進めてよい
（EXEC には必要な情報がすべて含まれている）。

### 6-4. そのまま採用する判断

以下は人間が確認済み。記述どおり実装してよい：
§4-1（`_empty_state_template()` への分離）、§4-2（発火シグナルの範囲）、
§4-4〜§4-12、§5-1、§5-3〜§5-10

### 6-5. 実装時の作業上の注意

- ファイルは1つずつ順番に作成する。1回のツール呼び出しに長い本文を
  詰め込むと失敗するため、必要なら分割して書き込む
- `Input Map`（`project.godot` の `[input]`）は変更しない
- `[autoload]` は変更しない（5件登録済み・順序も正しい）
- 実装後、EXEC の完了条件14項目を1つずつ実際に確認する
- 最後に `res://docs/03_log/IMPL_LOG_TITLE_TO_BASE.md` を
  `IMPL_LOG_TEMPLATE.md` の型で生成する
