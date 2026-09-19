# res://scenes/adventure/run_relic_select.gd
# レリック選択（シナリオ・難ダンジョン共通。2026-09-19・人間の決定「全部推奨で」）。
#
# ⚠⚠ 前は floor_relic_select（行の一覧）と dungeon_relic_select（マス目）の2枚だった。
#   ⚠ 見た目は難ダンジョン側（マス目＋押した所の近くに詳細）に揃えて1枚にした。
# ⚠ どちらのランかは TransferKeys.RUN_KIND で受け取る。⚠ 器は別のまま（台帳 §7）。
#   ⚠ 候補を引く・取る・脱落を見るのは GameManager の *_run_relic* の口だけ（⚠ 種類で振り分ける）。
# ⚠ 選ばずに出られない（⚠ 戻るは無い）。⚠ 踏んだら必ず1つ取る（⚠ 両方とも前からこの形）。
#   ⚠ 前の dungeon_relic_select.gd の冒頭には「⚠ 戻るでマップへ出られる」とあったが、
#     ⚠ 戻るボタンは .tscn にもスクリプトにも無かった（⚠ 2026-09-19 に報告）。
# ⚠ 候補は入った瞬間に1回だけ引く。⚠ シナリオは呼ぶたびに引き直すので、⚠ 作り直しで引かない。
# ⚠ この画面は状態を持たない。⚠ 選んだら GameManager へ渡してマップへ戻る。
# ⚠⚠ 2026-09-19：モック v2 §9 の形。⚠ 左に候補のマス目・右に詳細と「取る／誰に付けるか」を常設。
#   ⚠ ヘッダの右に鞄と持っているレリック・3人の行（⚠ 難ダンジョンだけ）。

extends Control

const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"

# ランの種類ごとの題と案内（⚠ 翻訳キーは寄せない＝人間の決定。⚠ 綴りを組み立てない）。
const FLOOR_TITLE_KEY: String = "ui_relic_select_title"
const FLOOR_HINT_KEY: String = "ui_relic_select_hint"
const DUNGEON_TITLE_KEY: String = "ui_dungeon_relic_select"
const DUNGEON_HINT_KEY: String = "ui_dungeon_relic_hint"

# ⚠ 脱落しているキャラのボタンは赤（UiButton の DANGER）。⚠ 押しても take_run_relic() の先が弾く。

@onready var title_label: Label = $Layout/Header/TitleLabel
@onready var bag_label: Label = $Layout/Header/BagLabel
@onready var held_relic_grid: ItemGrid = $Layout/Header/HeldRelicGrid
@onready var party_list: RunPartyStrip = $Layout/PartyList
@onready var message_label: Label = $Layout/MessageLabel
@onready var relic_grid: ItemGrid = $Layout/Body/Left/RelicGrid
@onready var relic_detail: ItemDetail = $Layout/Body/Right/RelicDetail
@onready var action_caption: Label = $Layout/Body/Right/ActionCaption
@onready var action_row: HBoxContainer = $Layout/Body/Right/ActionRow
@onready var hint_label: Label = $Layout/Footer/HintLabel

# 持っているレリックにホバーしたときの詳細（⚠ 候補の詳細は右に常設なので、⚠ 見張るのはヘッダだけ）。
var _detail_popup: ItemDetailPopup = null

