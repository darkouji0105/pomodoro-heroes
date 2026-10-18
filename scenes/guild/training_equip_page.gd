class_name TrainingEquipPage
extends VBoxContainer

# 育成のタブ「装備」（2026-09-27・回UI-組 育成・手本 Equip・人間「⚠ 2あ」）。
#
# ⚠ 左：部位の列（⚠ 頭・上半身・下半身・武器・アクセサリー。⚠ 押すとその部位の候補を右に出す）。
# ⚠ 右：その部位の個体の一覧（⚠ マス・名前・値・装飾の枠 ◆◇ ／ ⚠ 他の人が着けていればその人）。
# ⚠ 下：「鍛冶場で鍛える」＋「◯を着ける」（⚠ 選んだのが着けている品なら「外す」）。
# ⚠⚠ 鍛える・装飾を刺す・外す・分解は、⚠ **持ち物を「その品を選んだ状態」で開く**（2026-09-27・持ち物の回・人間「⚠ 3あ」）。
#   ⚠ 前は仮の鍛冶場（前の装備画面）を開いていた。⚠ 鍛冶場は「仕組みの回①」で作る。
# ⚠ 着けられるかの判定は `get_equip_reject_reason()` の1本（⚠ ここで部位や持ち主を見直さない）。
# ⚠ 購読：character_growth_changed（着脱）／ equipment_instances_changed（鍛えた・増えた）。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。
# ⚠⚠ 10-18（回UI-1018-4・web版の手本 `02_training_eq.png`）：⚠ 右の候補はマス目（`ItemCollection`・行にも切り替え）＋並べ替えの欄。
#   ⚠ ほかの人が着けている品は暗く（⚠ 右上に顔）・自分のは「着用中」。⚠ 下に選んだ品の比べ（「攻撃 18 → 31 +13」・いまの品）と「着ける」「鍛冶場で鍛える」。
#   ⚠ 着けている部位に「鍛える」（⚠ 鍛冶場をその品を選んで開く）。⚠ 触れると詳しい札（いま着けている品と比べる）。

signal forge_requested(instance_id: String)

var _character_id: String = ""
var _selected_slot: String = GameStateKeys.EQUIP_WEAPON
# ⚠ 右の一覧で選んでいる個体。⚠ 空なら「いま着けている品」を選んだものとして扱う。
var _selected_instance: String = ""
var _tip: ItemTipCard = null


func setup(character_id: String) -> void:
	_character_id = character_id
	_selected_instance = ""
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tip = ItemTipCard.attach(self)
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)
	_rebuild()


func _rebuild() -> void:
	# ⚠ 10-18：⚠ 候補を選んでも上へ戻らない（`ScrollKeeper`）。
	var kept: Dictionary = ScrollKeeper.capture(self)
	for child: Node in get_children():
		# ⚠ 触れると出る札は残す（⚠ 消すと並びが消えた札を掴む）。
		if child == _tip:
			continue
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
	heading.right_text = tr("ui_training_equip_count") % [tr("ui_equipment_slot_" + _selected_slot), candidates.size()] + "　・　" + tr("ui_training_equip_legend")
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
	# ⚠ 10-18（人間「⚠ 装備をソートできるように　レア度でフィルターなど」）：⚠ 並べ替えと絞り込み（`ItemListBar`・⚠ 部位は左の列が持つ）。
	var sort_bar: ItemListBar = ItemListBar.create(ItemListBar.KIND_EQUIP, {"slot": false})
	sort_bar.changed.connect(_on_sort_changed)
	right.add_child(sort_bar)
	var entries: Array = []
	var locked: Dictionary = {}
	var tags: Dictionary = {}
	for raw: Variant in candidates:
		var view: Dictionary = raw
		var entry: Dictionary = ItemView.entry_of_view(view)
		var key: String = ItemView.key_of(entry)
		entries.append(entry)
		var owner: String = str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
		if owner == _character_id:
			tags[key] = [tr("ui_item_tag_equipped"), ItemCell.Tag.PLAIN]
		elif owner != "":
			locked[key] = true
	var collection: ItemCollection = ItemCollection.create(ItemListBar.view_of(ItemListBar.KIND_EQUIP))
	collection.tip = _tip
	collection.selected_key = _selected_instance
	collection.locked = locked
	collection.tags = tags
	collection.compare_with = func(_entry: Dictionary) -> String: return equipped_id
	collection.empty_key = "ui_equip_filter_hidden" if ItemListBar.is_filtering(ItemListBar.KIND_EQUIP, false, false) else "ui_training_equip_none"
	collection.item_pressed.connect(_on_candidate_pressed)
	collection.set_entries(entries)
	right.add_child(collection)
	right.add_child(_build_footer(equipped_id))
	ScrollKeeper.restore(self, kept)


