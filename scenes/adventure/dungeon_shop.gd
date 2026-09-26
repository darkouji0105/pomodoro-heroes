# res://scenes/adventure/dungeon_shop.gd
# 難ダンジョンのボスの先のショップ（段階17-e-3・人間の指示「別画面にすべき」）。
#
# ⚠⚠ `floor_shop.gd`（フロア内ショップ）と画面は共有しない（2026-09-19・人間の決定「ショップは2枚のまま」）。
#   ⚠ あちらはゴールドで買い、⚠ こちらは一時通貨（決定16）。⚠ 借りると通貨の判定が同居する。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail` / `SlotActionPopover` / `RunPartyStrip`）。
# ⚠ 品と値段は `dungeon.json` の `shop`（表）。⚠ 画面で値段を組み立てない。
# ⚠ 押せるかの判定は `get_dungeon_shop_reject_reason()` の1本に聞く。
# ⚠⚠ 2026-09-27（回UI-4・手本 DungeonShop）：⚠ **板にピンで留めた紙の値札**を品の数だけ並べる。
#   ⚠ どの品も同じ形（⚠ 絵 ／ 名前 ／ 変化か鞄の個数 ／ 大きな値段 ／ 「買う」 ／ 買えない理由）。
#   ⚠ 前は「鞄に入る品＝マス目＋吹き出し ／ 入らない品＝行」に分けていた（モック v2 §10）。
#   ⚠ 右に鞄（⚠ 何個入るかが見える）。⚠ 3人の HP はフッター（`NAV-8`）。
#   ⚠ 出口は**右下の真鍮のボタン**（⚠ 左上の「戻る」はやめた＝わかれ道と同じく戻る先が無い）。

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

# ⚠ ここを出るときに次の階へ潜るか（2026-09-21・決定48）。
var _descend_after: bool = false

@onready var title_label: Label = $Layout/Header/TitleLabel
# ⚠ 遺物片は絵つき（2026-09-20）。⚠ 絵は IconTextures の1本（⚠ いまはレリックの絵を借りている）。
@onready var currency_value: ResourceDisplay = $Layout/Header/RunChip/CurrencyValue
@onready var bag_label: Label = $Layout/Body/BagPanel/BagColumn/BagLabel
@onready var held_relic_grid: ItemGrid = $Layout/Header/HeldRelicGrid
@onready var party_list: RunPartyStrip = $Layout/Footer/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var cards: HBoxContainer = $Layout/Body/Board/Cards
@onready var bag_grid: ItemGrid = $Layout/Body/BagPanel/BagColumn/BagGrid
@onready var item_detail: ItemDetail = $Layout/Body/BagPanel/BagColumn/ItemDetail
@onready var leave_button: UiButton = $Layout/Footer/LeaveButton

# ホバーで詳細を出す器（2026-09-07）。⚠ 「買う」は値札の中（⚠ 09-27 から。前は吹き出し）。
var _detail_popup: ItemDetailPopup = null



func _ready() -> void:
	# ⚠ ショップを出たら次の階へ潜るか（2026-09-21・決定48）。⚠ 受け取れるのは1回だけ。
	_descend_after = bool(
		SceneManager.consume_transfer_data().get(TransferKeys.DUNGEON_DESCEND_AFTER_SHOP, false)
	)
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

	title_label.text = tr("ui_dungeon_shop")
	_say(tr("ui_dungeon_shop_currency_note"), &"MutedLabel")
	leave_button.pressed.connect(_on_back_pressed)
	leave_button.text = (
		tr("ui_dungeon_shop_leave_descend") % (GameManager.get_dungeon_floor_index() + 1) if _descend_after
		else tr("ui_dungeon_shop_leave_map")
	)
	GameManager.dungeon_run_changed.connect(_on_dungeon_run_changed)
	# ⚠ 詳細をドロップダウンへ移す（2026-09-07）。
	_detail_popup = ItemDetailPopup.adopt(self, item_detail)
	if _detail_popup != null:
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
	party_list.refresh(GameManager.RUN_KIND_DUNGEON)
	bag_grid.rebuild(GameManager.get_dungeon_bag_slot_layout(), slots)
	_rebuild_cards()


# 品の値札を並べる。⚠ 押せるかは `get_dungeon_shop_reject_reason()` の1本に聞く（⚠ ここで条件を書かない）。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
func _rebuild_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var shop: Array = GameManager.get_dungeon_shop_entries()
	for i: int in range(shop.size()):
		cards.add_child(_make_card(i, shop[i]))


