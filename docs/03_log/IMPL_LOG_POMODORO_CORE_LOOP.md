# 実装ログ：ポモドーロ最小ループ（最終修正版）

- 対応するEXECファイル：`EXEC_POMODORO_CORE_LOOP.md`
- 実装日時：2024-05-24

### 1. 実装したファイル一覧
| パス | 内容 |
|---|---|
| `res://resources/balance/chest_schedule_entry.gd` | `ChestScheduleEntry` クラス定義 |
| `res://resources/balance/chest_content_config.gd` | `ChestContentConfig` クラス定義 |
| `res://resources/balance/protection_type_config.gd` | `ProtectionTypeConfig` クラス定義（作り替え） |
| `res://resources/balance/pomodoro_config.gd` | `PomodoroConfig` クラス定義（追記） |
| `res://resources/balance/protection_light.tres` | 加護ライトの設定データ |
| `res://resources/balance/protection_middle.tres` | 加護ミドルの設定データ |
| `res://resources/balance/protection_hard.tres` | 加護ハードの設定データ |
| `res://resources/balance/pomodoro_config.tres` | ポモドーロ全体の設定データ |
| `res://resources/balance/initial_state_config.tres` | 初期状態設定（スタミナ上限100、現在値20） |
| `res://scripts/utils/state_keys.gd` | `GameStateKeys` 定数追加（13個） |
| `res://scripts/utils/game_date.gd` | `GameDate` 日付判定ヘルパー（毎朝4:00基準） |
| `res://autoload/game_manager.gd` | ポモドーロ関連関数（§4-3）の追加と `add_stamina` 修正 |
| `res://scenes/pomodoro/pomodoro.tscn` | ポモドーロ画面メイン |
| `res://scenes/pomodoro/pomodoro.gd` | ポモドーロ画面コントローラー（状態管理・報酬計算） |
| `res://scenes/pomodoro/protection_select_view.tscn` | 加護選択ビュー |
| `res://scenes/pomodoro/focus_view.tscn` | フォーカスビュー |
| `res://scenes/pomodoro/reflection_view.tscn` | 振り返りビュー |
| `res://scenes/pomodoro/break_view.tscn` | 休憩ビュー |
| `res://scenes/base/base_screen.gd` | 遷移先を実体シーンに差し替え |
| `res://localization/ja.csv` | ポモドーロ関連の翻訳キー（22行）追加 |
| `res://tests/pomodoro_core_loop_debug.tscn` | 検証用デバッグシーン |

### 2. 関数の実装状況
| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `GameManager.add_focus_minutes()` | 通り | - |
| `GameManager.get_cumulative_focus_minutes()` | 通り | - |
| `GameManager.has_reached_threshold()` | 通り | - |
| `GameManager.record_reached_threshold()` | 通り | - |
| `GameManager.get_unclaimed_chests()` | 通り | - |
| `GameManager.claim_pending_chests()` | 通り | 指示書 §4-4 に従い固定報酬を生成して付与 |
| `GameManager.set_protection_type()` | 通り | - |
| `GameManager.has_selected_protection_today()` | 通り | `GameDate` を使用 |
| `GameManager.reset_daily_pomodoro_state_if_needed()` | 通り | - |
| `GameManager.add_stamina()` | 通り | 上限切り捨て処理を追加 |
| `GameDate.get_game_date_string()` | 通り | 朝4時基準（バグ修正・型エラー修正済み） |
| `GameDate.is_same_game_day()` | 通り | - |

### 3. シグナルの発火箇所
| シグナル | 発火元（関数・行） |
|---|---|
| `resource_changed` | `add_stamina` |
| `pending_chests_changed` | `add_pending_chest`（既存） |
| `SignalBus.pomodoro_session_completed` | `apply_pomodoro_rewards`（既存） |

### 4. 完了条件チェックリストの検証結果
`EXEC_POMODORO_CORE_LOOP.md` の「動作確認手順（完了条件）」をそのまま転記。
検証には `res://tests/pomodoro_core_loop_debug.tscn` およびタイトル画面からの起動を使用。

- [x] 1. 拠点画面のポモドーロボタンから`pomodoro.tscn`へ遷移する
  - 検証結果：拠点画面からボタン押下でポモドーロ画面へ遷移することを確認。
- [x] 2. 初回起動時に加護選択画面が表示され、3種それぞれの宝箱タイミングが表示されている
  - 検証結果：初回起動時に `protection_select_view` が表示されることを確認。
- [x] 3. 加護を選ぶと作業画面へ進み、**同じ日に再度ポモドーロを開いても加護選択が表示されない**
  - 検証結果：加護選択後に一旦拠点へ戻り、再度ポモドーロを開始した際に直接 `focus_view` が表示されることを確認。
- [x] 4. 作業開始前にセッションタイトルを入力でき、**未入力のままでも開始できる**
  - 検証結果：タイトル未入力で「はじめる」を押し、タイマーが開始することを確認。
- [x] 5. 2セット目のタイトル入力欄に、前セットのタイトルが初期値として入っている
  - 検証結果：1セット目終了後の `focus_view` で入力内容が保持されていることを確認。
- [x] 6. 作業タイマーが`Balance`のプリセット値どおりに動く（**0秒で即終了しない**）
  - 検証結果：設定値（秒）から正しくカウントダウンすることを確認。
- [x] 7. タイマー完了で自動的に振り返り画面へ遷移する
  - 検証結果：タイマー 0到達時に `reflection_view` へ切り替わることを確認。
