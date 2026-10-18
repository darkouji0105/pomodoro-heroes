# res://scenes/ui/components/item_collection.gd
# 品の並び：マス目か行（2026-10-18・回UI-1018-1・手本 `mocks/Belongings.html` の `.egrid` / `.erow`）。
#
# ⚠ 中身は「マスの形」の Dictionary の配列（`ItemView`）。⚠ 何を並べるか・どの順かは画面と `ItemListBar` が決める。
# ⚠ 状態（選んでいる・選べない・一括分解で選んだ・札）は画面が渡す。⚠ ここは描いて、押された鍵を返すだけ。
# ⚠ 送り（ScrollContainer）を自分で持つ（⚠ 名前は `ItemScroll`＝`ScrollKeeper` が戻せる）。
# ⚠ マス目は折り返して流す（`HFlowContainer`）。⚠ 列の数を決めて並べると、⚠ 決める前の1回で 12 列ぶんの幅を要求して画面がはみ出した（10-18 の絵）。
# ⚠ 触れると出る札（`ItemTipCard`）を渡されていれば、⚠ ここが出し入れする。
# ⚠ 再描画は画面が丸ごと作り直す（⚠ await を持たない・CLAUDE.md 5番）。

class_name ItemCollection
extends VBoxContainer

signal item_pressed(key: String)

const THEME_TYPE: StringName = &"ItemCell"

var view: String = ItemListBar.VIEW_GRID
var selected_key: String = ""
# ⚠ key -> true。
var picked: Dictionary = {}
var locked: Dictionary = {}
# ⚠ key -> [字, ItemCell.Tag]。
var tags: Dictionary = {}
var tip: ItemTipCard = null
# ⚠ 触れたときに比べる相手（⚠ entry を受けて instance_id を返す。⚠ 空なら比べない）。
var compare_with: Callable = Callable()
# ⚠ 0件のときの字（⚠ EmptyState の鍵）。
var empty_key: String = "ui_warehouse_empty"

var _entries: Array = []
var _grid: HFlowContainer = null
var _cells: Dictionary = {}


static func create(p_view: String) -> ItemCollection:
	var collection: ItemCollection = ItemCollection.new()
	collection.name = "ItemCollection"
	collection.view = p_view
	collection.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return collection


# ⚠ 並べる（⚠ 1回だけ呼ぶ。⚠ 変わったら画面が作り直す）。
func set_entries(entries: Array) -> void:
	_entries = entries
	if is_inside_tree():
		_build()


func _ready() -> void:
	_build()


func get_cell(key: String) -> ItemCell:
	return _cells.get(key, null) as ItemCell


func get_keys() -> Array[String]:
	var keys: Array[String] = []
	for entry: Variant in _entries:
		keys.append(ItemView.key_of(entry as Dictionary))
	return keys


func _build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	_grid = null
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	if _entries.is_empty():
		var empty: Control = EmptyState.create(empty_key)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(empty)
		return
	if view == ItemListBar.VIEW_LIST:
		var rows: VBoxContainer = VBoxContainer.new()
		rows.name = "Rows"
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		for entry: Variant in _entries:
			rows.add_child(_make_row(entry as Dictionary))
		return
	# ⚠ マス目。⚠ はみ出す印（顔・札・選んだ縁）の分だけ内側に余白を取る。
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "GridMargin"
	margin.theme_type_variation = &"ItemCellGridMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	_grid = HFlowContainer.new()
	_grid.name = "Grid"
	_grid.theme_type_variation = &"ItemCellGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_grid)
	for entry: Variant in _entries:
		var cell: ItemCell = _make_cell(entry as Dictionary, 0)
		# ⚠ NEW のしおり紐（⚠ 行と同じ）。
		if GameManager.is_item_new(ItemView.item_id_of(entry as Dictionary)):
			RibbonMark.attach(cell)
		_grid.add_child(cell)


func _make_cell(entry: Dictionary, side: int) -> ItemCell:
	var cell: ItemCell = ItemCell.create(entry, side)
	var key: String = cell.key
	cell.set_selected(key == selected_key)
	cell.set_picked(picked.has(key))
	cell.set_locked(locked.has(key))
	if tags.has(key):
		var tag: Array = tags[key]
		cell.set_tag(str(tag[0]), int(tag[1]))
	cell.pressed.connect(func() -> void: item_pressed.emit(key))
	cell.cell_hovered.connect(_on_cell_hovered)
	cell.cell_unhovered.connect(_on_cell_unhovered)
	_cells[key] = cell
	return cell


# 行：マス ／ 名前・添え書き ／ 主な値 ／ ほかの値 ／ 着けている人。
func _make_row(entry: Dictionary) -> LedgerRow:
	var key: String = ItemView.key_of(entry)
	var row: LedgerRow = LedgerRow.new()
	row.name = "Row_" + key
	row.selected = key == selected_key
	row.disabled = locked.has(key) and not picked.has(key)
	row.pressed.connect(func() -> void: item_pressed.emit(key))
	if GameManager.is_item_new(ItemView.item_id_of(entry)):
		RibbonMark.attach(row)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(line)
	var cell: ItemCell = _make_cell(entry, get_theme_constant(&"row_icon", THEME_TYPE))
	# ⚠ 行の中のマスは押下を行に渡す（⚠ 押すのは行）。⚠ 触れると出る札はマスのまま。
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(cell)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = ItemView.name_text(entry)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	var sub: Label = Label.new()
	sub.name = "SubLabel"
	sub.theme_type_variation = &"CaptionLabel"
	sub.text = ItemView.sub_text(entry) if ItemView.is_instance(entry) else (tr("ui_belongings_owned") % maxi(0, ItemView.count_of(entry)))
	column.add_child(sub)

	var main: Label = Label.new()
	main.name = "MainLabel"
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main.custom_minimum_size.x = float(get_theme_constant(&"row_main", THEME_TYPE))
	var main_key: String = ItemView.main_stat_key(entry)
	main.text = ("%s %s" % [tr("ui_training_stat_" + main_key), ItemView.main_value_text(entry)]) if main_key != "" else ""
	line.add_child(main)
	if ItemView.is_instance(entry):
		var other: Label = Label.new()
		other.name = "OtherLabel"
		other.theme_type_variation = &"CaptionLabel"
		other.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		other.custom_minimum_size.x = float(get_theme_constant(&"row_other", THEME_TYPE))
		other.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		other.text = ItemView.other_stats_text(entry)
		line.add_child(other)
		var owner: Label = Label.new()
		owner.name = "OwnerLabel"
		owner.theme_type_variation = &"CaptionLabel"
		owner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		owner.custom_minimum_size.x = float(get_theme_constant(&"row_owner", THEME_TYPE))
		owner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		owner.text = ItemView.owner_name(entry)
		line.add_child(owner)
	return row


# --- 触れると出る札 ---

func _on_cell_hovered(cell: ItemCell) -> void:
	if tip == null or not is_instance_valid(tip):
		return
	var compare: String = str(compare_with.call(cell.entry)) if compare_with.is_valid() else ""
	tip.show_entry(cell.entry, compare)


func _on_cell_unhovered(_cell: ItemCell) -> void:
	if tip != null and is_instance_valid(tip):
		tip.hide_tip()
