# 【実装計画】ギルド画面と倉庫（宝箱・インベントリ・図鑑）

対象指示書: `res://docs/02_exec/EXEC_GUILD_WAREHOUSE.md`
この計画は指示書 §0 の制約を前提に、§1〜§6 の作業内容を設計したものである。実装はこの計画に対して人間から承認を得てから開始する。

---

## 1. 作成・変更するファイル一覧

### 1-1. 新規作成（5ファイル）

| パス | 役割 |
|---|---|
| `res://scenes/guild/guild_screen.tscn` | ギルド画面のルートシーン（Control） |
| `res://scenes/guild/guild_screen.gd` | ギルド画面のスクリプト。5つの遷移ボタン＋戻るボタンを持つ |
| `res://scenes/guild/warehouse_screen.tscn` | 倉庫画面のルートシーン（Control + TabContainer） |
| `res://scenes/guild/warehouse_screen.gd` | 倉庫画面のスクリプト。3タブ（持ち物/図鑑/宝箱）の動的生成と宝箱開封処理 |
| `res://docs/03_log/IMPL_LOG_GUILD_WAREHOUSE.md` | 実装ログ（指示書 §6-3 の完了条件20と対応） |

`res://scenes/guild/` は `res://scenes/guild/.gitkeep` のみ存在する空フォルダ。新規作成は AGENTS.md フォルダ構造の「Guild」配下に正しく位置する。

### 1-2. 既存ファイルの書き換え（4ファイル）

| パス | 変更内容 | 想定差分行数 |
|---|---|---|
| `res://scripts/utils/transfer_keys.gd` | 末尾に `const WAREHOUSE_TAB: String = "warehouse_tab"` を1行追記 | +1 |
| `res://scenes/base/base_screen.gd` | `SCREEN_SCENES` の `SCREEN_GUILD` 行を `PLACEHOLDER_PATH` から `guild_screen.tscn` パスに差し替え（1行）。`_on_chest_badge_pressed()` をギルド経由から倉庫画面直接＋タブ指定に変更（数行） | +3 / 置換1 |
| `res://localization/ja.csv` | 末尾に18行追記（`ui_guild_*` 5行 + `ui_nav_*` 5行 + `ui_warehouse_*` 8行） | +18 |
| `res://docs/03_log/IMPL_LOG_GUILD_WAREHOUSE.md` | 実装後に新規生成 | 全行 |

書き換えのルール：
- 既存定数・関数・翻訳キーの削除・改名はしない（指示書 §0-3）。
- `transfer_keys.gd` の `SCREEN_ID` および `base_screen.gd` の他の行は触らない。
- `ja.csv` は BOM なし UTF-8 維持・`cat >>` で追記・既存65行は残す。

### 1-3. 触らないもの（明示）

指示書 §0-3 および追加ルールの遵守。AI が編集禁止と確認した一覧：

- `res://autoload/game_manager.gd`（**今回 GameManager への追加は不要**。指示書「既存の実装状況」§前提を参照。`open_chest()` のシグネチャも変更しない）
- `res://autoload/scene_manager.gd` ほか `res://autoload/` 配下5つのAutoload
- `res://theme/main_theme.tres`
- `res://resources/balance/**/*.tres`（全 `.tres` ファイル）
- `project.godot` の `[input]` セクション
- `res://addons/`（Ziva）
- `res://docs/02_exec/EXEC_GUILD_WAREHOUSE.md`（指示書本体）、`res://docs/01_plan/PLAN_GUILD_WAREHOUSE.md`（第2層）
- `res://scripts/utils/state_keys.gd`（既存のネストキー定数で足りる。新規追加なし）
- `res://scenes/ui/placeholder_screen.tscn` / `.gd`（既存挙動を変更しない）
- `res://scenes/ui/components/primary_button.tscn` / `.gd` ほか既存コンポーネント
- 既存画面（`pomodoro.tscn` / `title_screen.tscn` など）のソース

---

## 2. `guild_screen.tscn` / `guild_screen.gd` の設計

### 2-1. ノード階層

指示書 §2 の階層をそのまま採用する。中央寄せは `CenterContainer` に担当させ、Control の直下に Control を置かない（指示書§2 注釈の「DialogBase で実際に踏んだ罠」）。

```
GuildScreen (Control)                         # anchors_preset = full rect
├─ Background (ColorRect)                     # full rect, color は指示書記載
└─ CenterContainer (CenterContainer)          # full rect
	└─ Layout (VBoxContainer)                 # ※テーマは main_theme.tres 経由
		├─ TitleLabel (Label)                 # text = "ui_nav_guild"（auto_translate）
		├─ WarehouseButton (primary_button)   # label_key = "ui_guild_warehouse"
		├─ ShopButton (primary_button)        # label_key = "ui_guild_shop"
		├─ TrainingButton (primary_button)    # label_key = "ui_guild_training"
		├─ ResearchButton (primary_button)    # label_key = "ui_guild_research"
		├─ WorkshopButton (primary_button)    # label_key = "ui_guild_workshop"
		└─ BackButton (primary_button)        # label_key = "ui_common_back"
```

`primary_button.tscn` は `scenes/ui/components/primary_button.tscn` をインスタンス化して使う。`label_key` プロパティは `PrimaryButton.label_key`（`@export` 設定で `tr()` 反映済み）。

### 2-2. 遷移先の対応表とボタン接続

指示書 §2 の設計通り、対応表を `guild_screen.gd` 内に1箇所集約する（`base_screen.gd` の `SCREEN_SCENES` と同じ方式）。

```gdscript
# guild_screen.gd
class_name GuildScreen
extends Control

const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"
const WAREHOUSE_PATH: String = "res://scenes/guild/warehouse_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"

# sub_screen_id -> 遷移先パス
const GUILD_SCENES: Dictionary = {
	"warehouse": WAREHOUSE_PATH,
	"shop": PLACEHOLDER_PATH,
	"training": PLACEHOLDER_PATH,
	"research": PLACEHOLDER_PATH,
	"workshop": PLACEHOLDER_PATH,
}

# ボタン名(PascalCase) -> sub_screen_id
const BUTTON_TO_SUB: Dictionary = {
	"WarehouseButton": "warehouse",
	"ShopButton": "shop",
	"TrainingButton": "training",
	"ResearchButton": "research",
	"WorkshopButton": "workshop",
}
```

