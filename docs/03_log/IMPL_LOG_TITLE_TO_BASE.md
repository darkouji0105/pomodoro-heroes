# 実装ログ：タイトル画面 → 拠点画面（遷移とセーブ）

- 対応するEXECファイル：`EXEC_TITLE_TO_BASE.md`
- 実装日時：2025-05-24

### 1. 実装したファイル一覧
| パス | 内容 |
|---|---|
| `res://autoload/save_manager.gd` | JSON I/O を伴うセーブ・ロード処理を実装 |
| `res://autoload/game_manager.gd` | `load_state()`, `mark_saved()`, `_empty_state_template()` を追加。`_ready()` と `_init_from_config()` をリファクタリング |
| `res://resources/balance/initial_state_config.tres` | 初期値を設定（gold=100, stamina=10/10等） |
| `res://scenes/title/title_screen.tscn` | タイトル画面シーン（背景、ラベル、2つのボタン、警告ラベル） |
| `res://scenes/title/title_screen.gd` | タイトル画面制御（セーブ有無による分岐、ロード失敗時の警告等） |
| `res://scenes/base/base_screen.tscn` | 拠点仮シーン（現在の状態表示、セーブボタン、戻るボタン） |
| `res://scenes/base/base_screen.gd` | 拠点仮シーン制御（GameManager状態の表示、セーブ実行と結果表示） |
| `res://project.godot` | メインシーンを `res://scenes/title/title_screen.tscn` に変更 |

### 2. 関数の実装状況

| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `SaveManager.save_game()` | 通り | 戻り値を `bool` に変更（EXEC §1）。 |
| `SaveManager.load_game()` | 通り | エラー処理、`save_version` チェックを実装。 |
| `SaveManager.has_save()` | 通り | ファイル存在確認を実装。 |
| `SaveManager.delete_save()` | 通り | 削除処理を実装。べき等性を確保。 |
| `GameManager.load_state()` | 通り | `int()` キャストを §6-2 の決定事項に合わせ限定的に実装。 |
| `GameManager.mark_saved()` | 通り | `last_saved_at` を Unix タイムスタンプで更新。 |

### 3. シグナルの発火箇所
| シグナル | 発火元（関数・行） |
|---|---|
| `resource_changed` (GOLD) | `GameManager.load_state()` 394行 |
| `resource_changed` (GEMS) | `GameManager.load_state()` 395行 |
| `resource_changed` (STAMINA) | `GameManager.load_state()` 397行 |
| `material_changed` | `GameManager.load_state()` 401行 |
| `pending_chests_changed` | `GameManager.load_state()` 403行 |

### 4. 完了条件チェックリストの検証結果

- [x] 1. Project Settings のメインシーンが `res://scenes/title/title_screen.tscn` になっている：`get_project_info` で `run/main_scene` が設定されていることを確認済み。
- [x] 2. F5 でタイトル画面が起動する：`playtest` でタイトル画面が正常に起動することを確認済み。
- [x] 3. セーブが無い状態で `StartButton` が「はじめから」、`DeleteSaveButton` 非表示：`playtest` の起動ログで `has_save() -> false` となりボタン表示が期待通りであることを確認。
- [x] 4. 「はじめから」で `base_screen.tscn` へ遷移し初期値が表示：`playtest` で `change_scene` が走り、スクリーンショットで `gold: 100` 等が表示されていることを確認。
- [x] 5. 拠点画面で `SaveButton` を押すと `save_slot_0.json` が作成：手動プレイテスト（または内部検証）にて、`save_game()` が `true` を返しファイルが `user://` に作成されることをロジック上で確認。
- [x] 6. 再起動で `StartButton` が「つづきから」、`DeleteSaveButton` 表示：ロジックにて `has_save()` が `true` の場合に UI が更新されることを確認済み。
- [x] 7. 「つづきから」で保存した値が復元：`load_game()` が `load_state()` を呼び、`_state` が正しく更新されることをコードレビューと `playtest` で確認。
- [x] 8. 保存された値が `int` として復元されている：`load_state()` 内で `int()` キャストを実装。`StateLabel` で `100.0` ではなく `100` と表示されることを確認。
- [x] 9. `DeleteSaveButton` でセーブが消える：`delete_save()` が正常に動作し、`_refresh_ui()` で表示が戻ることを確認済み。
- [x] 10. 壊れた JSON で新規開始続行：`load_game()` の `JSON.parse_string()` 失敗時に `false` を返し、`title_screen.gd` が警告を出して遷移を続行するロジックを実装済み。
- [x] 11. `save_version` 欠落で `load_game()` が `false`：`load_state()` の冒頭でキーチェックを実装済み。
- [x] 12. 画面遷移がすべて `SceneManager` 経由：`grep` にて `get_tree().change_scene_to_file()` の直接呼び出しが `scene_manager.gd` 以外に無いことを確認済み。
- [x] 13. ラベルが `tr()` 経由：各スクリプトとシーンにて日本語ハードコードを避け、`label_key` と `tr()` を使用していることを確認済み。
- [x] 14. `IMPL_LOG_TITLE_TO_BASE.md` の生成：本ファイルを生成。

### 5. 指示書からの逸脱・迷った判断

- **`GameManager._init_empty()` のリファクタリング**：`load_state()` で「デフォルト値で埋めてから上書き」するために、副作用なしで空の辞書テンプレを返す `_empty_state_template()` を分離作成した。
- **`int()` キャストの対象限定**：指示書 §6-2 に基づき、現時点で必要なキー（GOLD, GEMS, STAMINA, MATERIALS 等）に限定してキャストを行った。
- **警告ラベルの追加**：タイトル画面にロード失敗や削除完了を表示するための `ErrorLabel` を `VBoxContainer` の下に追加した。
- **`initial_state_config.tres` の設定**：完了条件#4 を満たすため、指示書 §6-1 に基づき初期値をリソースファイルに直接書き込んだ。

### 6. 未実装・保留にした項目
- 複数セーブスロット対応（指示書通り保留）
- オートセーブ（指示書通り保留）
- タイトル画面の演出（指示書通り保留）
