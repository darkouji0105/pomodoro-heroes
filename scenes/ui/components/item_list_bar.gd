# res://scenes/ui/components/item_list_bar.gd
# 品の一覧の欄：見せ方（マス目｜行）・並び・しぼる（2026-10-18・回UI-1018-1・手本 `mocks/Belongings.html` の `.tool`）。
#
# ⚠ 前の回の `EquipSortBar`（10-18 朝）を置き換えた（⚠ 同じ役目の部品を2つ持たない）。
# ⚠ 種類は3つ：装備（並び＝いつもの順・等級・部位・名前 ／ しぼる＝部位・等級◯以上・★だけ・着けている物だけ）
#   ／ 装飾・素材（並び＝いつもの順・等級・数・名前）。⚠ 装備に「レア度」の欄は無い＝等級と★をレア度として扱う。
# ⚠ 選んだものは遊んでいるあいだ覚える（`SceneManager.remember()`・⚠ 種類ごと＝持ち物・鍛冶場・育成で共通）。⚠ セーブには入れない。
# ⚠ 並べ替えと絞り込みはここ1か所（`apply_views()` / `apply_entries()`）。⚠ 画面側で並べ直さない。
# ⚠ 持ち物・鍛冶場・育成・詰所で使う（components/）。

class_name ItemListBar
extends VBoxContainer

signal changed

const KIND_EQUIP: String = "equip"
const KIND_PART: String = "part"
const KIND_MATERIAL: String = "material"

const VIEW_GRID: String = "grid"
const VIEW_LIST: String = "list"
const VIEWS: Array[String] = [VIEW_GRID, VIEW_LIST]
const VIEW_KEYS: Array[String] = ["ui_item_view_grid", "ui_item_view_list"]

const SORT_DEFAULT: String = "default"
const SORT_GRADE: String = "grade"
const SORT_SLOT: String = "slot"
const SORT_NAME: String = "name"
const SORT_COUNT: String = "count"
const SORT_USE: String = "use"
const EQUIP_SORTS: Array[String] = [SORT_DEFAULT, SORT_GRADE, SORT_SLOT, SORT_NAME]
const STACK_SORTS: Array[String] = [SORT_DEFAULT, SORT_GRADE, SORT_COUNT, SORT_NAME]
# ⚠ 素材は「使い道」で並べられる（⚠ 手本 `06_belongings_mat_grid.png`・`GameManager.get_material_uses()`）。
const MATERIAL_SORTS: Array[String] = [SORT_DEFAULT, SORT_COUNT, SORT_USE, SORT_NAME]

# ⚠ 覚える欄（⚠ `TransferKeys.MEMORY_ITEM_BAR` ＋ 種類 ＋ これ）。
const FIELD_VIEW: String = "view"
const FIELD_SORT: String = "sort"
const FIELD_SLOT: String = "slot"
const FIELD_MIN_GRADE: String = "min_grade"
const FIELD_SPECIAL: String = "special"
const FIELD_EQUIPPED: String = "equipped"
const FIELD_OWNED: String = "owned"

var kind: String = KIND_EQUIP
var show_view_toggle: bool = true
var show_slot_filter: bool = true
var show_equipped_only: bool = false
# ⚠ しぼるの行の右端に置くもの（⚠ 「一括分解」など。⚠ 画面が渡す）。
var trailing: Control = null


static func create(p_kind: String, options: Dictionary = {}) -> ItemListBar:
	var bar: ItemListBar = ItemListBar.new()
	bar.name = "ItemListBar"
	bar.kind = p_kind
	bar.show_view_toggle = bool(options.get("view", true))
	bar.show_slot_filter = bool(options.get("slot", true))
	bar.show_equipped_only = bool(options.get("equipped", false))
	return bar