5回同じコードを書かない実装として、`_ready()` で `get_tree().get_nodes_in_group("guild_nav")` ではなく、シーンツリー構造が静的なので `@onready var ... = $...` を使いつつ、**接続は Dictionary をループで回す** 方式にする：

```gdscript
@onready var warehouse_button: PrimaryButton = $CenterContainer/Layout/WarehouseButton
@onready var shop_button: PrimaryButton      = $CenterContainer/Layout/ShopButton
@onready var training_button: PrimaryButton  = $CenterContainer/Layout/TrainingButton
@onready var research_button: PrimaryButton  = $CenterContainer/Layout/ResearchButton
@onready var workshop_button: PrimaryButton  = $CenterContainer/Layout/WorkshopButton
@onready var back_button: PrimaryButton      = $CenterContainer/Layout/BackButton

const _NAV_BUTTONS: Array[PrimaryButton] = []  # 下記 _ready で初期化せず Dictionary で持つ
```

ただし `const Array[PrimaryButton]` は変数で初期化できないため、以下のように `_init()` または `var` で `_ready()` 前に組み立てる形ではなく、**`@onready` したボタンを Dictionary 化してからループで接続** する純粋な実装にする：

```gdscript
var _nav_buttons: Dictionary = {}  # sub_screen_id -> PrimaryButton

func _ready() -> void:
	_nav_buttons = {
		"warehouse": warehouse_button,
		"shop":      shop_button,
		"training":  training_button,
		"research":  research_button,
		"workshop":  workshop_button,
	}
	for sub_id: String in _nav_buttons:
		_nav_buttons[sub_id].pressed.connect(_go_to_sub.bind(sub_id))
	back_button.pressed.connect(_on_back_pressed)

func _go_to_sub(sub_id: String) -> void:
	var path: String = str(GUILD_SCENES.get(sub_id, ""))
	if path == "":
		push_warning("[GuildScreen] unknown sub_screen_id: " + sub_id)
		return
	# 未実装画面は placeholder_screen が screen_id を表示に使うため SCREEN_ID を渡す
	if path == PLACEHOLDER_PATH:
		SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: sub_id})
	else:
		# 倉庫画面は別途タブ指定があるため _on_warehouse_pressed 経由
		SceneManager.change_scene(path)
```

ただし設計を単純化するため、**接続のソースオブトゥルースを `BUTTON_TO_SUB` の Dictionary 1つに統一** する案を採る。`@onready` 宣言は Type 補完のために維持しつつ、ループ内のキー順は `BUTTON_TO_SUB` 側を正とする：

```gdscript
const BUTTON_TO_SUB: Dictionary = {
	"warehouse": "WarehouseButton",
	"shop":      "ShopButton",
	"training":  "TrainingButton",
	"research":  "ResearchButton",
	"workshop":  "WorkshopButton",
}

# 動的参照用: ノードパスを決め打ちで Dictionary 化
const _BUTTON_NODE_PATHS: Dictionary = {
	"WarehouseButton": "^" ...,  # 下記のように Dictionary で参照
}
```

実装方針を確定するため、最終形は以下のようにする：

- **A) ノード参照**：5つのボタンを `@onready` で1つずつ取得し、`_ready()` 内で `_nav_buttons: Dictionary = {sub_id: btn, ...}` を組み立てる（@onready は型補完が効くのでこちらを採る）
- **B) 接続**：`_nav_buttons` を for ループで `pressed.connect(_go_to_sub.bind(sub_id))` する
- **C) 遷移先解決**：`_go_to_sub(sub_id)` が `GUILD_SCENES[sub_id]` を見て、未実装なら `SCREEN_ID` を渡して placeholder へ、倉庫ならそのまま開く

5回同じコードを書かないのは for ループで接続する点。未実装の判別は `path == PLACEHOLDER_PATH` で行う（汎用的に「`scene_path` が placeholder かどうか」を Dictionary 化するのは過剰なため、ベタ比較で十分）。

### 2-3. 戻るボタン

```gdscript
func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
```

`go_back()` は履歴管理が「ダミー扱い」（`scene_manager.gd` 14行目コメント参照）なので使わない。明示パスを指定する。

### 2-4. 副次事項

- **`get_tree().change_scene_to_file()` を直接呼ばない**（指示書 §2 強調）
- ノード名（PascalCase）とファイル名（snake_case）を混同しない（AGENTS.md 命名規則）
- `class_name GuildScreen` をスクリプト先頭に付与

---

## 3. `warehouse_screen.tscn` / `warehouse_screen.gd` の設計

### 3-1. ノード階層

指示書 §3-1 の階層をそのまま採用する。

```
WarehouseScreen (Control)                     # full rect
├─ Background (ColorRect)                     # full rect
└─ Layout (VBoxContainer)                     # full rect
	├─ Header (HBoxContainer)
	│   ├─ TitleLabel (Label)                 # text = "ui_guild_warehouse"
	│   └─ BackButton (primary_button)        # label_key = "ui_common_back"
	└─ Tabs (TabContainer)                    # size_flags_vertical = EXPAND_FILL
		├─ InventoryTab (ScrollContainer)
		│   └─ InventoryGrid (GridContainer)  # columns = 4
		├─ CodexTab (ScrollContainer)
		│   └─ CodexList (VBoxContainer)
		└─ ChestTab (VBoxContainer)
			├─ OpenAllButton (primary_button) # label_key = "ui_warehouse_open_all"
			├─ ChestScroll (ScrollContainer)
			│   └─ ChestList (VBoxContainer)
			└─ ResultLabel (Label)            # 開封結果（複数行）
```

`TabContainer` 自身のノード名は `Tabs`、子タブのノード名（`InventoryTab` / `CodexTab` / `ChestTab`）がそのままデフォルトのタブ名に出る。**デフォルト英語名（"InventoryTab"）が画面に出るのを避けるため、指示書 §3-1 の通り `_ready()` 内で `set_tab_title()` を呼んで日本語化する**（下の§3-3）。

### 3-2. スクリプト冒頭と定数

```gdscript
class_name WarehouseScreen
extends Control

const TAB_INVENTORY: String = "inventory"
const TAB_CODEX: String    = "codex"
const TAB_CHEST: String    = "chest"

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"

# タブインデックス（InventoryTab=0, CodexTab=1, ChestTab=2）
const TAB_INDEX: Dictionary = {
	TAB_INVENTORY: 0,
	TAB_CODEX: 1,
	TAB_CHEST: 2,
}

# タブタイトル用翻訳キー
const TAB_TITLE_KEYS: Array[String] = [
	"ui_warehouse_tab_inventory",
	"ui_warehouse_tab_codex",
	"ui_warehouse_tab_chest",
]
```

