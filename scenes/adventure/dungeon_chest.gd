# res://scenes/adventure/dungeon_chest.gd
# 難ダンジョンの宝箱のマス（段階19-b・人間の決定21「遺物や宝箱やショップは別画面」）。
#
# ⚠⚠ 拠点の宝箱（`PENDING_CHESTS` / `open_chest()`）と1行も共有していない。
#   ⚠ あちらは「持ち帰って拠点で開ける」もの。⚠ こちらは「その場で開く」（案A）。
#   ⚠ 共有すると、⚠ ランの戦利品が拠点の資産になり、⚠ 全ロスト（決定7・§4-8）が崩れる。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail`）。
# ⚠ 開ける判定を自分で書かない（`open_dungeon_chest()` が弾く）。
#   ⚠ もう開けたかも聞くだけ（`was_dungeon_chest_opened()`）。⚠ cleared を直接読まない。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
# ⚠ ScrollContainer を使わない。中は scenario=layout で測れない。

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

# 鞄が満杯で置いてきたものの色。⚠ 「入らなかった」が一目で分かること。
const COLOR_LEFT_BEHIND: Color = Color(0.85, 0.35, 0.35)

@onready var title_label: Label = $Layout/TitleLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var bag_label: Label = $Layout/BagLabel
@onready var loot_grid: ItemGrid = $Layout/LootGrid
@onready var loot_detail: ItemDetail = $Layout/LootDetail
@onready var action_row: HBoxContainer = $Layout/ActionRow

# どのマスの宝箱か。⚠ 通路の宝箱なら空（⚠ 通路はノードに紐づかない）。
var _node_id: String = ""
# 通路の宝箱として来たか（段階19-c-2）。
#
# ⚠⚠ 開けたかの覚え方が2通りある（⚠ ノード＝`cleared` ／ ⚠ 通路＝持ち越しの欄）。
#   ⚠ 画面はどちらかを1回だけ選び、⚠ 以降その枝だけを使う。⚠ 混ぜないこと。
var _is_corridor: bool = false
# 開けた結果。⚠ {"granted": {item_id: 個数}, "left_behind": {item_id: 個数}}。
# ⚠ 開けるまで空。⚠ 中身は開けた瞬間に決まる（⚠ 先に見せない＝選択が消えるため）。
var _result: Dictionary = {}
# 選んでいるマス。⚠ 空なら選んでいない。
var _selected_entry: Dictionary = {}


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_node_id = str(data.get(TransferKeys.DUNGEON_NODE_ID, ""))
	_is_corridor = bool(data.get(TransferKeys.DUNGEON_CORRIDOR_CHEST, false))

	# ⚠ ランに入っていない／どちらの宝箱かが渡っていないのに来た。⚠ 空の画面を描かない。
	if not GameManager.is_in_dungeon() or (_node_id == "" and not _is_corridor):
		push_warning("[DungeonChest] ランか宝箱の出どころが無いのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	title_label.text = tr(
		"ui_dungeon_corridor_chest_title" if _is_corridor else "ui_dungeon_chest_title"
	)
	loot_grid.slot_pressed.connect(_on_loot_pressed)
	_rebuild()


func _rebuild() -> void:
	_update_message()
	_rebuild_loot()
	_rebuild_actions()


# もう開けたか。⚠ 出どころで聞く先が変わる（段階19-c-2）。
#
# ⚠⚠ 判定を自分で書かない。⚠ どちらも GameManager の口に聞くだけ。
#   ⚠ ノード＝`was_dungeon_chest_opened()`（cleared を見る）
#   ⚠ 通路＝`has_pending_dungeon_corridor_chest()` の裏返し（持ち越しの欄を見る）
func _was_opened() -> bool:
	if _is_corridor:
		return not GameManager.has_pending_dungeon_corridor_chest()
	return GameManager.was_dungeon_chest_opened(_node_id)


# ⚠ 鞄の残りを必ず出す。⚠ 「開ける前に鞄を空けるか」を選べないと、
#   ⚠ 満杯のまま開けて中身が消えたときに理不尽になる。
func _update_message() -> void:
	bag_label.text = "%s %d/%d" % [
		tr("ui_dungeon_bag"), GameManager.get_dungeon_bag_used(), GameManager.get_dungeon_bag_slots()
	]
	if not _was_opened():
		message_label.text = tr("ui_dungeon_chest_hint")
		message_label.modulate = Color.WHITE
		return

	var left_behind: Dictionary = _result.get("left_behind", {})
	if left_behind.is_empty():
		message_label.text = tr("ui_dungeon_chest_opened")
		message_label.modulate = Color.WHITE
		return
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	var left_count: int = 0
	for item_id: Variant in left_behind:
		left_count += int(left_behind[item_id])
	message_label.text = "%s %d" % [tr("ui_dungeon_chest_left_behind"), left_count]
	message_label.modulate = COLOR_LEFT_BEHIND


# 開けて手に入ったものをマス目で出す（⚠ 鞄・倉庫と同じ流儀）。
#
# ⚠ 中身は `_result` から組み立てる。⚠ 鞄の中身を出さないこと
#   （⚠ 前から持っていたものが「この宝箱から出た」ように見える）。
func _rebuild_loot() -> void:
	var entries: Array = []
	var granted: Dictionary = _result.get("granted", {})
	var item_ids: Array = granted.keys()
	item_ids.sort()
	for entry: Variant in item_ids:
		var item_id: String = str(entry)
		var count: int = int(granted[item_id])
		for _i: int in range(maxi(0, count)):
			entries.append({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
				GameManager.SLOT_ENTRY_ITEM_ID: item_id,
				GameManager.SLOT_ENTRY_INSTANCE_ID: "",
				GameManager.SLOT_ENTRY_GRADE: 0,
				GameManager.SLOT_ENTRY_EQUIPPED_BY: "",
				GameManager.SLOT_ENTRY_COUNT: count,
			})
	loot_grid.rebuild(entries, entries.size())
	loot_detail.show_entry(_selected_entry)


func _on_loot_pressed(entry: Dictionary, _index: int) -> void:
	_selected_entry = entry
	loot_detail.show_entry(_selected_entry)


# 開ける前は「開ける」、開けたあとは「マップへ戻る」。
#
# ⚠ 開けずに戻る口も残す。⚠ 鞄が満杯のときに、⚠ 開けずにポーションを使ってから
#   戻ってくる、という手が残る（⚠ マップに戻っても同じマスに立ったまま）。
func _rebuild_actions() -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()

	if not _was_opened():
		var open_button: PrimaryButton = PrimaryButton.new()
		open_button.name = "OpenButton"
		open_button.text = tr("ui_dungeon_chest_open")
		open_button.pressed.connect(_on_open_pressed)
		action_row.add_child(open_button)

	var back_button: PrimaryButton = PrimaryButton.new()
	back_button.name = "BackButton"
	back_button.text = tr("ui_dungeon_shop_back")
	back_button.pressed.connect(_on_back_pressed)
	action_row.add_child(back_button)


# ⚠ 1マスにつき1回だけ。⚠ 弾かれたら結果は空のまま（⚠ 状態は動いていない）。
func _on_open_pressed() -> void:
	# ⚠ 開ける口も出どころで分かれる（⚠ 1本にまとめない＝覚え方が別）。
	if _is_corridor:
		_result = GameManager.open_dungeon_corridor_chest()
	else:
		_result = GameManager.open_dungeon_chest(_node_id)
	_selected_entry = {}
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.change_scene(DUNGEON_MAP_PATH)
