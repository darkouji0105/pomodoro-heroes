# res://scenes/guild/level_up_screen.gd
# 昇級（2026-09-27・回UI-組 育成・手本 LevelUp / LevelUpDone・人間「⚠ 3あ」）。
#
# ⚠ 左：昇級申請書（⚠ 写真・名前・「1 → 2」・ステータスノードの点 +1・次に覚えるスキル ／ 右下に「ここに判」）。
# ⚠ 右：使うもの（⚠ 修練の証 3 ／ のこり 57 → 54）と ⚠ 「判を押して昇級させる」「やめる」。
# ⚠ 押すと判（「昇級」）が落ち、⚠ 「Lv 2」になる。⚠ 右は「点を振りに行く」「続けて昇級させる」「育成へ戻る」。
# ⚠ 判は長押しにしない（⚠ 取り返しのつかない操作ではない・人間の選択）。
# ⚠ 昇級そのものは `GameManager.level_up_character()` の1本（⚠ 判定もあちら。⚠ ここは押せる／押せないを出すだけ）。
# ⚠ 手本の3人のひとこと（吹き出し）は入れていない（⚠ 台詞のデータが無い）。
# ⚠ 育成からしか来ないので scenes/guild/（AGENTS.md）。

extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"
const THEME_TYPE: StringName = &"Training"

var _character_id: String = ""
# ⚠ 判を押したあとか（⚠ 状態ではなく画面の都合）。
var _done: bool = false

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var body: HBoxContainer = $Margin/Layout/Body


func _ready() -> void:
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))
	header.back_pressed.connect(_back_to_training.bind(TransferKeys.TRAINING_TAB_OVERVIEW))
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに（⚠ 本部の右上の素材16件はやめた）。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_TRAINING_MATERIAL_PREFIX))
	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	header.set_subtitle_text(tr(str(char_data.get("name_key", ""))))
	if _character_id == "":
		push_warning("[LevelUpScreen] character_id が渡されていない")
	_rebuild()


# remove_child してから queue_free する（AGENTS.md「再描画は await を持たせない」）。
func _rebuild() -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if _character_id == "":
		return
	body.add_child(_build_form())
	body.add_child(_build_side())


# --- 左：昇級申請書 ---

func _build_form() -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.create(1)
	holder.name = "Form"
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.sheet.add_child(column)

	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_level_up_form"
	heading.ornament = true
	heading.ornament_below = true
	heading.centered = true
	column.add_child(heading)

	var level: int = _level()
	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	var hero: HBoxContainer = HBoxContainer.new()
	hero.name = "Hero"
	hero.add_child(CharacterAvatar.create(_character_id, get_theme_constant(&"dossier_photo", THEME_TYPE)))
	var who: VBoxContainer = VBoxContainer.new()
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(who)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"DossierNameLabel"
	name_label.text = tr(str(char_data.get("name_key", _character_id)))
	who.add_child(name_label)
	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	if _done:
		level_label.theme_type_variation = &"LevelDoneLabel"
		level_label.text = tr("ui_level_up_done_level") % level
	else:
		level_label.theme_type_variation = &"LevelArrowLabel"
		level_label.text = tr("ui_training_level_arrow") % [level, level + 1]
	who.add_child(level_label)
	column.add_child(hero)

	column.add_child(_create_gain_row())
	var next_skill: String = _next_skill()
	if next_skill != "":
		var skill_row: LedgerRow = _plain_row("SkillRow")
		var line: HBoxContainer = skill_row.get_child(0) as HBoxContainer
		var label: Label = Label.new()
		label.text = tr("ui_level_up_next_skill") % GameManager.get_skill_unlock_level(next_skill)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var skill_name: Label = Label.new()
		skill_name.name = "SkillName"
		skill_name.text = tr(str(MasterDataLoader.get_skill(next_skill).get("name_key", next_skill)))
		line.add_child(skill_name)
		column.add_child(skill_row)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	var approver: Label = Label.new()
	approver.theme_type_variation = &"CaptionLabel"
	approver.text = tr("ui_level_up_approver")
	approver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	approver.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(approver)
	foot.add_child(_build_seal())
	column.add_child(foot)
	return holder