### 3-3. `_ready()` の流れ

指示書 §3-1 と §3-2 を統合した `_ready()` の実装方針：

```gdscript
@onready var tabs: TabContainer = $Layout/Tabs
@onready var back_button: PrimaryButton = $Layout/Header/BackButton
@onready var inventory_grid: GridContainer = $Layout/Tabs/InventoryTab/InventoryGrid
@onready var codex_list: VBoxContainer    = $Layout/Tabs/CodexTab/CodexList
@onready var open_all_button: PrimaryButton = $Layout/Tabs/ChestTab/OpenAllButton
@onready var chest_list: VBoxContainer    = $Layout/Tabs/ChestTab/ChestScroll/ChestList
@onready var result_label: Label          = $Layout/Tabs/ChestTab/ResultLabel

func _ready() -> void:
	# 1. タブ名を日本語化（_ready で行う＝set_tab_title が反映される順序）
	for i: int in range(TAB_TITLE_KEYS.size()):
		tabs.set_tab_title(i, tr(TAB_TITLE_KEYS[i]))

	# 2. 遷移データの消費 → 該当タブを選択
	var data: Dictionary = SceneManager.consume_transfer_data()
	var initial_tab: String = str(data.get(TransferKeys.WAREHOUSE_TAB, TAB_INVENTORY))
	if TAB_INDEX.has(initial_tab):
		tabs.current_tab = int(TAB_INDEX[initial_tab])
	else:
		tabs.current_tab = 0

	# 3. ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	open_all_button.pressed.connect(_on_open_all_pressed)

	# 4. GameManager のシグナル購読
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.pending_chests_changed.connect(_on_pending_chests_changed)

	# 5. 初期描画
	_rebuild_inventory()
	_rebuild_codex()
	_rebuild_chest_list()
```

### 3-4. 戻るボタン

`SceneManager.change_scene(GUILD_PATH)` でギルド画面へ。`go_back()` は履歴管理がダミー扱いのため使わない方針（§2-3 と同じ理由）。

```gdscript
func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)
```

### 3-5. 「すべて開ける」ボタン

実装の中身は §4 で詳述。シグナル接続は `_ready()` で行う。

### 3-6. タブ日本語化の実装位置についての補足

指示書 §3-1 は「`_ready()` で `Tabs.set_tab_title(i, tr("..."))` を呼ぶこと」と明記している。`set_tab_title()` は TabContainer 側で各 TabBar の表示を即時更新する API なので、`_ready()` 末尾でも冒頭でも問題ない。実装では `tabs.set_tab_title(i, tr(TAB_TITLE_KEYS[i]))` のループを `_ready()` の最初（描画前）に置く。これにより InventoryGrid を再生成する前にタブ名が日本語化される。

---

## 4. 宝箱の開封処理の流れ

指示書 §3-5「宝箱タブ」と §3-5「開封処理」「結果の表示形式」「すべて開ける」を統合した実装方針。`open_chest()` は rewards を返さない（`game_manager.gd` 219-253 行で `bool` のみ返却）ため、**呼び出し側で `rewards` を読んでから呼ぶ** 必要がある。

### 4-1. 宝箱一覧の生成（`_rebuild_chest_list()`）

```gdscript
func _rebuild_chest_list() -> void:
	# 既存の子ノードを全削除（差分更新しない方針・指示書 §3-3）
	for child: Node in chest_list.get_children():
		child.queue_free()
	await chest_list.get_tree().process_frame  # free 完了を待つ

	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	var has_unopened: bool = false

	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		has_unopened = true
		_create_chest_row(chest_dict)

	open_all_button.disabled = not has_unopened

	if not has_unopened:
		var empty_label: Label = Label.new()
		empty_label.text = tr("ui_warehouse_no_chest")
		empty_label.name = "EmptyLabel"
		chest_list.add_child(empty_label)
```

### 4-2. 宝箱1件の行生成（`_create_chest_row()`）

```gdscript
func _create_chest_row(chest: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ChestRow_" + str(chest.get(GameStateKeys.CHEST_ID, ""))

	var name_label: Label = Label.new()
	name_label.text = tr("ui_pomodoro_chest_" + str(chest.get(GameStateKeys.CHEST_TYPE, "")))
	name_label.name = "ChestNameLabel"
	row.add_child(name_label)

	var open_button: Button = Button.new()
	open_button.text = tr("ui_warehouse_open")
	open_button.name = "OpenButton"
	var chest_id: String = str(chest.get(GameStateKeys.CHEST_ID, ""))
	open_button.pressed.connect(_on_open_chest_pressed.bind(chest_id))
	row.add_child(open_button)

	chest_list.add_child(row)
```

「開ける」ボタンの翻訳キーは指示書 §5 のリストには無いが、EXEC §3-5 の「『開ける』を押すと宝箱が一覧から消え、獲得した中身が『建築素材 ×10』のような形で表示される」（完了条件11）からボタンが必要。新規キー追加（`ui_warehouse_open`）は §7 で判断点として記載。

### 4-3. 個別開封（`_on_open_chest_pressed()`）― ここが本題

指示書 §3-5「開封処理（重要）」の手順を実装に落とす：

```gdscript
func _on_open_chest_pressed(chest_id: String) -> void:
	# 1. 開封前に rewards を読んでおく
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	var target: Dictionary = {}
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		if str(chest.get(GameStateKeys.CHEST_ID, "")) == chest_id:
			target = chest
			break
	if target.is_empty():
		push_warning("[WarehouseScreen] chest not found: " + chest_id)
		return
	var rewards: Dictionary = target.get(GameStateKeys.CHEST_REWARDS, {})

	# 2. open_chest() を呼ぶ
	var success: bool = GameManager.open_chest(chest_id)
	if not success:
		push_warning("[WarehouseScreen] open_chest failed: " + chest_id)
		return

	# 3. 整形して ResultLabel に表示
	_append_opened_rewards(rewards, tr("ui_warehouse_opened"))
```

ポイント：
- **呼び出し前に `rewards` を読む**：`open_chest()` を呼ぶと `game_manager.gd` 232行目で `chest[CHEST_OPENED] = true` されるが rewards 自体は破壊しない。`get_state()` が `duplicate(true)` したスナップショットを返すため、後で読んでもよいが、**指示書 §3-5 が「開封の前に読んでおく」と明示** しているのでそれに従う。
- `target` には `rewards` だけでなく `opened` も含まれるが、`rewards.get(...)` しか参照しないので問題ない。
- `get_state()` 経由なので、参照中に他スレッドが書き換える競合は発生しない（GDScript はシングルスレッド）。

