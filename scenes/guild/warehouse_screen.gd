# res://scenes/guild/warehouse_screen.gd
# 倉庫画面：3タブ（持ち物/図鑑/宝箱）を持つ。指示書 EXEC_GUILD_WAREHOUSE.md §3 準拠。
# 拠点からチェストバッジ経由で来た場合は宝箱タブが開く（TransferKeys.WAREHOUSE_TAB）。
# §8-3 に基づき class_name WarehouseScreen を公開し、base_screen.gd 等から
# TAB_INVENTORY / TAB_CODEX / TAB_CHEST を参照できるようにする。

class_name WarehouseScreen
extends Control

# --- タブ識別子（§8-3 で他ファイルから参照される前提で public） ---
const TAB_INVENTORY: String = "inventory"
const TAB_CODEX: String = "codex"
const TAB_CHEST: String = "chest"

# タブインデックス（InventoryTab=0, CodexTab=1, ChestTab=2）
const TAB_INDEX: Dictionary = {
	TAB_INVENTORY: 0,
	TAB_CODEX: 1,
	TAB_CHEST: 2,
}

# タブタイトル用翻訳キー（_ready で set_tab_title に使う）
const TAB_TITLE_KEYS: Array[String] = [
	"ui_warehouse_tab_inventory",
	"ui_warehouse_tab_codex",
	"ui_warehouse_tab_chest",
]

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"

# --- ノード参照 ---
@onready var tabs: TabContainer = $Layout/Tabs
@onready var back_button: PrimaryButton = $Layout/Header/BackButton
@onready var inventory_grid: GridContainer = $Layout/Tabs/InventoryTab/InventoryGrid
@onready var codex_list: VBoxContainer = $Layout/Tabs/CodexTab/CodexList
@onready var open_all_button: PrimaryButton = $Layout/Tabs/ChestTab/OpenAllButton
@onready var chest_list: VBoxContainer = $Layout/Tabs/ChestTab/ChestScroll/ChestList
@onready var result_label: Label = $Layout/Tabs/ChestTab/ResultLabel

func _ready() -> void:
	# 1. タブ名を日本語化（ノード名の英語が画面に出る前に上書き）
	for i: int in range(TAB_TITLE_KEYS.size()):
		tabs.set_tab_title(i, tr(TAB_TITLE_KEYS[i]))

	# 2. 遷移データを消費 → 該当タブを選択（無ければタブ0）
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

# --- 戻る ---

func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)

# --- インベントリタブ ---

func _rebuild_inventory() -> void:
	for child: Node in inventory_grid.get_children():
		child.queue_free()
	await get_tree().process_frame

	var state: Dictionary = GameManager.get_state()
	var inventory: Dictionary = state.get(GameStateKeys.INVENTORY, {})

	if inventory.is_empty():
		_add_empty_label(inventory_grid)
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
	name_label.text = tr("ui_res_" + item_id)
	name_label.name = "NameLabel"
	entry.add_child(name_label)

	var count_label: Label = Label.new()
	count_label.text = str(count)
	count_label.name = "CountLabel"
	entry.add_child(count_label)

	inventory_grid.add_child(entry)

# --- 図鑑タブ ---

func _rebuild_codex() -> void:
	for child: Node in codex_list.get_children():
		child.queue_free()
	await get_tree().process_frame

	var state: Dictionary = GameManager.get_state()
	var codex: Dictionary = state.get(GameStateKeys.CODEX, {})

	if codex.is_empty():
		_add_empty_label(codex_list)
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

# --- 宝箱タブ ---

func _rebuild_chest_list() -> void:
	for child: Node in chest_list.get_children():
		child.queue_free()
	await get_tree().process_frame

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
		_add_empty_label(chest_list)

func _create_chest_row(chest: Dictionary) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var chest_id: String = str(chest.get(GameStateKeys.CHEST_ID, ""))
	row.name = "ChestRow_" + chest_id

	var name_label: Label = Label.new()
	name_label.text = tr("ui_pomodoro_chest_" + str(chest.get(GameStateKeys.CHEST_TYPE, "")))
	name_label.name = "ChestNameLabel"
	row.add_child(name_label)

	var open_button: Button = Button.new()
	open_button.text = tr("ui_warehouse_open")
	open_button.name = "OpenButton"
	open_button.pressed.connect(_on_open_chest_pressed.bind(chest_id))
	row.add_child(open_button)

	chest_list.add_child(row)

func _add_empty_label(parent: Container) -> void:
	var empty_label: Label = Label.new()
	empty_label.text = tr("ui_warehouse_no_chest")
	empty_label.name = "EmptyLabel"
	parent.add_child(empty_label)

# --- 開封処理 ---

func _on_open_chest_pressed(chest_id: String) -> void:
	# 1. 開封前に rewards を読んでおく（open_chest は rewards を返さない）
	var rewards: Dictionary = _read_chest_rewards(chest_id)
	if rewards.is_empty() and not _chest_exists(chest_id):
		push_warning("[WarehouseScreen] chest not found: " + chest_id)
		return

	# 2. open_chest を呼ぶ
	var success: bool = GameManager.open_chest(chest_id)
	if not success:
		push_warning("[WarehouseScreen] open_chest failed: " + chest_id)
		return

	# 3. 整形して ResultLabel に表示
	_append_opened_rewards(rewards, tr("ui_warehouse_opened"))

func _on_open_all_pressed() -> void:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	var opened_count: int = 0
	var combined: Dictionary = _empty_rewards()

	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var chest_id: String = str(chest_dict.get(GameStateKeys.CHEST_ID, ""))
		var rewards: Dictionary = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})

		if GameManager.open_chest(chest_id):
			_merge_rewards(combined, rewards)
			opened_count += 1

	if opened_count > 0:
		_append_opened_rewards(combined, tr("ui_warehouse_opened"))

# --- rewards 整形 ---

func _append_opened_rewards(rewards: Dictionary, prefix: String) -> void:
	var lines: Array[String] = []
	if result_label.text != "":
		lines.append(result_label.text)
	if prefix != "":
		lines.append(prefix)

	# gold
	if int(rewards.get(GameStateKeys.REWARD_GOLD, 0)) > 0:
		lines.append("%s ×%d" % [tr("ui_res_gold"), int(rewards[GameStateKeys.REWARD_GOLD])])
	# gems
	if int(rewards.get(GameStateKeys.REWARD_GEMS, 0)) > 0:
		lines.append("%s ×%d" % [tr("ui_res_gems"), int(rewards[GameStateKeys.REWARD_GEMS])])
	# stamina
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

# --- ヘルパー ---

func _read_chest_rewards(chest_id: String) -> Dictionary:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if str(chest_dict.get(GameStateKeys.CHEST_ID, "")) == chest_id:
			var rewards_val: Variant = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})
			if rewards_val is Dictionary:
				return rewards_val
			return {}
	return {}

func _chest_exists(chest_id: String) -> bool:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if str(chest_dict.get(GameStateKeys.CHEST_ID, "")) == chest_id:
			return true
	return false

# --- シグナルハンドラ ---

func _on_inventory_changed(_item_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()

func _on_pending_chests_changed(_pending_count: int) -> void:
	_rebuild_chest_list()
