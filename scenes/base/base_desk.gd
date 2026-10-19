class_name BaseDesk
extends HBoxContainer

# 本部の机（2026-10-18・回UI-1018-6・web版の手本 `05_base_desk.png`・決定 `NAV-34`）。
#
# ⚠ 左＝今日の紙（`BaseTodaySheet`）／ ⚠ 真ん中＝⚠ **上は空けておく**（⚠ 人間「あ：空けたまま」）・⚠ 下に細い札3枚
#   （⚠ 集中の砂時計 ／ ⚠ 冒険 ／ ⚠ 依頼掲示板）／ ⚠ 右＝宝箱・育てる・研究の札と、ほかの施設。
# ⚠ 用事の判定は帯のしおり紐と同じ口（`BaseFacilityBar.attention_of()`）。⚠ 行き先も帯の表（`BaseFacilityBar.path_of()`）。
# ⚠⚠ 10-19（回SEE29-B・`NAV-34`・見る回29回目・人間「⚠ ポモドーロと冒険は目立つように　シナリオの続きからはいらない
#   あとポモドーロの設定を拠点から簡易的にできるがいらない」→「⚠ ２あ」＝冒険は押すと依頼掲示板が開くだけ）：
#   ⚠ 真ん中の下は**2枚**＝⚠ 集中の砂時計 ／ ⚠ 冒険（⚠ 依頼掲示板の札とまとめた＝行き先が同じ）。⚠ 2枚とも真鍮の太い縁と大きい題（`DeskFeaturePanel`）。
#   ⚠ 集中の長さの札（15・25・45・50分）・冒険の「次の話」「出撃する」「続きから」・編成の顔とスタミナはやめた
#   （⚠ 顔とスタミナの行が長いと机が画面より広がり、題「ギルド本部」が左で切れていた＝10-19 の絵）。
# ⚠ 寸法と色は Theme の `BaseDesk` 型。⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番）。

const THEME_TYPE: StringName = &"BaseDesk"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"
const BOARD_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
# ⚠ 右下の「ほかの施設」の並び（⚠ 手本の順）。⚠ 開けない施設は出さない。
const OTHER_IDS: Array[String] = [
	BaseFacilityBar.BARRACKS, BaseFacilityBar.FORGE, BaseFacilityBar.GUILD_RELIC,
	BaseFacilityBar.BELONGINGS, BaseFacilityBar.RECORDS, BaseFacilityBar.SHOP,
]


static func create() -> BaseDesk:
	var desk: BaseDesk = BaseDesk.new()
	desk.name = "DeskView"
	return desk


var _middle: VBoxContainer = null
var _right: VBoxContainer = null