### 4-4. rewards の整形（`_append_opened_rewards()`）

指示書 §3-5「結果の表示形式」：

```gdscript
func _append_opened_rewards(rewards: Dictionary, prefix: String) -> void:
	var lines: Array[String] = []
	if result_label.text != "":
		lines.append(result_label.text)  # 既存表示を保持して追記
	if prefix != "":
		lines.append(prefix)

	# gold
	if int(rewards.get(GameStateKeys.REWARD_GOLD, 0)) > 0:
		lines.append("%s ×%d" % [tr("ui_res_gold"), int(rewards[GameStateKeys.REWARD_GOLD])])
	# gems
	if int(rewards.get(GameStateKeys.REWARD_GEMS, 0)) > 0:
		lines.append("%s ×%d" % [tr("ui_res_gems"), int(rewards[GameStateKeys.REWARD_GEMS])])
	# stamina（指示書では「値が0または空でないものだけ」なので > 0 のみ）
	if int(rewards.get(GameStateKeys.REWARD_STAMINA, 0)) > 0:
		lines.append("%s ×%d" % [tr("ui_res_stamina"), int(rewards[GameStateKeys.REWARD_STAMINA])])
	# materials
	var materials: Dictionary = rewards.get(GameStateKeys.REWARD_MATERIALS, {})
	for mat_id: String in materials:
		var amount: int = int(materials[mat_id])
		if amount > 0:
			lines.append("%s ×%d" % [tr("ui_res_" + mat_id), amount])
	# inventory
	var inv: Dictionary = rewards.get(GameStateKeys.REWARD_INVENTORY, {})
	for item_id: String in inv:
		var count: int = int(inv[item_id])
		if count > 0:
			lines.append("%s ×%d" % [tr("ui_res_" + item_id), count])

	result_label.text = "\n".join(lines)
```

### 4-5.「すべて開ける」

指示書 §3-5「1件ずつ `open_chest()` を呼ぶ。まとめて処理する新しい関数を作らないこと」。

```gdscript
func _on_open_all_pressed() -> void:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	var opened_count: int = 0
	var combined_rewards: Dictionary = _empty_rewards()

	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var chest_id: String = str(chest_dict.get(GameStateKeys.CHEST_ID, ""))
		var rewards: Dictionary = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})

		if GameManager.open_chest(chest_id):
			_merge_rewards(combined_rewards, rewards)
			opened_count += 1

	if opened_count > 0:
		_append_opened_rewards(combined_rewards, tr("ui_warehouse_opened"))
	# opened_count == 0 なら何もしない（OpenAllButton は disabled のはず）
```

合算は次のヘルパーで行う：

```gdscript
func _empty_rewards() -> Dictionary:
	return {
		GameStateKeys.REWARD_GOLD: 0,
		GameStateKeys.REWARD_GEMS: 0,
		GameStateKeys.REWARD_STAMINA: 0,
		GameStateKeys.REWARD_MATERIALS: {},
		GameStateKeys.REWARD_INVENTORY: {},
	}

func _merge_rewards(combined: Dictionary, add: Dictionary) -> void:
	combined[GameStateKeys.REWARD_GOLD] = int(combined.get(GameStateKeys.REWARD_GOLD, 0)) + int(add.get(GameStateKeys.REWARD_GOLD, 0))
	combined[GameStateKeys.REWARD_GEMS] = int(combined.get(GameStateKeys.REWARD_GEMS, 0)) + int(add.get(GameStateKeys.REWARD_GEMS, 0))
	combined[GameStateKeys.REWARD_STAMINA] = int(combined.get(GameStateKeys.REWARD_STAMINA, 0)) + int(add.get(GameStateKeys.REWARD_STAMINA, 0))
	var cur_mats: Dictionary = combined.get(GameStateKeys.REWARD_MATERIALS, {})
	var add_mats: Dictionary = add.get(GameStateKeys.REWARD_MATERIALS, {})
	for mat_id: String in add_mats:
		cur_mats[mat_id] = int(cur_mats.get(mat_id, 0)) + int(add_mats[mat_id])
	combined[GameStateKeys.REWARD_MATERIALS] = cur_mats
	var cur_inv: Dictionary = combined.get(GameStateKeys.REWARD_INVENTORY, {})
	var add_inv: Dictionary = add.get(GameStateKeys.REWARD_INVENTORY, {})
	for item_id: String in add_inv:
		cur_inv[item_id] = int(cur_inv.get(item_id, 0)) + int(add_inv[item_id])
	combined[GameStateKeys.REWARD_INVENTORY] = cur_inv
```

`open_chest()` の呼び出し自体は **1件ずつ** であり、指示書 §3-5 の「1件ずつ `open_chest()` を呼ぶ。まとめて処理する新しい関数を作らないこと」に従う。合算は GameManager の `_state` を直接触らず、`rewards` Dictionary（呼び出し側で参照用に保持しているコピー）の数値を足し合わせるだけ。

### 4-6. シグナル受信時の再描画

```gdscript
func _on_pending_chests_changed(_pending_count: int) -> void:
	_rebuild_chest_list()

func _on_inventory_changed(_item_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()  # codex は inventory_changed 経由でも更新される（GameManager 側の挙動）
```

`_rebuild_chest_list()` の中で `pending_chests_changed` のシグナル経由で開封後の状態が即時反映される。各 `open_chest()` 呼び出しは GameManager 内で `pending_chests_changed.emit(...)` するため、**1回開けるたびに chest_list が再構築され、開けた宝箱は消える**。これが指示書完了条件11「開けると宝箱が一覧から消え」の挙動。

---

## 5. インベントリタブと図鑑タブの生成方法

### 5-1. インベントリタブ（`_rebuild_inventory()`）

指示書 §3-3 に従う。

