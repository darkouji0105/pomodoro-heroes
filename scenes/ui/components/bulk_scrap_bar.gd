# res://scenes/ui/components/bulk_scrap_bar.gd
# 一括分解の選び方の帯（2026-10-18・回UI-1018-1・手本 `mocks/Belongings.html` の `.scrapbar`・絵 `06_belongings_scrap.png`）。
#
# ⚠ 「分解するものを選ぶ　等級［1以下｜2以下｜3以下｜4以下］をまとめて ／ 見えている物ぜんぶ ／ 選び直す」。
# ⚠ 選ぶ決まり（⚠ ここ1か所）：⚠ 着けている物は選べない ／ ⚠ ★は「まとめて」に入らない（⚠ 1つずつ押せば選べる）。
# ⚠ 実際に分解するのは `BulkScrapSummary.run()` → `GameManager.dismantle_equipment_bulk()`。
# ⚠ 持ち物・鍛冶場で使う（components/）。

class_name BulkScrapBar
extends PanelContainer

signal grade_chosen(max_grade: int)
signal visible_all_pressed
signal reset_pressed

# ⚠ 「◯以下」の札（⚠ 手本の4つ）。⚠ 釣り合いの値ではない（⚠ 選びやすさだけ）。
const GRADE_CHOICES: Array[int] = [1, 2, 3, 4]


static func create() -> BulkScrapBar:
	var bar: BulkScrapBar = BulkScrapBar.new()
	bar.name = "BulkScrapBar"
	return bar


func _ready() -> void:
	theme_type_variation = &"ScrapBarPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"ButtonRow"
	add_child(row)
	var title: Label = Label.new()
	title.theme_type_variation = &"ErrorLabel"
	title.text = tr("ui_bulk_scrap_pick")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"FieldCaptionLabel"
	caption.text = tr("ui_bulk_scrap_grade")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var seg: PanelContainer = PanelContainer.new()
	seg.name = "GradeSeg"
	seg.theme_type_variation = &"SegGroup"
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seg)
	var seg_row: HBoxContainer = HBoxContainer.new()
	seg_row.theme_type_variation = &"SegRow"
	seg.add_child(seg_row)
	for grade: int in GRADE_CHOICES:
		var button: Button = Button.new()
		button.name = "Grade_%d" % grade
		button.theme_type_variation = &"SegButton"
		button.focus_mode = Control.FOCUS_NONE
		button.text = tr("ui_bulk_scrap_grade_max") % grade
		button.pressed.connect(func() -> void: grade_chosen.emit(grade))
		seg_row.add_child(button)
	var together: Label = Label.new()
	together.theme_type_variation = &"FieldCaptionLabel"
	together.text = tr("ui_bulk_scrap_together")
	together.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(together)
	var all: Button = _paper_button("VisibleAll", "ui_bulk_scrap_visible_all")
	all.pressed.connect(func() -> void: visible_all_pressed.emit())
	row.add_child(all)
	var again: Button = _paper_button("ResetPick", "ui_bulk_scrap_reset")
	again.pressed.connect(func() -> void: reset_pressed.emit())
	row.add_child(again)


func _paper_button(button_name: String, key: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = &"PaperToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(key)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


# --- 選ぶ決まり（⚠ ここ1か所） ---

# ⚠ 選べるか（⚠ 着けている物は選べない）。
static func can_pick(view: Dictionary) -> bool:
	return str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, "")) == ""


# ⚠ 「まとめて」に入るか（⚠ 選べて、⚠ ★ではない）。
static func can_pick_together(view: Dictionary) -> bool:
	return can_pick(view) and GameManager.get_item_special_effect(str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))) == ""


# 等級◯以下をまとめて（⚠ `views` は画面に見えている物＝`get_owned_instances()` の形）。
static func pick_by_grade(views: Array, max_grade: int) -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in views:
		var view: Dictionary = raw
		if can_pick_together(view) and int(view.get(GameStateKeys.INSTANCE_GRADE, 1)) <= max_grade:
			ids.append(str(view.get(GameManager.INSTANCE_VIEW_ID, "")))
	return ids


static func pick_visible(views: Array) -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in views:
		var view: Dictionary = raw
		if can_pick_together(view):
			ids.append(str(view.get(GameManager.INSTANCE_VIEW_ID, "")))
	return ids
