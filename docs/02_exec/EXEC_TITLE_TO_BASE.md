# 【実行指示書】タイトル画面 → 拠点画面（遷移とセーブ）

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・状態構造の表・Autoloadの登録順
- `PLAN_TITLE_TO_BASE.md`：この実行指示書のもとになった第2層の作戦計画書

### 既存の実装状況

| 対象 | 状態 |
|---|---|
| `GameManager` | 実装済み。`get_state()`（スナップショット返却）まで動作 |
| `Balance` | 実装済み。`initial_state`（`InitialStateConfig`）から初期化される |
| `SceneManager` | 実装済み。`change_scene()` / `change_scene_with_data()` / `consume_transfer_data()` が動作 |
| `SaveManager` | **空実装のまま**（`has_save()`が常にfalse）。今回ここを実装する |
| `main_theme.tres` | 実装済み。プロジェクト全体のデフォルトThemeに設定済み |
| `primary_button.tscn` | 実装済み。`label_key`で`tr()`経由のテキスト設定 |

---

## 今回のタスク

タイトル画面を作り、セーブの有無に応じて分岐して拠点画面へ遷移できるようにする。あわせて、**空実装のままだった`SaveManager`を実際に動くようにする**。

### やること
- `SaveManager` の実装（JSON形式で `user://saves/` に保存・読込）
- `GameManager.load_state()` の追加（セーブデータから状態を復元する関数。現状存在しない）
- タイトル画面（`title_screen.tscn`）の作成
- 拠点画面の**仮シーン**（`base_screen.tscn`）の作成 — 遷移先として最小限のもののみ
- Project Settings のメインシーンを `title_screen.tscn` に設定

### やらないこと
- **拠点画面の中身の実装**（リソース表示・遷移ボタン・施設描画等）。今回は「タイトルから遷移できた」ことが分かる最小限の仮シーンのみ。中身は`PLAN_BASE_SCREEN.md`をもとにした別タスクで作る
- 複数セーブスロット対応（1セーブのみ）
- オートセーブ（保存タイミングの設計は今回のスコープ外。手動で`save_game()`を呼んだときだけ保存する）
- タイトル画面の演出・アニメーション
- 設定画面・クレジット等への遷移

---

## 1. SaveManager の実装

`res://autoload/save_manager.gd` を書き換える。**`GameManager`が持つ状態を丸ごとJSONにして保存する。**

### 保存先（決定済み・変更しないこと）

- ディレクトリ：`user://saves/`
- ファイル名：`save_slot_0.json`
- 理由：Steamクラウドセーブがフォルダ単位の同期のため（`GODOT_SETUP.md` 6章）。実行ファイルと同じ場所や複数箇所に散らさない

### 実装する関数

```gdscript
extends Node

const SAVE_DIR: String = "user://saves/"
const SAVE_PATH: String = "user://saves/save_slot_0.json"

# GameManagerの現在の状態をJSONで保存する。
# 保存前にlast_saved_atを更新すること。
func save_game() -> bool:
	pass

# セーブがあれば読み込んでGameManagerに反映しtrueを返す。
# セーブが無い／壊れている場合は何もせずfalseを返す。
func load_game() -> bool:
	pass

# セーブファイルが存在するか
func has_save() -> bool:
	pass

# セーブを削除する（テスト・デバッグ用）
func delete_save() -> bool:
	pass
```

### 実装上の注意

- `save_game()` の戻り値は `bool` に変更する（`PLAN_COMMON_INFRA.md`では`void`だったが、書き込み失敗を呼び出し元が検知できないため）。この変更は`PLAN_COMMON_INFRA.md`にも反映すること
- `SAVE_DIR` が存在しない場合は `DirAccess.make_dir_recursive_absolute()` で作成する
- 保存内容は `GameManager.get_state()` の返り値をそのまま `JSON.stringify()` する
- **読み込みは必ずエラー処理を通すこと**：
  - ファイルが開けない → `false`
  - `JSON.parse_string()` が `null` を返す（壊れている） → `push_warning`して`false`。**ゲームを止めない**
  - パースできたが `save_version` キーが無い → 壊れているとみなし`false`