```gdscript
func _rebuild_inventory() -> void:
	for child: Node in inventory_grid.get_children():
		child.queue_free()
	await inventory_grid.get_tree().process_frame

	var state: Dictionary = GameManager.get_state()
	var inventory: Dictionary = state.get(GameStateKeys.INVENTORY, {})

	if inventory.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = tr("ui_warehouse_empty")
		empty_label.name = "EmptyLabel"
		inventory_grid.add_child(empty_label)
		return

	for item_id: String in inventory:
		var entry: Dictionary = inventory[item_id]
		var count: int = int(entry.get(GameStateKeys.ITEM_COUNT, 0))
		if count <= 0:
			continue
		_create_inventory_entry(item_id, count)

func _create_inventory_entry(item_id: String, count: int) -> void:
	var entry: VBoxContainer = VBoxContainer.new()
	entry.name = "Inv_" + item_id

	var name_label: Label = Label.new()
	name_label.text = tr("ui_res_" + item_id)  # 素材と同じ規約・新しい接頭辞を作らない
	name_label.name = "NameLabel"
	entry.add_child(name_label)

	var count_label: Label = Label.new()
	count_label.text = str(count)  # 数値のみ・tr() 不要
	count_label.name = "CountLabel"
	entry.add_child(count_label)

	inventory_grid.add_child(entry)
```

設計要点：
- **アイテム名翻訳キー**：`tr("ui_res_" + item_id)`。`item_id` は `stamina_potion` 等のスネークケース文字列で、既存の `ui_res_stamina_potion = "スタミナポーション"`（ja.csv 63行目）に当たる。指示書 §3-3「新しい接頭辞を作らないこと」を遵守。
- **個数**：`str(count)` の数値のみ。`tr()` 不要（AGENTS.md 翻訳ルール）。
- **空判定**：`inventory.is_empty()` でなく `count <= 0` のエントリを除外しているのは、将来 count=0 が来た場合のため。指示書完了条件7「所持しているアイテム（建築素材・スタミナポーション等）」は count>0 を意味するためこれで十分。
- **差分更新しない**：指示書 §3-3 の方針通り、`inventory_changed` シグナルを受けたら `_rebuild_inventory()` で全削除→全再生成。

### 5-2. 図鑑タブ（`_rebuild_codex()`）

指示書 §3-4 に従う。

```gdscript
func _rebuild_codex() -> void:
	for child: Node in codex_list.get_children():
		child.queue_free()
	await codex_list.get_tree().process_frame

	var state: Dictionary = GameManager.get_state()
	var codex: Dictionary = state.get(GameStateKeys.CODEX, {})

	if codex.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = tr("ui_warehouse_empty")
		empty_label.name = "EmptyLabel"
		codex_list.add_child(empty_label)
		return

	for item_id: String in codex:
		var entry: Dictionary = codex[item_id]
		var discovered: bool = bool(entry.get(GameStateKeys.CODEX_DISCOVERED, false))
		_create_codex_row(item_id, discovered)

func _create_codex_row(item_id: String, discovered: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CodexRow_" + item_id

	var name_label: Label = Label.new()
	if discovered:
		name_label.text = tr("ui_res_" + item_id)
	else:
		name_label.text = tr("ui_warehouse_undiscovered")
	name_label.name = "NameLabel"
	row.add_child(name_label)

	codex_list.add_child(row)
```

設計要点：
- **discovered=true → `ui_res_<item_id>`**、**false → `ui_warehouse_undiscovered`**（指示書 §3-4）。
- 現状の GameManager 実装（`game_manager.gd` 188-192 行）では `add_to_inventory()` 時に `discovered` が true になる経路しかない。**false の経路は現状発生しない**（指示書 §3-4 末尾の「武器がまだ存在しないため、ポーション等が数件並ぶだけになる」記述、および完了条件8「未入手があれば『？？？』」が「未入手があれば」と条件付きであることから、将来の「図鑑は持っているが未発見」の状態への布石と解釈）。
- 並び順：`codex` Dictionary の挿入順 = アイテム入手順。`sort_keys` はしない（指示書記載なし）。

### 5-3. 翻訳キーの整合確認

`ja.csv` の現状で確認した既存翻訳キー（指示書 §5 で「すでに存在する」明記分）：

- `ui_res_gold` / `ui_res_gems` / `ui_res_stamina`（行18-20）
- `ui_res_construction_material`（行21）
- `ui_res_stamina_potion`（行63）
- `ui_common_back`（行15）
- `ui_nav_guild`（行23）
- `ui_pomodoro_chest_generic` / `ui_pomodoro_chest_bonus_small` / `ui_pomodoro_chest_bonus_medium` / `ui_pomodoro_chest_bonus_large`（行36-39）

**これらは新規追加しない**。§5 で追加する18行は指示書 §5 のリスト通り：
- `ui_guild_*` 5行（倉庫/ショップ/育成/研究/作業場）
- `ui_nav_*` 5行（同上、placeholder_screen が `tr("ui_nav_" + screen_id)` で引く）
- `ui_warehouse_*` 8行（タブ名3 + ボタン1 + 空表示1 + 未発見1 + 宝箱なし1 + 開封後1）

### 5-4. 完了条件との対応

| 完了条件 | 該当実装 |
|---|---|
| 7. 持ち物タブに名前と個数で表示 | §5-1 `_rebuild_inventory()` + `_create_inventory_entry()` |
| 8. 図鑑タブに名前表示・未入手は「？？？」 | §5-2 `_rebuild_codex()` + `_create_codex_row()` |
| 10. 宝箱タブに未開封が種類名で並ぶ | §4-1 `_rebuild_chest_list()` + §4-2 `_create_chest_row()` |
| 11. 開けると消えて中身表示 | §4-3 `_on_open_chest_pressed()` + `pending_chests_changed` 経由の `_rebuild_chest_list()` |
| 14. すべて開けるで合算 | §4-5 `_on_open_all_pressed()` + §4-4 の `_append_opened_rewards()` |
| 15. 0件時に文言と disabled | §4-1 の `open_all_button.disabled = not has_unopened` と `EmptyLabel` 表示 |

---

## 6. `base_screen.gd` の変更点と、既存ファイルを壊さない手順

### 6-1. `base_screen.gd` の変更2箇所

#### 変更箇所A：`SCREEN_SCENES` の `SCREEN_GUILD` 行の差し替え

**変更前**（行18）：
```gdscript
	GameStateKeys.SCREEN_GUILD: PLACEHOLDER_PATH,
```

**変更後**：
```gdscript
	GameStateKeys.SCREEN_GUILD: "res://scenes/guild/guild_screen.tscn",
```

