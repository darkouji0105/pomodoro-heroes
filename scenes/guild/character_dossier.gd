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

const THEME_TYPE: StringName = &"Training"

var _character_id: String = ""


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

	var guild: Label = Label.new()
	guild.theme_type_variation = &"CaptionLabel"
	guild.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guild.text = tr("ui_title_guild")
	add_child(guild)

	var heading: SheetHeading = SheetHeading.new()
	heading.name = "Heading"
	heading.title_key = "ui_dossier_title"
	heading.ornament = true
	heading.ornament_below = true
	heading.centered = true
	add_child(heading)

	add_child(_build_hero(name_text))
	add_child(_build_stats())

	var sign_row: HBoxContainer = HBoxContainer.new()
	sign_row.name = "SignRow"
	var sign_caption: Label = Label.new()
	sign_caption.theme_type_variation = &"CaptionLabel"
	sign_caption.text = tr("ui_dossier_signature")
	sign_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sign_caption.size_flags_vertical = Control.SIZE_SHRINK_END
	sign_row.add_child(sign_caption)
	var signature: Label = Label.new()
	signature.theme_type_variation = &"SheetHeadingLabel"
	signature.text = name_text
	sign_row.add_child(signature)
	add_child(sign_row)


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
