# res://scenes/adventure/dungeon_chest.gd
# 難ダンジョンの拾いもの（段階19-b → ⚠ 20-e で「選んで入れる」形に作り替えた）。
#
# ⚠⚠ 人間の指示（2026-09-05）：「⚠ 何を拾ったか、表示するように」
#   「⚠ モーダルの中にアイテムとして見せて」「⚠ インベントリの中に何を入れるか選べるように」。
#   ⚠ 人間の裁き：⚠ 宝箱の画面を使い回す ／ ⚠ 宝箱も「選ぶ」形に揃える ／
#   ⚠ 鞄の中身を捨てて入れ替えられるようにする。
#
# ⚠⚠ 拠点の宝箱（`PENDING_CHESTS` / `open_chest()`）と1行も共有していない。
#   ⚠ あちらは「持ち帰って拠点で開ける」もの。⚠ こちらは「その場で開く」（案A）。
#   ⚠ 共有すると、⚠ ランの戦利品が拠点の資産になり、⚠ 全ロスト（決定7・§4-8）が崩れる。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail`）。
# ⚠ 入る・捨てるの判定を自分で書かない（⚠ GameManager の口が弾く）。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
# ⚠ ScrollContainer を使わない。中は scenario=layout で測れない。

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

# 鞄が満杯のときの色。⚠ 「もう入らない」が一目で分かること。
const COLOR_FULL: Color = Color(0.85, 0.35, 0.35)

@onready var title_label: Label = $Layout/TitleLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var bag_label: Label = $Layout/BagLabel
@onready var loot_grid: ItemGrid = $Layout/LootGrid
@onready var bag_title_label: Label = $Layout/BagTitleLabel
@onready var bag_grid: ItemGrid = $Layout/BagGrid
@onready var loot_detail: ItemDetail = $Layout/LootDetail
@onready var action_row: HBoxContainer = $Layout/ActionRow

# どのマスの宝箱か。⚠ 通路の宝箱・通路の資源なら空。
var _node_id: String = ""
# 通路の宝箱として来たか（段階19-c-2）。
#
# ⚠⚠ 開けたかの覚え方が2通りある（⚠ ノード＝`cleared` ／ ⚠ 通路＝持ち越しの欄）。
#   ⚠ 画面はどちらかを1回だけ選び、⚠ 以降その枝だけを使う。⚠ 混ぜないこと。
var _is_corridor: bool = false