**実施方法**：bash の `cat >>` では部分置換できないため、Python 等の補助スクリプトは禁止（指示書 §0-1）。代わりに **2行だけ再記述する形**でファイル末尾の任意の行を置き換える手段が必要。指示書 §0-1 は `edit_file` を使わないと明記しているが、本プロジェクトでは `edit_file` は動作しないと指示書 §0-1 に明記されているため、**`bash` で `awk` ではなく `sed` も禁止**（指示書 §0-1）。

**実施手順**：直接 `read` で該当行周辺を確認し、`base_screen.gd` を再生成するための方針：
- 案1：`base_screen.gd` 全体（199行）を再生成する。中身は把握済み（read で確認）。指示書 §0-1「既存ファイルを `cat >` で上書きしない」に違反しないように、**全行を `cat >` で1回書き換えるのは禁止**。
- 案2：置換したい行を含む最小範囲を `cat >>` で追記しない（意味がない）。
- 案3：`transfer_keys.gd` への追記は `cat >>` で問題ない（末尾への追記だから）。`base_screen.gd` の行18の置換は **ファイル全体の上書きが必要**。

→ AGENTS.md「`edit_file`は使用しない。このプロジェクトでは動作しない」だが、Ziva の `edit_file` ツールは本指示書で禁止されている（指示書 §0-1）。**実装フェーズでは人間に判断を仰ぐ**。本計画では「変更箇所」を明確化し、§7 で迷いポイントとして記載する。

#### 変更箇所B：`_on_chest_badge_pressed()` の差し替え

**変更前**（行189-191）：
```gdscript
func _on_chest_badge_pressed() -> void:
	# 宝箱はギルド画面にある想定
	_go_to_screen(GameStateKeys.SCREEN_GUILD)
```

**変更後**：
```gdscript
func _on_chest_badge_pressed() -> void:
	# バッジから押されたら倉庫画面の宝箱タブへ直接遷移（指示書 §4-2）
	SceneManager.change_scene_with_data(
		"res://scenes/guild/warehouse_screen.tscn",
		{TransferKeys.WAREHOUSE_TAB: "chest"}
	)
```

`"chest"` の文字列リテラルは AGENTS.md の「文字列リテラルではなく `GameStateKeys` の定数を使う」ルールに抵触するように見えるが、`TransferKeys.WAREHOUSE_TAB` の**値として渡される側**（=`WarehouseScreen.TAB_CHEST`）は **タブ識別子のプロトコル** であり、GameManager 状態キーではない。指示書 §1 では `WarehouseScreen.TAB_*` の文字列を値とする前提で `WAREHOUSE_TAB: String = "warehouse_tab"` を追加している。整合性を取るため、**`WarehouseScreen` 側に `const TAB_CHEST: String = "chest"` を定義し、`base_screen.gd` 側からは `"chest"` の文字列リテラルで参照する** か、あるいは **`base_screen.gd` 側に同等の定数を持つ** かのいずれかとなる。

本計画では **AGENTS.md の精神に従い、ベース画面側に定数を持たせる** のが安全：
- 選択肢イ：`base_screen.gd` 内に `const CHEST_TAB_ID: String = "chest"` を導入
- 選択肢ロ：指示書 §4-2 のコードをそのまま書き、文字列リテラル `"chest"` を使う（指示書が「このコードを書け」と示しているので AGENTS.md ルールに対する明示的な例外とみなす）
- 選択肢ハ：TransferKeys に `WAREHOUSE_TAB_CHEST: String = "chest"` のような値定数も追加

本計画では **選択肢ロ**（指示書のコードそのまま）を採用する。理由は：
1. 指示書 §4-2 がコード全文をそのまま提示している
2. 値定数の新設は TransferKeys の責務（画面間の**キー名**）を逸脱し、値の取り違えリスクを生む
3. `base_screen.gd` 側に同名の定数を置くと、今度は `WarehouseScreen.TAB_CHEST` との二重管理になる

§7 でも改めて記載する。

### 6-2. `transfer_keys.gd` への追記コマンド

指示書 §1 に従い、末尾に1行追記：

