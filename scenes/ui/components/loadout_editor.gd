# res://scenes/ui/components/loadout_editor.gd
# スキルと装備を替える部品（2026-10-19・回SEE29-E・決定 `GR-15`・`docs/02_exec/EXEC_LOADOUT_EDITOR.md`）。
#
# ⚠ 人間「⚠ 育成と一か所にしたい」→「⚠ ６同じものを使うが、少し処理を変えるだけにする　呼び出し元が２個って感じ」→「⚠ １い」。
#   ⚠ 中身は詰所の窓（`BuildEditWindow`・10-18 回UI-1018-5）のものをそのまま移した：
#   ⚠ 真ん中＝スキルの枠・装備の枠（⚠ 押すと選ぶ）／ ⚠ 右＝装備の候補（マス目と並べ替えの欄・ほかの人の物は暗い）＋ 比べる欄 ＋ 着ける／外す。
#   ⚠ スキルの枠は押すと**紙の窓で選ぶ**（⚠ 回SEE29-A「⚠ スキル選択は、モーダルにして」）。⚠ 右の候補は装備だけ。
# ⚠ 呼び出し元（詰所の窓・育成）が変えるのは3つだけ：
#   ⚠ `top_builder`＝真ん中の上（⚠ 詰所＝「ビルド◯の中身」と名前 ／ 育成＝見出し）
#   ⚠ `idle_builder`＝何も選んでいない右（⚠ 詰所＝案内 ／ 育成＝通常攻撃とパッシブ）
#   ⚠ `forge`＝比べる欄に「鍛える」（⚠ 育成だけ・押すと `forge_requested`）
# ⚠ 中身を変えると**そのキャラのいまの形がすぐ変わる**（⚠ 本番の口 `equip_instance()` / `select_skill()`）。⚠ 判定は全部 `GameManager`。
# ⚠ 自分で character_growth_changed / equipment_instances_changed を受けて描き直す（⚠ 選んでいる枠と候補は持ち越す）。
# ⚠ 寸法は Theme の `Sortie`（⚠ 詰所の窓の値のまま）。⚠ 再描画に await を持たせない（CLAUDE.md 5番）。

class_name LoadoutEditor
extends HBoxContainer

signal changed(text: String)
signal forge_requested(instance_id: String)

const THEME_TYPE: StringName = &"Sortie"
const TARGET_SKILL: String = "skill_"
const TARGET_EQUIP: String = "equip_"
const CANDIDATE_COLUMNS: int = 2

var character_id: String = ""
# ⚠ 真ん中の上に置くもの（⚠ `func(column: VBoxContainer)`・描き直すたびに呼ぶ）。
var top_builder: Callable = Callable()
# ⚠ 何も選んでいない右に置くもの（⚠ `func(column: VBoxContainer)`）。⚠ 無ければ案内の一言。
var idle_builder: Callable = Callable()
# ⚠ 比べる欄に「鍛える」を出すか。
var forge: bool = false
var tip: ItemTipCard = null

# ⚠ 選んでいる枠（⚠ "skill_0" / "equip_weapon"・空なら何も選んでいない）。⚠ スキルの枠は窓が開いている間だけ。
var _target: String = ""
var _selected_candidate: String = ""
var _picker: ModalDialog = null


static func create(p_character_id: String, initial_target: String = "") -> LoadoutEditor:
	var editor: LoadoutEditor = LoadoutEditor.new()
	editor.name = "LoadoutEditor"
	editor.character_id = p_character_id
	editor._target = initial_target if initial_target.begins_with(TARGET_EQUIP) else ""
	return editor


# ⚠ 装備の欄を出すか（⚠ 装備の画面が開いてから＝GAME_DESIGN.md 9-5 の #2）。
static func equipment_open() -> bool:
	return GameManager.is_screen_unlocked(GameStateKeys.SCREEN_EQUIPMENT)


func _ready() -> void:
	theme_type_variation = &"WideRow"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameManager.character_growth_changed.connect(_on_growth_changed)
	GameManager.equipment_instances_changed.connect(_on_instances_changed)
	rebuild()


# ⚠ いま選んでいる枠（⚠ 検査・呼び出し元が読む）。
func target() -> String:
	return _target


# ⚠ 検査用：⚠ 開いているスキルの窓（⚠ 無ければ null）。
func picker_dialog() -> ModalDialog:
	return _picker if _is_picking() else null


