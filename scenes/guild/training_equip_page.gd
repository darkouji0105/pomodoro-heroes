class_name TrainingEquipPage
extends VBoxContainer

# 育成のタブ「装備」（2026-09-27・回UI-組 育成・手本 Equip・人間「⚠ 2あ」）。
#
# ⚠ 左：部位の列（⚠ 頭・上半身・下半身・武器・アクセサリー。⚠ 押すとその部位の候補を右に出す）。
# ⚠ 右：その部位の個体の一覧（⚠ マス・名前・値・装飾の枠 ◆◇ ／ ⚠ 他の人が着けていればその人）。
# ⚠ 下：「鍛冶場で鍛える」＋「◯を着ける」（⚠ 選んだのが着けている品なら「外す」）。
# ⚠⚠ 鍛える・装飾を刺す・外す・分解は、⚠ **前の装備画面（`equipment_screen`）を仮の鍛冶場として開く**。
#   ⚠ 鍛冶場は「仕組みの回①」で作る。⚠ それまで機能を減らさないためのつなぎ。
# ⚠ 着けられるかの判定は `get_equip_reject_reason()` の1本（⚠ ここで部位や持ち主を見直さない）。
# ⚠ 購読：character_growth_changed（着脱）／ equipment_instances_changed（鍛えた・増えた）。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。

signal forge_requested

var _character_id: String = ""
var _selected_slot: String = GameStateKeys.EQUIP_WEAPON
# ⚠ 右の一覧で選んでいる個体。⚠ 空なら「いま着けている品」を選んだものとして扱う。
var _selected_instance: String = ""


func setup(character_id: String) -> void:
	_character_id = character_id
	_selected_instance = ""
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _character_id == "":
		return
	var candidates: Array = _candidates_of(_selected_slot)
	var equipped_id: String = GameManager.get_equipped_instance_id(_character_id, _selected_slot)
	if _selected_instance == "" or not _has_instance(candidates, _selected_instance):
		_selected_instance = equipped_id

	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_training_equip_heading"
	heading.right_text = tr("ui_training_equip_count") % [tr("ui_equipment_slot_" + _selected_slot), candidates.size()]
	add_child(heading)

	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"WideRow"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	var slots: VBoxContainer = VBoxContainer.new()
	slots.name = "SlotColumn"
	slots.custom_minimum_size.x = float(get_theme_constant(&"dossier_width", &"Training")) * 0.6
	body.add_child(slots)
	for row: Variant in GameManager.get_equipment_slot_entries(_character_id):
		slots.add_child(_create_slot_row(row as Dictionary))
	body.add_child(VSeparator.new())

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CandidateScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Candidates"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if candidates.is_empty():
		list.add_child(EmptyState.create("ui_training_equip_none"))
	for view: Variant in candidates:
		list.add_child(_create_candidate_row(view as Dictionary))
	right.add_child(_build_footer(equipped_id))


# 部位の1行。⚠ 押すとその部位を選ぶ（⚠ 着けている品を右で選んだ状態にする）。
func _create_slot_row(row_data: Dictionary) -> LedgerRow:
	var slot: String = str(row_data.get(GameManager.SLOT_ENTRY_EQUIP_SLOT, ""))
	var entry: Dictionary = row_data.get(GameManager.SLOT_ENTRY_ENTRY, {})
	var row: LedgerRow = LedgerRow.new()
	row.name = "Slot_" + slot
	row.selected = slot == _selected_slot
	row.pressed.connect(_on_slot_pressed.bind(slot))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	line.add_child(_item_icon(entry))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var slot_label: Label = Label.new()
	slot_label.theme_type_variation = &"CaptionLabel"
	slot_label.text = tr("ui_equipment_slot_" + slot)
	column.add_child(slot_label)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	name_label.text = tr(GameManager.item_name_key(item_id)) if item_id != "" else tr("ui_training_equip_empty")
	column.add_child(name_label)
	return row