- `save_version` が現在のバージョンと異なる場合は、今回は**警告を出して読み込みは続行**する（マイグレーション処理は将来必要になった時点で実装）
- 保存直前に `GameManager` の `last_saved_at` を更新する。そのための関数を`GameManager`側に用意すること（下記2参照）

---

## 2. GameManager への追加

`res://autoload/game_manager.gd` に以下を追加する。**既存の関数は変更しないこと。**

```gdscript
# セーブデータから状態を復元する。
# SaveManagerからのみ呼ばれることを想定。
# 復元後、画面が再描画できるよう主要なシグナルを発火すること。
func load_state(data: Dictionary) -> bool:
	pass

# 保存直前に呼ばれ、last_saved_atを更新する
func mark_saved() -> void:
	pass
```

### `load_state()` の実装上の注意

- 渡された `data` をそのまま `_state` に代入せず、**`duplicate(true)` してから代入する**（外部のDictionaryへの参照を保持しないため）
- **必須キーの存在チェックを行う**：`GameStateKeys.SAVE_VERSION` が無ければ壊れているとみなし、`_state`を変更せず`false`を返す
- 読み込んだデータに欠けているキーがあれば、`_init_empty()` の既定値で補う（将来キーが増えたとき、古いセーブが読めなくならないようにするため）
- 復元後、以下のシグナルを発火する（拠点画面が表示を更新できるようにするため）：
  - `resource_changed` を `GOLD` / `GEMS` / `STAMINA` それぞれで発火
  - `MATERIALS` の各素材について `material_changed` を発火
  - `pending_chests_changed` を発火
- **JSONは整数を`float`として復元する**点に注意。`gold`等の数値は`int()`で明示的に変換すること。これを怠ると`"gold": 100.0`のような表示になる

---

## 3. タイトル画面

`res://scenes/title/title_screen.tscn`

```
TitleScreen (Control)                    # full rect
├─ Background (ColorRect)                # 背景色はTheme外のため直接指定可
├─ TitleLabel (Label)                    # 中央上部
└─ ButtonContainer (VBoxContainer)       # 中央
    ├─ StartButton (primary_button.tscn のインスタンス)
    └─ DeleteSaveButton (primary_button.tscn のインスタンス)   # セーブがある時のみ表示
```

- `Background` の色は `#1A1418`（`PLAN_UI_COMMON.md` 2章の背景色）
- `TitleLabel` のテキストは仮でよい（正式なタイトル名は未定）。`tr()`で囲むこと
- スクリプト：`res://scenes/title/title_screen.gd`

### 挙動

1. `_ready()` で `SaveManager.has_save()` を確認する
2. セーブあり → `StartButton` のラベルを「つづきから」、`DeleteSaveButton` を表示
3. セーブなし → `StartButton` のラベルを「はじめから」、`DeleteSaveButton` を非表示
4. `StartButton` 押下時：
   - セーブあり → `SaveManager.load_game()` を呼ぶ。**失敗した場合は、警告を画面に表示して新規開始として続行する**（ゲームを止めない）
   - セーブなし → 何もしない（`GameManager`は`Balance.initial_state`で初期化済み）
   - どちらの場合も `SceneManager.change_scene("res://scenes/base/base_screen.tscn")` で遷移
5. `DeleteSaveButton` 押下時：`SaveManager.delete_save()` を呼び、ボタン表示を更新する

### 実装上の注意

- ボタンのラベルは `label_key` を使い、`tr()` 経由にする。日本語をハードコードしない
- **`get_tree().change_scene_to_file()` を直接呼ばない。** 必ず `SceneManager` 経由
- `load_game()` が失敗したときの警告表示は、`Label` のテキストを変える程度の最小実装でよい

---

