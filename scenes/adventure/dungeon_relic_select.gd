# res://scenes/adventure/dungeon_relic_select.gd
# 難ダンジョンのレリック選択（段階17-e-3・人間の指示「別画面にすべき」）。
#
# ⚠⚠ `floor_relic_select.gd` と1行も共有していない（台帳 §7）。
#   ⚠ あちらは `FLOOR_RUN` を読む。⚠ 見た目が似ているのは意図どおり。
# ⚠ 共有するのは部品だけ（`ItemGrid` / `ItemSlot` / `ItemDetail`）。
# ⚠ 選ばずに出られる（⚠ 「戻る」でマップへ）。⚠ フロア側は選ぶまで出られないが、
#   ⚠ こちらは踏んだマスに残る（⚠ `cleared` が立たないので、⚠ また来られる形にはしない）。
# ⚠ 候補は GameManager が「ノードごとに固定」で返す。⚠ ここで引き直さないこと。

extends Control

const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

@onready var title_label: Label = $Layout/TitleLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var relic_grid: ItemGrid = $Layout/RelicGrid
@onready var relic_detail: ItemDetail = $Layout/RelicDetail
@onready var action_row: HBoxContainer = $Layout/ActionRow

# どのマスのレリックか。⚠ 空ならマップへ戻す。
var _node_id: String = ""
# 選んでいるレリック。⚠ 空なら選んでいない。
var _selected_relic_id: String = ""


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_node_id = str(data.get(TransferKeys.DUNGEON_NODE_ID, ""))

	# ⚠ ランに入っていない／ノードが渡っていないのに来た。⚠ 空の画面を描かない。
	if not GameManager.is_in_dungeon() or _node_id == "":
		push_warning("[DungeonRelicSelect] ランかノードが無いのでマップへ戻る")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	title_label.text = tr("ui_dungeon_relic_select")
	message_label.text = tr("ui_dungeon_relic_hint")
	relic_grid.slot_pressed.connect(_on_relic_pressed)
	_rebuild()


func _rebuild() -> void:
	var entries: Array = []
	for relic_id: Variant in GameManager.get_dungeon_relic_choices(_node_id):
		entries.append(GameManager.make_relic_slot_entry(str(relic_id)))
	relic_grid.rebuild(entries, entries.size())
	_rebuild_actions()


func _on_relic_pressed(entry: Dictionary, _index: int) -> void:
	_selected_relic_id = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	_rebuild_actions()


# 選んだレリックに対してできること。
#
# ⚠ 全体用は「取る」1つ。⚠ 1人用は編成3人ぶんのボタン（⚠ 鞄のポーションと同じ流儀）。
# ⚠ 取れるかの判定は take_dungeon_relic() が持つ。⚠ ここで条件を書かない。
func _rebuild_actions() -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()

	relic_detail.show_entry(
		{} if _selected_relic_id == "" else GameManager.make_relic_slot_entry(_selected_relic_id)
	)
	if _selected_relic_id == "":
		return

	if not GameManager.is_single_relic(_selected_relic_id):
		var take_button: PrimaryButton = PrimaryButton.new()
		take_button.name = "TakeButton"
		take_button.text = tr("ui_relic_take")
		take_button.pressed.connect(_on_take_pressed.bind(""))
		action_row.add_child(take_button)
		return

	var caption: Label = Label.new()
	caption.name = "PickCharacterLabel"
	caption.text = tr("ui_relic_pick_character")
	action_row.add_child(caption)
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var button: PrimaryButton = PrimaryButton.new()
		button.name = "Give_" + character_id
		button.text = tr(str(char_data.get("name_key", character_id)))
		# ⚠ 脱落しているキャラは押しても弾かれる。⚠ 見て分かるように色を落とす。
		if GameManager.is_dungeon_character_downed(character_id):
			button.modulate = Color(0.85, 0.35, 0.35)
		button.pressed.connect(_on_take_pressed.bind(character_id))
		action_row.add_child(button)


func _on_take_pressed(character_id: String) -> void:
	if not GameManager.take_dungeon_relic(_node_id, _selected_relic_id, character_id):
		message_label.text = tr("ui_relic_take_failed")
		return
	SceneManager.change_scene(DUNGEON_MAP_PATH)