# 選んでいるマス。⚠ 空なら選んでいない。
var _selected_entry: Dictionary = {}
# 選んでいるのが拾い待ちか鞄か（段階20-e）。⚠ できることが違う（入れる／捨てる）。
var _selected_from_bag: bool = false


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_node_id = str(data.get(TransferKeys.DUNGEON_NODE_ID, ""))
	_is_corridor = bool(data.get(TransferKeys.DUNGEON_CORRIDOR_CHEST, false))

	# ⚠ ランに入っていないのに来た。⚠ 空の画面を描かない。
	# ⚠ 出どころが無くても、⚠ 拾い待ちがあれば開く（段階20-e＝通路の資源から来た場合）。
	if not GameManager.is_in_dungeon():
		push_warning("[DungeonChest] ランに入っていないのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return
	if _node_id == "" and not _is_corridor and not GameManager.has_dungeon_pending_loot():
		push_warning("[DungeonChest] 出どころも拾い待ちも無いのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	title_label.text = tr(_title_key())
	bag_title_label.text = tr("ui_dungeon_chest_bag_title")
	loot_grid.slot_pressed.connect(_on_loot_pressed)
	bag_grid.slot_pressed.connect(_on_bag_pressed)
	_rebuild()


# 見出し。⚠ 出どころで変える（⚠ マスの宝箱 ／ 通路の宝箱 ／ 通路の拾いもの）。
func _title_key() -> String:
	if _is_corridor:
		return "ui_dungeon_corridor_chest_title"
	if _node_id != "":
		return "ui_dungeon_chest_title"
	return "ui_dungeon_pickup_title"


func _rebuild() -> void:
	_update_message()
	_rebuild_loot()
	_rebuild_bag()
	_rebuild_actions()


# もう開けたか。⚠ 出どころで聞く先が変わる（段階19-c-2）。
#
# ⚠⚠ 判定を自分で書かない。⚠ どちらも GameManager の口に聞くだけ。
#   ⚠ ノード＝`was_dungeon_chest_opened()`（cleared を見る）
#   ⚠ 通路の宝箱＝`has_pending_dungeon_corridor_chest()` の裏返し（持ち越しの欄を見る）
#   ⚠ 通路の拾いもの＝開ける動作が無いので常に「開けた」扱い
func _was_opened() -> bool:
	if _is_corridor:
		return not GameManager.has_pending_dungeon_corridor_chest()
	if _node_id == "":
		return true
	return GameManager.was_dungeon_chest_opened(_node_id)


# ⚠ 鞄の残りを必ず出す。⚠ 「何を捨てて何を入れるか」を選ぶのに要る。
func _update_message() -> void:
	var used: int = GameManager.get_dungeon_bag_used()
	var slots: int = GameManager.get_dungeon_bag_slots()
	bag_label.text = "%s %d/%d" % [tr("ui_dungeon_bag"), used, slots]
	bag_label.modulate = COLOR_FULL if used >= slots else Color.WHITE

	if not _was_opened():
		message_label.text = tr("ui_dungeon_chest_hint")
		message_label.modulate = Color.WHITE
		return
	if not GameManager.has_dungeon_pending_loot():
		message_label.text = tr("ui_dungeon_chest_opened")
		message_label.modulate = Color.WHITE
		return
	# ⚠ 満杯なら「捨てて空ける」ことを言う（⚠ 言わないと手が無いように見える）。
	if used >= slots:
		message_label.text = tr("ui_dungeon_pickup_full")
		message_label.modulate = COLOR_FULL
		return
	message_label.text = tr("ui_dungeon_pickup_hint")
	message_label.modulate = Color.WHITE


# 拾い待ちをマス目で出す（段階20-e）。
#
# ⚠⚠ 中身は GameManager の拾い待ちから引く。⚠ 画面で覚えないこと
#   （⚠ 1個入れるたびに描き直すので、⚠ 覚えると鞄と食い違う）。
func _rebuild_loot() -> void:
	var entries: Array = GameManager.get_dungeon_pending_loot_slot_layout()
	loot_grid.rebuild(entries, maxi(1, entries.size()))


# 鞄をマス目で出す（段階20-e・人間の指示「⚠ 入れ替えられる」）。
#
# ⚠ 空きマスも並ぶ（⚠ 「あと何個入るか」が見えること）。⚠ 鞄の口に聞く。
func _rebuild_bag() -> void:
	bag_grid.columns = maxi(1, GameManager.get_dungeon_bag_slots())
	bag_grid.rebuild(
		GameManager.get_dungeon_bag_slot_layout(), GameManager.get_dungeon_bag_slots()
	)


func _on_loot_pressed(entry: Dictionary, _index: int) -> void:
	_selected_entry = entry
	_selected_from_bag = false
	_rebuild_actions()


func _on_bag_pressed(entry: Dictionary, _index: int) -> void:
	_selected_entry = entry
	_selected_from_bag = true
	_rebuild_actions()


# できること。⚠ 選んだ場所で変わる（段階20-e）。
#
# ⚠ 拾い待ちを選んだ → 「鞄に入れる」（⚠ 満杯なら押せない）
# ⚠ 鞄を選んだ → 「捨てる」（⚠ 入れ替えのため）
# ⚠ いつでも → 「全部入れる」「マップへ戻る」
# ⚠ 開けていない宝箱 → 「開ける」
func _rebuild_actions() -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()

	loot_detail.show_entry(_selected_entry)

	if not _was_opened():
		_add_action("OpenButton", "ui_dungeon_chest_open", _on_open_pressed)
		_add_action("BackButton", "ui_dungeon_shop_back", _on_back_pressed)
		return

	var item_id: String = str(_selected_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	if item_id != "":
		if _selected_from_bag:
			_add_action("DiscardBagButton", "ui_dungeon_pickup_discard_bag", _on_discard_bag_pressed)
		else:
			var take: PrimaryButton = _add_action(
				"TakeButton", "ui_dungeon_pickup_take", _on_take_pressed
			)
			# ⚠ 満杯なら押せない（⚠ 押してから弾かない＝ショップと同じ流儀）。
			take.disabled = (
				GameManager.get_dungeon_bag_used() >= GameManager.get_dungeon_bag_slots()
			)
			_add_action("DiscardLootButton", "ui_dungeon_pickup_discard", _on_discard_loot_pressed)

	if GameManager.has_dungeon_pending_loot():
		_add_action("TakeAllButton", "ui_dungeon_pickup_take_all", _on_take_all_pressed)
	_add_action("BackButton", "ui_dungeon_shop_back", _on_back_pressed)


func _add_action(node_name: String, label_key: String, handler: Callable) -> PrimaryButton:
	var button: PrimaryButton = PrimaryButton.new()
	button.name = node_name
	button.text = tr(label_key)
	button.pressed.connect(handler)
	action_row.add_child(button)
	return button


# ⚠ 1マスにつき1回だけ。⚠ 弾かれたら拾い待ちは増えない（⚠ 状態は動いていない）。
func _on_open_pressed() -> void:
	# ⚠ 開ける口も出どころで分かれる（⚠ 1本にまとめない＝覚え方が別）。
	if _is_corridor:
		var _corridor: Dictionary = GameManager.open_dungeon_corridor_chest()
	else:
		var _node: Dictionary = GameManager.open_dungeon_chest(_node_id)
	_clear_selection()
	_rebuild()


func _on_take_pressed() -> void:
	var item_id: String = str(_selected_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	if not GameManager.take_dungeon_pending_loot(item_id):
		message_label.text = tr("ui_dungeon_pickup_full")
		message_label.modulate = COLOR_FULL
		return
	_clear_selection()
	_rebuild()


func _on_take_all_pressed() -> void:
	var _taken: Dictionary = GameManager.take_all_dungeon_pending_loot()
	_clear_selection()
	_rebuild()


func _on_discard_loot_pressed() -> void:
	var _dropped: bool = GameManager.discard_dungeon_pending_loot(
		str(_selected_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	)
	_clear_selection()
	_rebuild()


func _on_discard_bag_pressed() -> void:
	var _dropped: bool = GameManager.discard_dungeon_bag_item(
		str(_selected_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	)
	_clear_selection()
	_rebuild()


# ⚠ 中身が減ると、⚠ 選んだままのマスが消える。⚠ 残すと押しても何も起きないボタンになる。
func _clear_selection() -> void:
	_selected_entry = {}
	_selected_from_bag = false


# ⚠⚠ 出るときに拾い待ちを捨てる（段階20-e）。⚠ 引き返さないので拾い直せない。
#   ⚠ 捨てないと、⚠ 次の宝箱の画面に前の拾いものが混ざる。
# ⚠⚠ 開けていない通路の宝箱も、⚠ 出た時点で捨てる（決定31・2026-09-05）。
#   ⚠ 人間の指示「宝箱はあとから開けれないようにしたい」。⚠ マップに案内は出ない。
func _on_back_pressed() -> void:
	var _left: Dictionary = GameManager.clear_dungeon_pending_loot()
	var _gone: bool = GameManager.discard_dungeon_corridor_chest()
	SceneManager.change_scene(DUNGEON_MAP_PATH)