# 部位の1行。⚠ 押すとその部位を選ぶ（⚠ 着けている品を右で選んだ状態にする）。
func _create_slot_row(row_data: Dictionary) -> LedgerRow:
	var slot: String = str(row_data.get(GameManager.SLOT_ENTRY_EQUIP_SLOT, ""))
	var entry: Dictionary = row_data.get(GameManager.SLOT_ENTRY_ENTRY, {})
	var row: LedgerRow = LedgerRow.new()
	row.name = "Slot_" + slot
	row.compact = true
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
	if item_id != "":
		var gap: Control = Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)
		# ⚠ 着けている部位に「鍛える」（⚠ 鍛冶場をその品を選んで開く・NOTES §2）。
		var forge: Button = Button.new()
		forge.theme_type_variation = &"PaperToggle"
		forge.focus_mode = Control.FOCUS_NONE
		forge.text = tr("ui_training_equip_forge_short")
		forge.name = "SlotForge_" + slot
		forge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		forge.pressed.connect(func() -> void: forge_requested.emit(str(entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))))
		line.add_child(forge)
	return row


# 下の比べる欄（⚠ 手本 `02_training_eq.png`）：⚠ 選んだ品のマス・名前・等級 ／ 「攻撃 18 → 31 +13」・いまの品 ／ 着ける（外す）・鍛冶場で鍛える。
func _build_footer(equipped_id: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Footer"
	panel.theme_type_variation = &"CompareBoxPanel"
	var line: HBoxContainer = HBoxContainer.new()
	panel.add_child(line)
	if _selected_instance == "":
		var none: Label = Label.new()
		none.theme_type_variation = &"CaptionLabel"
		none.text = tr("ui_training_equip_pick")
		line.add_child(none)
		return panel
	var entry: Dictionary = ItemView.instance_entry(_selected_instance)
	line.add_child(ItemCell.create(entry, get_theme_constant(&"head_icon", &"Forge")))
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(titles)
	var name_label: Label = Label.new()
	name_label.name = "SelectedName"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = ItemView.name_text(entry)
	titles.add_child(name_label)
	var grade: Label = Label.new()
	grade.theme_type_variation = &"CaptionLabel"
	grade.text = tr("ui_equipment_grade") % int(entry.get(GameManager.SLOT_ENTRY_GRADE, 1))
	titles.add_child(grade)
	var compare: VBoxContainer = VBoxContainer.new()
	compare.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compare.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(compare)
	var main_key: String = ItemView.main_stat_key(entry)
	if main_key != "":
		var now: int = int(GameManager.get_effective_stats(_character_id).get(main_key, 0))
		var mine: int = int(ItemView.stats_of(entry).get(main_key, 0))
		var theirs: int = 0 if equipped_id == "" else int(GameManager.get_instance_stats(equipped_id).get(main_key, 0))
		var after: int = now if equipped_id == _selected_instance else now - theirs + mine
		var stat_line: Label = Label.new()
		stat_line.name = "CompareLine"
		stat_line.theme_type_variation = &"GainLabel" if after >= now else &"ErrorLabel"
		stat_line.text = tr("ui_training_equip_compare") % [tr("ui_training_stat_" + main_key), now, after, BelongingsDetail.stat_text(main_key, after - now)]
		compare.add_child(stat_line)
	var current: Label = Label.new()
	current.theme_type_variation = &"CaptionLabel"
	current.text = tr("ui_training_equip_current") % (tr("ui_training_equip_empty") if equipped_id == "" else
		"%s（%s）" % [ItemView.name_text(ItemView.instance_entry(equipped_id)), tr("ui_equipment_grade") % int(ItemView.instance_entry(equipped_id).get(GameManager.SLOT_ENTRY_GRADE, 1))])
	compare.add_child(current)
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(buttons)
	if _selected_instance == equipped_id:
		var off: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_equipment_unequip")
		off.name = "UnequipButton"
		off.pressed.connect(_on_unequip_pressed)
		buttons.add_child(off)
	else:
		var wear: UiButton = UiButton.create(UiButton.Variant.PRIMARY)
		wear.name = "EquipButton"
		wear.text = tr("ui_training_equip_wear") % ItemView.name_text(entry)
		wear.disabled = GameManager.get_equip_reject_reason(_character_id, _selected_slot, _selected_instance) != ""
		wear.pressed.connect(_on_equip_pressed)
		buttons.add_child(wear)
	var forge: Button = UiButton.create_paper_choice("ui_training_equip_forge")
	forge.name = "ForgeButton"
	forge.pressed.connect(_on_forge_pressed)
	buttons.add_child(forge)
	return panel


# その部位に着けられる個体（⚠ 他の人が着けている品も並べる＝手本）。⚠ 並びと絞り込みは `ItemListBar.apply_views()`（10-18）。
# ⚠ いま着けている品は絞り込みで隠さない（⚠ 「外す」の相手が消えるため）。
func _candidates_of(slot: String) -> Array:
	var result: Array = []
	var equipped_id: String = GameManager.get_equipped_instance_id(_character_id, slot)
	var shown: Array = ItemListBar.apply_views(GameManager.get_owned_instances(), false, false)
	if equipped_id != "" and not _has_instance(shown, equipped_id):
		for entry: Variant in GameManager.get_owned_instances():
			if str((entry as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == equipped_id:
				shown.push_front(entry)
	for entry: Variant in shown:
		var view: Dictionary = entry
		var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		var definition: Dictionary = MasterDataLoader.get_item(item_id)
		# ⚠ 10-07（回HB-2・`EQ-1`）：⚠ 持てないジャンルの武器は並べない。
		if str(definition.get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")) == slot and GameManager.can_wield(_character_id, item_id):
			result.append(view)
	return result


func _has_instance(candidates: Array, instance_id: String) -> bool:
	for view: Variant in candidates:
		if str((view as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
			return true
	return false


# ⚠ 部位の行の絵（⚠ 着けていれば品のマス・空きなら薄い枠）。⚠ 押下は行が受ける。
func _item_icon(entry: Dictionary) -> Control:
	var side: int = get_theme_constant(&"item_icon", &"Training")
	if entry.is_empty():
		var empty: PanelContainer = PanelContainer.new()
		empty.theme_type_variation = &"MergeSlotEmptyPanel"
		empty.custom_minimum_size = Vector2(side, side)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return empty
	var cell: ItemCell = ItemCell.create(entry, side)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


func _on_slot_pressed(slot: String) -> void:
	if slot == _selected_slot:
		return
	_selected_slot = slot
	_selected_instance = ""
	ScrollKeeper.reset(self)
	_rebuild()


func _on_sort_changed() -> void:
	_selected_instance = ""
	ScrollKeeper.reset(self)
	_rebuild()


func _on_candidate_pressed(instance_id: String) -> void:
	if instance_id == _selected_instance:
		return
	_selected_instance = instance_id
	_rebuild()


func _on_forge_pressed() -> void:
	forge_requested.emit(_selected_instance)


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