## 4. 拠点画面（仮シーン）

`res://scenes/base/base_screen.tscn`

**今回は遷移先として存在することだけが目的。** 中身は`PLAN_BASE_SCREEN.md`をもとにした別タスクで作る。

```
BaseScreen (Control)                     # full rect
├─ Background (ColorRect)                # #1A1418
├─ PlaceholderLabel (Label)              # 「拠点画面（仮）」等
├─ StateLabel (Label)                    # GameManagerの現在値を表示（動作確認用）
├─ SaveButton (primary_button.tscn)      # 押すとSaveManager.save_game()
└─ BackToTitleButton (primary_button.tscn)  # タイトルへ戻る
```

- `StateLabel` には `GameManager.get_state()` から gold / gems / stamina を読んで表示する
- `SaveButton` は動作確認用。押すと `SaveManager.save_game()` を呼び、成功したかを`StateLabel`に表示する
- スクリプト：`res://scenes/base/base_screen.gd`
- **リソース表示に `resource_display.tscn` を使わないこと**（本番の拠点画面で改めて設計するため、ここでは`Label`1つで十分）

---

## 5. Project Settings

- **Application → Run → Main Scene** に `res://scenes/title/title_screen.tscn` を設定する
- **Input Map は変更しないこと**

---

## 動作確認手順（完了条件）

以下をすべて満たしたら完了とする。

1. Project Settings のメインシーンが `res://scenes/title/title_screen.tscn` になっている
2. **F5**（メインシーン実行）でタイトル画面が起動する
3. セーブが無い状態で起動すると `StartButton` が「はじめから」になり、`DeleteSaveButton` が非表示になっている
4. 「はじめから」を押すと `base_screen.tscn` へ遷移し、`StateLabel` に `Balance.initial_state` の初期値（gold等）が表示される
5. 拠点画面で `GameManager.add_gold(500)` 相当の変化を起こしてから `SaveButton` を押すと、`user://saves/save_slot_0.json` が作成される
6. 一度ゲームを終了して再起動すると、`StartButton` が「つづきから」になり、`DeleteSaveButton` が表示される
7. 「つづきから」を押すと拠点画面に遷移し、`StateLabel` に**保存した時点の値**（gold=500等）が表示される
8. 保存された値が `int` として復元されている（`500.0` のような`float`表示になっていない）
9. `DeleteSaveButton` を押すとセーブが消え、再起動すると「はじめから」に戻る
10. `user://saves/save_slot_0.json` の中身を意図的に壊す（`{{{`等を書き込む）と、`load_game()`が`false`を返し、**警告表示のみで新規開始として続行できる**（クラッシュしない）
11. `save_slot_0.json` から `save_version` キーを削除すると、`load_game()`が`false`を返す
12. 画面遷移がすべて `SceneManager` 経由で行われている（`change_scene_to_file()` の直接呼び出しが無い）ことをコードレビューで確認できる
13. ボタンのラベルが `tr()` 経由になっており、日本語がハードコードされていないことをコードレビューで確認できる
14. `IMPL_LOG_TEMPLATE.md`の型に沿って `res://docs/03_log/IMPL_LOG_TITLE_TO_BASE.md` が生成されている

### セーブファイルの場所（確認用）

Windows：`%APPDATA%\Godot\app_userdata\<プロジェクト名>\saves\save_slot_0.json`

エディタからは **Project → Open User Data Folder** で開ける。

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形にする
- 状態のキーは文字列リテラルではなく `GameStateKeys` の定数を使う（**ネストしたキーも含む**）
- 全ての表示テキストは `tr()` で囲む（数値のみの表示は対象外）
- 色・フォントは個別シーンにハードコードせず、Theme経由にする（背景色のColorRectは例外）
- 画面遷移は必ず `SceneManager` 経由
- `res://addons/` の既存ファイルには無断で触れない
- 新しいフォルダが必要になった場合は、勝手に作らず人間に提案してから作成する
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
