# res://scenes/adventure/dungeon_shop.gd
# 難ダンジョンのボスの先のショップ（段階17-e-3・人間の指示「別画面にすべき」）。
#
# ⚠⚠ `floor_shop.gd`（フロア内ショップ）と画面は共有しない（2026-09-19・人間の決定「ショップは2枚のまま」）。
#   ⚠ あちらはゴールドで買い、⚠ こちらは一時通貨（決定16）。⚠ 借りると通貨の判定が同居する。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail` / `SlotActionPopover` / `RunPartyStrip`）。
# ⚠ 品と値段は `dungeon.json` の `shop`（表）。⚠ 画面で値段を組み立てない。
# ⚠ 押せるかの判定は `get_dungeon_shop_reject_reason()` の1本に聞く。
# ⚠⚠ 2026-09-19：モック v2 §10 の形。⚠ 品を2種類に分けて出す：
#     ⚠ 鞄に入るもの（ポーション）… 左のマス目（⚠ 押す → 吹き出しで「買う(値段)」）
#     ⚠ 入らないもの（鞄の枠・たいまつ）… 右の行（⚠ 名前・値段・買う・買えない理由）

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

@onready var title_label: Label = $Layout/Header/TitleLabel
# ⚠ 遺物片は絵つき（2026-09-20）。⚠ 絵は IconTextures の1本（⚠ いまはレリックの絵を借りている）。
@onready var currency_value: ResourceDisplay = $Layout/Header/CurrencyValue
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var held_relic_grid: ItemGrid = $Layout/Header/HeldRelicGrid
@onready var party_list: RunPartyStrip = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var item_grid: ItemGrid = $Layout/Body/Left/ItemGrid
@onready var bag_grid: ItemGrid = $Layout/Body/Left/BagGrid
@onready var item_detail: ItemDetail = $Layout/Body/Left/ItemDetail
@onready var upgrade_list: VBoxContainer = $Layout/Body/Right/UpgradeList
@onready var back_button: UiButton = $Layout/Header/BackButton

# ホバーで詳細を出す器（2026-09-07）。⚠ 押したときの「買う」は SlotActionPopover。
var _detail_popup: ItemDetailPopup = null

# マス目の何番目が、店の並びの何番目か。⚠ 買う口は店の番号で呼ぶ。
var _item_indexes: Array[int] = []


