class_name DossierCard
extends VBoxContainer

# 身上書カード（2026-09-27・手本 Barracks の上の3枚 → 育成の一覧へ移した）。
#
# ⚠ 人間「⚠ 上側のやつは育成に入れたほうがいい　⚠ キャラの配置とキャラ個別のものはべつにしよう」→「⚠ 3あ」。
#   ⚠ 前は詰所（`party_preset_screen`）の上に3枚あった。⚠ 詰所は配置だけになった。
# ⚠ 写真・「身上書」・名前・役割・Lv ／ HP・主な値 ／ スキル ／ 上がれるなら「昇級できる」の判 ／ 「開く ›」。
# ⚠ 紙そのものは持たない（⚠ 置く側が `TiltedSheet` の `sheet` に入れる）。
# ⚠ 「ビルド」の行は持たない（⚠ 控えに残すときの参照先＝配置の話なので詰所の出撃届へ移した）。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。

signal open_pressed(character_id: String)

# ⚠ 写真の大きさは育成の身上書と同じ値を引く（⚠ 2つ目の値を作らない）。
const TRAINING_THEME_TYPE: StringName = &"Training"

var character_id: String = ""


func setup(p_character_id: String) -> void:
	character_id = p_character_id
	name = "Card_" + character_id
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	add_child(_make_hero())
	add_child(HSeparator.new())
	var stats: Dictionary = GameManager.get_effective_stats(character_id)
	add_child(_make_stat_row(GameStateKeys.STAT_HP, stats))
	add_child(_make_stat_row(_main_stat_of(stats), stats))
	add_child(_make_text_row("Skills", tr("ui_training_skill"), _skills_text()))

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	if can_level_up(character_id):
		var stamp: Stamp = Stamp.new()
		stamp.name = "LevelUpStamp"
		stamp.label_key = "ui_barracks_can_level_up"
		foot.add_child(stamp)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)
	var open: Button = UiButton.create_paper_choice("ui_barracks_open")
	open.name = "OpenButton"
	open.size_flags_vertical = Control.SIZE_SHRINK_END
	open.pressed.connect(_on_open_pressed)
	foot.add_child(open)
	add_child(foot)


func _on_open_pressed() -> void:
	open_pressed.emit(character_id)


# ⚠ 判定は育成の概要の「昇級させる」と同じ2つ（⚠ 上限 ／ 素材）。
static func can_level_up(id: String) -> bool:
	var level: int = int(GameManager.get_character_growth(id).get(GameStateKeys.GROWTH_LEVEL, 1))
	if level >= GameManager.get_effective_level_cap(id):
		return false
	var cost: Dictionary = GameManager.get_level_up_cost(id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	return material_id != "" and GameManager.get_material_count(material_id) >= amount


# 写真・「身上書」・名前・役割・Lv。⚠ 育成の身上書（`CharacterDossier`）と同じ型の字を使う。
func _make_hero() -> HBoxContainer:
	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	hero.add_child(CharacterAvatar.create(character_id, get_theme_constant(&"dossier_photo", TRAINING_THEME_TYPE)))
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(column)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_dossier_title")
	column.add_child(caption)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"DossierNameLabel"
	name_label.text = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
	column.add_child(name_label)
	var role: Label = Label.new()
	role.theme_type_variation = &"CaptionLabel"
	# ⚠ 役割は `characters.json` に欄が無い。⚠ 検証用はIDをそのまま出す（⚠ 身上書と同じ）。
	role.text = character_id if GameManager.is_debug_character(character_id) else tr("ui_role_" + character_id)
	column.add_child(role)
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
	value.text = str(int(GameManager.get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1)))
	level_row.add_child(value)
	var of_cap: Label = Label.new()
	of_cap.theme_type_variation = &"CaptionLabel"
	of_cap.text = "/ %d" % GameManager.get_effective_level_cap(character_id)
	of_cap.size_flags_vertical = Control.SIZE_SHRINK_END
	level_row.add_child(of_cap)
	column.add_child(level_row)
	return hero


# 「HP ………… 120」。⚠ 押せない台帳の行（⚠ 罫だけ借りる）。
func _make_stat_row(stat_key: String, stats: Dictionary) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "Stat_" + stat_key
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var label: Label = Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = tr("ui_training_stat_" + stat_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	var amount: int = int(stats.get(stat_key, 0))
	value.text = "%d%%" % amount if GameManager.is_percent_stat(stat_key) else str(amount)
	line.add_child(value)
	return row


# 「スキル  強撃・［空き］」の形。⚠ 左の小さな見出し ＋ 中身。
func _make_text_row(row_name: String, caption_text: String, value_text: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.compact = true
	row.show_rule = false
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	caption.custom_minimum_size.x = float(get_theme_constant(&"dossier_photo", TRAINING_THEME_TYPE)) * 0.66
	line.add_child(caption)
	var value: Label = Label.new()
	value.name = "ValueLabel"
	value.theme_type_variation = &"SmallLabel"
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(value)
	return row


# ⚠ 主な値は「攻撃」か「魔力」の大きいほう（⚠ 手本は HP と攻撃。⚠ 僧侶の手本は「[攻]」の仮のまま）。
func _main_stat_of(stats: Dictionary) -> String:
	if int(stats.get(GameStateKeys.STAT_MAG, 0)) > int(stats.get(GameStateKeys.STAT_ATK, 0)):
		return GameStateKeys.STAT_MAG
	return GameStateKeys.STAT_ATK


func _skills_text() -> String:
	var parts: Array[String] = []
	var selected: Array = GameManager.get_selected_skills(character_id, GameManager.SLOT_KIND_SKILL)
	for i: int in range(GameManager.get_skill_slot_count()):
		var skill_id: String = str(selected[i]) if i < selected.size() else ""
		if skill_id == "":
			parts.append(tr("ui_barracks_skill_empty"))
		else:
			parts.append(tr(str(MasterDataLoader.get_skill(skill_id).get("name_key", skill_id))))
	return tr("ui_barracks_skill_separator").join(parts)
