# PRE_PLAN：共通基盤（Autoload群）の空実装

対応するEXEC：`EXEC_COMMON_INFRA.md`
本ファイルは実装着手前の計画レビュー用。実装完了後は `IMPL_LOG_COMMON_INFRA.md` を別途生成する。

---

## 1. 作成するファイル一覧

### Autoload（`res://autoload/`）
| パス | 役割 |
|---|---|
| `res://autoload/balance.gd` | Balance集約スクリプト（`extends Node`）。6つのConfigを`@export`で保持。**`class_name`なし**（autoload名でグローバル参照） |
| `res://autoload/balance.tscn` | Balance用シーン。ルートNodeに`balance.gd`をアタッチし、6つの`@export`枠に各`.tres`を割当済みの状態で作成 |
| `res://autoload/game_manager.gd` | GameManager（`extends Node`）。状態保持・更新の各関数の空実装＋シグナル定義。`_ready()`で`Balance.initial_state`から初期化 |
| `res://autoload/save_manager.gd` | SaveManager（`extends Node`）。`save_game`/`load_game`/`has_save`の空実装 |
| `res://autoload/scene_manager.gd` | SceneManager（`extends Node`）。画面遷移・`_transfer_data`受け渡し |
| `res://autoload/signal_bus.gd` | SignalBus（`extends Node`）。画面間通信用シグナル4つの定義 |

### Configクラス（`res://resources/balance/`・`.gd`のみ・`class_name`付き）
| パス | 役割 |
|---|---|
| `res://resources/balance/pomodoro_config.gd` | `PomodoroConfig extends Resource`。加護3種・換算レート・プリセット配列・ユーザー設定範囲 |
| `res://resources/balance/pomodoro_preset.gd` | `PomodoroPreset extends Resource`。プリセット1件分の時間設定 |
| `res://resources/balance/protection_type_config.gd` | `ProtectionTypeConfig extends Resource`。加護1種のしきい値・倍率（EXEC未記載・追加提案→採用） |
| `res://resources/balance/shop_config.gd` | `ShopConfig extends Resource`。ショップ抽選テーブル関連の最小スケルトン |
| `res://resources/balance/research_config.gd` | `ResearchConfig extends Resource`。研究ノード解放コストの最小スケルトン |
| `res://resources/balance/workshop_config.gd` | `WorkshopConfig extends Resource`。レシピ所要時間・素材の最小スケルトン |
| `res://resources/balance/character_config.gd` | `CharacterConfig extends Resource`。レベルアップ素材の最小スケルトン |
| `res://resources/balance/initial_state_config.gd` | `InitialStateConfig extends Resource`。新規開始時のGameManager初期値 |

### Configアセット（`res://resources/balance/`・`.tres`・中身は空）
| パス | 役割 |
|---|---|
| `res://resources/balance/pomodoro_config.tres` | `PomodoroConfig`の空インスタンス（完了条件#8用） |
| `res://resources/balance/shop_config.tres` | `ShopConfig`の空インスタンス |
| `res://resources/balance/research_config.tres` | `ResearchConfig`の空インスタンス |
| `res://resources/balance/workshop_config.tres` | `WorkshopConfig`の空インスタンス |
| `res://resources/balance/character_config.tres` | `CharacterConfig`の空インスタンス |
| `res://resources/balance/initial_state_config.tres` | `InitialStateConfig`の空インスタンス |

### Utils（`res://scripts/utils/`）
| パス | 役割 |
|---|---|
| `res://scripts/utils/state_keys.gd` | `class_name GameStateKeys`。`get_state()`のDictionaryトップレベルキーを`const String`で定義 |
| `res://scripts/utils/transfer_keys.gd` | `class_name TransferKeys`。画面間データ受け渡しキー集約（本タスクでは空） |

### 検証用シーン（`res://tests/`・完了条件#3〜#13の検証用）
| パス | 役割 |
|---|---|
| `res://tests/test_common_infra.tscn` / `.gd` | GameManager各関数を`_ready()`で自動実行しPASS/FAILをprint。Timerで自動遷移 |
| `res://tests/dummy_scene_a.tscn` / `.gd` | `consume_transfer_data()`の中身をprint。Timerで`change_scene()`へ |
| `res://tests/dummy_scene_b.tscn` / `.gd` | 到着をprint。ヘッドレス検証時に`get_tree().quit()`で自動終了 |

