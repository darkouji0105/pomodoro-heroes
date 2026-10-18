# res://scenes/adventure/build_edit_window.gd
# ビルドと装備の窓（2026-10-18・回UI-1018-5・web版の手本 `01_barracks_window.png` / `01_barracks_build_delete.png`・NOTES §1）。
#
# ⚠ 詰所の「中身を直す・着替える ›」「＋組む」から開く。⚠ 詰所の上に暗幕と紙を重ねる。
#   ⚠ 左：ビルド1〜3（⚠ 押すとそのビルドに切り替わる＝当てる ／「出撃で使う」＝いまの形と同じビルド ／ ゴミ箱＝消す）・ステータス10個。
#   ⚠ 真ん中：ビルド◯の中身＝名前（✎）・スキル2枠・装備5枠（⚠ 押すと右に候補）。
#   ⚠ 右：候補（⚠ 装備＝マス目と並べ替えの欄・ほかの人の物は暗い ／ スキル＝一覧）＋ 比べる欄 ＋ 着ける／外す。
#   ⚠ 下：変えたところ ／「残さずに閉じる」「別の番号に残す…」「ビルド◯に残して閉じる」。
# ⚠⚠ 中身を変えると**そのキャラのいまの形がすぐ変わる**（⚠ 本番の口 `equip_instance()` / `select_skill()`）。⚠ 「残す」でビルドに焼く（`save_character_preset()`）。
#   ⚠ 「残さずに閉じる」はビルドに焼かないだけ（⚠ いまの形は変えたまま）。
# ⚠ 判定は全部 `GameManager` の口。⚠ 詰所でしか使わないので scenes/adventure/（AGENTS.md）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。

class_name BuildEditWindow
extends Control

# ⚠ 閉じた（⚠ 詰所の帯に出す一言・⚠ 空なら出さない）。
signal closed(notice: String)

const THEME_TYPE: StringName = &"Sortie"
const TARGET_SKILL: String = "skill_"
const TARGET_EQUIP: String = "equip_"

var _character_id: String = ""
var _index: int = 0
# ⚠ 右に候補を出している枠（⚠ "skill_0" / "equip_weapon"・空なら出さない）。
var _target: String = ""
var _selected_candidate: String = ""
var _pending_name: String = ""
var _changes: Array[String] = []
var _tip: ItemTipCard = null
var _sheet_body: VBoxContainer = null


static func open(host: Control, character_id: String, index: int) -> BuildEditWindow:
	var window: BuildEditWindow = BuildEditWindow.new()
	window.name = "BuildEditWindow"
	window._character_id = character_id
	window._index = index
	window._pending_name = GameManager.get_character_preset_name(character_id, index)
	host.add_child(window)
	return window


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = get_theme_color(&"result_scrim", &"Forge")
	add_child(scrim)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"BuildWindowMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	margin.add_child(sheet)
	_sheet_body = VBoxContainer.new()
	_sheet_body.name = "Body"
	sheet.add_child(_sheet_body)
	_tip = ItemTipCard.attach(self)
	# ⚠ 開いたビルドが焼いてあれば、⚠ そのビルドに切り替えてから直す（⚠ 「ビルド◯の中身」を直すため）。
	if _is_saved(_index) and GameManager.get_matching_character_preset(_character_id) != _index:
		var _report: Dictionary = GameManager.apply_character_preset(_character_id, _index)
	GameManager.character_growth_changed.connect(_on_growth_changed)
	_rebuild()


func _is_saved(index: int) -> bool:
	return bool(GameManager.get_character_preset(_character_id, index).get(GameStateKeys.PRESET_SAVED, false))


func _on_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()


