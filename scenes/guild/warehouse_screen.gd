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
# 持ち物タブはマス目（段階18-c・PLAN_INVENTORY.md）。
# ⚠ ScrollContainer をやめた。⚠ 中が scenario=layout で測れないため（宿題68）。
#   ⚠ 20列 × 5行 ＝ 100 マスが1ページで、⚠ 5ページを送って見る（人間の決定8）。
@onready var inventory_grid: ItemGrid = $Layout/Tabs/InventoryTab/InventoryGrid
@onready var capacity_label: Label = $Layout/Tabs/InventoryTab/InventoryHeader/CapacityLabel
@onready var page_label: Label = $Layout/Tabs/InventoryTab/InventoryHeader/PageLabel
# 枠を買う（段階18-e）。⚠ 値段も押せるかも GameManager に聞く。⚠ ここで式を書かない。
@onready var expand_button: PrimaryButton = $Layout/Tabs/InventoryTab/InventoryHeader/ExpandButton
@onready var prev_page_button: PrimaryButton = $Layout/Tabs/InventoryTab/InventoryHeader/PrevPageButton
@onready var next_page_button: PrimaryButton = $Layout/Tabs/InventoryTab/InventoryHeader/NextPageButton
# 押したマスの詳細（段階18-c-2・共有部品）。⚠ 中身の判定は部品の中で GameManager に聞く。
@onready var item_detail: ItemDetail = $Layout/Tabs/InventoryTab/ItemDetail
@onready var action_row: HBoxContainer = $Layout/Tabs/InventoryTab/ActionRow
@onready var codex_list: VBoxContainer = $Layout/Tabs/CodexTab/CodexList
@onready var open_all_button: PrimaryButton = $Layout/Tabs/ChestTab/OpenAllButton
@onready var chest_list: VBoxContainer = $Layout/Tabs/ChestTab/ChestScroll/ChestList
@onready var result_label: Label = $Layout/Tabs/ChestTab/ResultLabel

# 押した所の近くに詳細を出す器（2026-09-07）。⚠ 上の2つを引き取るので、
#   ⚠ `item_detail` / `action_row` の参照はそのまま使える（⚠ 親が変わるだけ）。
var _detail_popup: ItemDetailPopup = null

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
	# 装備は inventory ではなく equipment_instances に入るため、こちらも購読する。
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)

	# 5. マス目の配線（段階18-c）。⚠ ページ送りは GameManager に聞く（5 を直接書かない）。
	inventory_grid.columns = GameManager.get_inventory_columns()
	inventory_grid.slot_pressed.connect(_on_slot_pressed)
	inventory_grid.slot_moved.connect(_on_slot_moved)
	expand_button.pressed.connect(_on_expand_pressed)
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)

	# 6. 詳細をドロップダウンへ移す（2026-09-07）。⚠ 引き取るのは詳細だけで、
	#    ⚠ `action_row` は画面に残す（⚠ ホバーで消える器にボタンを入れない）。
	_detail_popup = ItemDetailPopup.adopt(self, item_detail)
	if _detail_popup != null:
		_detail_popup.watch(inventory_grid)

	# 7. 初期描画
	_rebuild_inventory()
	_rebuild_codex()
	_rebuild_chest_list()

# --- 戻る ---

func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)

# --- インベントリタブ ---

# 持ち物タブ（段階18-c・マス目）。
#
# ⚠⚠ 「何がマスを占めるか」をここで決めない。GameManager.get_inventory_page_entries()
#   が唯一の口（⚠ 装備中の個体は出てこない＝人間の決定7。キャラの装備マスへ移っている）。
# ⚠ ページの大きさも掛け算しない（get_inventory_slots_per_page()）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ この画面は inventory_changed と
#   equipment_instances_changed の2本を購読していて、⚠ 1操作で2本飛ぶ。
var _page: int = 0
# いま選んでいるマスの中身。⚠ 空なら何も選んでいない。
var _selected: Dictionary = {}
# いま選んでいるマスの番号（⚠ ページを足した「通し番号」）。⚠ -1 なら選んでいない。
#   ⚠ 捨てる口はマスの番号で呼ぶ（⚠ 中身では空のマスと同じ品を区別できない）。
var _selected_index: int = -1


