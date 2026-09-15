class_name InventoryWindow
extends Window

# インベントリの窓（2026-09-15）。
#
# ⚠⚠ いつも OS の別窓（force_native）で出す（人間の決定「別窓で」「（ゲームの中は）消す」）。
#   ⚠ ゲームの中（埋め込み）と設定で切り替えて比べた結果。⚠ 設定の項目ごと消した。
#   ⚠ ヘッドレスは OS の窓を作れないので、⚠ そこでだけ埋め込みになる（⚠ 検査はその形で回る）。
# ⚠⚠ force_native は「隠している間」にしか立てられない（⚠ 表示中に立てると赤・前回の実測）。
#   ⚠ Window.new() は表示中扱いなので、⚠ 先に visible を落とす。
# ⚠ 中身は倉庫の持ち物と同じ並び（GameManager.get_inventory_page_entries()）。
#   ⚠ ここで並びを組み立てない。
# ⚠ ドラッグは送るだけ（⚠ 装備マスが受ける）。⚠ 窓は別のマス目から受けない。
# ⚠ インベントリ専用のフォルダ scenes/inventory/（人間の決定 2026-09-15）。⚠ `.tscn` を持たない。

# ⚠ マス目の組の名前（2026-09-15）。⚠ 装備マスがこの組から受ける。
const DRAG_GROUP: String = "inventory"
const MARGIN_VARIATION: StringName = &"DialogMargin"
const PANEL_VARIATION: StringName = &"SidePanel"

var grid: ItemGrid = null
var _page: int = 0
var _page_label: Label = null
var _prev_button: UiButton = null
var _next_button: UiButton = null


static func create() -> InventoryWindow:
	var window: InventoryWindow = InventoryWindow.new()
	window.name = "InventoryWindow"
	window.visible = false
	window.force_native = true
	return window


func _ready() -> void:
	title = tr("ui_warehouse_tab_inventory")
	# ⚠ 窓の大きさは中身の最小サイズに合わせる（⚠ 数字をここに書かない）。
	wrap_controls = true
	close_requested.connect(hide)
	_build()
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	_rebuild()


func _build() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = PANEL_VARIATION
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.theme_type_variation = MARGIN_VARIATION
	panel.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	margin.add_child(layout)

	grid = ItemGrid.new()
	grid.name = "InventoryGrid"
	grid.columns = GameManager.get_inventory_columns()
	grid.drag_group = DRAG_GROUP
	layout.add_child(grid)

	var page_row: HBoxContainer = HBoxContainer.new()
	page_row.name = "PageRow"
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(page_row)

	_prev_button = UiButton.create(UiButton.Variant.SECONDARY, "ui_warehouse_page_prev")
	_prev_button.name = "PrevPageButton"
	_prev_button.pressed.connect(_on_prev_page_pressed)
	page_row.add_child(_prev_button)

	_page_label = Label.new()
	_page_label.name = "PageLabel"
	page_row.add_child(_page_label)

	_next_button = UiButton.create(UiButton.Variant.SECONDARY, "ui_warehouse_page_next")
	_next_button.name = "NextPageButton"
	_next_button.pressed.connect(_on_next_page_pressed)
	page_row.add_child(_next_button)


# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ `ItemGrid.rebuild()` がその形。
func _rebuild() -> void:
	var page_count: int = GameManager.get_inventory_page_count()
	_page = clampi(_page, 0, page_count - 1)
	grid.rebuild(GameManager.get_inventory_page_entries(_page), GameManager.get_inventory_slots_per_page())
	_page_label.text = "%d / %d" % [_page + 1, page_count]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= page_count - 1


func _on_prev_page_pressed() -> void:
	_page -= 1
	_rebuild()


func _on_next_page_pressed() -> void:
	_page += 1
	_rebuild()


func _on_inventory_changed(_item_id: String) -> void:
	_rebuild()


func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild()


# ⚠ 装備するとマスから外れる（決定7）。⚠ 着脱はこのシグナルしか飛ばない。
func _on_character_growth_changed(_character_id: String) -> void:
	_rebuild()