func _rebuild() -> void:
	var kept: Dictionary = ScrollKeeper.capture(self)
	for child: Node in _sheet_body.get_children():
		_sheet_body.remove_child(child)
		child.queue_free()
	if _tip != null:
		_tip.hide_tip()
	_sheet_body.add_child(_build_head())
	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Columns"
	body.theme_type_variation = &"WideRow"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_body.add_child(body)
	body.add_child(_build_left())
	body.add_child(VSeparator.new())
	body.add_child(_build_middle())
	body.add_child(VSeparator.new())
	body.add_child(_build_right())
	_sheet_body.add_child(HSeparator.new())
	_sheet_body.add_child(_build_foot())
	ScrollKeeper.restore(self, kept)


# --- 頭 ---

func _build_head() -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.add_child(CharacterAvatar.create(_character_id, get_theme_constant(&"mini_photo", THEME_TYPE) + 8))
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_build_window_title") % _name_of(_character_id)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var sub: Label = Label.new()
	sub.theme_type_variation = &"CaptionLabel"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var level: int = int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	sub.text = "%s・%s %d" % [tr("ui_role_" + _character_id), tr("ui_dossier_lv"), level]
	head.add_child(sub)
	var close: Button = _small("ui_build_window_close")
	close.name = "CloseButton"
	close.pressed.connect(_close.bind(""))
	head.add_child(close)
	return head


# --- 左：ビルド1〜3 ／ ステータス ---

func _build_left() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Left"
	column.custom_minimum_size.x = float(get_theme_constant(&"build_left", THEME_TYPE))
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_build_window_builds"
	heading.right_text = tr("ui_build_window_builds_max") % GameManager.get_character_preset_count()
	column.add_child(heading)
	var matching: int = GameManager.get_matching_character_preset(_character_id)
	var presets: Array = GameManager.get_character_presets(_character_id)
	for i: int in range(presets.size()):
		column.add_child(_build_card(i, presets[i] as Dictionary, matching))
	var stats_heading: SheetHeading = SheetHeading.new()
	stats_heading.title_key = "ui_build_window_stats"
	column.add_child(stats_heading)
	var stats: Dictionary = GameManager.get_effective_stats(_character_id)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Stats"
	list.theme_type_variation = &"TightList"
	column.add_child(list)
	for stat_key: String in GameManager.get_stat_keys():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Stat_" + stat_key
		var caption: Label = Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = tr("ui_training_stat_" + stat_key)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var value: Label = Label.new()
		value.name = "Value"
		var number: int = int(stats.get(stat_key, 0))
		value.text = ("%d%%" % number) if GameManager.is_percent_stat(stat_key) else str(number)
		row.add_child(value)
		list.add_child(row)
	var note: Label = Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = tr("ui_build_window_nodes_note")
	column.add_child(note)
	return column


