# res://scenes/ui/components/equip_sort_bar.gd
# 装備の一覧の並べ替えと絞り込み（2026-10-18・人間「⚠ 装備をソートできるように　レア度でフィルターなど」）。
#
# ⚠ 持ち物の装備タブと、育成の装備タブで使う（⚠ 2画面＝components/）。
# ⚠ 並び：既定（`get_owned_instances()` のまま）／ 等級の高い順 ／ 名前順。
# ⚠ 絞り込み：等級◯以上 ／ ★（特殊効果）だけ。⚠ 装備に「レア度」の欄は無い＝⚠ 等級と★をレア度として扱う（`EQ-13`・`EQ-15`）。
# ⚠ 選んだものは遊んでいるあいだ覚える（`SceneManager.remember()`・⚠ 2画面で共通）。⚠ セーブには入れない。
# ⚠ 行の並べ替えはここ1か所（`apply()`）。⚠ 画面側で並べ直さない。

class_name EquipSortBar
extends HBoxContainer

signal changed

const SORT_DEFAULT: String = "default"
const SORT_GRADE: String = "grade"
const SORT_NAME: String = "name"
const SORTS: Array[String] = [SORT_DEFAULT, SORT_GRADE, SORT_NAME]
const SORT_KEYS: Array[String] = ["ui_equip_sort_default", "ui_equip_sort_grade", "ui_equip_sort_name"]


static func create() -> EquipSortBar:
	var bar: EquipSortBar = EquipSortBar.new()
	bar.name = "EquipSortBar"
	return bar


func _ready() -> void:
	theme_type_variation = &"ButtonRow"
	var sort_picker: OptionButton = OptionButton.new()
	sort_picker.name = "SortPicker"
	for key: String in SORT_KEYS:
		sort_picker.add_item(tr(key))
	sort_picker.select(maxi(0, SORTS.find(current_sort())))
	sort_picker.item_selected.connect(_on_sort_selected)
	add_child(sort_picker)

	var grade_picker: OptionButton = OptionButton.new()
	grade_picker.name = "GradePicker"
	grade_picker.add_item(tr("ui_equip_filter_grade_all"))
	for grade: int in range(2, GameManager.get_max_equipment_grade() + 1):
		grade_picker.add_item(tr("ui_equip_filter_grade_min") % grade)
	grade_picker.select(maxi(0, current_min_grade() - 1))
	grade_picker.item_selected.connect(_on_grade_selected)
	add_child(grade_picker)

	var special: CheckBox = CheckBox.new()
	special.name = "SpecialOnly"
	special.text = tr("ui_equip_filter_special")
	special.tooltip_text = tr("ui_eqfx_legend")
	special.button_pressed = current_special_only()
	special.toggled.connect(_on_special_toggled)
	add_child(special)


# --- いまの選び（⚠ 画面をまたいで覚える） ---

static func current_sort() -> String:
	var sort: String = str(SceneManager.recall(TransferKeys.MEMORY_EQUIP_SORT, SORT_DEFAULT))
	return sort if sort in SORTS else SORT_DEFAULT


# ⚠ 1 ＝すべての等級。
static func current_min_grade() -> int:
	return clampi(int(SceneManager.recall(TransferKeys.MEMORY_EQUIP_MIN_GRADE, 1)), 1, GameManager.get_max_equipment_grade())


static func current_special_only() -> bool:
	return bool(SceneManager.recall(TransferKeys.MEMORY_EQUIP_SPECIAL_ONLY, false))


# ⚠ 絞り込みが掛かっているか（⚠ 0件のときに「絞り込みで隠れている」と言うため）。
static func is_filtering() -> bool:
	return current_min_grade() > 1 or current_special_only()


# `get_owned_instances()` の形の配列を、いまの選びで絞って並べた新しい配列を返す（⚠ 元の配列は触らない）。
static func apply(views: Array) -> Array:
	var min_grade: int = current_min_grade()
	var special_only: bool = current_special_only()
	var result: Array = []
	for raw: Variant in views:
		var view: Dictionary = raw
		if int(view.get(GameStateKeys.INSTANCE_GRADE, 1)) < min_grade:
			continue
		if special_only and GameManager.get_item_special_effect(str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))) == "":
			continue
		result.append(view)
	match current_sort():
		SORT_GRADE:
			# ⚠ 同じ等級は既定の並び（⚠ sort_custom は安定ではない＝⚠ 元の位置で決める）。
			var order: Dictionary = _order_of(result)
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var grade_a: int = int(a.get(GameStateKeys.INSTANCE_GRADE, 1))
				var grade_b: int = int(b.get(GameStateKeys.INSTANCE_GRADE, 1))
				if grade_a != grade_b:
					return grade_a > grade_b
				return int(order[a.get(GameManager.INSTANCE_VIEW_ID, "")]) < int(order[b.get(GameManager.INSTANCE_VIEW_ID, "")])
			)
		SORT_NAME:
			var order: Dictionary = _order_of(result)
			result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var name_a: String = TranslationServer.translate(GameManager.item_name_key(str(a.get(GameStateKeys.INSTANCE_ITEM_ID, ""))))
				var name_b: String = TranslationServer.translate(GameManager.item_name_key(str(b.get(GameStateKeys.INSTANCE_ITEM_ID, ""))))
				if name_a != name_b:
					return name_a < name_b
				var grade_a: int = int(a.get(GameStateKeys.INSTANCE_GRADE, 1))
				var grade_b: int = int(b.get(GameStateKeys.INSTANCE_GRADE, 1))
				if grade_a != grade_b:
					return grade_a > grade_b
				return int(order[a.get(GameManager.INSTANCE_VIEW_ID, "")]) < int(order[b.get(GameManager.INSTANCE_VIEW_ID, "")])
			)
	return result


static func _order_of(views: Array) -> Dictionary:
	var order: Dictionary = {}
	for i: int in range(views.size()):
		order[(views[i] as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")] = i
	return order


# --- 操作 ---

func _on_sort_selected(index: int) -> void:
	SceneManager.remember(TransferKeys.MEMORY_EQUIP_SORT, SORTS[index])
	changed.emit()


func _on_grade_selected(index: int) -> void:
	SceneManager.remember(TransferKeys.MEMORY_EQUIP_MIN_GRADE, index + 1)
	changed.emit()


func _on_special_toggled(pressed: bool) -> void:
	SceneManager.remember(TransferKeys.MEMORY_EQUIP_SPECIAL_ONLY, pressed)
	changed.emit()