### 編集（新規作成ではなく編集）
| パス | 編集内容 |
|---|---|
| `res://project.godot` | `[autoload]`セクションを追加し、§2の5件を順に登録 |

## 2. Autoloadの登録

| 登録順 | 登録名 | パス | スクリプト or シーン |
|---|---|---|---|
| 1 | `Balance` | `res://autoload/balance.tscn` | シーン |
| 2 | `GameManager` | `res://autoload/game_manager.gd` | スクリプト |
| 3 | `SaveManager` | `res://autoload/save_manager.gd` | スクリプト |
| 4 | `SceneManager` | `res://autoload/scene_manager.gd` | スクリプト |
| 5 | `SignalBus` | `res://autoload/signal_bus.gd` | スクリプト |

`project.godot` の `[autoload]` セクションに上記順で登録する（`Name="*res://path"` 形式）。**Input Map は触らない**（ユーザー指示）。

## 3. GameStateKeys に定義する定数一覧

すべて `const String`。

| 定数名 | 値 |
|---|---|
| `GOLD` | `"gold"` |
| `GEMS` | `"gems"` |
| `STAMINA` | `"stamina"` |
| `MATERIALS` | `"materials"` |
| `INVENTORY` | `"inventory"` |
| `PENDING_CHESTS` | `"pending_chests"` |
| `UNLOCKED_SCREENS` | `"unlocked_screens"` |
| `SCENARIO_CHAPTER` | `"scenario_chapter"` |
| `BOSS_UNLOCKED` | `"boss_unlocked"` |
| `PITY_COUNTERS` | `"pity_counters"` |
| `TOTAL_POMODORO_COMPLETED` | `"total_pomodoro_completed"` |
| `LAST_POMODORO_END_AT` | `"last_pomodoro_end_at"` |
| `SAVE_VERSION` | `"save_version"` |
| `LAST_SAVED_AT` | `"last_saved_at"` |
| `STORY` | `"story"` |
| `TRAINING_MODE_UNLOCKED` | `"training_mode_unlocked"` |
| `CODEX` | `"codex"` |
| `DAILY_SHOP` | `"daily_shop"` |
| `WEEKLY_SHOP` | `"weekly_shop"` |
| `MONTHLY_SHOP` | `"monthly_shop"` |
| `CHARACTER_GROWTH` | `"character_growth"` |
| `RESEARCH_TREE` | `"research_tree"` |
| `RECIPES_UNLOCKED` | `"recipes_unlocked"` |
| `CRAFTING_QUEUE` | `"crafting_queue"` |

## 4. 各Configクラスと @export 変数

### `Balance`（`autoload/balance.gd`・`extends Node`・class_nameなし）
- `@export var pomodoro: PomodoroConfig`
- `@export var shop: ShopConfig`
- `@export var research: ResearchConfig`
- `@export var workshop: WorkshopConfig`
- `@export var character: CharacterConfig`
- `@export var initial_state: InitialStateConfig`

### `PomodoroConfig`
- `@export var protection_light: ProtectionTypeConfig`
- `@export var protection_middle: ProtectionTypeConfig`
- `@export var protection_hard: ProtectionTypeConfig`
- `@export var gold_per_focus_minute: float`
- `@export var stamina_per_focus_minute: float`
- `@export var materials_per_focus_minute: float`
- `@export var presets: Array[PomodoroPreset]`
- `@export var min_sets: int`
- `@export var max_sets: int`
- `@export var min_long_break_minutes: int`
- `@export var max_long_break_minutes: int`
- `@export var min_long_break_interval: int`
- `@export var max_long_break_interval: int`

### `PomodoroPreset`
- `@export var preset_id: String`
- `@export var focus_duration_sec: int`
- `@export var short_break_sec: int`
- `@export var long_break_sec: int`
- `@export var long_break_interval: int`
- `@export var default_total_sets: int`

### `ProtectionTypeConfig`（追加提案→採用）
- `@export var threshold_min: int`
- `@export var bonus_multiplier: float`
- `@export var before_multiplier: float`
- `@export var after_multiplier: float`

### `InitialStateConfig`
- `@export var starting_gold: int`
- `@export var starting_gems: int`
- `@export var starting_stamina_max: int`
- `@export var starting_stamina_current: int`
- `@export var starting_materials: Dictionary`（material_id → 個数）
- `@export var initially_unlocked_screens: Array[String]`
- `@export var starting_scenario_chapter: int`
- `@export var save_version: int`

