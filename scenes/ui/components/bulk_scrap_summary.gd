# res://scenes/ui/components/bulk_scrap_summary.gd
# 一括分解の右の欄（2026-10-18・回UI-1018-1・絵 `06_belongings_scrap.png` の右の紙）。
#
# ⚠ 「一括分解　選んだ N 個」／ 選んだ品のマス ／ 戻ってくる素材（＋遺物に入る点）／ 「選んだ N 個を分解する」「やめる」。
# ⚠ 分解は `run()` の1本：⚠ 確かめの窓 → `GameManager.dismantle_equipment_bulk()`（⚠ 判定はあちら）。
# ⚠ 持ち物・鍛冶場で使う（components/）。⚠ 紙の中に置く（⚠ 字は紙のテーマで墨）。

class_name BulkScrapSummary
extends VBoxContainer

signal confirm_pressed
signal cancel_pressed

var _ids: Array[String] = []


static func create(ids: Array[String]) -> BulkScrapSummary:
	var summary: BulkScrapSummary = BulkScrapSummary.new()
	summary.name = "BulkScrapSummary"
	summary._ids = ids
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return summary


func _ready() -> void:
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	heading.title_key = "ui_bulk_scrap_title"
	heading.right_text = tr("ui_bulk_scrap_count") % _ids.size()
	add_child(heading)

	var cells: HFlowContainer = HFlowContainer.new()
	cells.name = "PickedCells"
	add_child(cells)
	var side: int = Balance.icon.icon_size_px if Balance.icon != null else 40
	for instance_id: String in _ids:
		var cell: ItemCell = ItemCell.create(ItemView.instance_entry(instance_id), side)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cells.add_child(cell)

	var refund: Dictionary = GameManager.get_bulk_dismantle_refund(_ids)
	for material_id: Variant in refund:
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "Refund_" + str(material_id)
		add_child(line)
		var caption: Label = Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = tr("ui_bulk_scrap_refund") % tr("ui_res_" + str(material_id))
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(caption)
		var amount: Label = Label.new()
		amount.name = "Amount"
		amount.theme_type_variation = &"GainLabel"
		amount.text = "+%d" % int(refund[material_id])
		line.add_child(amount)
	var points: int = 0
	var stars: int = 0
	var high: int = 0
	for instance_id: String in _ids:
		points += int(GameManager.get_offer_preview(instance_id).get(GameManager.OFFER_POINTS, 0))
		var entry: Dictionary = ItemView.instance_entry(instance_id)
		if ItemView.is_special(entry):
			stars += 1
		if int(entry.get(GameManager.SLOT_ENTRY_GRADE, 1)) >= GameManager.get_guild_relic_grade_min():
			high += 1
	if _ids.is_empty():
		var hint: Label = Label.new()
		hint.name = "PickHint"
		hint.theme_type_variation = &"CaptionLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = tr("ui_bulk_scrap_empty_hint")
		add_child(hint)
	# ⚠ 手本の注意（⚠ ★つきが入っている ／ 等級5以上が入っている）。
	if stars > 0:
		var star_note: Label = Label.new()
		star_note.name = "StarNote"
		star_note.theme_type_variation = &"ErrorLabel"
		star_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		star_note.text = tr("ui_bulk_scrap_star_note") % stars
		add_child(star_note)
	if high > 0:
		var high_note: Label = Label.new()
		high_note.name = "HighNote"
		high_note.theme_type_variation = &"CaptionLabel"
		high_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		high_note.text = tr("ui_bulk_scrap_high_note") % [GameManager.get_guild_relic_grade_min(), high]
		add_child(high_note)
	if points > 0:
		var relic: Label = Label.new()
		relic.name = "RelicPoints"
		relic.theme_type_variation = &"CaptionLabel"
		relic.text = tr("ui_bulk_scrap_relic") % points
		add_child(relic)

	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(gap)
	var go: UiButton = UiButton.create(UiButton.Variant.DANGER, "")
	go.name = "ScrapGoButton"
	go.text = tr("ui_bulk_scrap_go") % _ids.size()
	go.disabled = _ids.is_empty()
	go.pressed.connect(func() -> void: confirm_pressed.emit())
	add_child(go)
	var cancel: Button = UiButton.create_paper_choice("ui_common_cancel")
	cancel.name = "ScrapCancelButton"
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	add_child(cancel)


# ⚠ 分解する（⚠ 確かめの窓の「はい」で）。⚠ 分解したら true。
static func run(host: Node, ids: Array[String]) -> bool:
	if ids.is_empty():
		return false
	var yes: bool = await Modal.confirm(host, "ui_bulk_scrap_confirm", [ids.size()])
	if not yes:
		return false
	return GameManager.dismantle_equipment_bulk(ids)
