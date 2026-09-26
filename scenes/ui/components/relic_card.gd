class_name RelicCard
extends Control

# レリックのカード（2026-09-26・回UI-4 レリック・人間「⚠ もっとカードっぽく傾けてほしい」）。
#
# ⚠ 紙（`PaperSheet`）に 絵 ／ 名前（明朝）／ 効き目 ／ 罫 ／ 誰に効くか（⚠ 付いている人）を書く。
# ⚠⚠ **傾ける**。⚠ `Container` は子の回転を並べるたびに 0 に戻すので、⚠ この部品は**並べない器**
#   （素の `Control`）で、⚠ 中の紙を自分で広げて回す。⚠ 器の最小の大きさは紙の最小に合わせる。
#   ⚠ 傾きは Theme の `PaperPanel` の `tilt_<n>`（⚠ 手本 `paper_tilt_deg`）を並びの番号で順に使う。
# ⚠ 使う画面：レリック選択（⚠ 押して選ぶ）／ レリックをまとめて見る窓（⚠ 見るだけ）。
# ⚠ `.new()` ではなく `RelicCard.create()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

signal pressed

const TILT_COUNT: int = 3

var relic_id: String = ""
var _sheet: PaperSheet = null
var _stamp: Stamp = null
var _tilt_index: int = 0


static func create(p_relic_id: String, index: int, owner_id: String = "", pressable: bool = false) -> RelicCard:
	var card: RelicCard = RelicCard.new()
	card.name = "Card_" + p_relic_id
	card.relic_id = p_relic_id
	card._build(index, owner_id, pressable)
	return card


func _build(index: int, owner_id: String, pressable: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_sheet = PaperSheet.new()
	_sheet.name = "Sheet"
	add_child(_sheet)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_sheet.add_child(column)

	# ⚠ 「選んだ」の判。⚠ 選ぶまで透明（⚠ 並びが動かない）。⚠ 見るだけのカードでは出さない。
	_stamp = Stamp.new()
	_stamp.label_key = "ui_stamp_chosen"
	_stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	_stamp.modulate.a = 0.0
	_stamp.visible = pressable
	column.add_child(_stamp)

	var icon: ItemGrid = ItemGrid.new()
	icon.name = "Icon"
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	icon.rebuild([GameManager.make_relic_slot_entry(relic_id, owner_id)], 1)

	var relic: Dictionary = MasterDataLoader.get_relic(relic_id)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tr(str(relic.get("name_key", relic_id)))
	column.add_child(name_label)

	# ⚠ 効き目は `ui_desc_<id>`（⚠ 効果の中身をここで文章にしない＝`ItemDetail._show_relic()` と同じ）。
	var desc: Label = Label.new()
	desc.theme_type_variation = &"AccentLabel"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = tr("ui_desc_" + relic_id)
	column.add_child(desc)

	column.add_child(HSeparator.new())
	var scope: Label = Label.new()
	scope.theme_type_variation = &"CaptionLabel"
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if owner_id != "":
		var char_data: Dictionary = MasterDataLoader.get_character(owner_id)
		scope.text = tr("ui_equipment_equipped_by") % tr(str(char_data.get("name_key", owner_id)))
	else:
		scope.text = tr("ui_relic_scope_single" if GameManager.is_single_relic(relic_id) else "ui_relic_scope_party")
	column.add_child(scope)

	if pressable:
		# ⚠ 面ぜんぶを押せる（⚠ 中身を足し終わってから敷く＝`attach_hit` の決まり）。⚠ 当たりも一緒に傾く。
		var _hit: Button = UiButton.attach_hit(_sheet, func() -> void: pressed.emit())

	_tilt_index = index % TILT_COUNT
	_sheet.minimum_size_changed.connect(_fit)
	resized.connect(_fit)



func set_chosen(chosen: bool) -> void:
	_sheet.theme_type_variation = &"PaperPanelChosen" if chosen else &"PaperPanel"
	_stamp.modulate.a = 1.0 if chosen else 0.0


func _ready() -> void:
	_fit()


# ⚠ 紙を器いっぱいに広げ、⚠ 真ん中を軸に傾ける。⚠ 器の最小は紙の最小に合わせる（⚠ 並べる側が幅を決める）。
func _fit() -> void:
	if _sheet == null:
		return
	custom_minimum_size = _sheet.get_combined_minimum_size()
	_sheet.position = Vector2.ZERO
	_sheet.size = size
	_sheet.pivot_offset = size * 0.5
	if is_inside_tree():
		var tenths: int = get_theme_constant(StringName("tilt_%d" % _tilt_index), &"PaperPanel")
		_sheet.rotation = deg_to_rad(float(tenths) * 0.1)
