# res://scenes/guild/part_merge_panel.gd
# 装飾を合わせる右の欄（2026-10-18・回UI-1018-2c・人間「⚠ ２う」・決定 `BS-23`・手本 `06_belongings_part_grid.png` の「3つ合わせて上の等級にする」）。
#
# ⚠ 「3つ合わせる」／ 選んだ材料の枠（⚠ 押すと1つ外す）／ できるもの（1つ上の段・押して選ぶ）／ 「合わせる」「やめる」。
# ⚠ 材料を選ぶのは左の一覧（⚠ 持ち物の画面）。⚠ ここは見せて、押されたことを返すだけ。
# ⚠ 判定は `GameManager.get_part_merge_reject_reason()` の1本（⚠ ここで数え直さない）。
# ⚠ 持ち物でしか使わないので scenes/guild/（AGENTS.md）。

class_name PartMergePanel
extends VBoxContainer

signal pick_removed(index: int)
signal target_chosen(item_id: String)
signal confirm_pressed
signal cancel_pressed

var _picks: Array[String] = []
var _target: String = ""


static func create(picks: Array[String], target: String) -> PartMergePanel:
	var panel: PartMergePanel = PartMergePanel.new()
	panel.name = "PartMergePanel"
	panel._picks = picks
	panel._target = target
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return panel


func _ready() -> void:
	var need: int = GameManager.get_part_merge_count()
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	heading.title_text = tr("ui_part_merge_title") % need
	heading.right_text = "%d / %d" % [_picks.size(), need]
	add_child(heading)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_part_merge_hint")
	add_child(hint)

	# 材料の枠（⚠ 空きは薄い枠）。
	var slots: HBoxContainer = HBoxContainer.new()
	slots.name = "PickSlots"
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(slots)
	var side: int = get_theme_constant(&"head_icon", &"Belongings")
	for i: int in range(need):
		if i < _picks.size():
			var cell: ItemCell = ItemCell.create({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
				GameManager.SLOT_ENTRY_ITEM_ID: _picks[i],
			}, side)
			cell.name = "Pick_%d" % i
			cell.pressed.connect(func() -> void: pick_removed.emit(i))
			slots.add_child(cell)
		else:
			var empty: PanelContainer = PanelContainer.new()
			empty.name = "PickEmpty_%d" % i
			empty.theme_type_variation = &"MergeSlotEmptyPanel"
			empty.custom_minimum_size = Vector2(side, side)
			slots.add_child(empty)

	# できるもの（⚠ 材料の段が決まってから）。
	var tier: int = 0
	if not _picks.is_empty():
		tier = int(GameManager.get_part_definition(_picks[0]).get(GameManager.ITEM_MASTER_PART_TIER, 0))
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_part_merge_targets") % (tier + 1) if tier > 0 else tr("ui_part_merge_targets_wait")
	add_child(caption)
	if tier > 0:
		var targets: HFlowContainer = HFlowContainer.new()
		targets.name = "Targets"
		targets.theme_type_variation = &"ItemCellGrid"
		add_child(targets)
		for item_id: String in GameManager.get_part_merge_targets(tier):
			var cell: ItemCell = ItemCell.create({
				GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
				GameManager.SLOT_ENTRY_ITEM_ID: item_id,
			}, Balance.icon.icon_size_px if Balance.icon != null else 40)
			cell.name = "Target_" + item_id
			cell.tooltip_text = "%s  %s" % [ItemView.name_text({GameManager.SLOT_ENTRY_ITEM_ID: item_id}), BelongingsDetail.part_range_text(item_id)]
			cell.set_selected(item_id == _target)
			cell.pressed.connect(func() -> void: target_chosen.emit(item_id))
			targets.add_child(cell)
	if _target != "":
		var chosen: Label = Label.new()
		chosen.name = "TargetLabel"
		chosen.theme_type_variation = &"GainLabel"
		chosen.text = tr("ui_part_merge_chosen") % [ItemView.name_text({GameManager.SLOT_ENTRY_ITEM_ID: _target}), BelongingsDetail.part_range_text(_target)]
		add_child(chosen)

	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(gap)
	var go: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_part_merge_go")
	go.name = "MergeGoButton"
	go.disabled = GameManager.get_part_merge_reject_reason(_picks, _target) != ""
	go.pressed.connect(func() -> void: confirm_pressed.emit())
	add_child(go)
	var cancel: Button = UiButton.create_paper_choice("ui_common_cancel")
	cancel.name = "MergeCancelButton"
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	add_child(cancel)


# ⚠ 合わせる（⚠ 確かめの窓の「はい」で）。⚠ 合わせたら true。
static func run(host: Node, picks: Array[String], target: String) -> bool:
	var yes: bool = await Modal.confirm(host, "ui_part_merge_confirm", [picks.size(), ItemView.name_text({GameManager.SLOT_ENTRY_ITEM_ID: target})])
	if not yes:
		return false
	return GameManager.merge_parts(picks, target)