func _rebuild_inventory() -> void:
	# ⚠ ページ数が減ったときに空のページを見続けないよう、⚠ 毎回丸める。
	_page = clampi(_page, 0, GameManager.get_inventory_page_count() - 1)

	var entries: Array = GameManager.get_inventory_page_entries(_page)
	inventory_grid.rebuild(entries, GameManager.get_inventory_slots_per_page())

	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	capacity_label.text = "%s %d/%d" % [
		tr("ui_warehouse_capacity"),
		GameManager.get_inventory_slots_used(), GameManager.get_inventory_slot_max(),
	]
	page_label.text = "%d / %d" % [_page + 1, GameManager.get_inventory_page_count()]
	_update_expand_button()
	prev_page_button.disabled = _page <= 0
	next_page_button.disabled = _page >= GameManager.get_inventory_page_count() - 1

	# ⚠ 選んでいたものが無くなっていることがある（壊した・段階を上げた）。
	#   ⚠ 消えたのに操作ボタンが残ると、⚠ 押した瞬間に何も起きない画面になる。
	if not _selected.is_empty() and not _is_selection_alive():
		_selected = {}
		_selected_index = -1
	_rebuild_actions()


# 枠を買うボタン（段階18-e）。⚠ 値段も断る理由も GameManager の1本に聞く。
func _update_expand_button() -> void:
	var reason: String = GameManager.get_inventory_expand_reject_reason()
	if reason == GameManager.INVENTORY_EXPAND_REJECT_MAX:
		expand_button.text = tr("ui_warehouse_expand_max")
		expand_button.disabled = true
		return
	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	expand_button.text = "%s(%d)" % [tr("ui_warehouse_expand"), GameManager.get_inventory_expand_cost()]
	expand_button.disabled = reason != ""


func _on_expand_pressed() -> void:
	if not GameManager.expand_inventory():
		return
	# ⚠ 再描画は inventory_changed 側でも走るが、⚠ ページ数が増えたことを確実に反映する。
	_rebuild_inventory()


func _on_prev_page_pressed() -> void:
	_page -= 1
	_rebuild_inventory()


func _on_next_page_pressed() -> void:
	_page += 1
	_rebuild_inventory()


# マスを押した。⚠ ここでは選ぶだけ。⚠ 何ができるかは _rebuild_actions() が出す。
#   ⚠ 押した瞬間に壊す/上げるを走らせないこと（マス目は押し間違えやすい）。
func _on_slot_pressed(entry: Dictionary, index: int) -> void:
	_selected = entry
	# ⚠ ページのぶんを足して「通し番号」にする（⚠ 捨てる口はこれで呼ぶ）。
	_selected_index = _page * GameManager.get_inventory_slots_per_page() + index
	_rebuild_actions()


# マスを動かした（段階18-f・ドラッグ＆ドロップ）。
#
# ⚠ マス目の番号はページの中の番号。⚠ ページのぶんをここで足す
#   （⚠ 部品はページを知らない。⚠ 足し忘れると2ページ目で1ページ目の中身が動く）。
# ⚠ 入れ替えの判定は GameManager。⚠ ここで並びを組み立て直さないこと。
func _on_slot_moved(from_index: int, to_index: int) -> void:
	var offset: int = _page * GameManager.get_inventory_slots_per_page()
	if not GameManager.move_inventory_slot(offset + from_index, offset + to_index):
		return
	# ⚠ 選んでいたマスの中身が動いたので、⚠ 詳細も含めて描き直す。
	_rebuild_inventory()


# 選んでいるものがまだ在るか。
func _is_selection_alive() -> bool:
	var kind: String = str(_selected.get(GameManager.SLOT_ENTRY_KIND, ""))
	if kind == GameManager.SLOT_KIND_INSTANCE:
		return not GameManager.get_equipment_instance(
			str(_selected.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
		).is_empty()
	return GameManager.get_item_count(str(_selected.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))) > 0


