class_name GoalSheet
extends VBoxContainer

# 目標の紙の中身（2026-10-09・回AUTO-1・`EXEC_GOAL.md`）。
#
# ⚠ 上の帯を押したときの窓と、別枠のサイドバーの中身は**同じこの部品**（⚠ 見比べるのは置き方だけ）。
# ⚠ 見出し ／ 品ごとの行（絵・名前・持っている数／届けたい数・「入手先」）／「目標をやめる」。
# ⚠ 数は毎回 `GameManager.get_goal_progress()` から（⚠ 判定を持たない）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

# ⚠ 窓の中で目標が消えた（届いた・やめた）とき、⚠ 窓ごと閉じたいので知らせる。
signal emptied()


static func create() -> GoalSheet:
	var sheet: GoalSheet = GoalSheet.new()
	sheet.name = "GoalSheet"
	return sheet


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameManager.goal_changed.connect(_rebuild)
	GameManager.material_changed.connect(_on_amount_changed)
	GameManager.resource_changed.connect(_on_amount_changed)
	GameManager.inventory_changed.connect(_on_amount_changed)
	_rebuild()


func _on_amount_changed(_a: Variant = null, _b: Variant = null) -> void:
	_rebuild()


# ⚠ remove_child() してから queue_free()（CLAUDE.md 5番）。⚠ await を持たせない。
func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if not GameManager.has_goal():
		emptied.emit()
		return
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_goal_title")
	add_child(title)
	var origin_text: String = GoalSheet.origin_text(GameManager.get_goal())
	if origin_text != "":
		var origin: Label = Label.new()
		origin.name = "OriginLabel"
		origin.theme_type_variation = &"CaptionLabel"
		origin.text = origin_text
		origin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(origin)
	add_child(HSeparator.new())
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "LineList"
	list.theme_type_variation = &"TightList"
	add_child(list)
	for line: Dictionary in GameManager.get_goal_progress():
		list.add_child(_make_line(line))
	# ⚠ 10-09（回AUTO-3）：⚠ おまかせで集める（⚠ 宝箱 → ショップ → 周回を画面を見せながら・`GoalRunner`）。⚠ 走っているあいだは押せない。
	var auto: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_goal_auto")
	auto.name = "AutoButton"
	auto.disabled = GoalRunner.is_running()
	auto.pressed.connect(_on_auto_pressed)
	add_child(auto)
	# ⚠ 紙の上なので紙の選び札（⚠ 透かしのボタンは暗い地用＝紙の上だと字が消える・10-09 の撮影で見た）。
	var stop: Button = UiButton.create_paper_choice("ui_goal_stop")
	stop.name = "StopButton"
	stop.pressed.connect(GameManager.clear_goal)
	add_child(stop)


func _make_line(line: Dictionary) -> LedgerRow:
	var item_id: String = str(line.get(GameManager.GOAL_LINE_ITEM_ID, ""))
	var owned: int = int(line.get(GameManager.GOAL_LINE_OWNED, 0))
	var target: int = int(line.get(GameManager.GOAL_LINE_TARGET, 0))
	var row: LedgerRow = LedgerRow.new()
	row.name = "Line_" + item_id
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: HBoxContainer = HBoxContainer.new()
	row.add_child(box)
	if not (item_id in ResourceBar.CURRENCY_IDS):
		box.add_child(ItemIcon.create(item_id))
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr(GameManager.item_name_key(item_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# ⚠ 折り返さない・切らない（⚠ サイドバーで「鍛冶／の欠／片」と3行に割れた → 切ると「鍛冶の…」・10-09 の撮影）。
	#   ⚠ 名前の幅が要る分は紙が左へ広がる。
	box.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = "%d / %d" % [owned, target]
	count_label.theme_type_variation = &"" if owned >= target else &"ErrorLabel"
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(count_label)
	var go: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_goal_sources")
	go.name = "SourceButton"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_source_pressed.bind(item_id, target))
	box.add_child(go)
	return row


# ⚠ 入手先の窓へ。⚠ 自分が窓の中なら先に閉じる（⚠ 窓は1つずつ＝閉じないと入手先の窓が後ろで待つ）。
func _on_source_pressed(item_id: String, target: int) -> void:
	var scene: Node = get_tree().current_scene
	var owner_dialog: ModalDialog = _owner_dialog()
	if owner_dialog != null:
		owner_dialog.close()
	if scene != null:
		var _window: ModalDialog = ItemSourceWindow.open(scene, item_id, target)


func _on_auto_pressed() -> void:
	var owner_dialog: ModalDialog = _owner_dialog()
	if owner_dialog != null:
		owner_dialog.close()
	var _runner: GoalRunner = GoalRunner.start(self)


func _owner_dialog() -> ModalDialog:
	var node: Node = get_parent()
	while node != null:
		if node is ModalDialog:
			return node as ModalDialog
		node = node.get_parent()
	return null


# 目標の見出し（⚠ どこから作った目標か）。⚠ 品から作った目標は "" （⚠ 行の名前で足りる）。
static func origin_text(goal: Dictionary) -> String:
	var ref: String = str(goal.get(GameStateKeys.GOAL_REF, ""))
	match str(goal.get(GameStateKeys.GOAL_ORIGIN, "")):
		GameStateKeys.GOAL_ORIGIN_RECIPE:
			return TranslationServer.translate("ui_goal_origin_recipe") % recipe_result_text(ref)
		GameStateKeys.GOAL_ORIGIN_LEVEL:
			return TranslationServer.translate("ui_goal_origin_level") % [
				TranslationServer.translate(str(MasterDataLoader.get_character(ref).get("name_key", ref))), int(goal.get(GameStateKeys.GOAL_VALUE, 0)),
			]
	return ""


# 帯の1行（⚠ 「鍛冶の欠片 3 / 10・飾り石 0 / 12」）。
static func summary_text() -> String:
	var parts: Array[String] = []
	for line: Dictionary in GameManager.get_goal_progress():
		parts.append(TranslationServer.translate("ui_goal_line") % [
			TranslationServer.translate(GameManager.item_name_key(str(line.get(GameManager.GOAL_LINE_ITEM_ID, "")))),
			int(line.get(GameManager.GOAL_LINE_OWNED, 0)), int(line.get(GameManager.GOAL_LINE_TARGET, 0)),
		])
	var origin: String = origin_text(GameManager.get_goal())
	var body: String = TranslationServer.translate("ui_goal_join").join(parts)
	return body if origin == "" else "%s　%s" % [origin, body]


# レシピの出るもの（⚠ 作業場の右辺と同じ字の並び。⚠ くじのレシピは「ランダム」の字）。
static func recipe_result_text(recipe_id: String) -> String:
	var recipe: Dictionary = MasterDataLoader.get_recipe(recipe_id)
	var parts: Array[String] = []
	for raw: Variant in recipe.get(GameManager.RECIPE_OUTPUTS, []):
		if raw is Dictionary:
			parts.append(TranslationServer.translate(GameManager.item_name_key(str((raw as Dictionary).get(GameManager.RECIPE_IO_ITEM_ID, "")))))
	if parts.is_empty():
		return TranslationServer.translate("ui_guild_workshop_draw")
	return " + ".join(parts)
