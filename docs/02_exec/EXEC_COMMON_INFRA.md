# 【実行指示書】共通基盤（Autoload群）の空実装

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・数値管理ルール・Autoload一覧・拒否仕様
- `PLAN_COMMON_INFRA.md`：この実行指示書のもとになった第2層の作戦計画書

---

## 今回のタスク

`AGENTS.md`で定義された5つのAutoload（`GameManager` / `Balance` / `SaveManager` / `SceneManager` / `SignalBus`）を、関数シグネチャのみの空実装（中身はダミー処理＋`print`によるログ出力でよい）で作成し、Project SettingsのAutoloadタブに登録する。

### やること
- 5つのAutoloadの作成。**`Balance`のみシーン（`.tscn`）として作成・登録**すること（Inspectorで各Configを差し替えられるようにするため）。他の4つ（`GameManager` / `SaveManager` / `SceneManager` / `SignalBus`）はスクリプト単体（`.gd`）でよい
- Project SettingsのAutoloadタブでの**登録順は `Balance` → `GameManager` → `SaveManager` → `SceneManager` → `SignalBus`** とすること。`GameManager`が`_ready()`で`Balance.initial_state`を参照するため、`Balance`が先に初期化されている必要がある（`AGENTS.md`「Autoloadの登録順」参照）
- 各関数の空実装（実際のゲームロジックは書かない。呼ばれたことがprintで確認できればよい）
- 対応するシグナルの定義と、関数呼び出し時の発火
- `resources/balance/`配下への各Configクラス（`.gd`のみ。`.tres`アセット自体は本タスクでは作らなくてよい）の雛形作成
- `scripts/utils/state_keys.gd`（`class_name GameStateKeys`）の作成。`get_state()`が返すDictionaryのトップレベルキーを`const String`で定義する（下記の一覧を参照）
- `scripts/utils/transfer_keys.gd`（`class_name TransferKeys`）の作成。`SceneManager.change_scene_with_data()`で使うキー名を集約する（本タスク時点では空でよく、画面実装時に各PLANファイル側で追記していく）
- `GameManager.get_state()`の空実装内で、Dictionaryのキーを文字列リテラルではなく`GameStateKeys`定数経由で組み立てる（中身がダミーでもキーの組み立て方はこの時点から統一する）

#### `GameStateKeys`に定義するキー一覧（`DATA_SCHEMA.md`のトップレベル項目に対応）

| 定数名 | 値 | 対応するDATA_SCHEMA |
|---|---|---|
| `GOLD` | `"gold"` | 1. 拠点 |
| `GEMS` | `"gems"` | 1. 拠点 |
| `STAMINA` | `"stamina"` | 1. 拠点（`current` / `max`を持つ） |
| `MATERIALS` | `"materials"` | 1. 拠点 |
| `INVENTORY` | `"inventory"` | 1. 拠点 |
| `PENDING_CHESTS` | `"pending_chests"` | 1. 拠点 |
| `UNLOCKED_SCREENS` | `"unlocked_screens"` | 1. 拠点 |
| `SCENARIO_CHAPTER` | `"scenario_chapter"` | 1. 拠点 |
| `BOSS_UNLOCKED` | `"boss_unlocked"` | 1. 拠点 |
| `PITY_COUNTERS` | `"pity_counters"` | 1. 拠点 |
| `TOTAL_POMODORO_COMPLETED` | `"total_pomodoro_completed"` | 1. 拠点 |
| `LAST_POMODORO_END_AT` | `"last_pomodoro_end_at"` | 1. 拠点 |
| `SAVE_VERSION` | `"save_version"` | 1. 拠点 |
| `LAST_SAVED_AT` | `"last_saved_at"` | 1. 拠点 |
| `STORY` | `"story"` | 3. 冒険選択（`current_chapter` / `stages`） |
| `TRAINING_MODE_UNLOCKED` | `"training_mode_unlocked"` | 3. 冒険選択 |
| `CODEX` | `"codex"` | 4-1. 倉庫 |
| `DAILY_SHOP` | `"daily_shop"` | 4-2. ショップ |
| `WEEKLY_SHOP` | `"weekly_shop"` | 4-2. ショップ |
| `MONTHLY_SHOP` | `"monthly_shop"` | 4-2. ショップ |
| `CHARACTER_GROWTH` | `"character_growth"` | 4-3. 育成 |
| `RESEARCH_TREE` | `"research_tree"` | 4-4. 研究 |
| `RECIPES_UNLOCKED` | `"recipes_unlocked"` | 4-5. 作業場 |
| `CRAFTING_QUEUE` | `"crafting_queue"` | 4-5. 作業場 |