# 値札1枚（⚠ 傾いた紙）。⚠ 中身＝絵 ／ 名前 ／ 変化（鞄の枠・たいまつ）か鞄の個数（品）／ 値段 ／ 買う ／ 理由。
func _make_card(index: int, entry: Dictionary) -> TiltedSheet:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = "Card_%d" % index
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.custom_minimum_size.x = float(get_theme_constant(&"card_width", &"ShopCard"))
	card.sheet.add_child(column)

	var kind: String = str(entry.get(GameManager.DUNGEON_SHOP_KIND, ""))
	var name_text: String = ""
	var change_text: String = ""
	if kind == GameManager.DUNGEON_SHOP_KIND_ITEM:
		var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		var icon: ItemGrid = ItemGrid.new()
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		icon.rebuild([_slot_entry_of(item_id)], 1)
		if _detail_popup != null:
			_detail_popup.watch(icon)
		name_text = tr(GameManager.item_name_key(item_id))
		change_text = tr("ui_dungeon_shop_in_bag") % int(GameManager.get_dungeon_bag().get(item_id, 0))
	else:
		# ⚠ 鞄の枠・たいまつは絵が無い（⚠ 素材待ち）。⚠ いまは大きな字の印。
		var mark: Label = Label.new()
		mark.theme_type_variation = &"HeadingLabel"
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.text = Glyphs.TORCH if kind != GameManager.DUNGEON_SHOP_KIND_BAG_SLOT else Glyphs.NODE_SHOP
		column.add_child(mark)
		name_text = _upgrade_title(kind, entry)
		change_text = _upgrade_change(kind, entry)

	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = name_text
	column.add_child(name_label)
	var change: Label = Label.new()
	change.theme_type_variation = &"CaptionLabel"
	change.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	change.text = change_text
	column.add_child(change)

	# ⚠ 値段は大きく（⚠ 手本の「◎ 40」）。⚠ 通貨の絵つき。
	var price_row: HBoxContainer = HBoxContainer.new()
	price_row.theme_type_variation = &"ChipRow"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(price_row)
	var coin: TextureRect = TextureRect.new()
	coin.texture = IconTextures.for_resource(GameStateKeys.DUNGEON_RUN_CURRENCY)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var coin_side: float = float(get_theme_constant(&"coin", &"ShopCard"))
	coin.custom_minimum_size = Vector2(coin_side, coin_side)
	coin.self_modulate = get_theme_color(&"coin", &"ShopCard")
	price_row.add_child(coin)
	var price: Label = Label.new()
	price.theme_type_variation = &"PriceLabel"
	price.text = str(int(entry.get(GameManager.DUNGEON_SHOP_COST, 0)))
	price_row.add_child(price)

	var reason: String = GameManager.get_dungeon_shop_reject_reason(index)
	var buy: UiButton = UiButton.new()
	buy.name = "Buy_%d" % index
	buy.text = tr("ui_dungeon_shop_buy")
	buy.disabled = reason != ""
	buy.pressed.connect(_on_buy_pressed.bind(index))
	column.add_child(buy)
	var why: Label = Label.new()
	why.theme_type_variation = &"CaptionLabel"
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.text = tr("ui_dungeon_shop_reject_" + reason) if reason != "" else " "
	column.add_child(why)
	return card


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


# 鞄の枠・たいまつの札の名前（⚠ 手本「鞄の枠 +2」「たいまつ +1」）。
func _upgrade_title(kind: String, entry: Dictionary) -> String:
	if kind == GameManager.DUNGEON_SHOP_KIND_BAG_SLOT:
		return "%s +%d" % [tr("ui_dungeon_shop_bag_slot"), int(entry.get(GameManager.DUNGEON_SHOP_AMOUNT, 1))]
	return tr("ui_dungeon_shop_torch")


# 買うと何が変わるか（⚠ 「いま → あと」）。⚠ たいまつの次の層数は GameManager の1本。
func _upgrade_change(kind: String, entry: Dictionary) -> String:
	if kind == GameManager.DUNGEON_SHOP_KIND_BAG_SLOT:
		var slots: int = GameManager.get_dungeon_bag_slots()
		return "%d → %d" % [slots, slots + int(entry.get(GameManager.DUNGEON_SHOP_AMOUNT, 1))]
	var now: int = GameManager.get_dungeon_reveal_layers()
	var next: int = GameManager.get_dungeon_next_reveal_layers()
	if next < 0:
		return tr("ui_dungeon_layers_ahead") % now
	return "%s → %s" % [tr("ui_dungeon_layers_ahead") % now, tr("ui_dungeon_layers_ahead") % next]


func _on_buy_pressed(index: int) -> void:
	var reason: String = GameManager.get_dungeon_shop_reject_reason(index)
	if reason != "":
		_say(tr("ui_dungeon_shop_reject_" + reason), &"ErrorLabel")
		return
	if not GameManager.buy_dungeon_shop_entry(index):
		return
	_say(tr("ui_dungeon_shop_bought"), &"GainLabel")
	_rebuild()


# ⚠⚠ 「わかれ道の画面」から来たときは、⚠ ここを出るときに次の階へ潜る（決定48）。
#   ⚠ 潜ってからだと店が消えるので、⚠ 順番を入れ替えないこと（`TransferKeys` の注記）。
func _on_back_pressed() -> void:
	if _descend_after:
		_descend_after = false
		if not GameManager.descend_dungeon_floor():
			push_warning("[DungeonShop] ⚠ 次の階へ潜れなかった（⚠ 最後の階か、ボスの先に居ない）")
	SceneManager.change_scene(DUNGEON_MAP_PATH)