# 「ステータスノードの点 +1」。⚠ 判のあとは「振りに行く ›」を足す。
func _create_gain_row() -> LedgerRow:
	var row: LedgerRow = _plain_row("PointRow")
	var line: HBoxContainer = row.get_child(0) as HBoxContainer
	var label: Label = Label.new()
	label.text = tr("ui_level_up_point")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var gain: Label = Label.new()
	gain.theme_type_variation = &"GainLabel"
	# ⚠ ポイントは必ず +1（⚠ `get_stat_node_total_points()` が「レベル-1」）。
	gain.text = tr("ui_level_up_point_gain")
	line.add_child(gain)
	if _done:
		var go: Button = UiButton.create_paper_choice("ui_level_up_go_nodes_short")
		go.name = "GoNodesLink"
		go.pressed.connect(_back_to_training.bind(TransferKeys.TRAINING_TAB_NODES))
		line.add_child(go)
	return row


func _plain_row(row_name: String) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	# ⚠ 行そのものは押せない（⚠ 中の本物のボタンだけ）。
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(HBoxContainer.new())
	return row


# 右下の判。⚠ 押す前は「ここに判」の点線の丸、⚠ 押したあとは「昇級」の判（`Stamp` の丸）。
func _build_seal() -> Control:
	var side: float = float(get_theme_constant(&"seal", THEME_TYPE))
	if _done:
		var stamp: Stamp = Stamp.new()
		stamp.name = "Seal"
		stamp.shape = Stamp.Shape.CIRCLE
		stamp.label_key = "ui_stamp_level_up_done"
		return stamp
	var seal: Control = Control.new()
	seal.name = "Seal"
	seal.custom_minimum_size = Vector2(side, side)
	seal.draw.connect(_draw_seal_hint.bind(seal))
	return seal


func _draw_seal_hint(seal: Control) -> void:
	var color: Color = get_theme_color(&"seal", THEME_TYPE)
	var center: Vector2 = seal.size * 0.5
	var radius: float = minf(seal.size.x, seal.size.y) * 0.5 - 1.0
	var steps: int = 40
	for i: int in range(0, steps, 2):
		var a0: float = TAU * float(i) / float(steps)
		var a1: float = TAU * float(i + 1) / float(steps)
		seal.draw_line(center + Vector2.from_angle(a0) * radius, center + Vector2.from_angle(a1) * radius, color, 1.0)
	var font: Font = seal.get_theme_font(&"font", &"CaptionLabel")
	var font_size: int = seal.get_theme_font_size(&"font_size", &"CaptionLabel")
	var text: String = tr("ui_level_up_seal_here")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	seal.draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- 右：使うもの・ボタン ---