# ビルドの札（⚠ 押すとそのビルドを直す＝当てる・⚠ 空きなら「押して組む」＝いまの形のまま直す先にする）。
func _build_card(index: int, preset: Dictionary, matching: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "BuildCard_%d" % index
	card.theme_type_variation = &"SkillSlotSelectedPanel" if index == _index else &"SkillSlotPanel"
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var saved: bool = bool(preset.get(GameStateKeys.PRESET_SAVED, false))
	var title: Label = Label.new()
	title.name = "BuildTitle"
	title.theme_type_variation = &"SheetHeadingLabel" if saved else &"CaptionLabel"
	title.text = "%d　%s" % [index + 1, _preset_name(index)] if saved else tr("ui_build_window_empty") % (index + 1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	if saved:
		var used: Label = Label.new()
		used.name = "UsedLabel"
		used.theme_type_variation = &"ErrorLabel" if index == matching else &"CaptionLabel"
		used.text = tr("ui_build_window_in_use") if index == matching else ""
		used.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(used)
		var trash: Button = _small("ui_build_window_delete")
		trash.name = "DeleteBuild_%d" % index
		trash.pressed.connect(_on_delete_pressed.bind(index))
		top.add_child(trash)
		var icons: LoadoutIcons = LoadoutIcons.from_preset(preset, get_theme_constant(&"build_icon", THEME_TYPE))
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for child: Node in icons.get_children():
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icons)
	UiButton.attach_hit(card, _on_build_card_pressed.bind(index))
	return card


func _on_build_card_pressed(index: int) -> void:
	if index == _index:
		return
	_index = index
	_pending_name = GameManager.get_character_preset_name(_character_id, index)
	_target = ""
	if _is_saved(index):
		var report: Dictionary = GameManager.apply_character_preset(_character_id, index)
		_note_change(GameManager.format_apply_report(report))
	_rebuild()


# ビルドを消す（⚠ 確かめの窓・手本 `01_barracks_build_delete.png`）。
func _on_delete_pressed(index: int) -> void:
	var ok: bool = await Modal.confirm(self, "ui_build_window_delete_confirm", [], false, {
		Modal.OPTION_TITLE: tr("ui_build_window_delete_title") % [index + 1, _preset_name(index)],
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_build_window_delete_go",
	})
	if not ok or not is_instance_valid(self):
		return
	if GameManager.clear_character_preset(_character_id, index):
		_note_change(tr("ui_build_window_deleted") % (index + 1))
	_rebuild()


# --- 真ん中：ビルド◯の中身 ---

func _build_middle() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Middle"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr("ui_build_window_content") % (_index + 1)
	heading.right_text = tr("ui_build_window_content_hint")
	column.add_child(heading)
	var name_row: HBoxContainer = HBoxContainer.new()
	column.add_child(name_row)
	var name_caption: Label = Label.new()
	name_caption.theme_type_variation = &"CaptionLabel"
	name_caption.text = tr("ui_build_window_name")
	name_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(name_caption)
	var name_edit: LineEdit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.theme_type_variation = &"PaperLineEdit"
	name_edit.text = _pending_name
	name_edit.placeholder_text = tr("ui_party_preset_build") % (_index + 1)
	name_edit.max_length = GameManager.CHARACTER_PRESET_NAME_MAX
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)

	column.add_child(_caption(tr("ui_build_window_skills") % GameManager.get_skill_slot_count()))
	var skills: HBoxContainer = HBoxContainer.new()
	skills.name = "SkillSlots"
	column.add_child(skills)
	var selected: Array = GameManager.get_selected_skills(_character_id)
	for i: int in range(GameManager.get_skill_slot_count()):
		skills.add_child(_skill_slot(i, str(selected[i]) if i < selected.size() and selected[i] != null else ""))

	column.add_child(_caption(tr("ui_build_window_equipment") % GameManager.get_equip_slots().size()))
	for view: Variant in GameManager.get_equipment_slot_entries(_character_id):
		column.add_child(_equip_row(view as Dictionary))
	return column


