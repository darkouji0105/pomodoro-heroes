# res://scenes/ui/components/run_side_panel.gd
# ランの地図の左の板（2026-10-03・人間「⚠ かばんのわくがふえると横にずれていくので見づらい　⚠ マップが細くなったので
#   左側にインベントリやHPの状況などを書くように　⚠ あとインベントリが長くなるならスクロールできるように」）。
#
# ⚠ 使う画面：難ダンジョンの地図 ／ シナリオの地図（⚠ 2画面＝components・`NAV-8`「シナリオも同じ形」）。
# ⚠ 板の中：⚠ 3人の HP（`RunPartyStrip` を縦に）／ ⚠ 鞄（`ItemGrid` を決まった列で折り返し・⚠ 長くなったら縦にスクロール）。
# ⚠ 画面が持っている器（3人の行・鞄の見出し・鞄のマス目）を**付け替える**だけ（⚠ 作り直さない＝`@onready` の参照がそのまま生きる）。
# ⚠ 値（幅・列の数）は Theme の `RunSide` 型（`theme_builder.gd` の `RUN_SIDE_*`）。
class_name RunSidePanel
extends PanelContainer

const THEME_TYPE: StringName = &"RunSide"

var column: VBoxContainer = null


# 地図の紙（`map_sheet`）の左に板を足す。⚠ 紙と板を横に並べる器（`Body`）を、紙の居た場所に入れる。
static func attach(map_sheet: Control) -> RunSidePanel:
	var layout: Node = map_sheet.get_parent()
	var index: int = map_sheet.get_index()
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = map_sheet.size_flags_vertical
	layout.add_child(body)
	layout.move_child(body, index)
	var side: RunSidePanel = RunSidePanel.new()
	side.name = "RunSide"
	side.theme_type_variation = &"SidePanel"
	body.add_child(side)
	side.custom_minimum_size.x = float(side.get_theme_constant(&"width", THEME_TYPE))
	side.column = VBoxContainer.new()
	side.column.name = "Column"
	side.column.theme_type_variation = &"SectionGap"
	side.add_child(side.column)
	layout.remove_child(map_sheet)
	body.add_child(map_sheet)
	map_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return side


# 見出し（明朝の小さな題）。
func add_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"HeaderTitleLabel"
	label.text = text
	column.add_child(label)
	return label


# 3人の行を縦にして板へ移す。
func take_party(party: RunPartyStrip) -> void:
	party.get_parent().remove_child(party)
	party.vertical = true
	# ⚠ 横のときの間（`WideRow`）は縦だと広すぎる（⚠ 1枚目の絵で行の間が 40px 空いた）＝縦の詰めた間。
	party.theme_type_variation = &"TightList"
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(party)


# 鞄の見出し（⚠ 無ければ null）と鞄のマス目を移す。⚠ マス目は決まった列で折り返し、⚠ 板の残りの高さで縦にスクロール。
func take_bag(caption: Control, grid: ItemGrid) -> ScrollContainer:
	if caption != null:
		caption.get_parent().remove_child(caption)
		column.add_child(caption)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "BagScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	grid.get_parent().remove_child(grid)
	grid.columns = bag_columns()
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(grid)
	return scroll


# 鞄の列の数（⚠ 画面が枠の数で列を決め直さないように＝口はここ）。
func bag_columns() -> int:
	return maxi(1, get_theme_constant(&"bag_columns", THEME_TYPE))