# 選んだマスに対してできること。⚠ ボタンの中身は前と同じ（壊す・段階を上げる・重ねる）。
#   ⚠ 判定は GameManager に聞く。⚠ ここで条件を書き直さない。
func _rebuild_actions() -> void:
	_clear_container(action_row)

	# ⚠ 詳細は共有部品が出す（段階18-c-2）。⚠ ここで名前や性能を組み立てないこと
	#   （⚠ 同じものを2箇所で組み立てると、⚠ 片方だけ古い数字を出す）。
	item_detail.show_entry(_selected)

	if _selected.is_empty():
		return

	var item_id: String = str(_selected.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	var kind: String = str(_selected.get(GameManager.SLOT_ENTRY_KIND, ""))

	if kind == GameManager.SLOT_KIND_INSTANCE:
		var instance_id: String = str(_selected.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
		# ⚠ 装備中の個体はマス目に出てこない（決定7）ので、⚠ ここは必ず外れている。
		var dismantle_button: Button = Button.new()
		dismantle_button.name = "DismantleButton"
		dismantle_button.text = "%s(%d)" % [
			tr("ui_warehouse_dismantle"), GameManager.get_dismantle_refund_total(instance_id),
		]
		dismantle_button.pressed.connect(_on_dismantle_pressed.bind(instance_id))
		action_row.add_child(dismantle_button)
		_add_discard_button(item_id)
		return

	var count: int = GameManager.get_item_count(item_id)
	# 装飾（item_type: "part"）だけボタンが付く。⚠ items.json だけで決まる。
	if not GameManager.get_part_definition(item_id).is_empty():
		_add_part_buttons(action_row, item_id, count)
	_add_discard_button(item_id)


# 捨てる（段階18-e）。⚠ 満杯で拡張も買えないときの逃げ道（台帳 §4-2）。
#
# ⚠ 取り返しがつかないので確認モーダルを出す（⚠ 装飾の「壊す」と同じ流儀）。
# ⚠ 1マス＝1個なので1個ずつ。⚠ 「全部捨てる」を作らない。
# ⚠ 装備は「素材にする」のほうが素材が戻る。⚠ ただしここで弾かない（逃げ道は塞がない）。
func _add_discard_button(item_id: String) -> void:
	var button: Button = Button.new()
	button.name = "DiscardButton"
	button.text = tr("ui_warehouse_discard")
	button.pressed.connect(_on_discard_pressed.bind(item_id))
	action_row.add_child(button)


func _on_discard_pressed(item_id: String) -> void:
	if _selected_index < 0:
		return
	var confirmed: bool = await Modal.confirm(
		self, "ui_warehouse_discard_confirm", [tr("ui_res_" + item_id)]
	)
	if not confirmed:
		return
	if not GameManager.discard_inventory_slot(_selected_index):
		return
	_selected = {}
	_selected_index = -1
	_rebuild_inventory()


# 子を消す。await を持たせない（AGENTS.md「再描画は await を持たせない」）。
func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_dismantle_pressed(instance_id: String) -> void:
	if not GameManager.dismantle_equipment(instance_id):
		push_warning("[WarehouseScreen] dismantle_equipment failed: " + instance_id)
	# 再描画は equipment_instances_changed 側で行う。

# 装飾の行に付くボタン。装備の個体の行（_create_instance_entry）と同じ形。
#
# ⚠ 「壊す」は確認モーダルを出さない。減るのは在庫の余りだけで、装備に刺さっている
#   ものは減らないため（装備の「素材にする」も確認を出していない）。
#   ⚠ 刺さっているものを壊すのは装備画面の「外す」側。あちらは取り返しがつかないので
#     確認モーダルを出す（EXEC_DECORATION.md §3-J）。
# ⚠ 段階が上限の装飾には「段階を上げる」を出さない（行き先が無い）。
# ⚠ 段階18-c で置き場所が「行の中」から「選んだときの操作の列」へ移った。
# ⚠ 中身は変えていない（壊す・段階を上げる・重ねる）。
func _add_part_buttons(entry: Container, item_id: String, count: int) -> void:
	# ルーンは分解方式で上がらず、壊しても素材にならない（GAME_DESIGN.md 7-7）。
	# ⚠ ボタンは「重ねる」の1つだけ。⚠ part_kind で分岐しない。
	if not GameManager.get_rune_definition(item_id).is_empty():
		_add_rune_merge_button(entry, item_id)
		return

	var refund_total: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund_total += int(amount)

	var dismantle_button: Button = Button.new()
	dismantle_button.name = "PartDismantleButton"
	dismantle_button.text = "%s(%d)" % [tr("ui_part_dismantle"), refund_total]
	dismantle_button.disabled = count <= 0 or refund_total <= 0
	dismantle_button.pressed.connect(_on_part_dismantle_pressed.bind(item_id))
	entry.add_child(dismantle_button)

	if GameManager.get_upgraded_part_id(item_id) == "":
		return

	var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
	var upgrade_button: Button = Button.new()
	upgrade_button.name = "PartUpgradeButton"
	# ⚠ 素材名を出すのは、段階ごとに要る素材が変わるため（鍛冶ボタンと同じ理由）。
	upgrade_button.text = "%s(%s %d)" % [
		tr("ui_part_upgrade"),
		tr("ui_res_" + str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, ""))),
		int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0)),
	]
	upgrade_button.disabled = not GameManager.can_upgrade_part(item_id)
	upgrade_button.pressed.connect(_on_part_upgrade_pressed.bind(item_id))
	entry.add_child(upgrade_button)