※ `story`と`training_mode_unlocked`は冒険選択画面用。画面のPLAN／EXECは未着手だが、後からキーを足すと命名がブレるため、この時点でキーだけ定義しておく。

### やらないこと
- 各画面（拠点・ポモドーロ・戦闘・ギルド等）のシーン実装
- セーブ処理の実際のファイルI/O実装（`SaveManager`は空実装まで）
- マスターデータ（スキル・ウェーブ・敵ステータス・研究ノード等）の具体的な数値投入

---

## 1. GameManager（`res://autoload/game_manager.gd`、Autoload登録名: `GameManager`）

**責務**：拠点共通データに加え、育成・図鑑・ショップ・研究ツリー・製作キューなど、複数画面から参照される永続データ全般を保持・更新する。全画面のSingle Source of Truth。

```gdscript
extends Node

# --- 基本リソース ---
func get_state() -> Dictionary:
    # 内部Dictionaryそのものを返さず、duplicate(true)した読み取り専用の
    # スナップショットを返すこと（呼び出し側からの直接書き換えを防ぐため）
    # キーは文字列リテラルではなくGameStateKeysの定数で組み立てる
    pass

func add_gold(amount: int) -> void:
    pass

func add_stamina(amount: int) -> void:
    pass

func spend_stamina(amount: int) -> bool:
    # 足りなければ何もせずfalseを返す
    return false

func add_material(material_id: String, amount: int) -> void:
    pass

func add_to_inventory(item_id: String, count: int) -> void:
    # 初出のitem_idであれば、図鑑（codex）のdiscoveredも自動でtrueにすること
    pass

# --- 画面アンロック ---
func unlock_screen(screen_id: String) -> void:
    pass

func is_screen_unlocked(screen_id: String) -> bool:
    return false

# --- 宝箱 ---
func add_pending_chest(chest_data: Dictionary) -> void:
    pass

func open_chest(chest_id: String) -> bool:
    # 存在しなければ何もせずfalse。存在すればopened=trueにしてrewardsを反映
    return false

func get_pending_chest_count() -> int:
    # opened == false の件数
    return 0

# --- ポモドーロ報酬 ---
func apply_pomodoro_rewards(reward_data: Dictionary) -> void:
    # gold/stamina/materialsの反映、total_pomodoro_completedの加算、
    # last_pomodoro_end_atの更新、SignalBus.pomodoro_session_completedの発火までを一括で行う
    pass

# --- 戦闘報酬 ---
func apply_battle_rewards(result_data: Dictionary) -> void:
    # gold/materialsの反映、SignalBus.battle_finishedの発火までを一括で行う
    # ※ expは扱わない（レベル上げは専用素材消費型。DATA_SCHEMA.md 4-3準拠）
    pass

# --- 倉庫：図鑑・インベントリ整理 ---
func get_codex_entry(item_id: String) -> Dictionary:
    return {}

func update_inventory_slot_position(item_id: String, position: Vector2i) -> void:
    pass

# --- ショップ ---
func get_shop_lineup(shop_type: String) -> Array:
    return []

func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
    # 残高不足・売り切れなら何もせずfalse
    return false

func refresh_shop_if_needed(shop_type: String) -> void:
    pass

# --- 育成 ---
func get_character_growth(character_id: String) -> Dictionary:
    return {}

func level_up_character(character_id: String) -> bool:
    # 素材不足なら何もせずfalse
    return false

func equip_item(character_id: String, slot: String, item_id: String) -> void:
    pass

func unequip_item(character_id: String, slot: String) -> void:
    pass

func select_skill(character_id: String, slot_id: int, skill_id: String) -> void:
    pass

# --- 研究 ---
func get_research_tree() -> Dictionary:
    return {}

func unlock_research_node(node_id: String) -> bool:
    # 前提未解放・素材不足なら何もせずfalse
    return false

func get_effective_level_cap(character_id: String) -> int:
    # 保存された値ではなく、research_treeを都度走査して計算する
    return 0

func get_stat_boost_all() -> Dictionary:
    # 保存された値ではなく、research_treeを都度走査して計算する
    return {}

# --- 作業場 ---
func get_crafting_queue() -> Array:
    return []

func start_craft(recipe_id: String) -> bool:
    # レシピ未解放・素材不足なら何もせずfalse
    return false

func collect_craft(queue_id: String) -> bool:
    # 完了前なら何もせずfalse。完了後は成功しinventoryへ反映
    return false

# --- シグナル ---
signal resource_changed(resource_type: String, new_value)
signal screen_unlocked(screen_id: String)
signal inventory_changed(item_id: String)
signal pending_chests_changed(pending_count: int)
```