func _skill_slot(slot_index: int, skill_id: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "SkillSlot_%d" % slot_index
	card.theme_type_variation = &"SkillSlotSelectedPanel" if _target == TARGET_SKILL + str(slot_index) else &"SkillSlotPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)
	var number: Label = Label.new()
	number.theme_type_variation = &"DossierLevelLabel"
	number.text = str(slot_index + 1)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(number)
	var frame: PanelContainer = LoadoutIcons.skill_frame(skill_id, get_theme_constant(&"build_slot_icon", THEME_TYPE))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(frame)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(texts)
	var name_label: Label = Label.new()
	name_label.text = _skill_name(skill_id) if skill_id != "" else tr("ui_training_skill_pick")
	texts.add_child(name_label)
	if skill_id != "":
		var cd: Label = Label.new()
		cd.theme_type_variation = &"CaptionLabel"
		cd.text = tr("ui_skill_select_cooldown") % float(MasterDataLoader.get_skill(skill_id).get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
		texts.add_child(cd)
	UiButton.attach_hit(card, _on_target_pressed.bind(TARGET_SKILL + str(slot_index)))
	return card


func _equip_row(view: Dictionary) -> LedgerRow:
	var slot: String = str(view.get(GameManager.SLOT_ENTRY_EQUIP_SLOT, ""))
	var entry: Dictionary = view.get(GameManager.SLOT_ENTRY_ENTRY, {})
	var row: LedgerRow = LedgerRow.new()
	row.name = "EquipSlot_" + slot
	row.compact = true
	row.selected = _target == TARGET_EQUIP + slot
	row.pressed.connect(_on_target_pressed.bind(TARGET_EQUIP + slot))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var side: int = get_theme_constant(&"build_slot_icon", THEME_TYPE)
	if entry.is_empty():
		var empty: PanelContainer = PanelContainer.new()
		empty.theme_type_variation = &"MergeSlotEmptyPanel"
		empty.custom_minimum_size = Vector2(side, side)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(empty)
	else:
		var cell: ItemCell = ItemCell.create(entry, side)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(cell)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(texts)
	var slot_label: Label = Label.new()
	slot_label.theme_type_variation = &"CaptionLabel"
	slot_label.text = tr("ui_equipment_slot_" + slot)
	texts.add_child(slot_label)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"" if not entry.is_empty() else &"CaptionLabel"
	name_label.text = ItemView.name_text(entry) if not entry.is_empty() else tr("ui_training_equip_empty")
	texts.add_child(name_label)
	if row.selected:
		var go: Label = Label.new()
		go.theme_type_variation = &"AccentLabel"
		go.text = tr("ui_build_window_pick_right")
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(go)
	return row


func _on_target_pressed(target: String) -> void:
	_target = "" if _target == target else target
	_selected_candidate = ""
	ScrollKeeper.reset(self)
	_rebuild()


func _on_name_changed(text: String) -> void:
	_pending_name = text


# --- 右：候補 ---

func _build_right() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Right"
	column.custom_minimum_size.x = float(get_theme_constant(&"build_right", THEME_TYPE))
	if _target.begins_with(TARGET_EQUIP):
		_build_equip_candidates(column, _target.trim_prefix(TARGET_EQUIP))
	elif _target.begins_with(TARGET_SKILL):
		_build_skill_candidates(column, int(_target.trim_prefix(TARGET_SKILL)))
	else:
		var hint: Label = Label.new()
		hint.theme_type_variation = &"CaptionLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.text = tr("ui_build_window_right_hint")
		column.add_child(hint)
	return column


func _build_equip_candidates(column: VBoxContainer, slot: String) -> void:
	var views: Array = []
	for raw: Variant in ItemListBar.apply_views(GameManager.get_owned_instances(), false, false):
		var view: Dictionary = raw
		var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		if str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")) == slot and GameManager.can_wield(_character_id, item_id):
			views.append(view)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr("ui_build_window_pick_equip") % tr("ui_equipment_slot_" + slot)
	heading.right_text = tr("ui_build_window_owned") % views.size()
	column.add_child(heading)
	var bar: ItemListBar = ItemListBar.create(ItemListBar.KIND_EQUIP, {"slot": false})
	bar.changed.connect(_rebuild)
	column.add_child(bar)
	var equipped_id: String = GameManager.get_equipped_instance_id(_character_id, slot)
	var entries: Array = []
	var locked: Dictionary = {}
	var tags: Dictionary = {}
	for raw: Variant in views:
		var view: Dictionary = raw
		var entry: Dictionary = ItemView.entry_of_view(view)
		var key: String = ItemView.key_of(entry)
		entries.append(entry)
		var owner: String = str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
		if owner == _character_id:
			tags[key] = [tr("ui_item_tag_equipped"), ItemCell.Tag.PLAIN]
		elif owner != "":
			locked[key] = true
	if _selected_candidate == "":
		_selected_candidate = equipped_id
	var collection: ItemCollection = ItemCollection.create(ItemListBar.view_of(ItemListBar.KIND_EQUIP))
	collection.tip = _tip
	collection.selected_key = _selected_candidate
	collection.locked = locked
	collection.tags = tags
	collection.compare_with = func(_entry: Dictionary) -> String: return equipped_id
	collection.empty_key = "ui_training_equip_none"
	collection.item_pressed.connect(_on_candidate_pressed)
	collection.set_entries(entries)
	column.add_child(collection)
	if _selected_candidate == "":
		return
	# 比べる欄 ＋ 外す／着ける。
	var box: PanelContainer = PanelContainer.new()
	box.name = "Compare"
	box.theme_type_variation = &"CompareBoxPanel"
	column.add_child(box)
	var inner: VBoxContainer = VBoxContainer.new()
	box.add_child(inner)
	var entry: Dictionary = ItemView.instance_entry(_selected_candidate)
	var top: HBoxContainer = HBoxContainer.new()
	inner.add_child(top)
	top.add_child(ItemCell.create(entry, get_theme_constant(&"build_slot_icon", THEME_TYPE)))
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = ItemView.name_text(entry)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var main_key: String = ItemView.main_stat_key(entry)
	if main_key != "":
		var now: int = int(GameManager.get_effective_stats(_character_id).get(main_key, 0))
		var mine: int = int(ItemView.stats_of(entry).get(main_key, 0))
		var theirs: int = 0 if equipped_id == "" else int(GameManager.get_instance_stats(equipped_id).get(main_key, 0))
		var after: int = now if equipped_id == _selected_candidate else now - theirs + mine
		var compare: Label = Label.new()
		compare.name = "CompareLine"
		compare.theme_type_variation = &"GainLabel" if after >= now else &"ErrorLabel"
		compare.text = tr("ui_training_equip_compare") % [tr("ui_training_stat_" + main_key), now, after, BelongingsDetail.stat_text(main_key, after - now)]
		inner.add_child(compare)
	var buttons: HBoxContainer = HBoxContainer.new()
	inner.add_child(buttons)
	var off: Button = _small("ui_equipment_unequip")
	off.name = "UnequipButton"
	off.disabled = equipped_id == ""
	off.pressed.connect(_on_unequip_pressed.bind(slot))
	off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(off)
	var wear: UiButton = UiButton.create(UiButton.Variant.PRIMARY)
	wear.name = "EquipButton"
	wear.text = tr("ui_training_equip_wear") % ItemView.name_text(entry)
	wear.disabled = _selected_candidate == equipped_id or GameManager.get_equip_reject_reason(_character_id, slot, _selected_candidate) != ""
	wear.pressed.connect(_on_equip_pressed.bind(slot))
	wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(wear)


func _build_skill_candidates(column: VBoxContainer, slot_index: int) -> void:
	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr("ui_training_skills_picker_title") % (slot_index + 1)
	column.add_child(heading)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"CaptionLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_training_skills_picker_hint")
	column.add_child(hint)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SkillScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var unlocked: Array = GameManager.get_skill_candidates(_character_id, GameManager.SLOT_KIND_SKILL)
	var selected: Array = GameManager.get_selected_skills(_character_id)
	for raw: Variant in GameManager.get_all_skill_candidates(_character_id, GameManager.SLOT_KIND_SKILL):
		var skill_id: String = str(raw)
		var row: LedgerRow = LedgerRow.new()
		row.name = "SkillCandidate_" + skill_id
		row.compact = true
		var in_slot: int = selected.find(skill_id)
		row.selected = in_slot == slot_index
		row.disabled = not (skill_id in unlocked)
		row.pressed.connect(_on_skill_pressed.bind(slot_index, skill_id))
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var frame: PanelContainer = LoadoutIcons.skill_frame(skill_id, get_theme_constant(&"build_slot_icon", THEME_TYPE))
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(frame)
		var texts: VBoxContainer = VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(texts)
		var name_label: Label = Label.new()
		name_label.text = _skill_name(skill_id)
		if in_slot >= 0:
			name_label.text += "　" + tr("ui_training_skill_in_slot") % (in_slot + 1)
		elif not (skill_id in unlocked):
			name_label.text += "　" + tr("ui_skill_select_locked") % GameManager.get_skill_unlock_level(skill_id)
		texts.add_child(name_label)
		var key: String = "ui_desc_" + skill_id
		if tr(key) != key:
			var desc: Label = Label.new()
			desc.theme_type_variation = &"CaptionLabel"
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.text = tr(key)
			texts.add_child(desc)
		list.add_child(row)


func _on_candidate_pressed(instance_id: String) -> void:
	_selected_candidate = instance_id
	_rebuild()


func _on_equip_pressed(slot: String) -> void:
	var item: String = ItemView.name_text(ItemView.instance_entry(_selected_candidate))
	if GameManager.equip_instance(_character_id, slot, _selected_candidate):
		_note_change(tr("ui_equipment_slot_" + slot) + " " + item)


func _on_unequip_pressed(slot: String) -> void:
	if GameManager.unequip_instance(_character_id, slot):
		_selected_candidate = ""
		_note_change(tr("ui_equipment_slot_" + slot) + " " + tr("ui_equipment_unequip"))


func _on_skill_pressed(slot_index: int, skill_id: String) -> void:
	if GameManager.select_skill(_character_id, slot_index, skill_id, GameManager.SLOT_KIND_SKILL):
		_note_change(tr("ui_build_window_skill_changed") % (slot_index + 1))
		_target = ""


# --- 下 ---

func _build_foot() -> HBoxContainer:
	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	var changes: Label = Label.new()
	changes.name = "ChangesLabel"
	changes.theme_type_variation = &"CaptionLabel"
	changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	changes.text = tr("ui_build_window_changes") % "・".join(_changes) if not _changes.is_empty() else tr("ui_build_window_no_change")
	changes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(changes)
	var discard: Button = _small("ui_build_window_discard")
	discard.name = "DiscardButton"
	discard.pressed.connect(_close.bind(""))
	foot.add_child(discard)
	var other: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_build_window_save_other")
	other.name = "SaveOtherButton"
	other.pressed.connect(_on_save_other_pressed.bind(other))
	foot.add_child(other)
	var save: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "")
	save.name = "SaveButton"
	save.text = tr("ui_build_window_save") % (_index + 1)
	save.pressed.connect(_save_and_close.bind(_index))
	foot.add_child(save)
	return foot


