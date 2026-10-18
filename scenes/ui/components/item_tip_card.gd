# res://scenes/ui/components/item_tip_card.gd
# 触れると出る詳しい札（2026-10-18・回UI-1018-1・手本 `mocks/Belongings.html` の `.tipcard`・絵 `02_training_eq_hover.png`）。
#
# ⚠ マスに触れているあいだ、⚠ マウスの右下に紙の札を出す（⚠ 外れたら消す）。⚠ 押すのはマス（⚠ 札は押せない）。
# ⚠ 中身：絵と名前・添え書き ／ 主な値（⚠ 比べる相手があれば増分）／ ほかの値 ／ ★の札 ／ 装飾の枠 ◆◇ ／ 比べている相手。
# ⚠ 文字は `ItemView` の1か所（⚠ マス・行と同じもの）。
# ⚠ 前の `ItemDetailPopup`（⚠ 宝箱・鞄・UI テストで使う）は触っていない。⚠ こちらは品の一覧の新しい部品だけが使う。
# ⚠ 全部マウスを通す（⚠ 止めると、指の下に札が入ってマスから外れたことに気づけない）。

class_name ItemTipCard
extends CanvasLayer

const THEME_TYPE: StringName = &"ItemCell"
# ⚠ `ModalDialog` は 200。⚠ 確かめの窓が必ず上に出るように下へ。
const LAYER_INDEX: int = 190

var _root: Control = null
var _panel: PanelContainer = null
var _body: VBoxContainer = null
var _entry: Dictionary = {}


static func attach(host: Node) -> ItemTipCard:
	var card: ItemTipCard = ItemTipCard.new()
	card.name = "ItemTipCard"
	host.add_child(card)
	return card


func _init() -> void:
	layer = LAYER_INDEX
	visible = false
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.theme = PaperSheet.PAPER_THEME
	_panel.theme_type_variation = &"ItemTipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.theme_type_variation = &"TightList"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_body)


func _ready() -> void:
	_panel.custom_minimum_size.x = float(_panel.get_theme_constant(&"tip_width", THEME_TYPE))


func is_open() -> bool:
	return visible


func get_entry() -> Dictionary:
	return _entry


# ⚠ `compare_instance_id`：比べる相手（⚠ 育成で「いま着けている品」など）。⚠ 空なら比べない。
func show_entry(entry: Dictionary, compare_instance_id: String = "") -> void:
	if entry.is_empty() or ItemView.item_id_of(entry) == "":
		hide_tip()
		return
	_entry = entry
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_build(entry, compare_instance_id)
	_set_mouse_ignore(_body)
	visible = true
	_panel.reset_size()
	_place()


func hide_tip() -> void:
	visible = false
	_entry = {}


func _process(_delta: float) -> void:
	if visible:
		_place()


# ⚠ マウスの右下。⚠ はみ出すなら左・上へ返す。
func _place() -> void:
	var viewport: Viewport = _root.get_viewport()
	if viewport == null:
		return
	var mouse: Vector2 = viewport.get_mouse_position()
	var offset: float = float(_panel.get_theme_constant(&"tip_offset", THEME_TYPE))
	var screen: Vector2 = viewport.get_visible_rect().size
	var card: Vector2 = _panel.get_combined_minimum_size()
	var at: Vector2 = mouse + Vector2(offset, offset)
	if at.x + card.x > screen.x:
		at.x = mouse.x - offset - card.x
	if at.y + card.y > screen.y:
		at.y = maxf(0.0, screen.y - card.y)
	_panel.position = at
	_panel.size = card


func _build(entry: Dictionary, compare_instance_id: String) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	_body.add_child(head)
	head.add_child(ItemCell.create(entry, Balance.icon.icon_size_px if Balance.icon != null else 40))
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(titles)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = ItemView.name_text(entry)
	titles.add_child(name_label)
	var sub: Label = Label.new()
	sub.name = "SubLabel"
	sub.theme_type_variation = &"CaptionLabel"
	sub.text = ItemView.sub_text(entry)
	titles.add_child(sub)
	_body.add_child(HSeparator.new())

	var main_key: String = ItemView.main_stat_key(entry)
	if main_key != "":
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "MainLine"
		_body.add_child(line)
		var caption: Label = Label.new()
		caption.text = tr("ui_training_stat_" + main_key)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(caption)
		var value: Label = Label.new()
		value.name = "MainValue"
		value.theme_type_variation = &"DossierLevelLabel"
		value.text = ItemView.main_value_text(entry)
		line.add_child(value)
		if ItemView.is_instance(entry) and compare_instance_id != "" and compare_instance_id != ItemView.instance_id_of(entry):
			var mine: int = int(ItemView.stats_of(entry).get(main_key, 0))
			var theirs: int = int(GameManager.get_instance_stats(compare_instance_id).get(main_key, 0))
			var delta: Label = Label.new()
			delta.name = "DeltaLabel"
			delta.theme_type_variation = &"GainLabel" if mine >= theirs else &"ErrorLabel"
			delta.text = "(%s)" % BelongingsDetail.stat_text(main_key, mine - theirs)
			delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(delta)
	var others: String = ItemView.other_stats_text(entry)
	if others != "":
		_body.add_child(_pair("OtherLine", tr("ui_item_tip_other"), others))
	if not ItemView.is_instance(entry) and ItemView.count_of(entry) >= 0:
		_body.add_child(_pair("CountLine", tr("ui_item_tip_owned"), tr("ui_item_count_mark") % ItemView.count_of(entry)))

	if ItemView.is_instance(entry):
		var card: SpecialEffectCard = SpecialEffectCard.create_for_item(ItemView.item_id_of(entry))
		if card != null:
			_body.add_child(card)
		var marks: String = ""
		for view: Variant in GameManager.get_part_entries(ItemView.instance_id_of(entry)):
			marks += tr("ui_training_equip_part_filled") if (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null) is Dictionary else tr("ui_training_equip_part_open")
		if marks != "":
			_body.add_child(_pair("PartLine", tr("ui_item_tip_parts"), marks))
		var owner: String = ItemView.owner_name(entry)
		if owner != "":
			_body.add_child(_pair("OwnerLine", tr("ui_item_tip_owner"), owner))
		if compare_instance_id != "" and compare_instance_id != ItemView.instance_id_of(entry):
			_body.add_child(HSeparator.new())
			var compare: Label = Label.new()
			compare.name = "CompareLabel"
			compare.theme_type_variation = &"CaptionLabel"
			compare.text = tr("ui_item_tip_compare") % ItemView.name_text(ItemView.instance_entry(compare_instance_id))
			_body.add_child(compare)


func _pair(row_name: String, caption_text: String, value_text: String) -> HBoxContainer:
	var line: HBoxContainer = HBoxContainer.new()
	line.name = row_name
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "Value"
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.custom_minimum_size.x = float(_panel.get_theme_constant(&"row_main", THEME_TYPE))
	line.add_child(value)
	return line


func _set_mouse_ignore(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_set_mouse_ignore(child)
