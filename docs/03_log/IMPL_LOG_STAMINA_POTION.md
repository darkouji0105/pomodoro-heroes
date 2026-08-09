# 実装ログ：スタミナポーション

- 対応するEXECファイル：`EXEC_STAMINA_POTION.md`
- 実装日時：2026-08-09

### 1. 実装したファイル一覧
| パス | 内容 |
|---|---|
| `res://scripts/utils/state_keys.gd` | ポーション関連定数2つを末尾に追記 |
| `res://autoload/game_manager.gd` | 状態テンプレートとポーション3関数を追加。ポーション使用はadd_staminaを使用せず上限超過可能な直接加算 |
| `res://scenes/pomodoro/pomodoro.gd` | 帰還時のポーション付与へ変更 |
| `res://scenes/base/base_screen.tscn` | PotionEntry、所持数、使用ボタンを追加 |
| `res://scenes/base/base_screen.gd` | 表示・シグナル・使用処理を追加 |
| `res://localization/ja.csv` | 指示キーは既存行として確認（重複追記なし） |

### 2. 関数の実装状況
| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `GameManager.grant_stamina_potions()` | 通り | 端数を保持し、Balanceのレートで付与 |
| `GameManager.get_stamina_potion_count()` | 通り | - |
| `GameManager.use_stamina_potion()` | 通り | `add_stamina()`を呼ばず直接加算 |
| `Pomodoro._return_to_base()` | 通り | 空報酬Dictionaryを適用 |

### 3. シグナルの発火箇所
| シグナル | 発火元（関数・行） |
|---|---|
| `inventory_changed` | `add_to_inventory()`、`use_stamina_potion()` |
| `resource_changed` | `use_stamina_potion()` |
| `SignalBus.pomodoro_session_completed` | 既存の`apply_pomodoro_rewards()` |

### 4. 完了条件チェックリストの検証結果
- [x] 項目1：read/grepで既存定数を保持し、2定数を末尾に確認。
- [x] 項目2：人間編集済みのtresを保持。presets/chest_contentsをreadで確認。
- [x] 項目3：人間編集済みの設定を保持。
- [ ] 項目4：実機操作は未実施。
- [ ] 項目5：実機操作は未実施。
- [ ] 項目6：実機操作は未実施。
- [ ] 項目7：実機操作は未実施。
- [ ] 項目8：シーン構造は確認済み、実機表示は未実施。
- [ ] 項目9：実機操作は未実施。
- [ ] 項目10：実機操作は未実施。
- [ ] 項目11：コードとシーン設定は確認済み、実機操作は未実施。
- [ ] 項目12：実機操作は未実施。
- [ ] 項目13：実機操作は未実施。
- [ ] 項目14：実機操作は未実施。
- [x] 項目15：read/grepで既存キーを保持し、キー2行を確認。
- [x] 項目16：本ログを生成。

### 5. 指示書からの逸脱・迷った判断（最重要）
`tres`とpomodoro_config.gdのexportは人間編集済みという§7に従い変更しなかった。ja.csvの2キーは既に存在し、重複作成禁止に従い追記しなかった。なお、実ファイルの_empty_state_templateに不足があったため、状態キー追加のため必要な1行のみ補完した。

### 6. 未実装・保留にした項目
完了条件4〜14の実機操作検証は、このセッションでは未実施。
