# res://scenes/adventure/dungeon_shop.gd
# 難ダンジョンのボスの先のショップ（段階17-e-3・人間の指示「別画面にすべき」）。
#
# ⚠⚠ `floor_shop.gd`（フロア内ショップ）と1行も共有していない。
#   ⚠ あちらはゴールドで買い、⚠ こちらは一時通貨（決定16）。⚠ 借りると通貨の判定が同居する。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail`）。
# ⚠ 品と値段は `dungeon.json` の `shop`（表）。⚠ 画面で値段を組み立てない。
# ⚠ 押せるかの判定は `get_dungeon_shop_reject_reason()` の1本に聞く。
# ⚠ 品を2種類に分けて出す：
#     ⚠ 鞄に入るもの（ポーション）… マス目（⚠ 押す → 詳細 → 買う）
#     ⚠ 入らないもの（鞄の枠・たいまつ）… 行（⚠ アイコンが無いのでマスにしない）

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

@onready var currency_label: Label = $Layout/Header/CurrencyLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var item_grid: ItemGrid = $Layout/ItemGrid
@onready var item_detail: ItemDetail = $Layout/ItemDetail
@onready var item_action_row: HBoxContainer = $Layout/ItemActionRow
@onready var upgrade_list: VBoxContainer = $Layout/UpgradeList
@onready var back_button: PrimaryButton = $Layout/Footer/BackButton

# 押した所の近くに詳細を出す器（2026-09-07）。⚠ `item_detail` と `item_action_row` を引き取る。
var _detail_popup: ItemDetailPopup = null

# マス目の何番目が、店の並びの何番目か。⚠ 買う口は店の番号で呼ぶ。
var _item_indexes: Array[int] = []
# 選んでいる品の番号（店の並びの中の番号）。⚠ -1 なら選んでいない。
var _selected_index: int = -1


func _ready() -> void:
	SceneManager.consume_transfer_data()

	# ⚠ ボスを倒した先でしか店は開かない（決定15）。⚠ 判定は GameManager に聞く
	#   （⚠ 開いていなければ空の配列が返る。⚠ ここで phase を見ない）。
	if GameManager.get_dungeon_shop_entries().is_empty():
		push_warning("[DungeonShop] 店が開いていないのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	message_label.text = ""
	item_grid.slot_pressed.connect(_on_item_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	# ⚠ 詳細をドロップダウンへ移す（2026-09-07）。⚠ `item_action_row` は画面に残す。
	_detail_popup = ItemDetailPopup.adopt(self, item_detail)
	if _detail_popup != null:
		_detail_popup.watch(item_grid)
	_rebuild()


# ⚠ ランが終わったとき（撤退・全ロスト）は "" が飛んでくる。⚠ 描き直さない。
func _on_dungeon_run_changed(dungeon_id: String) -> void:
	if dungeon_id == "":
		return
	_rebuild()


func _rebuild() -> void:
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	currency_label.text = "%s %d" % [tr("ui_dungeon_currency"), GameManager.get_dungeon_currency()]
	bag_label.text = "%s %d/%d" % [
		tr("ui_dungeon_bag"), GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots()
	]
	_rebuild_items()
	_rebuild_upgrades()


# 鞄に入る品（ポーション）をマス目で出す。
func _rebuild_items() -> void:
	var entries: Array = []
	_item_indexes.clear()
	var shop: Array = GameManager.get_dungeon_shop_entries()
	for i: int in range(shop.size()):
		var row: Dictionary = shop[i]
		if str(row.get(GameManager.DUNGEON_SHOP_KIND, "")) != GameManager.DUNGEON_SHOP_KIND_ITEM:
			continue
		entries.append(_slot_entry_of(str(row.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))))
		_item_indexes.append(i)
	item_grid.rebuild(entries, entries.size())

	# ⚠ 店の中身は固定なので消えないが、⚠ 番号は毎回引き直す。
	if _selected_index >= 0 and not (_selected_index in _item_indexes):
		_selected_index = -1
	_rebuild_item_actions()


# 店の品1つをマスの形に包む。
#
# ⚠ 個数は「いま鞄に何個あるか」（⚠ 拠点の所持数ではない。⚠ ラン専用の品は拠点に0個）。
func _slot_entry_of(item_id: String) -> Dictionary:
	return {
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
		GameManager.SLOT_ENTRY_ITEM_ID: item_id,
		GameManager.SLOT_ENTRY_INSTANCE_ID: "",
		GameManager.SLOT_ENTRY_GRADE: 0,
		GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
		GameManager.SLOT_ENTRY_COUNT: int(GameManager.get_dungeon_bag().get(item_id, 0)),
	}


func _on_item_pressed(_entry: Dictionary, index: int) -> void:
	if index < 0 or index >= _item_indexes.size():
		return
	_selected_index = _item_indexes[index]
	_rebuild_item_actions()


func _rebuild_item_actions() -> void:
	for child in item_action_row.get_children():
		item_action_row.remove_child(child)
		child.queue_free()

	if _selected_index < 0:
		item_detail.show_entry({})
		return

	var entry: Dictionary = GameManager.get_dungeon_shop_entries()[_selected_index]
	item_detail.show_entry(_slot_entry_of(str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))))

	var button: PrimaryButton = PrimaryButton.new()
	button.name = "BuyButton"
	# 数値のみなので見出しだけ tr()（AGENTS.md）。
	button.text = "%s(%d)" % [
		tr("ui_dungeon_shop_buy"), int(entry.get(GameManager.DUNGEON_SHOP_COST, 0))
	]
	# ⚠ 押せるかの判定は GameManager の1本。⚠ ここで通貨や鞄を数えないこと。
	button.disabled = GameManager.get_dungeon_shop_reject_reason(_selected_index) != ""
	button.pressed.connect(_on_buy_pressed.bind(_selected_index))
	item_action_row.add_child(button)