### `ShopConfig`（最小スケルトン・§5-9参照）
- `@export var daily_slot_count: int`
- `@export var weekly_slot_count: int`
- `@export var monthly_slot_count: int`
- `@export var item_pool: Array[String]`

### `ResearchConfig`（最小スケルトン）
- `@export var unlock_material_id: String`
- `@export var base_unlock_cost: int`

### `WorkshopConfig`（最小スケルトン）
- `@export var base_craft_duration_sec: int`
- `@export var level_up_material_id: String`

### `CharacterConfig`（最小スケルトン）
- `@export var level_up_material_id: String`
- `@export var base_level_up_cost: int`
- `@export var cost_growth_per_level: float`

## 5. 判断に迷った点・複数の実装方法がありえた点

1. **【解消済み】Project Settings編集とEXEC完了条件の矛盾** — ユーザー確認により「Project Settings変更禁止」はInput Mapのみを指すと判明。autoload登録は実施する。
2. **`balance.gd` と `balance.tscn` の分離** — `.tscn`のルートに付与するスクリプトは外部`.gd`とする（インラインはAGENTS.md運用と合わない）。物理的には`autoload/`に6ファイル、登録は5件。
3. **autoloadスクリプトに `class_name` を付けない** — autoload名でグローバル参照されるため`class_name`省略（EXECコードブロックも`extends Node`のみ）。Config類・`GameStateKeys`・`TransferKeys`には付ける。
4. **`ProtectionTypeConfig` を新規追加** — 加護3種のモデリング方法がEXECに未記載。`PomodoroPreset`と同じ「構造化データは別Resource」パターンに倣い新設。
5. **加護のフィールドは種別ごとに異なる（DATA_SCHEMA 2-3準拠）** — `light`/`middle`は`bonus_multiplier`+`after_multiplier`、`hard`は`before_multiplier`+`after_multiplier`。`ProtectionTypeConfig`に4フィールドすべて用意し、未使用は既定値のまま。
6. **換算レートを `float`** — 反映時に丸める前提。
7. **`InitialStateConfig` の `unlocked_screens` を `Array[String]`** — DATA_SCHEMAはDictionaryだが初期値は一覧が自然。`GameManager`側でDictionaryに組み立てる。
8. **`ShopConfig`/`ResearchConfig`/`WorkshopConfig`/`CharacterConfig` は最小スケルトン** — EXECは中身を曖昧に書く。AGENTS.md「docs/は指示されたもの以外読まない」に従いギルドPLAN（`PLAN_GUILD_*`）は読まず、明らかに必要な1〜4フィールドのみ定義。詳細は各ギルドEXECで拡張。
9. **`get_state()`/`_ready()`/`apply_*` は純粋な `pass` ではなく実構造を持つ** — 完了条件#11（`GameStateKeys`定数使用）・#12（`duplicate(true)`スナップショット）・#5/#6（SignalBus実発火）・#13（`Balance.initial_state`で初期化）を満たすため、これらは内部Dictionaryの組み立て・複製・シグナル発火まで実際に行う。基本関数はprint+内部Dictionary更新のみ。
10. **`SceneManager.change_scene`/`change_scene_with_data`/`consume_transfer_data` は実動作** — 完了条件#9/#10が実際の遷移とデータ受け渡しを要求するため実装する。`go_back()`の履歴はPLANで未確定のため、最小のスタック（`Array[String]`）を置くがダミー扱い。
11. **`print` デバッグ文は `tr()` 対象外** — ユーザー向け表示ではないため。

## 6. 指示書に書かれていないが必要だと思われること

1. **`project.godot` の `[autoload]` 編集** — ユーザー指示により実施。
2. **6つの空 `.tres` 作成とBalanceへの割当** — 完了条件#8のため。EXECの「`.tres`は作らなくてよい」は「値を入れなくてよい」の意味と判明したため、空インスタンスを作成し`balance.tscn`の`@export`枠に割り当てる。
3. **検証用ダミーシーン（`res://tests/`）** — 完了条件#3〜#13の検証用。「やらないこと」の除外対象は本番画面のみで検証シーンは対象外。
4. **`docs/03_log/` フォルダ新規作成** — AGENTS.mdで`IMPL_LOG`置き場として承認済み。
5. **実装後の完了条件14項目の検証と `IMPL_LOG_COMMON_INFRA.md` 生成** — 実装完了後、#1〜#14を1つずつ検証し、`IMPL_LOG_TEMPLATE.md`の型で生成する。