# どちらのランか（GameManager.RUN_KIND_*）。
var _kind: String = ""
# どのマスのレリックか。⚠ シナリオでは使わない（⚠ 渡し方だけ揃えてある）。
var _node_id: String = ""
# 入ったときに1回だけ引いた候補。
var _choices: Array = []
# 選んでいるレリック。⚠ 空なら選んでいない。
var _selected_relic_id: String = ""


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_kind = str(data.get(TransferKeys.RUN_KIND, ""))
	_node_id = str(data.get(TransferKeys.RUN_NODE_ID, ""))

	# ⚠ どちらのランか分からない／ランに入っていない。⚠ 空の画面を描かない。
	if _kind != GameManager.RUN_KIND_FLOOR and _kind != GameManager.RUN_KIND_DUNGEON:
		push_warning("[RunRelicSelect] ランの種類が渡っていないので冒険選択へ戻る: '%s'" % _kind)
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return
	if not GameManager.is_in_run(_kind):
		push_warning("[RunRelicSelect] ランに入っていないのでマップへ戻る")
		SceneManager.change_scene(_map_path())
		return

	_choices = GameManager.get_run_relic_choices(_kind, _node_id)
	if _choices.is_empty():
		# 候補が引けないのに閉じ込めない。⚠ そのままマップへ返す。
		push_warning("[RunRelicSelect] 候補が0件なのでマップへ戻る")
		SceneManager.change_scene(_map_path())
		return

	var is_floor: bool = _kind == GameManager.RUN_KIND_FLOOR
	title_label.text = tr(FLOOR_TITLE_KEY if is_floor else DUNGEON_TITLE_KEY)
	hint_label.text = tr(FLOOR_HINT_KEY if is_floor else DUNGEON_HINT_KEY)
	message_label.text = tr("ui_relic_select_locked")
	bag_label.text = "%s %d/%d" % [
		tr("ui_dungeon_bag"), GameManager.get_run_bag_used(_kind), GameManager.get_run_bag_slots(_kind)
	]
	var held: Array = GameManager.get_run_relic_slot_entries(_kind)
	held_relic_grid.rebuild(held, held.size())
	held_relic_grid.visible = not held.is_empty()
	$Layout/Header/RelicSep.visible = held_relic_grid.visible
	party_list.refresh(_kind)
	relic_grid.slot_pressed.connect(_on_relic_pressed)
	# ⚠ ヘッダのレリックはホバーで詳細（⚠ 右の常設の詳細とは別の器）。
	_detail_popup = ItemDetailPopup.adopt(self, ItemDetail.new())
	if _detail_popup != null:
		_detail_popup.watch(held_relic_grid)
	_rebuild()


func _map_path() -> String:
	return FLOOR_MAP_PATH if _kind == GameManager.RUN_KIND_FLOOR else DUNGEON_MAP_PATH


func _rebuild() -> void:
	var entries: Array = []
	for relic_id: Variant in _choices:
		entries.append(GameManager.make_relic_slot_entry(str(relic_id)))
	relic_grid.rebuild(entries, entries.size())
	_rebuild_actions()


func _on_relic_pressed(entry: Dictionary, _index: int) -> void:
	_selected_relic_id = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	_rebuild_actions()


# 選んだレリックに対してできること。
#
# ⚠ 全体用は「取る」1つ。⚠ 1人用は編成3人ぶんのボタン（⚠ 鞄のポーションと同じ流儀）。
# ⚠ 取れるかの判定は take_run_relic() の先が持つ。⚠ ここで条件を書かない。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
func _rebuild_actions() -> void:
	for child in action_row.get_children():
		action_row.remove_child(child)
		child.queue_free()

	relic_detail.show_entry(
		{} if _selected_relic_id == "" else GameManager.make_relic_slot_entry(_selected_relic_id)
	)
	action_caption.text = ""
	if _selected_relic_id == "":
		return

	if not GameManager.is_single_relic(_selected_relic_id):
		var take_button: UiButton = UiButton.new()
		take_button.name = "TakeButton"
		take_button.variant = UiButton.Variant.PRIMARY
		take_button.text = tr("ui_relic_take")
		take_button.pressed.connect(_on_take_pressed.bind(""))
		action_row.add_child(take_button)
		return

	action_caption.text = tr("ui_relic_pick_character")
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		if character_id == "":
			continue
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var button: UiButton = UiButton.new()
		button.name = "Give_" + character_id
		button.text = tr(str(char_data.get("name_key", character_id)))
		if GameManager.is_run_character_downed(_kind, character_id):
			button.variant = UiButton.Variant.DANGER
			button.text = "%s（%s）" % [button.text, tr("ui_dungeon_downed")]
		button.pressed.connect(_on_take_pressed.bind(character_id))
		action_row.add_child(button)


func _on_take_pressed(character_id: String) -> void:
	if not GameManager.take_run_relic(_kind, _node_id, _selected_relic_id, character_id):
		message_label.text = tr("ui_relic_take_failed")
		message_label.theme_type_variation = &"ErrorLabel"
		return
	SceneManager.change_scene(_map_path())
