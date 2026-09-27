class_name TrainingNodesPage
extends VBoxContainer

# 育成のタブ「ステータスノード」（2026-09-27・回UI-組 育成・手本 Nodes）。
#
# ⚠ 前は独立した画面（`stat_node_screen`）。⚠ 人間「⚠ 1い」＝1画面の中でタブを切り替える形にしたので中身をここへ移した。
# ⚠ 左：軸ごとに1行（⚠ 絵・軸名・次の1段 ／ 段の点 ／ 合計 ／ ＋）。⚠ 右：修練の道（パッシブ）。
# ⚠ 前の「振ったあとのステータス」の列は消した（⚠ 同じ値が左の身上書に常に出ている）。
#
# ⚠⚠ **＋は1回に1段**（人間の決定・2026-09-12）＝ `unlock_stat_node()` を1回呼ぶだけ。
# ⚠⚠ **行は allocatable_stats に従う**（⚠ ここで軸を決め打ちしない）。
# ⚠ パッシブは総ポイントで自動解放（決定 `GR-1`）。⚠ 表示はここ（`GR-2`）。
# ⚠ 購読するシグナルは character_growth_changed の1本だけ（⚠ 解放も振り直しも素材を触らない）。
# ⚠ 育成でしか使わないので scenes/guild/（AGENTS.md）。

const DESCRIPTION_PREFIX: String = "ui_desc_"

var _character_id: String = ""


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
	var remaining: int = GameManager.get_stat_node_remaining_points(_character_id)

	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_training_nodes_heading"
	heading.right_text = tr("ui_training_nodes_remaining") % remaining
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var reset: Button = UiButton.create_paper_choice("ui_stat_node_reset")
	reset.name = "ResetButton"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ⚠ 解放が0件のときに押しても何も起きないので、押せなくしておく。
	reset.disabled = GameManager.get_stat_nodes(_character_id).is_empty()
	reset.pressed.connect(_on_reset_pressed)
	head.add_child(reset)
	add_child(head)

	var body: HBoxContainer = HBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"WideRow"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	var branches: VBoxContainer = VBoxContainer.new()
	branches.name = "Branches"
	branches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(branches)
	_build_branches(branches, remaining)

	var passives: VBoxContainer = _build_passives()
	if passives != null:
		body.add_child(VSeparator.new())
		body.add_child(passives)


func _build_branches(branches: VBoxContainer, remaining: int) -> void:
	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	var allocatable: Variant = char_data.get("allocatable_stats", [])
	if not (allocatable is Array):
		push_warning("[TrainingNodesPage] allocatable_stats が配列ではない: " + _character_id)
		return
	var all_nodes: Dictionary = MasterDataLoader.get_all_character_nodes()
	var unlocked: Array = GameManager.get_stat_nodes(_character_id)
	# ⚠ 段が1つも無いキャラ（⚠ 検証用・宿題80）は空の状態を1つ出す（⚠ 中身の無い行を並べない）。
	var total_entries: int = 0
	for stat_key: Variant in (allocatable as Array):
		total_entries += _branch_nodes(str(stat_key), all_nodes).size()
	if total_entries == 0:
		branches.add_child(EmptyState.create("ui_stat_node_empty"))
		return
	for stat_key: Variant in (allocatable as Array):
		branches.add_child(_create_branch_row(str(stat_key), all_nodes, unlocked, remaining))


# 1つの軸ぶんの行。⚠ 押す場所は＋の1つだけ（⚠ 行ぜんぶは押せない）。
func _create_branch_row(stat_key: String, all_nodes: Dictionary, unlocked: Array, remaining: int) -> LedgerRow:
	var entries: Array = _branch_nodes(stat_key, all_nodes)
	var done: int = 0
	var total_value: int = 0
	var next_entry: Dictionary = {}
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) in unlocked:
			done += 1
			total_value += int(entry.get("value", 0))
		elif next_entry.is_empty():
			next_entry = entry

	var row: LedgerRow = LedgerRow.new()
	row.name = "Branch_" + stat_key
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var icon: TextureRect = _icon(IconTextures.for_stat(stat_key))
	if icon != null:
		line.add_child(icon)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	var title_row: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = tr("ui_training_stat_" + stat_key)
	title_row.add_child(title)
	var next_label: Label = Label.new()
	next_label.name = "NextLabel"
	next_label.theme_type_variation = &"CaptionLabel"
	next_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if next_entry.is_empty():
		next_label.text = tr("ui_stat_node_taken")
	else:
		next_label.text = tr("ui_training_nodes_next") % [
			int(next_entry.get("cost", 0)), _value_text(stat_key, int(next_entry.get("value", 0))),
		]
	title_row.add_child(next_label)
	column.add_child(title_row)
	# ⚠ 段が1つも無い軸は点を出さない（⚠ 0個の器を置くと行の高さだけが空く）。
	if not entries.is_empty():
		var dots: TierDots = TierDots.new()
		dots.name = "Dots"
		dots.setup(entries.size(), done)
		column.add_child(dots)

	var total_label: Label = Label.new()
	total_label.name = "TotalLabel"
	total_label.theme_type_variation = &"GainLabel" if total_value > 0 else &"MutedLabel"
	total_label.text = _value_text(stat_key, total_value)
	total_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(total_label)

	# ⚠ 押せてから失敗するより、押せないほうが分かりやすい。⚠ 紙の上なので `PaperChoice`（⚠ Ghost は字が明るすぎる）。
	var add: Button = UiButton.create_paper_choice("ui_stat_node_add")
	add.name = "AddButton"
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if next_entry.is_empty():
		add.disabled = true
	else:
		var node_id: String = str(next_entry.get("id", ""))
		var can_unlock: bool = GameManager.can_unlock_stat_node(_character_id, node_id)
		add.disabled = not (can_unlock and remaining >= int(next_entry.get("cost", 0)))
		add.pressed.connect(_on_node_pressed.bind(node_id))
	line.add_child(add)
	return row