# ルーンを重ねるボタン。⚠ 段階が上限なら出さない（かけらは今回作っていない）。
#
# ⚠ 押せるかの判定は get_rune_merge_reject_reason() の1本。画面で数えないこと。
func _add_rune_merge_button(entry: Container, item_id: String) -> void:
	var reason: String = GameManager.get_rune_merge_reject_reason(item_id)
	if reason == GameManager.RUNE_REJECT_MAX or reason == GameManager.RUNE_REJECT_KIND:
		return
	var cost: int = GameManager.get_rune_merge_count()
	var merge_button: Button = Button.new()
	merge_button.name = "RuneMergeButton"
	merge_button.text = "%s(%d)" % [tr("ui_part_rune_merge"), cost]
	merge_button.disabled = reason != ""
	merge_button.pressed.connect(_on_rune_merge_pressed.bind(item_id))
	entry.add_child(merge_button)

func _on_rune_merge_pressed(item_id: String) -> void:
	if not GameManager.merge_runes(item_id):
		push_warning("[WarehouseScreen] merge_runes failed: " + item_id)
	# 再描画は inventory_changed 側で行う。

func _on_part_dismantle_pressed(item_id: String) -> void:
	if GameManager.dismantle_part(item_id, 1).is_empty():
		push_warning("[WarehouseScreen] dismantle_part failed: " + item_id)
	# 再描画は inventory_changed 側で行う。

func _on_part_upgrade_pressed(item_id: String) -> void:
	if not GameManager.upgrade_part(item_id):
		push_warning("[WarehouseScreen] upgrade_part failed: " + item_id)

# --- 図鑑タブ ---

func _rebuild_codex() -> void:
	_clear_container(codex_list)

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

	# ⚠ 未発見の行にアイコンを出さない。文字で中身が割れる。
	if discovered:
		row.add_child(ItemIcon.create(item_id))

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
	_clear_container(chest_list)

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
	var instance_id: String = str(chest.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
	row.name = "ChestRow_" + instance_id

	var name_label: Label = Label.new()
	# ⚠ 表示名は chests.json の name_key（EXEC_CHEST_REGISTRY.md §3-F）。
	#   ⚠ 接頭辞を組み立てない。宝箱を増やしたときに .gd を触らず、
	#     キーの紴りも chests.json 側だけで決まるようにするため。
	var chest_def: Dictionary = MasterDataLoader.get_chest(str(chest.get(GameStateKeys.CHEST_ID, "")))
	name_label.text = tr(str(chest_def.get(GameManager.CHEST_NAME_KEY, "")))
	name_label.name = "ChestNameLabel"
	row.add_child(name_label)

	var open_button: Button = Button.new()
	open_button.text = tr("ui_warehouse_open")
	open_button.name = "OpenButton"
	open_button.pressed.connect(_on_open_chest_pressed.bind(instance_id))
	row.add_child(open_button)

	chest_list.add_child(row)

func _add_empty_label(parent: Container) -> void:
	var empty_label: Label = Label.new()
	empty_label.text = tr("ui_warehouse_no_chest")
	empty_label.name = "EmptyLabel"
	parent.add_child(empty_label)

# --- 開封処理 ---

func _on_open_chest_pressed(instance_id: String) -> void:
	# 1. 開封前に rewards を読んでおく（open_chest は rewards を返さない）
	var rewards: Dictionary = _read_chest_rewards(instance_id)
	if rewards.is_empty() and not _chest_exists(instance_id):
		push_warning("[WarehouseScreen] chest not found: " + instance_id)
		return

	# 2. open_chest を呼ぶ
	var success: bool = GameManager.open_chest(instance_id)
	if not success:
		push_warning("[WarehouseScreen] open_chest failed: " + instance_id)
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
		var instance_id: String = str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
		var rewards: Dictionary = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})

		if GameManager.open_chest(instance_id):
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

func _read_chest_rewards(instance_id: String) -> Dictionary:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, "")) == instance_id:
			var rewards_val: Variant = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})
			if rewards_val is Dictionary:
				return rewards_val
			return {}
	return {}

func _chest_exists(instance_id: String) -> bool:
	var state: Dictionary = GameManager.get_state()
	var chests: Array = state.get(GameStateKeys.PENDING_CHESTS, [])
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, "")) == instance_id:
			return true
	return false

# --- シグナルハンドラ ---

func _on_inventory_changed(_item_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()

func _on_pending_chests_changed(_pending_count: int) -> void:
	_rebuild_chest_list()

func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()
