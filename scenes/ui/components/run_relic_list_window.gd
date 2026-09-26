class_name RunRelicListWindow
extends CanvasLayer

# 持っているレリックをまとめて見る窓（2026-09-26・人間「⚠ レリックはレリックをまとめて見れるようにしたい」）。
#
# ⚠ 開く口は2つ：⚠ ヘッダーのレリック（マス）を押す ／ ⚠ 右上のメニューの「レリックを見る」（人間の選択）。
# ⚠ 中身は紙1枚に `RelicCard` を並べる（⚠ 見るだけ・押しても何も起きない）。⚠ 1人用は「装備中：誰」。
# ⚠ 窓なので**閉じるは下**（`NAV-2`）。⚠ 暗幕の外を押しても閉じる。⚠ 後ろは押せない。
# ⚠ 層は窓と同じ 200（`ModalDialog` と同じ・`RS-4`）。⚠ 値（幅・列・暗幕）は Theme の `RunRelicList` 型。
# ⚠ 文字はレリックの語（`ui_relic_list_*`）と共通の語（`ui_common_close`）だけ。⚠ `RUN-5`：`ui_run_*` に寄せない。
# ⚠ シナリオと難ダンジョンの両方で使うので scenes/ui/components/（AGENTS.md）。

signal closed

const THEME_TYPE: StringName = &"RunRelicList"
const WINDOW_LAYER: int = 200


static func open(host: Node, kind: String) -> RunRelicListWindow:
	var window: RunRelicListWindow = RunRelicListWindow.new()
	window.name = "RelicListWindow"
	window._kind = kind
	host.add_child(window)
	return window


var _kind: String = ""


func _ready() -> void:
	layer = WINDOW_LAYER
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = root.get_theme_color(&"dim", THEME_TYPE)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	sheet.custom_minimum_size.x = float(root.get_theme_constant(&"width", THEME_TYPE))
	center.add_child(sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"SectionStack"
	sheet.add_child(column)

	var entries: Array = GameManager.get_run_relic_slot_entries(_kind)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_relic_list_title"
	heading.right_text = str(entries.size())
	column.add_child(heading)

	if entries.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = &"CaptionLabel"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.text = tr("ui_relic_list_empty")
		column.add_child(none)
	else:
		var grid: GridContainer = GridContainer.new()
		grid.name = "Cards"
		grid.columns = root.get_theme_constant(&"columns", THEME_TYPE)
		grid.theme_type_variation = &"RelicListGrid"
		column.add_child(grid)
		for index: int in entries.size():
			var entry: Dictionary = entries[index]
			var card: RelicCard = RelicCard.create(
				str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")), index,
				str(entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, "")), false
			)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)

	var close: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_common_close")
	close.name = "CloseButton"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(_close)
	column.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _on_dim_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_close()


# ⚠ `remove_child()` してから捨てる（⚠ await を持たない・AGENTS.md）。
func _close() -> void:
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	closed.emit()
	queue_free()