### 実装上の注意
- 他のAutoloadやシーンから、GameManagerが持つデータを直接書き換えさせない。必ず上記関数を経由させる
- 状態が変わったら、対応するシグナルを必ず発火する
- `open_chest()` / `apply_pomodoro_rewards()` / `apply_battle_rewards()`は、`add_gold()`等の既存関数を内部で呼び出す形にし、同じような更新処理を重複して書かない
- `apply_pomodoro_rewards()` / `apply_battle_rewards()`は発火元をGameManagerに一本化する（呼び出し元のポモドーロ画面・戦闘画面側では`SignalBus.pomodoro_session_completed` / `SignalBus.battle_finished`を発火させない。二重発火防止のため）
- ショップ・育成・研究・作業場については、今回は専用シグナルを設けない。各画面側が操作成功後にその場で`get_*`系を呼び直す方式でよい（今後シグナルが必要になれば別途追記する）

---

## 2. Balance（`res://autoload/balance.tscn`、Autoload登録名: `Balance`）

**責務**：数値調整用Resourceの集約。`AGENTS.md`の「数値管理ルール」を実現する本体。

- スクリプト単体ではなく**シーン**として登録すること（Inspectorで各Configを差し替えられるようにするため）
- 各Configクラスは`res://resources/balance/`配下に`class_name`付きの`Resource`として定義し、ロジックを持たせない（純粋なデータ）

```gdscript
extends Node

@export var pomodoro: PomodoroConfig
@export var shop: ShopConfig
@export var research: ResearchConfig
@export var workshop: WorkshopConfig
@export var character: CharacterConfig
@export var initial_state: InitialStateConfig
```

### 各Configクラスの雛形（`resources/balance/`配下）
- `PomodoroConfig`：加護3種（light/middle/hard）のしきい値・倍率、作業分数からgold/stamina/materialsへの換算レート、および**プリセット配列**を`@export`で持つ。
  - プリセットは単一の`focus_duration_sec`ではなく、`PomodoroPreset`（別Resourceクラス）の配列として持つこと。体験版では`short`(15/3) / `standard`(25/5) / `long`(50/10)の3種を想定しており、単数のフィールドでは表現できないため
  - `PomodoroPreset`が持つ`@export`：`preset_id: String`（`short` / `standard` / `long`）、`focus_duration_sec: int`、`short_break_sec: int`、`long_break_sec: int`、`long_break_interval: int`、`default_total_sets: int`
  - あわせて、ユーザーが設定画面で変更できる範囲（セット数の最小／最大、長休憩の分数の最小／最大、長休憩挿入間隔の最小／最大）も`PomodoroConfig`側に`@export`で持たせる（`DEMO_CHECKLIST.md`「セット数・長休憩の分数・長休憩の挿入間隔をユーザーが範囲内で設定できる」に対応）
- `ShopConfig`：ラインナップ再生成用の抽選テーブル関連の値
- `ResearchConfig`：研究ノード解放に必要な素材数等
- `WorkshopConfig`：レシピごとの所要時間・必要素材
- `CharacterConfig`：レベルアップに必要な素材の種類・量
- `InitialStateConfig`：新規開始時（`SaveManager.has_save() == false`）のGameManager初期値（gold, stamina.max, unlocked_screens初期状態等）。`GameManager`は`_ready()`時にこの値で自身を初期化する

今回は各クラスに`class_name`と空の`@export`変数群を用意するところまででよい（具体的な数値は`.tres`アセット作成時に入れる）。

---

## 3. SaveManager（`res://autoload/save_manager.gd`、Autoload登録名: `SaveManager`）

**責務**：GameManagerが持つ状態のファイル保存・読込。

```gdscript
extends Node

func save_game() -> void:
    pass

func load_game() -> bool:
    # セーブがあればtrueで読み込み、なければfalse
    return false

func has_save() -> bool:
    return false
```

- 保存タイミング・保存ファイル形式（JSON / `ResourceSaver`等）は今回は決めない。空実装のままでよい