func _ready() -> void:
	SceneManager.consume_transfer_data()
	# ⚠⚠ ランの中では右上の通貨を出さない（2026-09-20・人間の指示
	#   「⚠ スタミナなどのリソースをダンジョン内で表示しないで」）。⚠ 戦闘・ポモドーロと同じ扱い。
	#   ⚠ 出し直すのは SceneManager（⚠ 画面を移ると既定で出る）。
	ResourceHud.set_shown(false)

	# ⚠ ボスを倒した先でしか店は開かない（決定15）。⚠ 判定は GameManager に聞く
	#   （⚠ 開いていなければ空の配列が返る。⚠ ここで phase を見ない）。
	if GameManager.get_dungeon_shop_entries().is_empty():
		push_warning("[DungeonShop] 店が開いていないのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	title_label.text = "%s %s" % [tr("ui_dungeon_shop"), Glyphs.NODE_SHOP]
	_say(tr("ui_dungeon_shop_currency_note"), &"MutedLabel")
	item_grid.slot_pressed.connect(_on_item_pressed)
	back_button.pressed.connect(_on_back_pressed)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	# ⚠ 詳細をドロップダウンへ移す（2026-09-07）。
	_detail_popup = ItemDetailPopup.adopt(self, item_detail)
	if _detail_popup != null:
		_detail_popup.watch(item_grid)
		_detail_popup.watch(bag_grid)
		_detail_popup.watch(held_relic_grid)
	_rebuild()


# ⚠ ランが終わったとき（撤退・全ロスト）は "" が飛んでくる。⚠ 描き直さない。
func _on_dungeon_run_changed(dungeon_id: String) -> void:
	if dungeon_id == "":
		return
	_rebuild()


# ⚠ 色は Theme の variation（⚠ 値を書かない）。
func _say(text: String, variation: StringName) -> void:
	message_label.text = text
	message_label.theme_type_variation = variation


func _rebuild() -> void:
	SlotActionPopover.close_in(self)
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	currency_value.resource_id = GameStateKeys.DUNGEON_RUN_CURRENCY
	currency_value.set_value(GameManager.get_dungeon_currency())
	var used: int = GameManager.get_dungeon_bag_used()
	var slots: int = GameManager.get_dungeon_bag_slots()
	bag_label.text = "%s %d/%d" % [tr("ui_dungeon_bag"), used, slots]
	bag_label.theme_type_variation = &"ErrorLabel" if used >= slots else &"MutedLabel"
	var held: Array = GameManager.get_run_relic_slot_entries(GameManager.RUN_KIND_DUNGEON)
	held_relic_grid.rebuild(held, held.size())
	held_relic_grid.visible = not held.is_empty()
	$Layout/Header/RelicSep.visible = held_relic_grid.visible
	party_list.refresh(GameManager.RUN_KIND_DUNGEON)
	bag_grid.rebuild(GameManager.get_dungeon_bag_slot_layout(), slots)
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


# 押したマスの近くに「買う(値段)」（モック v2 §10）。⚠ 押せるかは GameManager の1本に聞く。
func _on_item_pressed(_entry: Dictionary, index: int) -> void:
	if index < 0 or index >= _item_indexes.size() or index >= item_grid.get_child_count():
		return
	var shop_index: int = _item_indexes[index]
	var entry: Dictionary = GameManager.get_dungeon_shop_entries()[shop_index]
	var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	var anchor: Rect2 = (item_grid.get_child(index) as Control).get_global_rect()
	var pop: SlotActionPopover = SlotActionPopover.open(
		self, anchor, tr(GameManager.item_name_key(item_id)), ""
	)
	var reason: String = GameManager.get_dungeon_shop_reject_reason(shop_index)
	# 数値のみなので見出しだけ tr()（AGENTS.md）。
	var buy: UiButton = pop.add_action(
		"%s（%d）" % [tr("ui_dungeon_shop_buy"), int(entry.get(GameManager.DUNGEON_SHOP_COST, 0))],
		UiButton.Variant.PRIMARY, _on_buy_pressed.bind(shop_index), reason != ""
	)
	buy.name = "BuyButton"
	if reason != "":
		pop.set_note(tr("ui_dungeon_shop_reject_" + reason))
	else:
		pop.set_note(tr("ui_dungeon_shop_bag_free") % (
			GameManager.get_dungeon_bag_slots() - GameManager.get_dungeon_bag_used()
		))


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
		var reason: String = GameManager.get_dungeon_shop_reject_reason(i)

		var panel: PanelContainer = PanelContainer.new()
		panel.name = "Upgrade_%d" % i
		panel.theme_type_variation = &"CompactRowPanel"
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"ButtonRow"
		panel.add_child(row)

		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.custom_minimum_size = Vector2(220.0, 0.0)
		name_label.text = _upgrade_name(kind, entry)
		row.add_child(name_label)

		var cost_label: Label = Label.new()
		cost_label.name = "CostLabel"
		cost_label.theme_type_variation = &"AccentLabel"
		cost_label.custom_minimum_size = Vector2(44.0, 0.0)
		cost_label.text = str(int(entry.get(GameManager.DUNGEON_SHOP_COST, 0)))
		row.add_child(cost_label)

		var button: UiButton = UiButton.new()
		button.name = "Buy_%d" % i
		button.variant = UiButton.Variant.PRIMARY
		button.text = tr("ui_dungeon_shop_buy")
		button.disabled = reason != ""
		button.pressed.connect(_on_buy_pressed.bind(i))
		row.add_child(button)

		# ⚠ 買えないときは理由を行の中に出す（モック v2 §10「買えないときの理由」）。
		if reason != "":
			var why: Label = Label.new()
			why.name = "WhyLabel"
			why.theme_type_variation = &"CaptionLabel"
			why.text = tr("ui_dungeon_shop_reject_" + reason)
			row.add_child(why)
		upgrade_list.add_child(panel)


# 行の名前。⚠ 買うと何が変わるかを「いま → あと」で出す（モック v2 §10）。
#   ⚠ たいまつの次の層数は GameManager の1本（get_dungeon_next_reveal_layers）。⚠ 表を引き直さない。
func _upgrade_name(kind: String, entry: Dictionary) -> String:
	if kind == GameManager.DUNGEON_SHOP_KIND_BAG_SLOT:
		var slots: int = GameManager.get_dungeon_bag_slots()
		var amount: int = int(entry.get(GameManager.DUNGEON_SHOP_AMOUNT, 1))
		return "%s +%d（%d → %d）" % [tr("ui_dungeon_shop_bag_slot"), amount, slots, slots + amount]
	var now: int = GameManager.get_dungeon_reveal_layers()
	var next: int = GameManager.get_dungeon_next_reveal_layers()
	if next < 0:
		return "%s %s（%s）" % [Glyphs.TORCH, tr("ui_dungeon_shop_torch"), tr("ui_dungeon_layers_ahead") % now]
	return "%s %s（%s → %s）" % [
		Glyphs.TORCH, tr("ui_dungeon_shop_torch"),
		tr("ui_dungeon_layers_ahead") % now, tr("ui_dungeon_layers_ahead") % next,
	]


func _on_buy_pressed(index: int) -> void:
	var reason: String = GameManager.get_dungeon_shop_reject_reason(index)
	if reason != "":
		_say(tr("ui_dungeon_shop_reject_" + reason), &"ErrorLabel")
		return
	if not GameManager.buy_dungeon_shop_entry(index):
		return
	_say(tr("ui_dungeon_shop_bought"), &"GainLabel")
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.change_scene(DUNGEON_MAP_PATH)