# 鞄に入らないもの（鞄の枠・たいまつ）。⚠ アイコンが無いのでマスにしない。
func _rebuild_upgrades() -> void:
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()

	var shop: Array = GameManager.get_dungeon_shop_entries()
	for i: int in range(shop.size()):
		var entry: Dictionary = shop[i]
		var kind: String = str(entry.get(GameManager.DUNGEON_SHOP_KIND, ""))
		if kind == GameManager.DUNGEON_SHOP_KIND_ITEM:
			continue

		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Upgrade_%d" % i

		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if kind == GameManager.DUNGEON_SHOP_KIND_BAG_SLOT:
			name_label.text = "%s +%d" % [
				tr("ui_dungeon_shop_bag_slot"), int(entry.get(GameManager.DUNGEON_SHOP_AMOUNT, 1))
			]
		else:
			# ⚠ 「いま何層先まで見えるか」を出す。⚠ 買ったあとの値は出さない
			#   （⚠ GameManager に「次の等級の層数」を返す口が無い。⚠ 画面で表を引き直さない）。
			name_label.text = "%s（%s %d）" % [
				tr("ui_dungeon_shop_torch"), tr("ui_dungeon_shop_torch_now"),
				GameManager.get_dungeon_reveal_layers(),
			]
		row.add_child(name_label)

		var cost_label: Label = Label.new()
		cost_label.name = "CostLabel"
		cost_label.text = str(int(entry.get(GameManager.DUNGEON_SHOP_COST, 0)))
		row.add_child(cost_label)

		var button: PrimaryButton = PrimaryButton.new()
		button.name = "Buy_%d" % i
		button.text = tr("ui_dungeon_shop_buy")
		button.disabled = GameManager.get_dungeon_shop_reject_reason(i) != ""
		button.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(button)
		upgrade_list.add_child(row)


func _on_buy_pressed(index: int) -> void:
	var reason: String = GameManager.get_dungeon_shop_reject_reason(index)
	if reason != "":
		message_label.text = tr("ui_dungeon_shop_reject_" + reason)
		return
	if not GameManager.buy_dungeon_shop_entry(index):
		return
	message_label.text = tr("ui_dungeon_shop_bought")
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.change_scene(DUNGEON_MAP_PATH)