func _build_side() -> VBoxContainer:
	var side: VBoxContainer = VBoxContainer.new()
	side.name = "Side"
	side.custom_minimum_size.x = float(get_theme_constant(&"level_up_side_width", THEME_TYPE))
	var cost: Dictionary = GameManager.get_level_up_cost(_character_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))
	var owned: int = GameManager.get_material_count(material_id)
	var can_level: bool = _can_level_up()

	var card: PaperSheet = PaperSheet.new()
	card.name = "CostCard"
	card.show_corners = false
	side.add_child(card)
	var card_column: VBoxContainer = VBoxContainer.new()
	card.add_child(card_column)
	if _done:
		var left: Label = Label.new()
		left.name = "LeftLabel"
		left.text = tr("ui_level_up_left") % [tr("ui_res_" + material_id), owned]
		card_column.add_child(left)
	else:
		var caption: Label = Label.new()
		caption.theme_type_variation = &"CaptionLabel"
		caption.text = tr("ui_level_up_uses")
		card_column.add_child(caption)
		var line: HBoxContainer = HBoxContainer.new()
		var texture: Texture2D = IconTextures.for_item(material_id)
		if texture != null:
			var icon: TextureRect = TextureRect.new()
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_side: float = float(get_theme_constant(&"row_icon", THEME_TYPE)) * 1.5
			icon.custom_minimum_size = Vector2(icon_side, icon_side)
			icon.modulate = get_theme_color(&"row_icon", THEME_TYPE)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(icon)
		var material_label: Label = Label.new()
		material_label.text = tr("ui_res_" + material_id)
		material_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		material_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(material_label)
		var amount_label: Label = Label.new()
		amount_label.name = "AmountLabel"
		amount_label.theme_type_variation = &"DossierLevelLabel"
		amount_label.text = str(amount)
		line.add_child(amount_label)
		card_column.add_child(line)
		var remain: Label = Label.new()
		remain.name = "RemainLabel"
		remain.theme_type_variation = &"" if owned >= amount else &"ErrorLabel"
		remain.text = tr("ui_level_up_remain") % [owned, maxi(0, owned - amount)]
		card_column.add_child(remain)
		# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓（⚠ 行った先の「戻る」でこの申請書へ戻る）。
		# ⚠ 紙の上なので紙の札（⚠ Ghost は紙の上で読めない＝撮った絵）。
		var source: Button = UiButton.create_paper_choice("ui_source_open")
		source.name = "SourceButton"
		source.pressed.connect(ItemSourceWindow.open.bind(self, material_id, amount, {TransferKeys.CHARACTER_ID: _character_id}))
		card_column.add_child(source)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)

	if _done:
		var go: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_level_up_go_nodes")
		go.name = "GoNodesButton"
		go.pressed.connect(_back_to_training.bind(TransferKeys.TRAINING_TAB_NODES))
		side.add_child(go)
		var again: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_level_up_again")
		again.name = "AgainButton"
		again.disabled = not can_level
		again.pressed.connect(_on_again_pressed)
		side.add_child(again)
		var back: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_level_up_back")
		back.name = "BackToTrainingButton"
		back.pressed.connect(_back_to_training.bind(TransferKeys.TRAINING_TAB_OVERVIEW))
		side.add_child(back)
	else:
		var press: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_level_up_press")
		press.name = "PressButton"
		# ⚠ 押せてから失敗するより、押せないほうが分かりやすい（⚠ 判定は前の育成の詳細と同じ2つ）。
		press.disabled = not can_level
		press.pressed.connect(_on_press_pressed)
		side.add_child(press)
		var cancel: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_common_cancel")
		cancel.name = "CancelButton"
		cancel.pressed.connect(_back_to_training.bind(TransferKeys.TRAINING_TAB_OVERVIEW))
		side.add_child(cancel)
	return side


# --- 判定と操作 ---

func _level() -> int:
	return int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))


# ⚠ 上限 ／ 素材の2つ（⚠ 前の育成の詳細と同じ）。⚠ 本当の判定は `level_up_character()` が持つ。
func _can_level_up() -> bool:
	if _level() >= GameManager.get_effective_level_cap(_character_id):
		return false
	var cost: Dictionary = GameManager.get_level_up_cost(_character_id)
	var material_id: String = str(cost.get(GameManager.LEVEL_UP_COST_MATERIAL_ID, ""))
	return GameManager.get_material_count(material_id) >= int(cost.get(GameManager.LEVEL_UP_COST_AMOUNT, 0))


# ⚠ いまのレベルより後で解放される、いちばん近いスキル（⚠ 無ければ空＝行を出さない）。
func _next_skill() -> String:
	var level: int = _level()
	var best: String = ""
	var best_level: int = 0
	for entry: Variant in GameManager.get_all_skill_candidates(_character_id, GameManager.SLOT_KIND_SKILL):
		var unlock: int = GameManager.get_skill_unlock_level(str(entry))
		if unlock > level and (best == "" or unlock < best_level):
			best = str(entry)
			best_level = unlock
	return best


func _on_press_pressed() -> void:
	if not GameManager.level_up_character(_character_id):
		return
	_done = true
	_rebuild()


func _on_again_pressed() -> void:
	_done = false
	_rebuild()


# ⚠ 10-06（`NAV-18`）：⚠ 育成は寄り道で昇級を開く＝⚠ 積んだ戻り先へ（⚠ 育成の下に積んである記録・詰所の戻り先を消さない）。
func _back_to_training(tab_id: String) -> void:
	SceneManager.go_back_or(TRAINING_PATH, {
		TransferKeys.CHARACTER_ID: _character_id, TransferKeys.TRAINING_TAB: tab_id,
	})