func select_target(p_target: String) -> void:
	_target = p_target
	_selected_candidate = ""
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	var kept: Dictionary = ScrollKeeper.capture(self)
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if tip != null and is_instance_valid(tip):
		tip.hide_tip()
	if character_id == "":
		return
	add_child(_build_middle())
	add_child(VSeparator.new())
	add_child(_build_right())
	ScrollKeeper.restore(self, kept)


# --- 真ん中：スキルの枠 ／ 装備の枠 ---

func _build_middle() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Middle"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if top_builder.is_valid():
		top_builder.call(column)
	column.add_child(_caption(tr("ui_build_window_skills") % GameManager.get_skill_slot_count()))
	var skills: HBoxContainer = HBoxContainer.new()
	skills.name = "SkillSlots"
	column.add_child(skills)
	var selected: Array = GameManager.get_selected_skills(character_id)
	for i: int in range(GameManager.get_skill_slot_count()):
		skills.add_child(_skill_slot(i, str(selected[i]) if i < selected.size() and selected[i] != null else ""))
	if equipment_open():
		column.add_child(_caption(tr("ui_build_window_equipment") % GameManager.get_equip_slots().size()))
		for view: Variant in GameManager.get_equipment_slot_entries(character_id):
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
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(texts)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _skill_name(skill_id) if skill_id != "" else tr("ui_training_skill_pick")
	# ⚠ 空の枠は小さい字（⚠ 枠が狭く「押して選ぶ」が切れた＝撮った絵・前の育成のスキルのタブと同じ扱い）。
	name_label.theme_type_variation = &"" if skill_id != "" else &"CaptionLabel"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	if skill_id != "":
		var cd: Label = Label.new()
		cd.theme_type_variation = &"CaptionLabel"
		cd.text = tr("ui_skill_select_cooldown") % float(MasterDataLoader.get_skill(skill_id).get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
		texts.add_child(cd)
		# ⚠ 空の枠を外しても何も起きないので、ボタンごと出さない。
		var clear: Button = UiButton.create_paper_choice("ui_equipment_unequip")
		clear.name = "ClearButton"
		clear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clear.pressed.connect(_on_skill_clear_pressed.bind(slot_index))
		line.add_child(clear)
	var hit: Button = UiButton.attach_hit(card, _on_skill_slot_pressed.bind(slot_index))
	# ⚠ 触れると名前・効果・CD（回SEE29-A・`LoadoutIcons.skill_tip_text()`）。
	hit.tooltip_text = LoadoutIcons.skill_tip_text(skill_id)
	return card


func _equip_row(view: Dictionary) -> LedgerRow:
	var slot: String = str(view.get(GameManager.SLOT_ENTRY_EQUIP_SLOT, ""))
	var entry: Dictionary = view.get(GameManager.SLOT_ENTRY_ENTRY, {})
	var row: LedgerRow = LedgerRow.new()
	row.name = "EquipSlot_" + slot
	row.compact = true
	row.selected = _target == TARGET_EQUIP + slot
	row.pressed.connect(_on_equip_slot_pressed.bind(slot))
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
		cell.name = "SlotCell"
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


# --- 右：装備の候補（⚠ 何も選んでいなければ呼び出し元の欄） ---

func _build_right() -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Right"
	column.custom_minimum_size.x = float(get_theme_constant(&"build_right", THEME_TYPE))
	if _target.begins_with(TARGET_EQUIP) and equipment_open():
		_build_equip_candidates(column, _target.trim_prefix(TARGET_EQUIP))
	elif idle_builder.is_valid():
		idle_builder.call(column)
	else:
		var hint: Label = Label.new()
		hint.name = "RightHint"
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
		if str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")) == slot and GameManager.can_wield(character_id, item_id):
			views.append(view)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_text = tr("ui_build_window_pick_equip") % tr("ui_equipment_slot_" + slot)
	heading.right_text = tr("ui_build_window_owned") % views.size()
	column.add_child(heading)
	var bar: ItemListBar = ItemListBar.create(ItemListBar.KIND_EQUIP, {"slot": false})
	bar.changed.connect(rebuild)
	column.add_child(bar)
	var equipped_id: String = GameManager.get_equipped_instance_id(character_id, slot)
	var entries: Array = []
	var locked: Dictionary = {}
	var tags: Dictionary = {}
	for raw: Variant in views:
		var view: Dictionary = raw
		var entry: Dictionary = ItemView.entry_of_view(view)
		var key: String = ItemView.key_of(entry)
		entries.append(entry)
		var owner: String = str(view.get(GameManager.INSTANCE_VIEW_EQUIPPED_BY, ""))
		if owner == character_id:
			tags[key] = [tr("ui_item_tag_equipped"), ItemCell.Tag.PLAIN]
		elif owner != "":
			locked[key] = true
	if _selected_candidate == "" or GameManager.get_equipment_instance(_selected_candidate).is_empty():
		_selected_candidate = equipped_id
	var collection: ItemCollection = ItemCollection.create(ItemListBar.view_of(ItemListBar.KIND_EQUIP))
	collection.tip = tip
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
	# 比べる欄 ＋ 外す／着ける（＋ 鍛える）。
	var box: PanelContainer = PanelContainer.new()
	box.name = "Compare"
	box.theme_type_variation = &"CompareBoxPanel"
	column.add_child(box)
	var inner: VBoxContainer = VBoxContainer.new()
	box.add_child(inner)
	var entry: Dictionary = ItemView.instance_entry(_selected_candidate)
	var top: HBoxContainer = HBoxContainer.new()
	inner.add_child(top)
	var compare_cell: ItemCell = ItemCell.create(entry, get_theme_constant(&"build_slot_icon", THEME_TYPE))
	compare_cell.name = "CompareCell"
	top.add_child(compare_cell)
	var name_label: Label = Label.new()
	name_label.name = "CompareName"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = ItemView.name_text(entry)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	if forge:
		var forge_button: Button = UiButton.create_paper_choice("ui_training_equip_forge")
		forge_button.name = "ForgeButton"
		forge_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		forge_button.pressed.connect(func() -> void: forge_requested.emit(_selected_candidate))
		top.add_child(forge_button)
	var main_key: String = ItemView.main_stat_key(entry)
	if main_key != "":
		var now: int = int(GameManager.get_effective_stats(character_id).get(main_key, 0))
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
	wear.disabled = _selected_candidate == equipped_id or GameManager.get_equip_reject_reason(character_id, slot, _selected_candidate) != ""
	wear.pressed.connect(_on_equip_pressed.bind(slot))
	wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(wear)


# --- スキルを選ぶ紙の窓（⚠ 回SEE29-A の形・前は育成のスキルのタブが持っていた） ---

func _is_picking() -> bool:
	return _picker != null and is_instance_valid(_picker) and not _picker.is_queued_for_deletion()


func _open_picker(slot_index: int) -> void:
	var host: Node = get_tree().current_scene
	_picker = Modal.notify(host if host != null else self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_training_skills_picker_title") % (slot_index + 1),
		Modal.OPTION_CONTENT: _build_picker(slot_index),
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_LARGE,
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})
	if _picker != null:
		_picker.closed.connect(_on_picker_closed, CONNECT_ONE_SHOT)


