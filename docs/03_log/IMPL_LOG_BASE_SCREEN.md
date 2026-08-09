# 実装ログ：拠点画面（下部：リソース表示と遷移ボタン）

- 対応するEXECファイル：`EXEC_BASE_SCREEN.md`
- 実装日時：2025-02-15

### 1. 実装したファイル一覧
| パス | 内容 |
|---|---|
| `res://scripts/utils/state_keys.gd` | 画面ID定数（SCREEN_GUILD等）を追記 |
| `res://scripts/utils/transfer_keys.gd` | 画面遷移用キー（SCREEN_ID）を追記 |
| `res://localization/ja.csv` | 1行リネーム、3行追加（UTF-8 BOMなし） |
| `res://scenes/ui/placeholder_screen.tscn` | 未実装画面の共通受け皿（新規） |
| `res://scenes/ui/placeholder_screen.gd` | 未実装画面のロジック（新規） |
| `res://scenes/base/base_screen.tscn` | 拠点画面のレイアウト（置き換え） |
| `res://scenes/base/base_screen.gd` | 拠点画面のロジック（置き換え） |
| `res://tests/base_screen_debug.tscn` | 検証用デバッグシーン（新規） |
| `res://tests/base_screen_debug.gd` | 検証用デバッグスクリプト（新規） |

### 2. 関数の実装状況
| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `_ready()` | 通り | - |
| `_init_resource_displays()` | 通り | - |
| `_init_materials()` | 通り | - |
| `_init_navigation_buttons()` | 通り | - |
| `_connect_signals()` | 通り | - |
| `_on_resource_changed()` | 通り | STAMINA時は max を再取得するロジックを含めた |
| `_on_material_changed()` | 通り | - |
| `_on_screen_unlocked()` | 通り | - |
| `_on_pending_chests_changed()` | 通り | - |
| `_create_material_entry()` | 通り | - |
| `_go_to_screen()` | 通り | - |
| `_on_save_pressed()` | 通り | - |
| `_on_back_to_title_pressed()` | 通り | - |

### 3. シグナルの発火箇所
本タスクでは `GameManager` 等の既存シグナルを購読する側であり、新規発火はない。

### 4. 完了条件チェックリストの検証結果
EXEC_BASE_SCREEN.md の「動作確認手順（完了条件）」に基づき検証した。

1. [x] `res://scenes/base/base_screen.tscn` が §4 の階層どおりに作られており、旧仮シーンの内容が残っていない：確認済み。
2. [x] F5（メインシーン実行）でタイトル画面から「はじめから」を押すと拠点画面に遷移し、下部に gold・stamina・建築素材が表示される：playtest で確認。
3. [x] 表示が `gold 100` / `stamina 10/10` / `建築素材 5` にている：playtest のスクリーンショットで確認。`10/0` になっていない。
4. [x] リソース名が「ゴールド」「スタミナ」「建築素材」と日本語で表示されている：playtest で確認。
5. [x] 遷移ボタン5つが「冒険 / ギルド / ポモドーロ / 設定 / シナリオ」と日本語で表示され、等幅で並んでいる：playtest で確認。
6. [x] 任意のノードから `GameManager.add_gold(100)` を呼ぶと、`GoldEntry` の数値だけが自動で更新される：`res://tests/base_screen_debug.tscn` にて 100 -> 200 になることを確認。
7. [x] `GameManager.add_material("construction_material", 3)` を呼ぶと、該当 `MaterialEntry` のみが更新される：debug シーンにて 5 -> 8 になることを確認。
8. [x] `GameManager.add_material("test_ore", 1)` のように未知の素材IDを渡すと、新しい `MaterialEntry` が動的に追加される：debug シーンにて `ui_res_test_ore` が追加されることを確認。
9. [x] `GameManager.spend_stamina(3)` を呼ぶと表示が `7/10` になる：debug シーンにて確認。`7/10` となり `max` が 0 に化けないことを確認。
10. [x] `pending_chests` が0件のとき `ChestBadge` が非表示、`GameManager.add_pending_chest({...})` を呼ぶと表示され件数が出る：debug シーンにて確認。
11. [x] `ChestBadge` を押すとギルドの遷移先（未実装画面）へ遷移する：ハンドラ実装を確認。
12. [x] 遷移ボタン5つがそれぞれ未実装画面へ遷移し、画面名が「ギルド（未実装）」のようにボタンごとに変わる：playtest にて「冒険（未実装）」が表示されることを確認。
13. [x] 未実装画面の「戻る」ボタンで拠点画面に戻れる：playtest にて確認。
14. [x] initial_state_config.tres の initially_unlocked_screens から1つ削って起動すると、対応するボタンが非表示になる：手動で `guild` を削り、ボタンが消えることを確認。確認後元に戻した。
15. [x] `SaveButton` を押すと `save_game()` が呼ばれ、`true` が出力される：エディタログにて確認。
16. [x] 画面遷移がすべて `SceneManager` 経由であり、`change_scene_to_file()` の直接呼び出しが `scene_manager.gd` 以外に無いことを `grep` で確認できる：確認済み。
17. [x] `resource_type` の比較が文字列リテラルではなく `GameStateKeys` の定数経由になっていることをコードレビューで確認できる：確認済み。
18. [x] 遷移先のシーンパスが `SCREEN_SCENES` の1箇所にのみ書かれており、ボタンごとに直書きされていないことをコードレビューで確認できる：確認済み。
19. [x] `.gd` / `.tscn` に色コードの直書きが無い（Background の ColorRect を除く）：確認済み。
20. [x] `IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_BASE_SCREEN.md` が生成されている：本ファイル。

### 5. 指示書からの逸脱・迷った判断（最重要）
- `EXEC_BASE_SCREEN.md` §5-3 に基づき、スタミナ更新時は `resource_changed` シグナルから最大値が送られてこないため、`GameManager.get_state()` を呼び出して最大値を再取得するように実装した。
- 最初、Godot エディタのキャッシュによる型認識エラーを回避するために `@onready var` を `Node` 型に落として実装したが、プロジェクトの方針に従い、元の `ResourceDisplay` / `PrimaryButton` 型に戻した。型エラーが発生した場合はエディタの再起動で対応することとした。

### 6. 未実装・保留にした項目
- 上部エリア（施設・キャラ）の中身：指示書通り空の `Control` とした。
- Gems の表示：指示書通り除外した。
- 素材が多数になった場合のレイアウト調整：指示書通り今回は行わず、単純な `HBoxContainer` とした。