```bash
cat >> "D:/pomodoro-heroes/scripts/utils/transfer_keys.gd" << 'EOF'

# 倉庫画面を開いたときに最初に表示するタブ。
# 値は WarehouseScreen.TAB_* の文字列。
const WAREHOUSE_TAB: String = "warehouse_tab"
### 6-3. ja.csv への追記コマンド

重要：指示書 §5 の順番通りに追記する。指示書 §0-1「同じ内容を2回追記しない」を守るため、1回の cat >> で全18行を一括追記する：

```
cat >> "D:/pomodoro-heroes/localization/ja.csv" << 'CSV_EOF'
ui_guild_warehouse,倉庫
ui_guild_shop,ショップ
ui_guild_training,育成
ui_guild_research,研究
ui_guild_workshop,作業場
ui_nav_warehouse,倉庫
ui_nav_shop,ショップ
ui_nav_training,育成
ui_nav_research,研究
ui_nav_workshop,作業場
ui_warehouse_tab_inventory,持ち物
ui_warehouse_tab_codex,図鑑
ui_warehouse_tab_chest,宝箱
ui_warehouse_open_all,すべて開ける
ui_warehouse_empty,なにもありません
ui_warehouse_undiscovered,？？？
ui_warehouse_no_chest,受け取れる宝箱はありません
ui_warehouse_opened,開けました
CSV_EOF
```

追記後の確認方法：
- read ツールで ja.csv 全体を開き、以下を確認する：
  - 1行目 keys,ja が残っている
  - 既存の ui_title_label（行2）から ui_base_use_potion（行65）までの65行がすべて残っている
  - 新規18行が末尾に並んでいる
  - 重複行が無い
  - BOM なし UTF-8（read のヘッダ表示で判別）
- 上記を確認したら、Godot エディタ側で ja.csv を再インポート（指示書 §5「再インポートすること」）。FileSystem パネルで右クリック → 再インポート、または Godot 再起動。
EOF
EOF

---

## 7. 判断に迷った点

実装フェーズで人間に確認したい、または方針を選択したい点。指示書には明記されていなかった／解釈が分かれる箇所。

### 7-1. 「開ける」ボタンのラベル翻訳キー

指示書 §3-5 の完了条件11は「『開ける』を押すと宝箱が一覧から消え、獲得した中身が…」と書いているが、指示書 §5 の `ui_warehouse_*` 一覧に **`ui_warehouse_open` 等の "open" 単体のキーが無い**。考えられる選択肢：

- **A)** `ui_warehouse_open,開ける` を18行に追加して合計19行にする。完了条件11の文言と一致する
- **B)** Button の `text` プロパティに直接 `"開ける"` を書く（AGENTS.md の `tr()` ルール違反、翻訳表を通らない）
- **C)** `ui_common_ok`（既存・「決定」）を再利用する（意味がずれる）

→ **A を採用予定**。指示書 §5 の一覧は「最低限追加するもの」を示していると解釈し、UI に必要なキーは追加する。ただし追加することで指示書の「18行」と整合しなくなるため、**人間に最終確認を仰ぎたい**。

### 7-2. `base_screen.gd` 内の `chest_badge.pressed` ハンドラ内の文字列リテラル

指示書 §4-2 の提示コードは `{TransferKeys.WAREHOUSE_TAB: "chest"}` と `chest` を直接書いている。AGENTS.md「文字列リテラルではなく `GameStateKeys` の定数を使う」は **GameManager 状態キーのルール**であり、本ケースは画面間の **タブ識別子**（=WarehouseScreen 内部の定数値）なので、文字列リテラルでも AGENTS.md 違反にはならない、と解釈した（§6-1 選択肢ロ）。ただし厳密性を優先するなら：

- `WarehouseScreen.TAB_CHEST` を Public な定数として `class_name WarehouseScreen` で公開し、`base_screen.gd` から `WarehouseScreen.TAB_CHEST` で参照する
- `TransferKeys` に `WAREHOUSE_TAB_CHEST: String = "chest"` のような値定数を追加する

→ **現状は指示書 §4-2 のコードをそのまま採用**。本計画では「プロジェクトルールと指示書コードが衝突する場面」と整理し、**人間に最終判断を仰ぎたい**。

### 7-3. `base_screen.gd` の部分置換手段

§6-1 変更箇所A の `SCREEN_SCENES[SCREEN_GUILD]` 行の差し替えと、変更箇所B の `_on_chest_badge_pressed()` 関数本体の差し替えは、どちらも **既存行の削除＋新行の挿入** に該当する。指示書 §0-1 の禁止事項：

- `edit_file` 使用禁止
- `cat >` 上書き禁止
- `sed` 使用禁止
- 補助スクリプト（.py）作成禁止

この制約下で `base_screen.gd` の **行単位の差し替え**をどう実現するか。現実的な手段：

- **案1**：Ziva の `edit_file` ツールを使う（指示書 §0-1 違反）
- **案2**：ファイルを `cat >` で全行書き直す（指示書 §0-1 違反）
- **案3**：置換対象の前までの全行と、置換対象行、置換後の全行を `head`/`tail` で分割 → 連結（シェルスクリプトが必要、AGENTS.md で「bash で `sed` を使わない」とあり `awk` のみ許可と推測）
- **案4**：**変更箇所A のみ**実施（`SCREEN_SCENES` の `SCREEN_GUILD` 行を `PLACEHOLDER_PATH` → `guild_screen.tscn` パスに変えるだけ）。**変更箇所B は諦め、チェストバッジの遷移先変更は別タスクに回す**。ただし完了条件9（拠点画面のチェストバッジを押すと、倉庫画面の宝箱タブが開いた状態で表示される）が満たせなくなる

→ 案4 は完了条件を1つ落とすことになるため不可。**人間に案3（awk）の許可、または `edit_file` の例外許可を仰ぎたい**。実装フェーズに進む前に判断が必要。

### 7-4. `TabContainer` のデフォルトタブ名抑制

指示書 §3-1 では子ノード `InventoryTab` / `CodexTab` / `ChestTab` のノード名がそのままデフォルトのタブ表示になる、と書かれている。`_ready()` で `set_tab_title()` を呼ぶとデフォルト名は上書きされる。**`_ready()` が呼ばれるまでの1フレーム、ノード名が画面に出る懸念**：

- Godot の `TabContainer` は `_ready()` 完了後にタブバーを描画するため、**実際には1フレームも英語名は出ない**（と推測）
- 念のためノード名自体を `Tab0` / `Tab1` / `Tab2` のような機械的な名前にするか、`Inventory` / `Codex` / `Chest`（PascalCase を崩した中立名）にすれば、英語名でも違和感がない

→ 現状の `InventoryTab` 等で問題ないと判断。**過剰防衛は避ける**。ただし Godot 起動時に一瞬英語名が見える場合は要修正（実装後の動作確認で発覚したら §7 末尾に追記せず人間に判断を仰ぐ）。

### 7-5. `ResultLabel` の改行

指示書 §3-5「複数ある場合は改行で並べる」と明記。実装では `"\n".join(lines)` で改行を挿入する（§4-4 参照）。Label ノードのデフォルトでは複数行表示が有効（`autowrap_mode` 設定による）。`autowrap_mode = 0 (OFF)` の場合、幅を超えると切れて見える可能性：

- `ResultLabel` を `ChestTab`（VBoxContainer）の中に直接置いているため、VBoxContainer 内で幅は自動調整される
- `autowrap_mode` を `3 (WORD_SMART)` に設定すれば、長文が折り返される

→ 実装では `ResultLabel.autowrap_mode = 3` を `.tscn` 側で設定する。**これは指示書記載が無い**ため、軽微な判断として実装に含める。問題があれば人間に報告。

### 7-6. 「すべて開ける」での `rewards` 読み取りタイミング

§4-5 の `_on_open_all_pressed()` では、`open_chest()` を呼ぶ**前** に各宝箱の `rewards` を `get_state()` から読んでいる。`_state.duplicate(true)` のスナップショットなので、1回目・2回目の `open_chest()` 呼び出しで `_state` が書き換わっても、最初に見たスナップショットには影響しない：

- スナップショット内で `chests[i][CHEST_OPENED]` はすべて `false` のまま
- 各宝箱の `rewards` は変更されない（`open_chest()` は `opened=true` するだけで rewards は破壊しない）
- したがって、すべての宝箱の `rewards` を正確に読める

これは指示書 §3-5「開封の前に rewards を読んでおく」方針と整合する。**迷いはないが、設計判断として明記**。

### 7-7. タブ0/1/2 とプロトコル文字列のマッピング

`TransferKeys.WAREHOUSE_TAB` の値 `"inventory"` / `"codex"` / `"chest"` を `WarehouseScreen` 内の定数 `TAB_INVENTORY` / `TAB_CODEX` / `TAB_CHEST` と一致させる。`base_screen.gd` からは `"chest"` という生文字列で渡される（指示書 §4-2）：

- 受け側（WarehouseScreen）の `_ready()` で `data.get(WAREHOUSE_TAB, TAB_INVENTORY)` として比較 → 一致すれば `current_tab` を切り替え
- 不一致ならタブ0のまま

→ `TAB_INDEX` Dictionary で吸収する設計（§3-2）。**base_screen.gd と WarehouseScreen の間でプロトコルとして `"chest"` 等の文字列を共有する暗黙契約**になるが、指示書がこれを前提としているため採用。

### 7-8. `await get_tree().process_frame` の使用

`queue_free()` 直後に `process_frame` を待つことで、子の解放完了を待ってから新規追加する（§4-1, §5-1, §5-2）。Godot 4 では `queue_free()` は遅延解放のため、**直後に `add_child()` すると ID 衝突や描画のちらつきが起きる**。`process_frame` の待ちは安全な実装：

- ただし毎回の再構築で `await` を使うと、`inventory_changed` 連発時に1フレーム遅延が積み重なる可能性
- 代替：`queue_free()` の代わりに `child.free()`（同期解放）を使う → しかし `child` が今まさに描画中だとクラッシュリスクあり

→ `await get_tree().process_frame` を採用。**副作用は許容範囲**（タブ再構築は1秒に数回程度）。

### 7-9. §6-2 と §6-3 の間の構造

本ファイル作成時に、bash 呼び出しのバッククォート解釈エラーにより §6-2 末尾の `EOF` 閉じタグと §6-3 ヘッダの間に空行と整合性が崩れる箇所が生じた（行706 付近）。**§6-3 の本文は正しく末尾まで書かれている**ため、本計画としての §6 は読み取れる状態。誤字修正は人間が直す方針（指示書 §0-2）に従い、**構造破壊の修正には入らず、ここで停止**した。

### 7-10. 「セクション6を書きました」と報告する前の追記ミス

§6-3 の追記コマンドを書いた直前の bash 呼び出しで、heredoc 内のバッククォートがコマンド置換として解釈され、エラーで停止した。直前のセクション（§6-2 末尾）に中途半端な `### 6-3` ヘッダが書き込まれている状態。**§6-3 の本文自体は正常**だが、ファイル構造上は不整合。