# 右の1行（個体1つ）。⚠ 他の人が着けている品は押せるが「着ける」は押せない（⚠ 判定は GameManager）。
func _create_candidate_row(view: Dictionary) -> LedgerRow:
	var instance_id: String = str(view.get(GameManager.INSTANCE_VIEW_ID, ""))
	var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var owner: String = str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
	var row: LedgerRow = LedgerRow.new()
	row.name = "Candidate_" + instance_id
	row.selected = instance_id == _selected_instance
	row.pressed.connect(_on_candidate_pressed.bind(instance_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	line.add_child(_item_icon({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: item_id,
		GameManager.SLOT_ENTRY_INSTANCE_ID: instance_id,
		GameManager.SLOT_ENTRY_GRADE: int(view.get(GameStateKeys.INSTANCE_GRADE, 1)),
		GameManager.SLOT_ENTRY_EQUIPPED_BY: owner,
	}))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr(GameManager.item_name_key(item_id))
	column.add_child(name_label)
	var stats: Label = Label.new()
	stats.name = "StatsLabel"
	stats.theme_type_variation = &"SmallLabel"
	stats.text = _stats_text(view.get(GameManager.INSTANCE_VIEW_STATS, {}) as Dictionary) + _parts_text(instance_id)
	column.add_child(stats)
	if owner != "":
		var owner_label: Label = Label.new()
		owner_label.name = "OwnerLabel"
		owner_label.theme_type_variation = &"AccentLabel" if owner == _character_id else &"CaptionLabel"
		if owner == _character_id:
			owner_label.text = tr("ui_training_equip_wearing")
		else:
			var char_data: Dictionary = MasterDataLoader.get_character(owner)
			owner_label.text = tr(str(char_data.get("name_key", owner)))
		owner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(owner_label)
	return row


func _build_footer(equipped_id: String) -> HBoxContainer:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	var forge: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_training_equip_forge")
	forge.name = "ForgeButton"
	forge.pressed.connect(func() -> void: forge_requested.emit())
	footer.add_child(forge)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	if _selected_instance != "" and _selected_instance == equipped_id:
		var off: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_equipment_unequip")
		off.name = "UnequipButton"
		off.pressed.connect(_on_unequip_pressed)
		footer.add_child(off)
		return footer
	var wear: UiButton = UiButton.create(UiButton.Variant.PRIMARY)
	wear.name = "EquipButton"
	var item_id: String = ""
	if _selected_instance != "":
		item_id = str(GameManager.get_equipment_instance(_selected_instance).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	wear.text = tr("ui_training_equip_wear") % tr(GameManager.item_name_key(item_id)) if item_id != "" else tr("ui_training_equip_pick")
	wear.disabled = _selected_instance == "" or GameManager.get_equip_reject_reason(
		_character_id, _selected_slot, _selected_instance
	) != ""
	wear.pressed.connect(_on_equip_pressed)
	footer.add_child(wear)
	return footer


# その部位に着けられる個体（⚠ 他の人が着けている品も並べる＝手本）。⚠ 並びは `get_owned_instances()` のまま。
func _candidates_of(slot: String) -> Array:
	var result: Array = []
	for entry: Variant in GameManager.get_owned_instances():
		var view: Dictionary = entry
		var definition: Dictionary = MasterDataLoader.get_item(str(view.get(GameStateKeys.INSTANCE_ITEM_ID, "")))
		if str(definition.get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")) == slot:
			result.append(view)
	return result


func _has_instance(candidates: Array, instance_id: String) -> bool:
	for view: Variant in candidates:
		if str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
			return true
	return false


# ⚠ マス（等級の札つき）。⚠ 押す・つまむは行が受ける（⚠ マスは押下を食べない）。
func _item_icon(entry: Dictionary) -> ItemSlot:
	var icon: ItemSlot = ItemSlot.create(entry)
	var side: float = float(get_theme_constant(&"item_icon", &"Training"))
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


# 「HP +160」。⚠ 0 の軸は出さない。
func _stats_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int(stats.get(stat_key, 0))
		if value == 0:
			continue
		var shown: String = ("%d%%" % value) if GameManager.is_percent_stat(stat_key) else str(value)
		parts.append("%s +%s" % [tr("ui_training_stat_" + stat_key), shown])
	return "  ".join(parts)


# 装飾の枠（⚠ 刺さっている＝◆ ／ 空き＝◇・手本）。⚠ 開いている枠だけ（`get_part_entries()`）。
func _parts_text(instance_id: String) -> String:
	var marks: String = ""
	for view: Variant in GameManager.get_part_entries(instance_id):
		var entry: Variant = (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
		marks += tr("ui_training_equip_part_filled") if entry is Dictionary else tr("ui_training_equip_part_open")
	return "  " + marks if marks != "" else ""


func _on_slot_pressed(slot: String) -> void:
	if slot == _selected_slot:
		return
	_selected_slot = slot
	_selected_instance = ""
	_rebuild()


func _on_candidate_pressed(instance_id: String) -> void:
	if instance_id == _selected_instance:
		return
	_selected_instance = instance_id
	_rebuild()


func _on_equip_pressed() -> void:
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	GameManager.equip_instance(_character_id, _selected_slot, _selected_instance)


func _on_unequip_pressed() -> void:
	GameManager.unequip_instance(_character_id, _selected_slot)


func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()


func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild()
