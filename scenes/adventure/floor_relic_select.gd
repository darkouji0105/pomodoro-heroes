# res://scenes/adventure/floor_relic_select.gd
# レリック選択（段階14-d・PLAN_SCENARIO_MAP.md §5-2）。
#
# ⚠ Modal は使えない。notify()（OKだけ）と confirm()（2択・bool）しか無く、
#   3択が書けないため専用シーンにしてある（2026-08-25 に確認）。
# ⚠ この画面は状態を持たない。候補は入った瞬間に1回引き、選んだら GameManager へ渡す。
# ⚠ 選ばずに出られないようにする。踏んだら必ず1つ取る（行き止まりを作らない）。
# ⚠ 1人用のレリックは「誰に付けるか」を続けて選ぶ。周回の自動処理では
#   このノード自体が発生しないので「誰が選ぶのか」問題は起きない（§3-4）。

extends Control

const FLOOR_MAP_PATH: String = "res://scenes/adventure/floor_map.tscn"
const ADVENTURE_SELECT_PATH: String = "res://scenes/adventure/adventure_select.tscn"

# 何択にするか。⚠ バランス数値ではなく画面の器の話なのでここに置く。
const CHOICE_COUNT: int = 3

@onready var message_label: Label = $Layout/MessageLabel
@onready var choice_list: VBoxContainer = $Layout/ChoiceList

# 引いた候補。⚠ 1回だけ引く。作り直しのたびに引き直すと、キャラを選ぶ段で候補が変わる。
var _choices: Array = []
# 1人用を選んだあと、誰に付けるかを選んでいる最中のレリック。空なら候補の一覧。
var _pending_relic_id: String = ""


func _ready() -> void:
	SceneManager.consume_transfer_data()

	if not GameManager.is_in_floor():
		push_warning("[FloorRelicSelect] フロアに入っていないので冒険選択へ戻る")
		SceneManager.change_scene(ADVENTURE_SELECT_PATH)
		return

	_choices = GameManager.roll_relic_choices(CHOICE_COUNT)
	if _choices.is_empty():
		# 候補が引けないのに閉じ込めない。⚠ そのままマップへ返す。
		push_warning("[FloorRelicSelect] 候補が0件なのでマップへ戻る")
		SceneManager.change_scene(FLOOR_MAP_PATH)
		return

	message_label.text = tr("ui_relic_select_hint")
	_rebuild()


func _rebuild() -> void:
	# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()

	if _pending_relic_id != "":
		_build_character_rows()
		return
	_build_choice_rows()


func _build_choice_rows() -> void:
	for entry: Variant in _choices:
		var relic_id: String = str(entry)
		var relic: Dictionary = MasterDataLoader.get_relic(relic_id)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Choice_" + relic_id

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = 3
		var scope_key: String = (
			"ui_relic_scope_single" if GameManager.is_single_relic(relic_id)
			else "ui_relic_scope_party"
		)
		name_label.text = "%s（%s）" % [tr(str(relic.get("name_key", relic_id))), tr(scope_key)]
		row.add_child(name_label)

		var button: PrimaryButton = PrimaryButton.new()
		button.name = "Take_" + relic_id
		button.text = "ui_relic_take"
		button.pressed.connect(_on_choice_pressed.bind(relic_id))
		row.add_child(button)

		choice_list.add_child(row)


# 1人用のとき、誰に付けるかを選ぶ行。
func _build_character_rows() -> void:
	var relic: Dictionary = MasterDataLoader.get_relic(_pending_relic_id)
	message_label.text = "%s … %s" % [
		tr(str(relic.get("name_key", _pending_relic_id))), tr("ui_relic_pick_character")
	]
	for member: Variant in GameManager.get_party_members():
		var character_id: String = str(member)
		var char_data: Dictionary = MasterDataLoader.get_character(character_id)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Member_" + character_id

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = 3
		name_label.text = tr(str(char_data.get("name_key", character_id)))
		row.add_child(name_label)

		var button: PrimaryButton = PrimaryButton.new()
		button.name = "Give_" + character_id
		button.text = "ui_relic_give"
		button.pressed.connect(_on_character_pressed.bind(character_id))
		row.add_child(button)

		choice_list.add_child(row)


func _on_choice_pressed(relic_id: String) -> void:
	if GameManager.is_single_relic(relic_id):
		_pending_relic_id = relic_id
		_rebuild()
		return
	_finish(relic_id, "")


func _on_character_pressed(character_id: String) -> void:
	_finish(_pending_relic_id, character_id)


func _finish(relic_id: String, character_id: String) -> void:
	if not GameManager.take_relic(relic_id, character_id):
		message_label.text = tr("ui_relic_take_failed")
		return
	SceneManager.change_scene(FLOOR_MAP_PATH)