# ⚠ 修練の道（パッシブ）。⚠ 解放済みは墨・未解放は薄く（⚠ 消さない＝先に何が在るかは見せる）。
# ⚠ パッシブを持たないキャラ（⚠ 検証用）は列ごと出さない。
func _build_passives() -> VBoxContainer:
	var all_passives: Array = GameManager.get_all_skill_candidates(_character_id, GameManager.SLOT_KIND_PASSIVE)
	if all_passives.is_empty():
		return null
	var unlocked: Array = GameManager.get_skill_candidates(_character_id, GameManager.SLOT_KIND_PASSIVE)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Passives"
	column.custom_minimum_size.x = float(get_theme_constant(&"dossier_width", &"Training")) * 0.8
	var title: Label = Label.new()
	title.theme_type_variation = &"SectionLabel"
	title.text = tr("ui_training_passive_road")
	column.add_child(title)
	for entry: Variant in all_passives:
		var passive_id: String = str(entry)
		column.add_child(_create_passive_row(passive_id, passive_id in unlocked))
	return column


func _create_passive_row(passive_id: String, is_unlocked: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Passive_" + passive_id
	row.modulate.a = 1.0 if is_unlocked else 0.5
	# ⚠ 何 pt で開くか（⚠ 手本の丸の中の数字）。
	var points: Label = Label.new()
	points.name = "PointsLabel"
	points.theme_type_variation = &"AccentLabel" if is_unlocked else &"CaptionLabel"
	points.text = str(GameManager.get_passive_unlock_points(passive_id))
	points.custom_minimum_size.x = float(get_theme_constant(&"row_icon", &"Training")) * 2.0
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(points)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	var skill_data: Dictionary = MasterDataLoader.get_skill(passive_id)
	name_label.text = tr(str(skill_data.get("name_key", passive_id)))
	column.add_child(name_label)
	var key: String = DESCRIPTION_PREFIX + passive_id
	if tr(key) != key:
		var caption: Label = Label.new()
		caption.name = "EffectLabel"
		caption.theme_type_variation = &"CaptionLabel"
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.text = tr(key)
		column.add_child(caption)
	return row


func _icon(texture: Texture2D) -> TextureRect:
	if texture == null:
		return null
	var side: float = float(get_theme_constant(&"row_icon", &"Training"))
	var rect: TextureRect = TextureRect.new()
	rect.name = "Icon"
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.modulate = get_theme_color(&"row_icon", &"Training")
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


# 1つの軸に属するノードを段の順に並べて返す（⚠ 前の画面から移した）。
# 戻り値の要素: {"id": String, "tier": int, "cost": int, "value": int}
# ⚠ int にしているのは MasterDataLoader が JSON をそのまま返すため（3.0 のような float で来る）。
func _branch_nodes(stat_key: String, all_nodes: Dictionary) -> Array:
	var result: Array = []
	for node_id: Variant in all_nodes:
		var definition: Dictionary = all_nodes[node_id]
		if str(definition.get(GameManager.STAT_NODE_CHARACTER_ID, "")) != _character_id:
			continue
		if str(definition.get(GameManager.STAT_NODE_STAT, "")) != stat_key:
			continue
		result.append({
			"id": str(node_id),
			"tier": int(definition.get(GameManager.STAT_NODE_TIER, 0)),
			"cost": int(definition.get(GameManager.STAT_NODE_COST, 0)),
			"value": int(definition.get(GameManager.STAT_NODE_VALUE, 0)),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tier", 0)) < int(b.get("tier", 0)))
	return result


# ％系は "+5%"。実数はそのまま "+5"。
func _value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "+%d%%" % value
	return "+%d" % value


func _on_node_pressed(node_id: String) -> void:
	# 戻り値は見ない。成功なら character_growth_changed 経由で描画し直される。
	GameManager.unlock_stat_node(_character_id, node_id)


func _on_reset_pressed() -> void:
	GameManager.reset_stat_nodes(_character_id)


func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()