func _ready() -> void:
	theme_type_variation = &"TightList"
	var first: HBoxContainer = _row("ToolRow")
	if show_view_toggle:
		first.add_child(_caption("ui_item_bar_view"))
		first.add_child(_seg("ViewSeg", VIEWS, VIEW_KEYS, view_of(kind), _on_view_picked))
	first.add_child(_caption("ui_item_bar_sort"))
	var sorts: Array[String] = sorts_of(kind)
	var sort_keys: Array[String] = []
	for sort: String in sorts:
		sort_keys.append("ui_item_sort_" + sort)
	first.add_child(_seg("SortSeg", sorts, sort_keys, sort_of(kind), _on_sort_picked))
	if kind == KIND_EQUIP:
		first.add_child(_toggle("SpecialOnly", "ui_item_filter_special", special_only(kind), FIELD_SPECIAL))
	if kind == KIND_MATERIAL:
		first.add_child(_toggle("OwnedOnly", "ui_item_filter_owned", owned_only(kind), FIELD_OWNED))
	if kind != KIND_EQUIP:
		if trailing != null:
			first.add_child(_spacer())
			first.add_child(trailing)
		return

	var second: HBoxContainer = _row("FilterRow")
	second.add_child(_caption("ui_item_bar_filter"))
	if show_slot_filter:
		var slots: Array[String] = [""]
		var slot_keys: Array[String] = ["ui_belongings_filter_all"]
		for slot: String in GameManager.get_equip_slots():
			slots.append(slot)
			slot_keys.append("ui_equipment_slot_" + slot)
		second.add_child(_seg("SlotSeg", slots, slot_keys, slot_filter(kind), _on_slot_picked))
	var grade_pick: OptionButton = OptionButton.new()
	grade_pick.name = "GradePicker"
	grade_pick.theme_type_variation = &"PaperPick"
	grade_pick.add_item(tr("ui_item_filter_grade_all"))
	for grade: int in range(2, GameManager.get_max_equipment_grade() + 1):
		grade_pick.add_item(tr("ui_item_filter_grade_min") % grade)
	grade_pick.select(maxi(0, min_grade(kind) - 1))
	grade_pick.item_selected.connect(_on_grade_picked)
	second.add_child(grade_pick)
	if show_equipped_only:
		second.add_child(_toggle("EquippedOnly", "ui_item_filter_equipped", equipped_only(kind), FIELD_EQUIPPED))
	if trailing != null:
		second.add_child(_spacer())
		second.add_child(trailing)


# --- 部品 ---

