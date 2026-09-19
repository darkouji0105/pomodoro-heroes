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

extends Control

const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"

# ランの種類ごとの題と案内（⚠ 翻訳キーは寄せない＝人間の決定。⚠ 綴りを組み立てない）。
const FLOOR_TITLE_KEY: String = "ui_relic_select_title"
const FLOOR_HINT_KEY: String = "ui_relic_select_hint"
const DUNGEON_TITLE_KEY: String = "ui_dungeon_relic_select"
const DUNGEON_HINT_KEY: String = "ui_dungeon_relic_hint"

# 脱落しているキャラの色。⚠ 押しても弾かれるので、⚠ 見て分かるように色を落とす。
const COLOR_DOWNED: Color = Color(0.85, 0.35, 0.35)

@onready var title_label: Label = $Layout/TitleLabel
@onready var message_label: Label = $Layout/MessageLabel
@onready var relic_grid: ItemGrid = $Layout/RelicGrid
@onready var relic_detail: ItemDetail = $Layout/RelicDetail
@onready var action_row: HBoxContainer = $Layout/ActionRow

# 押した所の近くに詳細を出す器（2026-09-07）。⚠ `relic_detail` と `action_row` を引き取る。
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
	message_label.text = tr(FLOOR_HINT_KEY if is_floor else DUNGEON_HINT_KEY)
	relic_grid.slot_pressed.connect(_on_relic_pressed)
	# ⚠ 詳細をドロップダウンへ移す（2026-09-07）。⚠ `action_row` は画面に残す。
	_detail_popup = ItemDetailPopup.adopt(self, relic_detail)
	if _detail_popup != null:
		_detail_popup.watch(relic_grid)
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
	if _selected_relic_id == "":
		return

	if not GameManager.is_single_relic(_selected_relic_id):
		var take_button: UiButton = UiButton.new()
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
		var button: UiButton = UiButton.new()
		button.name = "Give_" + character_id
		button.text = tr(str(char_data.get("name_key", character_id)))
		if GameManager.is_run_character_downed(_kind, character_id):
			button.modulate = COLOR_DOWNED
		button.pressed.connect(_on_take_pressed.bind(character_id))
		action_row.add_child(button)


func _on_take_pressed(character_id: String) -> void:
	if not GameManager.take_run_relic(_kind, _node_id, _selected_relic_id, character_id):
		message_label.text = tr("ui_relic_take_failed")
		return
	SceneManager.change_scene(_map_path())