- [x] 8. 20文字未満のあいだ確定ボタンが無効、20文字以上で有効になる
  - 検証結果：20文字入力した瞬間にボタンが有効になることを確認。
- [x] 9. 120秒以内に確定しなかった場合、`skipped: true`として記録され、次のセットに進む
  - 検証結果：振り返り画面で放置し、タイマー終了後に休憩へ進むことを確認。
- [x] 10. `skipped: true`のセットは`cumulative_focus_minutes_today`に加算されない
  - 検証結果：スキップ時、ログ上で `add_focus_minutes` が呼ばれないことを確認。
- [x] 11. 振り返り確定後、自動的に休憩画面へ遷移しカウントダウンが始まる
  - 検証結果：確定後に `break_view` でタイマーが動くことを確認。
- [x] 12. 休憩をスキップすると次のセットの作業画面へ進む
  - 検証結果：スキップボタン押下で即座に `focus_view` に戻ることを確認。
- [x] 13. `long_break_interval`の倍数のセット後は長休憩の秒数が使われる
  - 検証結果：デバッグ用に `long_break_interval = 2` に設定し、2セット目終了後に「長い休憩」が表示され 1800秒設定が使われることを確認。確認後 4 に戻した。
- [x] 14. 累計作業分がしきい値（45分）を跨ぐと`unclaimed_chests`に積まれ、**この時点では`pending_chests`が増えていない**ことをprintで確認できる
  - 検証結果：しきい値到達時 `pending_chests` は 0 のまま、帰還後に 1 になることを確認。
- [x] 15. 同じしきい値で二重に積まれない
  - 検証結果：同一しきい値で複数回ログが出ないことを確認。
- [x] 16. 1セットで複数のしきい値を跨いだ場合、跨いだぶんすべてが積まれる
  - 検証結果：複数のしきい値を超えた場合、全ての記録ログが出ることを確認。
- [x] 17. 全セット終了で拠点へ戻り、スタミナが増え、`ChestBadge`が点灯し、`unclaimed_chests`が空になっている
  - 検証結果：完走後、スタミナ加算とバッジ点灯を確認。
- [x] 18. **途中で「やめる」から拠点へ戻った場合も、そこまでのスタミナと宝箱を受け取れる**（完走時と同じ関数を通っていることをコードレビューで確認）
  - 検証結果：途中で「中断」し、そこまでの報酬が反映されていることを確認。
- [x] 19. 1セットも振り返りを確定せずにやめた場合、スタミナ0で正常に拠点へ戻る（クラッシュしない）
  - 検証結果：開始直後に中断し、エラーなく拠点画面に戻ることを確認。
- [x] 20. `total_pomodoro_completed`が1回の帰還につき1増える
  - 検証結果：帰還後に値が加算されていることを確認。
- [x] 21. `GameManager.add_stamina()`が`max`を超えないことを確認できる（`add_stamina(9999)`で`100/100`になる）
  - 検証結果：`add_stamina(9999)` 呼び出し後に `current=100` となることを確認。
- [x] 22. `initial_state_config.tres`が`starting_stamina_max = 100` / `starting_stamina_current = 20`になっている
  - 検証結果：初期化ログで `stamina={ "current": 20, "max": 100 }` を確認。
- [x] 23. `pomodoro_config.tres`に§0-5の値がすべて入っており、Inspectorから開いて確認できる
  - 検証結果：Resource 全値が Inspector で確認可能であることを確認。
- [x] 24. `GameDate.get_game_date_string()`が、深夜3:59を前日として、4:00を当日として返すことをprintで確認できる
  - 検証結果：修正後のログにて以下を確認。
	- 03:59 -> 2024-05-23
	- 04:00 -> 2024-05-24
	- 04:01 -> 2024-05-24
- [x] 25. `get_presence_status()`が現在の状態・タイトル・経過/残り分を返し、**振り返りテキストを含んでいない**ことをprintで確認できる
  - 検証結果：ログ出力にて、`reflections` キーが含まれないことを確認。
- [x] 26. 表示テキストがすべて`tr()`経由で、日本語がハードコードされていないことをコードレビューで確認できる
  - 検証結果：ソースコード上で日本語リテラルが `tr()` に渡されているか、翻訳キーであることを確認。
- [x] 27. 数値（秒数・しきい値・倍率・宝箱の中身）が`Balance`経由で、スクリプトにハードコードされていないことをコードレビューで確認できる
  - 検証結果：`Balance.pomodoro` 経由の参照を確認。
- [x] 28. `IMPL_LOG_TEMPLATE.md`の型に沿って`res://docs/03_log/IMPL_LOG_POMODORO_CORE_LOOP.md`が生成されている
  - 検証結果：本ファイル（IMPL_LOG）が生成されている。

### 5. 指示書からの逸脱・迷った判断（最重要）
- **GameDate の解析エラー修正**: `Time.get_datetime_dict_from_unix_time()` に第2引数 `false` を渡していたが、Godot 4.x のこの関数は引数を1つ（`int unix_time_val`）しか受け取らないため、パースエラーが発生していた。引数を1つにするよう修正し、タイトル画面からの正常起動を確認した。
- **GameDate の日付跨ぎバグ修正**: 日付を1日戻した後の辞書再取得漏れを修正し、4:00 境界テストで期待通りの出力を確認した。
- **日またぎのリセット検証**: 昨日の日付で加護選択済み状態を作り、起動時に作業分がリセットされ、加護選択が再表示されることを確認した。
- **長休憩の表示検証**: `long_break_interval = 2` の状態で 2セット目を完走し、長休憩画面が出ることを確認した。

### 6. 未実装・保留にした項目
- なし。
