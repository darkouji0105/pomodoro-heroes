class_name CharacterDossier
extends VBoxContainer

# 身上書（2026-09-27・回UI-組 育成・手本 Character の左の紙）。
#
# ⚠ 冒険者ギルド ／ 身上書（真ん中の題と飾り罫）／ 写真・名前・役割・Lv ／ 10軸の値 ／ 本人署名。
# ⚠ 紙そのものは持たない（⚠ 置く側が `TiltedSheet` の `sheet` に入れる＝少し傾く）。
# ⚠ 写真は顔の絵が無いので `CharacterAvatar`（⚠ 段階13・素材待ち）。⚠ 署名は明朝（⚠ サインの字体は `UI-12`「まだ」）。
# ⚠ 手本の値の横の棒は出さない（⚠ 棒の最大がデータに無い）。
# ⚠ 値は `get_effective_stats()`（⚠ 素＋研究＋装備＋割り振り）、⚠ 緑は装備で増えた分（⚠ 前の育成の詳細と同じ）。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。
# ⚠⚠ 10-18（回UI-1018-4・web版の手本 `02_training_ov.png`）：⚠ 一番上に「◀ 前の人｜n / 18 人・一覧へ｜次の人 ▶」（⚠ 上の顔の列をやめた代わり）。
#   ⚠ 名前の下にスキル2つ（ふちつき）と装備5つ（触れると札・押すとそのタブ）。⚠ 本人署名はやめた（⚠ 縦が足りない）。

signal prev_pressed
signal next_pressed
signal list_pressed
# ⚠ スキル・装備のアイコンを押した（⚠ "skill" / "equip"＝画面がそのタブを開く）。
signal loadout_pressed(kind: String)

const THEME_TYPE: StringName = &"Training"

var _character_id: String = ""
# ⚠ 前後の人と、何人目か（⚠ 画面が渡す）。⚠ 空なら矢印は押せない。
var prev_id: String = ""
var next_id: String = ""
var nav_index: int = 0
var nav_total: int = 0
var tip: ItemTipCard = null


func setup(character_id: String) -> void:
	_character_id = character_id
	_rebuild()


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if _character_id == "":
		return
	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	var name_text: String = tr(str(char_data.get("name_key", _character_id)))

	add_child(_build_nav())
	add_child(HSeparator.new())

	add_child(_build_hero(name_text))
	add_child(_build_loadout())
	add_child(_build_stats())


# 「◀ [顔] 前の人 ｜ n / 18 人 ・ 一覧へ ｜ 次の人 [顔] ▶」。
func _build_nav() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Nav"
	var prev: Button = _small_button()
	prev.name = "PrevButton"
	prev.text = "◀ " + _short_name(prev_id)
	prev.disabled = prev_id == ""
	prev.pressed.connect(func() -> void: prev_pressed.emit())
	row.add_child(prev)
	var middle: HBoxContainer = HBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(middle)
	var count: Label = Label.new()
	count.name = "NavCount"
	count.theme_type_variation = &"CaptionLabel"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.text = tr("ui_dossier_nav_count") % [nav_index, nav_total]
	middle.add_child(count)
	var list: Button = _small_button()
	list.text = tr("ui_dossier_nav_list")
	list.name = "ListButton"
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.pressed.connect(func() -> void: list_pressed.emit())
	middle.add_child(list)
	var next: Button = _small_button()
	next.name = "NextButton"
	next.text = _short_name(next_id) + " ▶"
	next.disabled = next_id == ""
	next.pressed.connect(func() -> void: next_pressed.emit())
	row.add_child(next)
	return row


# ⚠ 小さい紙の札（⚠ `PaperChoice` は丸くて背が高い＝身上書が画面の下へはみ出した）。
func _small_button() -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"PaperToggle"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _short_name(character_id: String) -> String:
	if character_id == "":
		return ""
	return tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))