func _ready() -> void:
	theme_type_variation = &"BaseDeskRow"
	var today: BaseTodaySheet = BaseTodaySheet.create()
	add_child(today)
	_middle = VBoxContainer.new()
	_middle.name = "Middle"
	_middle.theme_type_variation = &"BaseDeskColumn"
	_middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_middle)
	_right = VBoxContainer.new()
	_right.name = "Right"
	_right.theme_type_variation = &"BaseDeskColumn"
	_right.custom_minimum_size.x = float(get_theme_constant(&"right_width", THEME_TYPE))
	add_child(_right)
	_rebuild()
	GameManager.pending_chests_changed.connect(_on_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(_rebuild)
	GameManager.research_node_unlocked.connect(_on_changed_str)
	GameManager.character_growth_changed.connect(_on_changed_str)
	GameManager.shop_changed.connect(_on_changed_str)
	GameManager.inventory_changed.connect(_on_changed_str)


func _rebuild() -> void:
	for column: VBoxContainer in [_middle, _right]:
		for child: Node in column.get_children():
			column.remove_child(child)
			child.queue_free()
	# ⚠ 真ん中の上は空けておく（⚠ 決まったら入れる＝手本「あとで入れる場所」）。
	var free_space: Control = Control.new()
	free_space.name = "FreeSpace"
	free_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	free_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_middle.add_child(free_space)
	if GameManager.is_screen_unlocked(GameStateKeys.SCREEN_POMODORO):
		_middle.add_child(_build_pomodoro_strip())
	if GameManager.is_screen_unlocked(GameStateKeys.SCREEN_ADVENTURE_SELECT):
		_middle.add_child(_build_adventure_strip())
	_right.add_child(_build_chest_card())
	if BaseFacilityBar.is_open(BaseFacilityBar.TRAINING) and BaseFacilityBar.training_path() != "":
		_right.add_child(_build_grow_card())
	if BaseFacilityBar.is_open(BaseFacilityBar.RESEARCH):
		_right.add_child(_build_research_card())
	_right.add_child(_build_others())


# --- 部品 ---

# ⚠ 札の器（⚠ 紙・左にアイコンの箱・真ん中に題と説明・右にボタン）。⚠ 用事があればしおり紐。
# ⚠ `feature` で目立つ札（⚠ 真鍮の太い縁・大きい題＝ポモドーロと冒険）。
func _card(card_name: String, icon: Texture2D, count: int, title_key: String, sub_text: String, attention: bool, feature: bool = false) -> Dictionary:
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = card_name
	sheet.show_corners = false
	sheet.theme_type_variation = &"DeskFeaturePanel" if feature else &"DeskCardPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	sheet.add_child(row)
	row.add_child(_icon_box(icon, count))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.name = "Texts"
	texts.theme_type_variation = &"TightList"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(texts)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"DeskFeatureTitleLabel" if feature else &"DeskCardTitleLabel"
	title.text = tr(title_key)
	texts.add_child(title)
	if sub_text != "":
		var sub: Label = Label.new()
		sub.name = "SubLabel"
		sub.theme_type_variation = &"CaptionLabel"
		sub.text = sub_text
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(sub)
	RibbonMark.set_on(sheet, attention)
	return {"sheet": sheet, "row": row, "texts": texts}


# ⚠ 箱は並べない器（`Control`）に入れる＝⚠ 数の札を箱の右上にはみ出して置ける（⚠ `PanelContainer` の子にすると全面に広げられた）。
func _icon_box(icon: Texture2D, count: int) -> Control:
	var holder: Control = Control.new()
	holder.name = "IconBox"
	var side: float = float(get_theme_constant(&"icon_box", THEME_TYPE))
	holder.custom_minimum_size = Vector2(side, side)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: PanelContainer = PanelContainer.new()
	box.name = "Box"
	box.theme_type_variation = &"DeskIconBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(box)
	if icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.self_modulate = get_theme_color(&"icon", THEME_TYPE)
		box.add_child(picture)
	if count > 0:
		var badge: Label = Label.new()
		badge.name = "CountBadge"
		badge.theme_type_variation = &"DeskCountBadge"
		badge.text = str(count)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var badge_side: float = float(get_theme_constant(&"badge", THEME_TYPE))
		badge.size = Vector2(badge_side, badge_side)
		badge.position = Vector2(side - badge_side * 0.6, -badge_side * 0.4)
		holder.add_child(badge)
	return holder


# ⚠ 大きい真鍮のボタン（⚠ 素の `Button`＝`UiButton` は木に入ると色を付け直すため）。
func _big_button(button_name: String, label_key: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.theme_type_variation = &"DeskBigButton"
	button.text = tr(label_key)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	return button


func _button(button_name: String, label_key: String, variant: UiButton.Variant, handler: Callable) -> UiButton:
	var button: UiButton = UiButton.create(variant, label_key)
	button.name = button_name
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	return button


# --- 真ん中の札 ---

# 集中の砂時計：⚠ いま片づけるやること（⚠ 一覧の一番上）／ ⚠ 始める。⚠ 長さは変えない（⚠ 設定はポモドーロの画面から＝10-19）。
func _build_pomodoro_strip() -> PaperSheet:
	var open_tasks: Array = GameManager.get_open_tasks()
	var task_id: String = ""
	var sub: String = tr("ui_hq_pomodoro_free")
	if not open_tasks.is_empty():
		task_id = str((open_tasks[0] as Dictionary).get(GameStateKeys.TASK_ID, ""))
		sub = tr("ui_hq_pomodoro_now") % str((open_tasks[0] as Dictionary).get(GameStateKeys.TASK_TITLE, ""))
	var parts: Dictionary = _card("PomodoroStrip", null, 0, "ui_hq_pomodoro_title", sub, false, true)
	var sheet: PaperSheet = parts["sheet"]
	var row: HBoxContainer = parts["row"]
	var sub_label: Label = (parts["texts"] as VBoxContainer).get_node_or_null("SubLabel") as Label
	if sub_label != null:
		sub_label.name = "NowTaskLabel"
		sub_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ⚠ アイコンの箱の代わりに砂時計（⚠ ポモドーロの加護の札と同じ絵）。
	var box: Node = row.get_node("IconBox")
	row.remove_child(box)
	box.queue_free()
	var glass: Hourglass = Hourglass.create(0)
	glass.name = "Hourglass"
	# ⚠ 砂時計は木に入ったとき自分の大きさ（Theme `Hourglass`）を当てる＝⚠ そのあとで机の大きさに直す。
	glass.ready.connect(_fit_glass.bind(glass))
	row.add_child(glass)
	row.move_child(glass, 0)
	row.add_child(_big_button("PomodoroButton", "ui_hq_pomodoro_start", _on_pomodoro_pressed.bind(task_id)))
	return sheet


func _fit_glass(glass: Hourglass) -> void:
	glass.custom_minimum_size = Vector2(float(get_theme_constant(&"glass_width", THEME_TYPE)), float(get_theme_constant(&"glass_height", THEME_TYPE)))


func _on_pomodoro_pressed(task_id: String) -> void:
	if task_id == "":
		SceneManager.change_scene(POMODORO_PATH)
	else:
		SceneManager.change_scene_with_data(POMODORO_PATH, {TransferKeys.TASK_ID: task_id})


# 冒険（⚠ 10-19「⚠ ２あ」）：⚠ 押すと依頼掲示板が開くだけ。⚠ 受けられる話と高難度の数（⚠ 前の「依頼掲示板」の札の中身）。
#   ⚠ ランの途中なら一言（⚠ 続きは掲示板の「続きから」）。
func _build_adventure_strip() -> PaperSheet:
	var open_stories: int = 0
	for raw: Variant in MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY):
		if GameManager.is_story_stage_unlocked(str(raw)) and not GameManager.is_stage_cleared(str(raw)):
			open_stories += 1
	var sub: String = tr("ui_hq_board_sub") % [open_stories, MasterDataLoader.get_all_dungeon_ids().size()]
	if GameManager.is_in_floor() or GameManager.is_in_dungeon():
		sub = tr("ui_hq_run_in_progress") + "　・　" + sub
	var parts: Dictionary = _card("AdventureStrip", IconTextures.for_hq(IconTextures.NAME_HQ_ADVENTURE), 0, "ui_hq_adventure_title", sub, false, true)
	(parts["row"] as HBoxContainer).add_child(_big_button("BoardButton", "ui_hq_adventure_open", SceneManager.change_scene.bind(BOARD_PATH)))
	return parts["sheet"]


# --- 右の札 ---

func _build_chest_card() -> PaperSheet:
	var count: int = GameManager.get_pending_chest_count()
	var sub: String = tr("ui_hq_chest_sub") % count if count > 0 else tr("ui_hq_chest_none")
	var parts: Dictionary = _card("ChestCard", IconTextures.for_chest(), count, "ui_hq_chest_title", sub, count > 0)
	var open: UiButton = _button("ChestBadge", "ui_hq_chest_open", UiButton.Variant.PRIMARY if count > 0 else UiButton.Variant.SECONDARY, SceneManager.change_scene.bind(CHEST_PATH))
	open.disabled = count <= 0
	(parts["row"] as HBoxContainer).add_child(open)
	return parts["sheet"]


func _build_grow_card() -> PaperSheet:
	var ready: Array[String] = GameManager.get_level_up_ready_characters()
	var sub: String = tr("ui_hq_grow_sub") % ready.size() if not ready.is_empty() else tr("ui_hq_grow_none")
	var parts: Dictionary = _card("GrowCard", IconTextures.for_hq(IconTextures.NAME_HQ_GROW), 0, "ui_hq_grow_title", sub, not ready.is_empty())
	if not ready.is_empty():
		var faces: HBoxContainer = HBoxContainer.new()
		faces.name = "ReadyFaces"
		(parts["texts"] as VBoxContainer).add_child(faces)
		var face: int = get_theme_constant(&"face", THEME_TYPE)
		for i: int in range(mini(ready.size(), int(get_theme_constant(&"grow_faces", THEME_TYPE)))):
			faces.add_child(CharacterAvatar.create(ready[i], face))
	(parts["row"] as HBoxContainer).add_child(_button("GrowButton", "ui_hq_grow_open", UiButton.Variant.SECONDARY, SceneManager.change_scene.bind(BaseFacilityBar.training_path())))
	return parts["sheet"]


func _build_research_card() -> PaperSheet:
	var count: int = GameManager.get_unlockable_research_count()
	var fresh: int = GameManager.get_new_research().size()
	var sub: String = tr("ui_hq_research_sub") % count if count > 0 else tr("ui_hq_research_none")
	# ⚠ 10-18（回UI-1018-7）：⚠ 新しく開いた研究（⚠ 自動で開いたものも）を先に書く。
	if fresh > 0:
		sub = tr("ui_hq_research_new") % [fresh, count]
	var parts: Dictionary = _card("ResearchCard", IconTextures.for_screen(GameStateKeys.SCREEN_RESEARCH), 0, "ui_facility_research", sub,
		BaseFacilityBar.attention_of(BaseFacilityBar.RESEARCH))
	(parts["row"] as HBoxContainer).add_child(_button("ResearchButton", "ui_hq_research_open", UiButton.Variant.SECONDARY, SceneManager.change_scene.bind(BaseFacilityBar.path_of(BaseFacilityBar.RESEARCH))))
	return parts["sheet"]


func _build_others() -> PaperSheet:
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "OtherFacilities"
	sheet.theme_type_variation = &"DeskCardPanel"
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = VBoxContainer.new()
	body.theme_type_variation = &"TightList"
	sheet.add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_hq_others_title"
	heading.right_text = tr("ui_hq_others_hint")
	body.add_child(heading)
	var grid: GridContainer = GridContainer.new()
	grid.name = "OtherGrid"
	grid.columns = 2
	body.add_child(grid)
	for id: String in OTHER_IDS:
		if not BaseFacilityBar.is_open(id):
			continue
		var button: Button = UiButton.create_paper_choice(BaseFacilityBar.label_key_of(id))
		button.name = "Other_" + id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(SceneManager.change_scene.bind(BaseFacilityBar.path_of(id)))
		RibbonMark.set_on(button, BaseFacilityBar.attention_of(id))
		grid.add_child(button)
	return sheet


func _on_changed_int(_value: int) -> void:
	_rebuild()


func _on_changed_str(_value: String) -> void:
	_rebuild()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	_rebuild()