→ §7-9 と同じ方針で、人間に修正を委ねる。

### 7-11. 完了条件 16（grep 確認）と 17（コードレビュー確認）

完了条件16「画面遷移がすべて `SceneManager` 経由であることを `grep` で確認できる（`change_scene_to_file()` の直接呼び出しが `scene_manager.gd` 以外に無い）」と17「遷移先のシーンパスが対応表1箇所にまとまっており、ボタンごとに直書きされていないことをコードレビューで確認できる」。

→ 実装後フェーズで実施する。本計画では「実装後、grep で `change_scene_to_file` を検索し、`scene_manager.gd` 以外でヒットしないことを確認」「`base_screen.gd` と `guild_screen.gd` の GUILD_SCENES / SCREEN_SCENES が一箇所集約になっていることを目視確認」とする。

### 7-12. 人間による決定事項（このプロジェクト方針）

AGENTS.md §二段構え「【C】PRE_PLAN に『人間による決定事項』章を追記してから実装させる」に従い、本章に人間から方針決定を要する項目を列挙する：

- **7-1**：`ui_warehouse_open` キーを追加するか（合計19行）。**追加する想定**で人間確認待ち
- **7-2**：`"chest"` の文字列リテラルを `WarehouseScreen.TAB_CHEST` 参照に置換するか否か
- **7-3**：`base_screen.gd` の部分置換を `awk` で許可するか、`edit_file` を本タスク限定で許可するか
- **7-4**：タブノード名を `Tab0` 等に変更するか、現状維持か
- **7-5**：`ResultLabel.autowrap_mode = 3` 設定を含めるか

→ 実装フェーズに進む前に、これら5項目について人間の決定を仰ぐ。
## 8. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§7 と矛盾する場合は **この §8 を優先する。**

### 8-1.【回答】§6-2 の破損箇所について

行706付近で transfer_keys.gd のコードブロックが閉じず、
6-3 のヘッダが混入している件は**そのままでよい。**
本文の内容はすべて揃っており、実装に支障はない。修正しないこと。

### 8-2.【承認】ui_warehouse_open を追加する（§7-1）

「開ける」ボタンのラベルが指示書 §5 から漏れていた。以下を追加し、
ja.csv への追記は合計19行とする。

	ui_warehouse_open,開ける

### 8-3.【承認】base_screen.gd では TAB_CHEST を参照する（§7-2）

指示書 §4-2 のコードは文字列リテラル "chest" になっているが、
AGENTS.md の方針に照らすと定数参照が正しい。
WarehouseScreen.TAB_CHEST を使うこと。

	SceneManager.change_scene_with_data(
		WAREHOUSE_PATH,
		{TransferKeys.WAREHOUSE_TAB: WarehouseScreen.TAB_CHEST}
	)

WAREHOUSE_PATH は base_screen.gd の定数として定義してよい。
この参照のため、warehouse_screen.gd には
class_name WarehouseScreen を付けること。

### 8-4.【回答】base_screen.gd の2箇所は人間が編集する（§7-3）

awk も edit_file も使わないこと。
**base_screen.gd の変更2箇所（SCREEN_SCENES の1行と
_on_chest_badge_pressed の中身）は人間がGodotエディタで編集する。**

実装側は base_screen.gd を触らないこと。
指示書 §4 は「人間が対応済み」として扱う。

理由：既存ファイルの途中を書き換える手段が安全に確保できておらず、
過去に既存定数が消える事故が起きているため。

### 8-5.【承認】タブノード名はそのまま（§7-4）

InventoryTab / CodexTab / ChestTab のままでよい。
PascalCase で AGENTS.md の命名規則に沿っている。
set_tab_title() で日本語表示にすること。

### 8-6.【承認】ResultLabel の autowrap（§7-5）

autowrap_mode を設定してよい。複数行の報酬で見切れるのを防ぐため。

### 8-7. そのまま採用する判断

§2、§3、§4（開封処理の流れ。特に 4-3 の「開封前に rewards を読む」）、
§5、§6-2、§6-3、§7-6、§7-7、§7-8、§7-11
### 8-8.【追記】transfer_keys.gd も人間が編集済み

base_screen.gd が WAREHOUSE_TAB を参照するため、
transfer_keys.gd への追記も**人間が実施済み**とする。
指示書 §1 は対応済み。実装側は transfer_keys.gd を触らないこと。
EOF