func _row(row_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = row_name
	row.theme_type_variation = &"ButtonRow"
	add_child(row)
	return row


func _caption(key: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"FieldCaptionLabel"
	label.text = tr(key)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _spacer() -> Control:
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return gap


# 切り替えの札（⚠ 1つだけ押されている）。⚠ 札の名前は `<seg名>_<値>`（⚠ 値が空なら all）。
func _seg(seg_name: String, values: Array[String], keys: Array[String], current: String, handler: Callable) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.name = seg_name
	box.theme_type_variation = &"SegGroup"
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"SegRow"
	box.add_child(row)
	var group: ButtonGroup = ButtonGroup.new()
	for i: int in range(values.size()):
		var button: Button = Button.new()
		button.name = "%s_%s" % [seg_name, values[i] if values[i] != "" else "all"]
		button.theme_type_variation = &"SegButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr(keys[i])
		button.button_pressed = values[i] == current
		button.pressed.connect(handler.bind(values[i]))
		row.add_child(button)
	return box


func _toggle(toggle_name: String, key: String, on: bool, field: String) -> Button:
	var button: Button = Button.new()
	button.name = toggle_name
	button.theme_type_variation = &"PaperToggle"
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(key)
	button.button_pressed = on
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.toggled.connect(_on_toggled.bind(field))
	return button


# --- いまの選び（⚠ 画面をまたいで覚える） ---

static func _memory_key(p_kind: String, field: String) -> String:
	return "%s_%s_%s" % [TransferKeys.MEMORY_ITEM_BAR, p_kind, field]


static func _recall(p_kind: String, field: String, fallback: Variant) -> Variant:
	var value: Variant = SceneManager.recall(_memory_key(p_kind, field), fallback)
	return fallback if value == null else value


static func view_of(p_kind: String) -> String:
	var view: String = str(_recall(p_kind, FIELD_VIEW, VIEW_GRID))
	return view if view in VIEWS else VIEW_GRID


static func sorts_of(p_kind: String) -> Array[String]:
	match p_kind:
		KIND_EQUIP:
			return EQUIP_SORTS
		KIND_MATERIAL:
			return MATERIAL_SORTS
	return STACK_SORTS


static func sort_of(p_kind: String) -> String:
	var sorts: Array[String] = sorts_of(p_kind)
	var sort: String = str(_recall(p_kind, FIELD_SORT, SORT_DEFAULT))
	return sort if sort in sorts else SORT_DEFAULT


static func slot_filter(p_kind: String) -> String:
	var slot: String = str(_recall(p_kind, FIELD_SLOT, ""))
	return slot if (slot == "" or slot in GameManager.get_equip_slots()) else ""


# ⚠ 1 ＝すべての等級。
static func min_grade(p_kind: String) -> int:
	return clampi(int(_recall(p_kind, FIELD_MIN_GRADE, 1)), 1, GameManager.get_max_equipment_grade())


static func special_only(p_kind: String) -> bool:
	return bool(_recall(p_kind, FIELD_SPECIAL, false))


static func owned_only(p_kind: String) -> bool:
	return bool(_recall(p_kind, FIELD_OWNED, false))


static func equipped_only(p_kind: String) -> bool:
	return bool(_recall(p_kind, FIELD_EQUIPPED, false))


# ⚠ 絞り込みが掛かっているか（⚠ 0件のときに「絞り込みで隠れている」と言うため）。
static func is_filtering(p_kind: String, with_equipped: bool = false, with_slot: bool = true) -> bool:
	if p_kind != KIND_EQUIP:
		return false
	return (with_slot and slot_filter(p_kind) != "") or min_grade(p_kind) > 1 or special_only(p_kind) or (with_equipped and equipped_only(p_kind))


# ⚠ 見せ方を決める（⚠ 検査が使う）。
static func set_view(p_kind: String, view: String) -> void:
	SceneManager.remember(_memory_key(p_kind, FIELD_VIEW), view)


# ⚠ 選びを全部はじめに戻す（⚠ 検査が使う）。
static func reset_memory(p_kind: String) -> void:
	for field: String in [FIELD_VIEW, FIELD_SORT, FIELD_SLOT, FIELD_MIN_GRADE, FIELD_SPECIAL, FIELD_EQUIPPED, FIELD_OWNED]:
		SceneManager.remember(_memory_key(p_kind, field), null)


# --- 並べ替えと絞り込み（⚠ ここ1か所） ---

# `get_owned_instances()` の形の配列を、いまの選びで絞って並べた新しい配列（⚠ 元は触らない）。
# ⚠ `with_equipped` / `with_slot`：その画面がその欄を出しているか（⚠ 出していない画面で、⚠ ほかの画面で選んだ絞り込みを効かせない）。
static func apply_views(views: Array, with_equipped: bool = false, with_slot: bool = true) -> Array:
	var p_kind: String = KIND_EQUIP
	var slot: String = slot_filter(p_kind) if with_slot else ""
	var floor_grade: int = min_grade(p_kind)
	var special: bool = special_only(p_kind)
	var equipped: bool = with_equipped and equipped_only(p_kind)
	var result: Array = []
	for raw: Variant in views:
		var view: Dictionary = raw
		var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		if slot != "" and str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")) != slot:
			continue
		if int(view.get(GameStateKeys.INSTANCE_GRADE, 1)) < floor_grade:
			continue
		if special and GameManager.get_item_special_effect(item_id) == "":
			continue
		if equipped and str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, "")) == "":
			continue
		result.append(view)
	var order: Dictionary = {}
	for i: int in range(result.size()):
		order[(result[i] as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")] = i
	var slots: Array[String] = GameManager.get_equip_slots()
	match sort_of(p_kind):
		SORT_GRADE:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _by(_grade_desc(a, b), a, b, order))
		SORT_SLOT:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var slot_a: int = slots.find(str(MasterDataLoader.get_item(str(a.get(GameStateKeys.INSTANCE_ITEM_ID, ""))).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")))
				var slot_b: int = slots.find(str(MasterDataLoader.get_item(str(b.get(GameStateKeys.INSTANCE_ITEM_ID, ""))).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")))
				if slot_a != slot_b:
					return slot_a < slot_b
				return _by(_grade_desc(a, b), a, b, order))
		SORT_NAME:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var name_a: String = TranslationServer.translate(GameManager.item_name_key(str(a.get(GameStateKeys.INSTANCE_ITEM_ID, ""))))
				var name_b: String = TranslationServer.translate(GameManager.item_name_key(str(b.get(GameStateKeys.INSTANCE_ITEM_ID, ""))))
				if name_a != name_b:
					return name_a < name_b
				return _by(_grade_desc(a, b), a, b, order))
	return result


# ⚠ 等級が違えば高い方が先（1）／ 低い方が先（-1）／ 同じ（0）。
static func _grade_desc(a: Dictionary, b: Dictionary) -> int:
	var grade_a: int = int(a.get(GameStateKeys.INSTANCE_GRADE, 1))
	var grade_b: int = int(b.get(GameStateKeys.INSTANCE_GRADE, 1))
	if grade_a == grade_b:
		return 0
	return 1 if grade_a > grade_b else -1


# ⚠ sort_custom は安定ではない＝⚠ 同じなら元の位置で決める。
static func _by(compare: int, a: Dictionary, b: Dictionary, order: Dictionary) -> bool:
	if compare != 0:
		return compare > 0
	return int(order.get(a.get(GameManager.INSTANCE_VIEW_ID, ""), 0)) < int(order.get(b.get(GameManager.INSTANCE_VIEW_ID, ""), 0))


# 装飾・素材（⚠ マスの形の配列）を並べた新しい配列。⚠ 絞り込みは素材の「持っている物だけ」だけ。
static func apply_entries(entries: Array, p_kind: String) -> Array:
	var result: Array = []
	for raw: Variant in entries:
		if p_kind == KIND_MATERIAL and owned_only(p_kind) and ItemView.count_of(raw as Dictionary) == 0:
			continue
		result.append(raw)
	var order: Dictionary = {}
	for i: int in range(result.size()):
		order[ItemView.key_of(result[i] as Dictionary)] = i
	var keep: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		return int(order.get(ItemView.key_of(a), 0)) < int(order.get(ItemView.key_of(b), 0))
	match sort_of(p_kind):
		SORT_GRADE:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var grade_a: int = ItemView.grade_of(a)
				var grade_b: int = ItemView.grade_of(b)
				return grade_a > grade_b if grade_a != grade_b else bool(keep.call(a, b)))
		SORT_COUNT:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var count_a: int = ItemView.count_of(a)
				var count_b: int = ItemView.count_of(b)
				return count_a > count_b if count_a != count_b else bool(keep.call(a, b)))
		SORT_USE:
			var rank: Callable = func(entry: Dictionary) -> int:
				var uses: Array[String] = GameManager.get_material_uses(ItemView.item_id_of(entry))
				return GameManager.MATERIAL_USES.size() if uses.is_empty() else GameManager.MATERIAL_USES.find(uses[0])
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var rank_a: int = int(rank.call(a))
				var rank_b: int = int(rank.call(b))
				return rank_a < rank_b if rank_a != rank_b else bool(keep.call(a, b)))
		SORT_NAME:
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var name_a: String = ItemView.name_text(a)
				var name_b: String = ItemView.name_text(b)
				return name_a < name_b if name_a != name_b else bool(keep.call(a, b)))
	return result


# --- 操作 ---

func _remember(field: String, value: Variant) -> void:
	SceneManager.remember(_memory_key(kind, field), value)
	changed.emit()


func _on_view_picked(value: String) -> void:
	_remember(FIELD_VIEW, value)


func _on_sort_picked(value: String) -> void:
	_remember(FIELD_SORT, value)


func _on_slot_picked(value: String) -> void:
	_remember(FIELD_SLOT, value)


func _on_grade_picked(index: int) -> void:
	_remember(FIELD_MIN_GRADE, index + 1)


func _on_toggled(on: bool, field: String) -> void:
	_remember(field, on)