---

## 4. SceneManager（`res://autoload/scene_manager.gd`、Autoload登録名: `SceneManager`）

**責務**：画面遷移の一元管理。

```gdscript
extends Node

var _transfer_data: Dictionary = {}

func change_scene(scene_path: String) -> void:
    pass

func go_back() -> void:
    pass

func change_scene_with_data(scene_path: String, data: Dictionary) -> void:
    # _transfer_dataをセットしてからchange_sceneと同様の遷移を行う
    pass

func consume_transfer_data() -> Dictionary:
    # 取り出すと同時に_transfer_dataを空にする
    return {}
```

- 各シーンのスクリプトから`get_tree().change_scene_to_file()`を直接呼ばせない。必ず`SceneManager`経由にする
- 画面ごとに専用の受け渡しクラスは作らない。この`_transfer_data`（Dictionary1つ）に統一する

---

## 5. SignalBus（`res://autoload/signal_bus.gd`、Autoload登録名: `SignalBus`）

**責務**：画面間通信のグローバルシグナル中継。循環参照を避けるため、画面同士は直接参照しない。

```gdscript
extends Node

signal pomodoro_session_completed(reward_data: Dictionary)
signal battle_finished(result_data: Dictionary)
signal facility_tapped(facility_id: String)
signal character_tapped(character_id: String)
```

- 画面Aのスクリプトが画面Bのノードを直接参照・呼び出すことを禁止する。必ずSignalBus経由で通知し、Bが自分で処理する

---

## 動作確認手順（完了条件）

以下をすべて満たしたら完了とする。

1. `res://autoload/`に5つのファイル（`Balance`のみ`.tscn`、他4つは`.gd`）が、snake_caseのファイル名で作成されている
2. Project SettingsのAutoloadタブに5つとも登録されており、**登録順が`Balance` → `GameManager` → `SaveManager` → `SceneManager` → `SignalBus`** になっている
3. `GameManager.add_gold(100)`を呼ぶと`resource_changed`シグナルが発火することをprintで確認できる
4. `GameManager.add_pending_chest({...})` → `open_chest(chest_id)`で`pending_chests_changed`シグナルが正しい件数で発火することをprintで確認できる
5. `GameManager.apply_pomodoro_rewards({...})`でgold/staminaが反映され、`total_pomodoro_completed`が+1、`SignalBus.pomodoro_session_completed`が発火することをprintで確認できる
6. `GameManager.apply_battle_rewards({...})`でgold/materialsが反映され、`SignalBus.battle_finished`が**GameManager内部から**発火することをprintで確認できる
7. `GameManager.purchase_shop_item()` / `level_up_character()` / `unlock_research_node()` / `start_craft()` / `collect_craft()`それぞれが、条件を満たさない場合は何もせずfalseを返すことを確認できる
8. `Balance.pomodoro`が`.tres`を割り当てた状態でInspectorから開ける（`.tres`自体は空でよい）
9. `SceneManager.change_scene()`でダミーシーン間の遷移ができる
10. `SceneManager.change_scene_with_data()`で渡したDictionaryを、遷移先で`consume_transfer_data()`経由で取得でき、取得後は空になっていることを確認できる
11. `scripts/utils/state_keys.gd`（`GameStateKeys`）が作成されており、上表のキーがすべて`const String`で定義されている。かつ`GameManager.get_state()`内で文字列リテラルではなく`GameStateKeys`定数を使ってDictionaryを組み立てていることをコードレビューで確認できる
12. `get_state()`が返したDictionaryを呼び出し側で書き換えても、`GameManager`の内部状態が変化しないことを確認できる（`duplicate(true)`によるスナップショット化の検証）
13. `Balance.initial_state`（`InitialStateConfig`）の値で`GameManager`が`_ready()`時に初期化されることを、Autoload登録順を含めてprintで確認できる（`Balance`が先に初期化されていること）
14. `IMPL_LOG_TEMPLATE.md`の型に沿って`IMPL_LOG_COMMON_INFRA.md`が生成されている（`AGENTS.md`の開発ルール参照）

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形にする
- ゲームバランスに関わる数値はスクリプトにハードコードせず、`Balance`経由の`Resource`（`.tres`）から取得する
- `res://autoload/`と`res://addons/`の既存ファイルには無断で触れない
- 新しいフォルダが必要になった場合は、勝手に作らず人間に提案してから作成する
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