func _on_save_other_pressed(anchor: Control) -> void:
	var pop: SlotActionPopover = SlotActionPopover.open(self, anchor.get_global_rect(), tr("ui_build_window_save_other"), "")
	for i: int in range(GameManager.get_character_preset_count()):
		var label: String = "%d　%s" % [i + 1, _preset_name(i) if _is_saved(i) else tr("ui_party_preset_empty")]
		var button: UiButton = pop.add_action(label, UiButton.Variant.SECONDARY, _save_and_close.bind(i))
		button.name = "SaveTo_%d" % i


# ⚠ いまの形をビルド◯に焼いて閉じる（⚠ 名前も）。
func _save_and_close(index: int) -> void:
	if not GameManager.save_character_preset(_character_id, index):
		return
	var _named: bool = GameManager.set_character_preset_name(_character_id, index, _pending_name)
	_close(tr("ui_build_window_saved") % [_name_of(_character_id), index + 1])


func _close(notice: String) -> void:
	if GameManager.character_growth_changed.is_connected(_on_growth_changed):
		GameManager.character_growth_changed.disconnect(_on_growth_changed)
	closed.emit(notice)
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


# --- 小さい道具 ---

func _note_change(text: String) -> void:
	if text != "" and not (text in _changes):
		_changes.append(text)


func _preset_name(index: int) -> String:
	var preset_name: String = GameManager.get_character_preset_name(_character_id, index)
	return preset_name if preset_name != "" else tr("ui_party_preset_build") % (index + 1)


func _name_of(character_id: String) -> String:
	return tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))


func _skill_name(skill_id: String) -> String:
	return tr(str(MasterDataLoader.get_skill(skill_id).get("name_key", skill_id)))


func _caption(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = text
	return label


func _small(key: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"PaperToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.text = tr(key)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button