# 「スキル [枠][枠] 強撃・横薙ぎ ／ 装備 [5つ]」（⚠ 押すとそのタブ）。
func _build_loadout() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Loadout"
	panel.theme_type_variation = &"LoadoutPanel"
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var side: int = get_theme_constant(&"loadout_icon", THEME_TYPE)
	var skill_row: HBoxContainer = HBoxContainer.new()
	skill_row.name = "SkillRow"
	column.add_child(skill_row)
	skill_row.add_child(_loadout_caption("ui_training_skill"))
	var skills: LoadoutIcons = LoadoutIcons.skills(_character_id, side)
	skills.pressed.connect(func(kind: String) -> void: loadout_pressed.emit(kind))
	skill_row.add_child(skills)
	var names: Array[String] = []
	for raw: Variant in GameManager.get_selected_skills(_character_id):
		if raw != null and str(raw) != "":
			names.append(tr(str(MasterDataLoader.get_skill(str(raw)).get("name_key", ""))))
	var skill_names: Label = Label.new()
	skill_names.name = "SkillNames"
	skill_names.theme_type_variation = &"CaptionLabel"
	skill_names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skill_names.text = "\n".join(names) if not names.is_empty() else tr("ui_dossier_no_skill")
	skill_row.add_child(skill_names)
	if GameManager.is_screen_unlocked(GameStateKeys.SCREEN_EQUIPMENT):
		var equip_row: HBoxContainer = HBoxContainer.new()
		equip_row.name = "EquipRow"
		column.add_child(equip_row)
		equip_row.add_child(_loadout_caption("ui_training_equipment"))
		var equipment: LoadoutIcons = LoadoutIcons.equipment(_character_id, side, tip)
		equipment.pressed.connect(func(kind: String) -> void: loadout_pressed.emit(kind))
		equip_row.add_child(equipment)
	return panel


func _loadout_caption(key: String) -> Label:
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr(key)
	caption.custom_minimum_size.x = float(get_theme_constant(&"loadout_caption", THEME_TYPE))
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return caption


# 写真・名前・役割・Lv。
func _build_hero(name_text: String) -> HBoxContainer:
	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	hero.add_child(CharacterAvatar.create(_character_id, get_theme_constant(&"dossier_photo", THEME_TYPE)))

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(column)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"DossierNameLabel"
	name_label.text = name_text
	column.add_child(name_label)

	var role: Label = Label.new()
	role.theme_type_variation = &"CaptionLabel"
	# ⚠ 役割は `characters.json` に欄が無い。⚠ 検証用はIDをそのまま出す（⚠ 前の一覧と同じ）。
	role.text = _character_id if GameManager.is_debug_character(_character_id) else tr("ui_role_" + _character_id)
	column.add_child(role)

	var level: int = int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var cap: int = GameManager.get_effective_level_cap(_character_id)
	var level_row: HBoxContainer = HBoxContainer.new()
	level_row.name = "LevelRow"
	var lv: Label = Label.new()
	lv.theme_type_variation = &"CaptionLabel"
	lv.text = tr("ui_dossier_lv")
	lv.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(lv)
	var value: Label = Label.new()
	value.name = "LevelLabel"
	value.theme_type_variation = &"DossierLevelLabel"
	value.text = str(level)
	level_row.add_child(value)
	var of_cap: Label = Label.new()
	of_cap.theme_type_variation = &"CaptionLabel"
	of_cap.text = "/ %d" % cap
	of_cap.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(of_cap)
	column.add_child(level_row)
	return hero


# 10軸。⚠ 絵・名前 ／ 値 ／ 装備で増えた分（緑）。⚠ 行の下に点線の罫。
func _build_stats() -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Stats"
	list.theme_type_variation = &"DossierStats"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stats: Dictionary = GameManager.get_effective_stats(_character_id)
	var bonus: Dictionary = GameManager.get_equipment_bonus(_character_id)
	var icon_size: float = float(get_theme_constant(&"stat_icon", THEME_TYPE))
	var icon_color: Color = get_theme_color(&"row_icon", THEME_TYPE)
	for stat_key: String in GameManager.get_stat_keys():
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Stat_" + stat_key
		var texture: Texture2D = IconTextures.for_stat(stat_key)
		if texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(icon_size, icon_size)
			icon.modulate = icon_color
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
		var name_label: Label = Label.new()
		name_label.theme_type_variation = &"SmallLabel"
		name_label.text = tr("ui_training_stat_" + stat_key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var value: Label = Label.new()
		value.name = "ValueLabel"
		value.text = _stat_text(stat_key, int(stats.get(stat_key, 0)))
		row.add_child(value)
		var added: int = int(bonus.get(stat_key, 0))
		var delta: Label = Label.new()
		delta.name = "DeltaLabel"
		# ⚠ 10-07（回HB-2）：⚠ 型の「下げる値」で減ることがある＝⚠ 減ったら赤で「-10」。
		delta.theme_type_variation = &"ErrorLabel" if added < 0 else &"GainLabel"
		# ⚠ 増えていない行にも空の欄を置く（⚠ 置かないと値の右端が行ごとにずれる）。
		delta.text = "+" + _stat_text(stat_key, added) if added > 0 else (_stat_text(stat_key, added) if added < 0 else "")
		delta.custom_minimum_size.x = icon_size * 3.0
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(delta)
		list.add_child(row)
	return list


# ％系は "25%"。⚠ 前の育成の詳細と同じ判定（`GameManager.is_percent_stat`）。
func _stat_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
