class_name EnemyInfoWindow
extends RefCounted

# 敵の解説の窓（2026-10-20・回SKD-1・決定 `GR-16`）。
#
# ⚠ 人間「⚠ 敵も後々クリックしたら解説を出す予定」→ 回SEE29-D の残り →「⚠ あ」・「⚠ 後スキルの係数とかも説明したい」→「⚠ １あ　２あ」。
# ⚠ 依頼掲示板の右の紙の「敵」の札を押すと開く（⚠ 紙の窓・外を押しても閉じる）。
# ⚠ 中身：名前（＋ボス）／ 強さ（HP・攻撃・魔力・物理防御・魔法防御・移動速度）／ 通常攻撃（射程・間隔・係数の行）／ スキル（名前・CD・説明・係数の行）。
#   ⚠ 通常攻撃は説明文が無いので係数の行をいつも出す ／ ⚠ スキルの係数の行は「詳細」の切り替え（`SkillDetailLines`）。
# ⚠ 値は敵のマスターから毎回引く（⚠ 書き写さない）。⚠ 掲示板でしか使わない＝scenes/adventure/（AGENTS.md）。

const STAT_KEYS: Array[String] = ["hp", "atk", "mag", "def", "mdef", "spd"]
const THEME_TYPE: StringName = &"QuestBoard"


static func open(host: Node, enemy_id: String, is_boss: bool) -> ModalDialog:
	var data: Dictionary = MasterDataLoader.get_enemy(enemy_id)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "EnemyInfoScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = float(ThemeDB.get_project_theme().get_constant(&"enemy_info_height", THEME_TYPE))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "EnemyInfoBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	_fill(body, enemy_id, data, is_boss)
	var title: String = TranslationServer.translate(str(data.get("name_key", enemy_id)))
	if is_boss:
		title = TranslationServer.translate("ui_quest_enemy_boss") % title
	return Modal.notify(host, "", [], false, {
		Modal.OPTION_TITLE: title,
		Modal.OPTION_CONTENT: scroll,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})


# ⚠ 「詳細」を押したら中身を組み直す（⚠ 窓は閉じない・await を持たない）。
static func _fill(body: VBoxContainer, enemy_id: String, data: Dictionary, is_boss: bool) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "Top"
	body.add_child(top)
	if is_boss:
		var boss: Label = Label.new()
		boss.name = "BossTag"
		boss.theme_type_variation = &"QuestTag_hard"
		boss.text = TranslationServer.translate("ui_enemy_info_boss")
		boss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(boss)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	top.add_child(SkillDetailLines.toggle(func() -> void: _fill(body, enemy_id, data, is_boss)))

	# 強さ。
	var stats_heading: SheetHeading = SheetHeading.new()
	stats_heading.name = "StatsHeading"
	stats_heading.title_key = "ui_enemy_info_stats"
	body.add_child(stats_heading)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Stats"
	grid.columns = 2
	body.add_child(grid)
	for stat_key: String in STAT_KEYS:
		var cell: HBoxContainer = HBoxContainer.new()
		cell.name = "Stat_" + stat_key
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var icon: TextureRect = TextureRect.new()
		icon.texture = IconTextures.for_stat(stat_key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var caption: Label = Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = TranslationServer.translate("ui_training_stat_" + stat_key)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(caption)
		var value: Label = Label.new()
		value.name = "Value"
		value.text = str(int(data.get(stat_key, 0)))
		cell.add_child(value)
		SkillDetailLines.tint(icon, value)

	# 通常攻撃（⚠ 説明文が無い＝係数の行はいつも）。
	var basic_heading: SheetHeading = SheetHeading.new()
	basic_heading.name = "BasicHeading"
	basic_heading.title_key = "ui_enemy_info_basic"
	basic_heading.right_text = TranslationServer.translate("ui_enemy_info_basic_numbers") % [int(data.get("attack_range", 0)), float(data.get("attack_interval_sec", 0.0))]
	body.add_child(basic_heading)
	var basic: Variant = data.get("basic_attack", {})
	var basic_effects: Array = (basic as Dictionary).get("effects", []) as Array if basic is Dictionary else []
	var basic_lines: SkillDetailLines = SkillDetailLines.create(SkillDetailText.lines_of_effects(basic_effects, {"team": SkillSchema.TEAM_ENEMY, "mode": "select", "sort": "nearest"}))
	basic_lines.name = "BasicDetail"
	body.add_child(basic_lines)

	# スキル。
	var skills_heading: SheetHeading = SheetHeading.new()
	skills_heading.name = "SkillsHeading"
	skills_heading.title_key = "ui_enemy_info_skills"
	body.add_child(skills_heading)
	var skills: Array = data.get("skills", []) as Array
	if skills.is_empty():
		var none: Label = Label.new()
		none.name = "NoSkill"
		none.theme_type_variation = &"CaptionLabel"
		none.text = TranslationServer.translate("ui_enemy_info_no_skill")
		body.add_child(none)
	for raw: Variant in skills:
		var skill_id: String = str(raw)
		var skill: Dictionary = MasterDataLoader.get_skill(skill_id)
		var block: VBoxContainer = VBoxContainer.new()
		block.name = "Skill_" + skill_id
		block.theme_type_variation = &"TightList"
		body.add_child(block)
		var head: HBoxContainer = HBoxContainer.new()
		block.add_child(head)
		var frame: PanelContainer = LoadoutIcons.skill_frame(skill_id, 28)
		frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(frame)
		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.theme_type_variation = &"SheetHeadingLabel"
		name_label.text = TranslationServer.translate(str(skill.get("name_key", skill_id)))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(name_label)
		# ⚠ 敵のスキルは CD ではなく SP で撃つものが多い（⚠ CD 0 は出さない＝「CD 0.0秒」と出ていた）。
		var cooldown: float = float(skill.get(SkillSchema.FIELD_COOLDOWN_SEC, 0.0))
		if cooldown > 0.0:
			var cd: Label = Label.new()
			cd.theme_type_variation = &"CaptionLabel"
			cd.text = TranslationServer.translate("ui_enemy_info_cooldown") % cooldown
			cd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(cd)
		var desc_key: String = "ui_desc_" + skill_id
		var desc: String = TranslationServer.translate(desc_key)
		if desc != desc_key:
			var desc_label: Label = Label.new()
			desc_label.name = "DescLabel"
			desc_label.theme_type_variation = &"CaptionLabel"
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.text = desc
			block.add_child(desc_label)
		# ⚠ 説明文が無いスキルは係数の行をいつも出す（⚠ 何もしないスキルに見えないように）。
		if SkillDetailLines.is_on() or desc == desc_key:
			block.add_child(SkillDetailLines.for_skill(skill_id))
