class_name TrainingSkillsPage
extends VBoxContainer

# 育成のタブ「スキル」（2026-09-27・回UI-組 育成・手本 Skills）。
#
# ⚠ 前は独立した画面（`skill_select_screen`）。⚠ 人間「⚠ 1い」で中身をここへ移した。
# ⚠ 上：持ち込む枠（⚠ 押すと「次に選んだスキルの行き先」になる＝押しただけでは状態を触らない）。
# ⚠ 下：候補を2列（⚠ 絵・名前・札（枠◯ ／ Lv◯で解放）・効果文 ／ CD）。⚠ 押すといまの行き先の枠に入る。
# ⚠ 枠の数は `get_skill_slot_count()` が決める（⚠ 2 と書かない）。⚠ 並び順は characters.json の "skills"。
# ⚠ チャージは `activation` が `charge` のスキルだけが持つ（⚠ 無い値は出さない）。
# ⚠ 購読するシグナルは character_growth_changed の1本だけ。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。

const DESCRIPTION_PREFIX: String = "ui_desc_"
const CANDIDATE_COLUMNS: int = 2

var _character_id: String = ""
# 次に選んだスキルを入れる枠。⚠ 状態ではなく画面の都合なのでセーブしない。
var _active_slot: int = 0


func setup(character_id: String) -> void:
	_character_id = character_id
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _character_id == "":
		return
	var all_candidates: Array = GameManager.get_all_skill_candidates(_character_id, GameManager.SLOT_KIND_SKILL)
	var unlocked: Array = GameManager.get_skill_candidates(_character_id, GameManager.SLOT_KIND_SKILL)

	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_training_skills_heading"
	heading.right_text = tr("ui_training_skills_known") % [unlocked.size(), all_candidates.size()]
	add_child(heading)

	var selected: Array = GameManager.get_selected_skills(_character_id, GameManager.SLOT_KIND_SKILL)
	var slots: HBoxContainer = HBoxContainer.new()
	slots.name = "Slots"
	add_child(slots)
	for i: int in range(GameManager.get_skill_slot_count()):
		slots.add_child(_create_slot(i, "" if i >= selected.size() else str(selected[i])))

	var candidates: GridContainer = GridContainer.new()
	candidates.name = "Candidates"
	candidates.columns = CANDIDATE_COLUMNS
	add_child(candidates)
	for entry: Variant in all_candidates:
		var skill_id: String = str(entry)
		candidates.add_child(_create_candidate(skill_id, skill_id in unlocked, selected.find(skill_id)))


func _create_slot(slot_index: int, skill_id: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Slot_%d" % slot_index
	row.selected = slot_index == _active_slot
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = float(get_theme_constant(&"skill_slot_height", &"Training"))
	row.pressed.connect(_on_slot_pressed.bind(slot_index))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)

	var number: Label = Label.new()
	number.name = "NumberLabel"
	number.theme_type_variation = &"DossierLevelLabel"
	number.text = str(slot_index + 1)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(number)
	var icon: TextureRect = _icon(IconTextures.for_skill(skill_id) if skill_id != "" else null)
	if icon != null:
		line.add_child(icon)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	if skill_id == "":
		name_label.theme_type_variation = &"CaptionLabel"
		name_label.text = tr("ui_training_skill_pick")
	else:
		name_label.theme_type_variation = &"SheetHeadingLabel"
		name_label.text = _skill_name(skill_id)
	column.add_child(name_label)
	if skill_id != "":
		var cooldown: Label = Label.new()
		cooldown.theme_type_variation = &"CaptionLabel"
		cooldown.text = _cooldown_text(skill_id)
		column.add_child(cooldown)
		# ⚠ 空の枠を外しても何も起きないので、ボタンごと出さない。⚠ 紙の上なので `PaperChoice`。
		var clear_button: Button = UiButton.create_paper_choice("ui_equipment_unequip")
		clear_button.name = "ClearButton"
		clear_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		clear_button.pressed.connect(_on_clear_pressed.bind(slot_index))
		line.add_child(clear_button)
	return row


func _create_candidate(skill_id: String, is_unlocked: bool, slot_index: int) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Candidate_" + skill_id
	row.selected = slot_index >= 0
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 判定は GameManager 側と同じもの（⚠ 画面で条件を作り直さない）。
	var can_select: bool = GameManager.can_select_skill(_character_id, _active_slot, skill_id, GameManager.SLOT_KIND_SKILL)
	# ⚠ 未解放は沈める（⚠ 消さない＝次に何が来るかは見せる）。⚠ 入っている候補は沈めない。
	row.disabled = not is_unlocked or (not can_select and slot_index < 0)
	row.pressed.connect(_on_candidate_pressed.bind(skill_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var icon: TextureRect = _icon(IconTextures.for_skill(skill_id))
	if icon != null:
		line.add_child(icon)

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
	var description: String = _description_of(skill_id)
	if description != "":
		var caption: Label = Label.new()
		caption.name = "EffectLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text = description
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


func _cooldown_text(skill_id: String) -> String:
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	return tr("ui_skill_select_cooldown") % float(data.get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))


func _icon(texture: Texture2D) -> TextureRect:
	if texture == null:
		return null
	var side: float = float(get_theme_constant(&"row_icon", &"Training")) * 1.5
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.modulate = get_theme_color(&"row_icon", &"Training")
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _skill_name(skill_id: String) -> String:
	var skill_data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if skill_data.is_empty():
		# skills.json から消えたID。セーブには残るがフォールバックで別のものが出る。
		return skill_id
	return tr(str(skill_data.get("name_key", "")))


# ⚠ 効果文は `ui_desc_<skill_id>`。⚠ 無ければ空（⚠ `tr()` は表に無いキーをそのまま返す）。
func _description_of(skill_id: String) -> String:
	var key: String = DESCRIPTION_PREFIX + skill_id
	var text: String = tr(key)
	return "" if text == key else text


# 枠を押す。状態は触らず、次にスキルを選んだときの行き先を変えるだけ。
func _on_slot_pressed(slot_index: int) -> void:
	if slot_index == _active_slot:
		return
	_active_slot = slot_index
	_rebuild()


func _on_candidate_pressed(skill_id: String) -> void:
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	# 既に別の枠に入っているスキルを選ぶと、2つの枠が入れ替わる（GameManager 側の仕様）。
	GameManager.select_skill(_character_id, _active_slot, skill_id, GameManager.SLOT_KIND_SKILL)


func _on_clear_pressed(slot_index: int) -> void:
	GameManager.clear_skill_slot(_character_id, slot_index, GameManager.SLOT_KIND_SKILL)


func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