func _build_picker(slot_index: int) -> ScrollContainer:
	var all_candidates: Array = GameManager.get_all_skill_candidates(character_id, GameManager.SLOT_KIND_SKILL)
	var unlocked: Array = GameManager.get_skill_candidates(character_id, GameManager.SLOT_KIND_SKILL)
	var selected: Array = GameManager.get_selected_skills(character_id, GameManager.SLOT_KIND_SKILL)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Picker"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = float(get_theme_constant(&"skill_picker_height", &"Training"))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var hint: Label = Label.new()
	hint.name = "PickerHint"
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr("ui_training_skills_picker_hint")
	column.add_child(hint)
	var candidates: GridContainer = GridContainer.new()
	candidates.name = "Candidates"
	candidates.columns = CANDIDATE_COLUMNS
	candidates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(candidates)
	for entry: Variant in all_candidates:
		var skill_id: String = str(entry)
		candidates.add_child(_create_candidate(skill_id, skill_id in unlocked, selected.find(skill_id), slot_index))
	return scroll


func _create_candidate(skill_id: String, is_unlocked: bool, slot_index: int, target_slot: int) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Candidate_" + skill_id
	row.selected = slot_index >= 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 判定は GameManager 側と同じもの（⚠ 画面で条件を作り直さない）。
	var can_select: bool = GameManager.can_select_skill(character_id, target_slot, skill_id, GameManager.SLOT_KIND_SKILL)
	# ⚠ 未解放は沈める（⚠ 消さない＝次に何が来るかは見せる）。⚠ 入っている候補は沈めない。
	row.disabled = not is_unlocked or (not can_select and slot_index < 0)
	row.pressed.connect(_on_candidate_skill_pressed.bind(target_slot, skill_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var frame: PanelContainer = LoadoutIcons.skill_frame(skill_id, get_theme_constant(&"skill_frame", &"Training"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(frame)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	var title_row: HBoxContainer = HBoxContainer.new()
	column.add_child(title_row)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _skill_name(skill_id)
	title_row.add_child(name_label)
	# ⚠ 札は「どの枠に入っているか」か「何レベルで解放されるか」のどちらか。
	var tag_text: String = ""
	if slot_index >= 0:
		tag_text = tr("ui_training_skill_in_slot") % (slot_index + 1)
	elif not is_unlocked:
		tag_text = tr("ui_skill_select_locked") % GameManager.get_skill_unlock_level(skill_id)
	if tag_text != "":
		var tag: Label = Label.new()
		tag.name = "TagLabel"
		tag.theme_type_variation = &"ErrorLabel" if slot_index >= 0 else &"CaptionLabel"
		tag.text = tag_text
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(tag)
	var desc_key: String = "ui_desc_" + skill_id
	if tr(desc_key) != desc_key:
		var caption: Label = Label.new()
		caption.name = "EffectLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text = tr(desc_key)
		column.add_child(caption)
	var timing: VBoxContainer = VBoxContainer.new()
	timing.name = "TimingColumn"
	timing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	var cooldown: Label = Label.new()
	cooldown.name = "CooldownLabel"
	cooldown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cooldown.text = "%.1f" % float(data.get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
	timing.add_child(cooldown)
	var charge: Variant = data.get(SkillSchema.FIELD_CHARGE, null)
	if str(data.get(SkillSchema.FIELD_ACTIVATION, "")) == SkillSchema.ACTIVATION_CHARGE and charge is Dictionary:
		var just: Label = Label.new()
		just.name = "ChargeLabel"
		just.theme_type_variation = &"CaptionLabel"
		just.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		just.text = tr("ui_skill_select_charge") % float((charge as Dictionary).get(SkillSchema.FIELD_JUST_SEC, 0.0))
		timing.add_child(just)
	line.add_child(timing)
	return row


func _on_picker_closed(_result: bool) -> void:
	_picker = null
	if _target.begins_with(TARGET_SKILL):
		_target = ""
	if is_inside_tree():
		rebuild()


# --- 押されたもの ---

func _on_skill_slot_pressed(slot_index: int) -> void:
	if _is_picking():
		return
	_target = TARGET_SKILL + str(slot_index)
	_selected_candidate = ""
	_open_picker(slot_index)
	rebuild()


func _on_equip_slot_pressed(slot: String) -> void:
	_target = "" if _target == TARGET_EQUIP + slot else TARGET_EQUIP + slot
	_selected_candidate = ""
	ScrollKeeper.reset(self)
	rebuild()


func _on_candidate_skill_pressed(slot_index: int, skill_id: String) -> void:
	# ⚠ 選んだら窓は閉じる（⚠ 描き直しは character_growth_changed と窓の closed から）。
	if _is_picking():
		_picker.close()
	# 既に別の枠に入っているスキルを選ぶと、2つの枠が入れ替わる（GameManager 側の仕様）。
	if GameManager.select_skill(character_id, slot_index, skill_id, GameManager.SLOT_KIND_SKILL):
		changed.emit(tr("ui_build_window_skill_changed") % (slot_index + 1))


func _on_skill_clear_pressed(slot_index: int) -> void:
	GameManager.clear_skill_slot(character_id, slot_index, GameManager.SLOT_KIND_SKILL)


func _on_candidate_pressed(instance_id: String) -> void:
	_selected_candidate = instance_id
	rebuild()


func _on_equip_pressed(slot: String) -> void:
	var item: String = ItemView.name_text(ItemView.instance_entry(_selected_candidate))
	if GameManager.equip_instance(character_id, slot, _selected_candidate):
		changed.emit(tr("ui_equipment_slot_" + slot) + " " + item)


func _on_unequip_pressed(slot: String) -> void:
	if GameManager.unequip_instance(character_id, slot):
		_selected_candidate = ""
		changed.emit(tr("ui_equipment_slot_" + slot) + " " + tr("ui_equipment_unequip"))


func _on_growth_changed(changed_id: String) -> void:
	if changed_id == character_id and is_inside_tree():
		rebuild()


func _on_instances_changed(_instance_id: String) -> void:
	if is_inside_tree():
		rebuild()


func _exit_tree() -> void:
	if GameManager.character_growth_changed.is_connected(_on_growth_changed):
		GameManager.character_growth_changed.disconnect(_on_growth_changed)
	if GameManager.equipment_instances_changed.is_connected(_on_instances_changed):
		GameManager.equipment_instances_changed.disconnect(_on_instances_changed)


# --- 小さい道具 ---

func _skill_name(skill_id: String) -> String:
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	return skill_id if data.is_empty() else tr(str(data.get("name_key", skill_id)))


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
