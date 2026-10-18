# res://scenes/guild/research_screen.gd
# 研究（育成の中のタブ）。AGENTS.md 準拠。
#
# ⚠⚠ 10-18（回UI-1018-7・web版の手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/` `04_research_*.png`・決定 `GR-10`〜`GR-12`）：⚠ **作り直した**。
#   ⚠ 研究室のコルク板＝**1画面に1ボード**（`ResearchBoardView`）。⚠ ボードは上の「◀［ボード1 ...］▶」で移る（⚠ タブは無い）。
#   ⚠ 札を押すと右の紙に詳しく（効果・先に開く研究・必要な素材・開くと次に開けるもの）＋「解放する」。
#   ⚠ 右上の紙：⚠ ボードの進み ／「開けるだけ開く」（⚠ 確かめの窓）／「自動」（⚠ 分類ごと・素材を残す量＝⚙ の窓）。
#   ⚠ 各ボードの右端に「完成の報酬」の札（⚠ 押すと右に報酬と「受け取る」）。⚠ 閉じたボードも中身は見える（⚠ 開く条件を題に）。
#   ⚠ 開いた研究は窓を出さず**赤い栞**（⚠ 札・ボード名・「研究」タブ・本部の研究の札）。⚠ 札を押すと消える。
# ⚠ ノードIDを決め打ちしない（⚠ 並び・置き場所は research.json から毎回）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

class_name ResearchScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"Research"
# ⚠ 右の紙で「完成の報酬」を見ている印（⚠ ノードIDと重ならない字）。
const REWARD_KEY: String = "@reward"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var board_nav: HBoxContainer = $Margin/Layout/BoardNav
@onready var body: HBoxContainer = $Margin/Layout/Body

var _board: int = 1
var _selected: String = ""
var _view: ResearchBoardView = null
var _scroll: ScrollContainer = null
var _summary: PaperSheet = null
var _detail: PaperSheet = null


func _ready() -> void:
	header.back_pressed.connect(_on_back_pressed)
	# ⚠ 10-06（`NAV-19`）：⚠ この画面で使う素材を見出しに。
	var _bar: ResourceBar = header.show_materials(GameManager.get_material_ids_of_series(GameStateKeys.ITEM_CONSTRUCTION_MATERIAL_PREFIX))
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.RESEARCH)
	_board = int(SceneManager.recall(TransferKeys.MEMORY_RESEARCH_BOARD, _default_board()))
	if not (_board in GameManager.get_research_boards()):
		_board = _default_board()
	_build_body()
	_show_board(_board)
	GameManager.research_node_unlocked.connect(_on_research_changed)
	GameManager.material_changed.connect(_on_material_changed)


# ⚠ はじめに見せるボード：⚠ いま開けるもののある一番前のボード → ⚠ 今のボード。
func _default_board() -> int:
	for board: int in GameManager.get_research_boards():
		if GameManager.get_affordable_research_count(board) > 0:
			return board
	return GameManager.get_current_research_board()


# --- 器 ---

func _build_body() -> void:
	var left: VBoxContainer = VBoxContainer.new()
	left.name = "BoardArea"
	left.theme_type_variation = &"TightList"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var cork: PanelContainer = PanelContainer.new()
	cork.name = "Cork"
	cork.theme_type_variation = &"ResearchCorkPanel"
	cork.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(cork)
	_scroll = ScrollContainer.new()
	_scroll.name = "BoardScroll"
	cork.add_child(_scroll)
	left.add_child(_build_legend())
	var side: VBoxContainer = VBoxContainer.new()
	side.name = "Side"
	side.custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
	body.add_child(side)
	_summary = PaperSheet.new()
	_summary.name = "Summary"
	_summary.show_corners = false
	_summary.theme_type_variation = &"DeskCardPanel"
	side.add_child(_summary)
	_detail = PaperSheet.new()
	_detail.name = "Detail"
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_detail)


func _build_legend() -> Control:
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "Legend"
	strip.theme_type_variation = &"ResearchLegendPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"WideRow"
	strip.add_child(row)
	for spec: Array in [
		[&"ResearchCardDone", "ui_research_legend_done"],
		[&"ResearchLegendRibbon", "ui_research_legend_new"],
		[&"ResearchCardOpen", "ui_research_legend_open"],
		[&"ResearchCardShort", "ui_research_legend_short"],
		[&"ResearchCardWait", "ui_research_legend_wait"],
	]:
		var item: HBoxContainer = HBoxContainer.new()
		row.add_child(item)
		var swatch: PanelContainer = PanelContainer.new()
		swatch.theme_type_variation = spec[0]
		var side: float = float(get_theme_constant(&"legend_swatch", THEME_TYPE))
		swatch.custom_minimum_size = Vector2(side * 1.6, side)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var label: Label = Label.new()
		label.theme_type_variation = &"ResearchLegendLabel"
		label.text = tr(str(spec[1]))
		item.add_child(label)
	return strip


# --- ボード ---

func _show_board(board: int) -> void:
	_board = board
	SceneManager.remember(TransferKeys.MEMORY_RESEARCH_BOARD, _board)
	if _view != null:
		_scroll.remove_child(_view)
		_view.queue_free()
	_view = ResearchBoardView.create(_board)
	_view.card_pressed.connect(_on_card_pressed)
	_view.reward_pressed.connect(_on_reward_pressed)
	_scroll.add_child(_view)
	_selected = _default_selection()
	_view.select("" if _selected == REWARD_KEY else _selected)
	_rebuild_nav()
	_rebuild_summary()
	_rebuild_detail()
	_scroll_to_selected.call_deferred()


# ⚠ はじめに選ぶ札：⚠ いま開ける → ⚠ まだの札 → ⚠ 完成の報酬。
func _default_selection() -> String:
	var first_open: String = ""
	var first_left: String = ""
	for node_id: String in _board_ids():
		var state: ResearchCard.State = ResearchCard.state_of(node_id)
		if state == ResearchCard.State.OPEN and first_open == "":
			first_open = node_id
		if state != ResearchCard.State.DONE and first_left == "":
			first_left = node_id
	if first_open != "":
		return first_open
	return first_left if first_left != "" else REWARD_KEY


func _board_ids() -> Array[String]:
	var ids: Array[String] = []
	for node_id: Variant in MasterDataLoader.get_all_research_nodes():
		if GameManager.get_research_board_of(str(node_id)) == _board:
			ids.append(str(node_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(MasterDataLoader.get_research_node(a).get("sort_order", 9999)) < int(MasterDataLoader.get_research_node(b).get("sort_order", 9999)))
	return ids


func _scroll_to_selected() -> void:
	if _view == null or _scroll == null:
		return
	var card: Control = _view.reward_card() if _selected == REWARD_KEY else _view.card_of(_selected)
	if card != null:
		_scroll.ensure_control_visible(card)


# --- 上：◀［ボード1 ...］▶ ／ レベル上限 ---

func _rebuild_nav() -> void:
	for child: Node in board_nav.get_children():
		board_nav.remove_child(child)
		child.queue_free()
	var boards: Array[int] = GameManager.get_research_boards()
	var index: int = boards.find(_board)
	var prev: Button = UiButton.create_paper_choice("ui_research_prev")
	prev.name = "PrevBoardButton"
	prev.disabled = index <= 0
	prev.pressed.connect(_on_board_step.bind(-1))
	board_nav.add_child(prev)
	var pill: PanelContainer = PanelContainer.new()
	pill.name = "BoardPill"
	pill.theme_type_variation = &"ResearchPillPanel"
	board_nav.add_child(pill)
	var row: HBoxContainer = HBoxContainer.new()
	pill.add_child(row)
	var title: Label = Label.new()
	title.name = "BoardName"
	title.theme_type_variation = &"ResearchPillTitleLabel"
	title.text = (tr("ui_research_closed_mark") if not GameManager.is_research_board_open(_board) else "") + tr("ui_research_board_name") % _board
	row.add_child(title)
	var position_label: Label = Label.new()
	position_label.theme_type_variation = &"ResearchPillLabel"
	position_label.text = "%d / %d" % [index + 1, boards.size()]
	position_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(position_label)
	var progress: Dictionary = GameManager.get_research_board_progress(_board)
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = &"DeskGoalBar"
	bar.show_percentage = false
	bar.custom_minimum_size.x = float(get_theme_constant(&"pill_bar", THEME_TYPE))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxf(1.0, float(progress.get("total", 0)))
	bar.value = float(progress.get("unlocked", 0))
	row.add_child(bar)
	var count: Label = Label.new()
	count.name = "BoardCount"
	count.theme_type_variation = &"ResearchPillLabel"
	count.text = tr("ui_research_pill_count") % [int(progress.get("unlocked", 0)), int(progress.get("total", 0))]
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	RibbonMark.set_on(pill, GameManager.has_new_research(_board))
	var next: Button = UiButton.create_paper_choice("ui_research_next")
	next.name = "NextBoardButton"
	next.disabled = index < 0 or index >= boards.size() - 1
	next.pressed.connect(_on_board_step.bind(1))
	board_nav.add_child(next)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_nav.add_child(gap)
	var cap: Label = Label.new()
	cap.name = "CapLabel"
	cap.theme_type_variation = &"ResearchCapLabel"
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# get_effective_level_cap() は character_id を使わない実装（全キャラ共通の上限）。
	cap.text = tr("ui_research_cap_short") % GameManager.get_effective_level_cap("")
	board_nav.add_child(cap)


func _on_board_step(step: int) -> void:
	var boards: Array[int] = GameManager.get_research_boards()
	var index: int = boards.find(_board) + step
	if index >= 0 and index < boards.size():
		_show_board(boards[index])


# --- 右上：進み ／ 開けるだけ開く ／ 自動 ---

func _rebuild_summary() -> void:
	for child: Node in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"TightList"
	_summary.add_child(column)
	var top: HBoxContainer = HBoxContainer.new()
	column.add_child(top)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_research_board_name") % _board
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(caption)
	var progress: Dictionary = GameManager.get_research_board_progress(_board)
	var big: Label = Label.new()
	big.theme_type_variation = &"DeskBigNumberLabel"
	big.text = str(int(progress.get("unlocked", 0)))
	top.add_child(big)
	var total: Label = Label.new()
	total.theme_type_variation = &"CaptionLabel"
	total.text = "/ %d" % int(progress.get("total", 0))
	total.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(total)
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	var affordable: int = GameManager.get_affordable_research_count(_board)
	var can: Label = Label.new()
	can.name = "AffordableLabel"
	can.theme_type_variation = &"GainLabel" if affordable > 0 else &"CaptionLabel"
	can.text = tr("ui_research_can_open") % affordable
	can.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(can)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.theme_type_variation = &"ButtonRow"
	column.add_child(buttons)
	var all: Button = Button.new()
	all.name = "UnlockAllButton"
	all.theme_type_variation = &"PrimaryButton"
	all.text = tr("ui_research_unlock_all") % affordable
	all.disabled = affordable <= 0
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.pressed.connect(_on_unlock_all_pressed)
	# ⚠ 10-07（人間「⚠ しおり紐は気づいたんだけど　そこから言ったページで何を見ればいいのかわかんなかった」）：⚠ いま開けるものがあれば紐。
	RibbonMark.set_on(all, affordable > 0)
	buttons.add_child(all)
	var auto: Dictionary = GameManager.get_research_auto()
	var toggle: Button = Button.new()
	toggle.name = "AutoToggle"
	toggle.theme_type_variation = &"PaperToggle"
	toggle.toggle_mode = true
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.set_pressed_no_signal(bool(auto[GameManager.RESEARCH_AUTO_ENABLED]))
	toggle.text = tr("ui_research_auto_on" if bool(auto[GameManager.RESEARCH_AUTO_ENABLED]) else "ui_research_auto_off")
	toggle.pressed.connect(_on_auto_pressed)
	buttons.add_child(toggle)
	var settings: Button = UiButton.create_paper_choice("")
	settings.name = "AutoSettingsButton"
	settings.icon = IconTextures.for_hq(IconTextures.NAME_SYS_SETTINGS)
	settings.tooltip_text = tr("ui_research_auto_title")
	settings.theme_type_variation = &"ResearchIconButton"
	settings.pressed.connect(_open_auto_window.bind(true))
	buttons.add_child(settings)


func _on_unlock_all_pressed() -> void:
	var count: int = GameManager.get_affordable_research_count(_board)
	if count <= 0:
		return
	var ok: bool = await Modal.confirm(self, "ui_research_unlock_all_confirm", [_board, count], false, {
		Modal.OPTION_TITLE: tr("ui_research_unlock_all_title"),
		Modal.OPTION_CONFIRM_LABEL: "ui_research_unlock_all_go",
	})
	if not ok:
		return
	var _opened: Array[String] = GameManager.unlock_research_all(_board)


# ⚠ 入っているかは状態から読む（⚠ ボタンの見た目からは読まない＝押した合図だけを使う）。
func _on_auto_pressed() -> void:
	var auto: Dictionary = GameManager.get_research_auto()
	if not bool(auto[GameManager.RESEARCH_AUTO_ENABLED]):
		# ⚠ 入れるときは窓で分類と残す量を見せてから（⚠ 手本「自動をオンにする」）。
		_open_auto_window(false)
		return
	GameManager.set_research_auto(false, auto[GameManager.RESEARCH_AUTO_CATEGORIES], int(auto[GameManager.RESEARCH_AUTO_KEEP]))


# ⚠ 自動で研究の窓（⚠ 分類ごとのオン・オフ ／ 素材を残す量）。⚠ 「はい」でオン（⚠ 既にオンなら設定だけ変える）。
func _open_auto_window(from_settings: bool) -> void:
	var auto: Dictionary = GameManager.get_research_auto()
	var was_on: bool = bool(auto[GameManager.RESEARCH_AUTO_ENABLED])
	var categories: Dictionary = (auto[GameManager.RESEARCH_AUTO_CATEGORIES] as Dictionary).duplicate()
	var keep: Array[int] = [int(auto[GameManager.RESEARCH_AUTO_KEEP])]
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "AutoContent"
	# ⚠ 説明は窓の上（⚠ 手本の並び）＝⚠ 窓の文は空にして中身に入れる。
	var desc: Label = Label.new()
	desc.text = tr("ui_research_auto_desc")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(desc)
	var cat_caption: Label = Label.new()
	cat_caption.theme_type_variation = &"CaptionLabel"
	cat_caption.text = tr("ui_research_auto_categories")
	content.add_child(cat_caption)
	var cat_row: HBoxContainer = HBoxContainer.new()
	cat_row.theme_type_variation = &"ButtonRow"
	content.add_child(cat_row)
	for category: String in categories:
		var chip: Button = Button.new()
		chip.name = "AutoCat_" + category
		chip.theme_type_variation = &"PaperToggle"
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.set_pressed_no_signal(bool(categories[category]))
		chip.text = tr("ui_research_category_" + category)
		chip.toggled.connect(func(pressed_now: bool) -> void: categories[category] = pressed_now)
		cat_row.add_child(chip)
	var keep_caption: Label = Label.new()
	keep_caption.theme_type_variation = &"CaptionLabel"
	keep_caption.text = tr("ui_research_auto_keep")
	content.add_child(keep_caption)
	var keep_row: HBoxContainer = HBoxContainer.new()
	keep_row.theme_type_variation = &"ButtonRow"
	content.add_child(keep_row)
	var keep_buttons: Array[Button] = []
	for raw: Variant in Balance.research.auto_keep_choices:
		var amount: int = int(raw)
		var chip: Button = Button.new()
		chip.name = "AutoKeep_%d" % amount
		chip.theme_type_variation = &"PaperToggle"
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.set_pressed_no_signal(amount == keep[0])
		chip.text = tr("ui_research_auto_keep_none") if amount == 0 else tr("ui_research_auto_keep_n") % amount
		keep_buttons.append(chip)
		keep_row.add_child(chip)
	for chip: Button in keep_buttons:
		chip.pressed.connect(func() -> void:
			keep[0] = int(str(chip.name).trim_prefix("AutoKeep_"))
			for other: Button in keep_buttons:
				other.set_pressed_no_signal(other == chip))
	var note: Label = Label.new()
	note.theme_type_variation = &"CaptionLabel"
	note.text = tr("ui_research_auto_keep_note")
	content.add_child(note)
	var ok: bool = await Modal.confirm(self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_research_auto_title"),
		Modal.OPTION_CONTENT: content,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CONFIRM_LABEL: "ui_research_auto_save" if was_on and from_settings else "ui_research_auto_turn_on",
	})
	if ok:
		GameManager.set_research_auto(true, categories, keep[0])
	else:
		# ⚠ やめたら見た目を元に戻す（⚠ 押したトグルが入ったままにならない）。
		_rebuild_summary()


# --- 右下：詳しく ---

func _rebuild_detail() -> void:
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = &"TightList"
	_detail.add_child(column)
	if _selected == REWARD_KEY:
		_fill_reward_detail(column)
	elif _selected != "":
		_fill_node_detail(column, _selected)


func _detail_head(column: VBoxContainer, icon: Texture2D, caption_text: String, title_text: String, status_key: String, status_variation: StringName) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	column.add_child(head)
	var circle: PanelContainer = PanelContainer.new()
	circle.theme_type_variation = &"ResearchIconLight"
	var side: float = float(get_theme_constant(&"detail_icon", THEME_TYPE))
	circle.custom_minimum_size = Vector2(side, side)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(circle)
	var picture: TextureRect = TextureRect.new()
	picture.texture = icon
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.self_modulate = get_theme_color(&"icon_on_paper", THEME_TYPE)
	circle.add_child(picture)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.theme_type_variation = &"TightList"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(texts)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = caption_text
	texts.add_child(caption)
	var title: Label = Label.new()
	title.name = "DetailTitle"
	title.theme_type_variation = &"DeskCardTitleLabel"
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(title)
	if status_key != "":
		var status: Label = Label.new()
		status.name = "StatusChip"
		status.theme_type_variation = status_variation
		status.text = tr(status_key)
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(status)
	column.add_child(HSeparator.new())


func _caption(column: VBoxContainer, key: String) -> void:
	var label: Label = Label.new()
	label.theme_type_variation = &"CaptionLabel"
	label.text = tr(key)
	column.add_child(label)


func _fill_node_detail(column: VBoxContainer, node_id: String) -> void:
	var state: ResearchCard.State = ResearchCard.state_of(node_id)
	var status: Array = {
		ResearchCard.State.DONE: ["ui_research_status_done", &"ResearchStatusDone"],
		ResearchCard.State.OPEN: ["ui_research_status_open", &"ResearchStatusOpen"],
		ResearchCard.State.SHORT: ["ui_research_status_short", &"ResearchStatusShort"],
		ResearchCard.State.WAIT: ["ui_research_status_wait", &"ResearchStatusWait"],
		ResearchCard.State.CLOSED: ["ui_research_status_closed", &"ResearchStatusShort"],
	}[state]
	var caption_text: String = "%s・%s" % [tr("ui_research_board_name") % _board, tr("ui_research_category_" + ResearchCard.category_of(node_id))]
	_detail_head(column, ResearchCard.icon_of(node_id), caption_text, ResearchCard.name_of(node_id), str(status[0]), status[1])
	_caption(column, "ui_research_effect")
	var effect: Label = Label.new()
	effect.name = "EffectText"
	effect.theme_type_variation = &"ResearchEffectLabel"
	effect.text = ResearchCard.effect_text(node_id)
	column.add_child(effect)
	# 先に開く研究。
	_caption(column, "ui_research_prereq")
	var prerequisites: Array = MasterDataLoader.get_research_node(node_id).get(GameStateKeys.NODE_PREREQUISITES, [])
	if prerequisites.is_empty():
		var none: Label = Label.new()
		none.theme_type_variation = &"CaptionLabel"
		none.text = tr("ui_research_prereq_none")
		column.add_child(none)
	for raw: Variant in prerequisites:
		var before: String = str(raw)
		var done: bool = ResearchCard.state_of(before) == ResearchCard.State.DONE
		var row: Button = Button.new()
		row.name = "Prereq_" + before
		row.theme_type_variation = &"DeskNoteButton"
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "%s %s　%s" % [tr("ui_research_check") if done else tr("ui_research_dot"), ResearchCard.name_of(before),
			tr("ui_research_prereq_done") if done else tr("ui_research_prereq_not")]
		row.pressed.connect(_select_any.bind(before))
		column.add_child(row)
	# 必要な素材。
	if state != ResearchCard.State.DONE:
		_caption(column, "ui_research_cost")
		var cost: Dictionary = GameManager.get_research_unlock_cost(node_id)
		var material_id: String = str(cost.get(GameManager.RESEARCH_COST_MATERIAL_ID, ""))
		var amount: int = int(cost.get(GameManager.RESEARCH_COST_AMOUNT, 0))
		var owned: int = GameManager.get_material_count(material_id)
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "CostLine"
		column.add_child(line)
		var mat_icon: TextureRect = TextureRect.new()
		mat_icon.texture = IconTextures.for_item(material_id)
		mat_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mat_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var mat_side: float = float(get_theme_constant(&"material_icon", THEME_TYPE))
		mat_icon.custom_minimum_size = Vector2(mat_side, mat_side)
		mat_icon.self_modulate = get_theme_color(&"icon_on_paper", THEME_TYPE)
		line.add_child(mat_icon)
		var mat_name: Label = Label.new()
		mat_name.text = tr("ui_res_" + material_id)
		mat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(mat_name)
		var need: Label = Label.new()
		need.name = "CostLabel_" + node_id
		need.theme_type_variation = &"DeskBigNumberLabel" if owned >= amount else &"ResearchShortNumberLabel"
		need.text = str(amount)
		line.add_child(need)
		var have: Label = Label.new()
		have.theme_type_variation = &"CaptionLabel"
		have.text = tr("ui_research_owned_n") % owned
		have.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_child(have)
		if owned < amount:
			var short: Button = Button.new()
			short.name = "SourceLink"
			short.theme_type_variation = &"DeskLinkButton"
			short.text = tr("ui_research_short_link") % (amount - owned)
			short.alignment = HORIZONTAL_ALIGNMENT_LEFT
			short.pressed.connect(_open_source.bind(material_id, amount))
			column.add_child(short)
	# 開くと次が開けるように。
	var nexts: Array[String] = []
	for other: Variant in MasterDataLoader.get_all_research_nodes():
		if node_id in (MasterDataLoader.get_research_node(str(other)).get(GameStateKeys.NODE_PREREQUISITES, []) as Array):
			nexts.append(ResearchCard.name_of(str(other)))
	if not nexts.is_empty():
		var next_label: Label = Label.new()
		next_label.theme_type_variation = &"CaptionLabel"
		next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		next_label.text = tr("ui_research_next_opens") % tr("ui_quest_reward_sep").join(nexts)
		column.add_child(next_label)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var button: Button = Button.new()
	button.name = "UnlockButton"
	button.theme_type_variation = &"DeskBigButton"
	match state:
		ResearchCard.State.DONE:
			button.text = tr("ui_research_unlocked")
			button.disabled = true
		ResearchCard.State.WAIT:
			button.text = tr("ui_research_status_wait")
			button.disabled = true
		ResearchCard.State.CLOSED:
			button.text = tr("ui_research_board_open_to_press") % _board
			button.disabled = true
		_:
			# ⚠ 10-07（`NAV-19`）：⚠ 素材が足りなくても押せる＝押すと入手先の窓。
			button.text = tr("ui_research_unlock")
	button.pressed.connect(_on_unlock_pressed.bind(node_id))
	column.add_child(button)


func _fill_reward_detail(column: VBoxContainer) -> void:
	var complete: bool = GameManager.is_research_board_complete(_board)
	var claimed: bool = GameManager.is_research_board_reward_claimed(_board)
	_detail_head(column, IconTextures.for_chest(), tr("ui_research_reward_caption") % _board, tr("ui_research_reward_title"), "", &"")
	var reward: Dictionary = GameManager.get_research_board_reward(_board)
	var rows: Array[Array] = []
	if int(reward.get(GameManager.RESEARCH_REWARD_GEMS, 0)) > 0:
		rows.append([IconTextures.for_resource(GameStateKeys.GEMS), tr("ui_res_gems"), int(reward[GameManager.RESEARCH_REWARD_GEMS])])
	if int(reward.get(GameManager.RESEARCH_REWARD_GOLD, 0)) > 0:
		rows.append([IconTextures.for_resource(GameStateKeys.GOLD), tr("ui_res_gold"), int(reward[GameManager.RESEARCH_REWARD_GOLD])])
	var materials: Dictionary = reward.get(GameManager.RESEARCH_REWARD_MATERIALS, {})
	for material_id: String in materials:
		rows.append([IconTextures.for_item(material_id), tr("ui_res_" + material_id), int(materials[material_id])])
	for row_spec: Array in rows:
		var row: PanelContainer = PanelContainer.new()
		row.theme_type_variation = &"ResearchRewardRowPanel"
		column.add_child(row)
		var line: HBoxContainer = HBoxContainer.new()
		row.add_child(line)
		var icon: TextureRect = TextureRect.new()
		icon.texture = row_spec[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = float(get_theme_constant(&"material_icon", THEME_TYPE))
		icon.custom_minimum_size = Vector2(side, side)
		icon.self_modulate = get_theme_color(&"icon_on_paper", THEME_TYPE)
		line.add_child(icon)
		var label: Label = Label.new()
		label.theme_type_variation = &"ResearchEffectLabel"
		label.text = tr("ui_quest_reward_item") % [str(row_spec[1]), int(row_spec[2])]
		line.add_child(label)
	var left: Array[String] = []
	for node_id: String in _board_ids():
		if ResearchCard.state_of(node_id) != ResearchCard.State.DONE:
			left.append(ResearchCard.name_of(node_id))
	if not left.is_empty():
		var shown: Array[String] = left.slice(0, 4)
		var remain: Label = Label.new()
		remain.name = "RemainLabel"
		remain.theme_type_variation = &"CaptionLabel"
		remain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var names: String = tr("ui_quest_reward_sep").join(shown)
		remain.text = tr("ui_research_reward_remain") % [left.size(), names if left.size() <= 4 else tr("ui_quest_reward_more") % names]
		column.add_child(remain)
	var progress: Dictionary = GameManager.get_research_board_progress(_board)
	var bar: ProgressBar = ProgressBar.new()
	bar.theme_type_variation = &"DeskGoalBar"
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(progress.get("total", 0)))
	bar.value = float(progress.get("unlocked", 0))
	column.add_child(bar)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var button: Button = Button.new()
	button.name = "ClaimRewardButton"
	button.theme_type_variation = &"DeskBigButton"
	button.text = tr("ui_research_reward_claimed") if claimed else (tr("ui_research_reward_claim") if complete else tr("ui_research_reward_need_all"))
	button.disabled = claimed or not complete
	button.pressed.connect(_on_claim_pressed)
	RibbonMark.set_on(button, complete and not claimed)
	column.add_child(button)


# --- 操作 ---

func _on_card_pressed(node_id: String) -> void:
	_select_any(node_id)


func _on_reward_pressed(_board_no: int) -> void:
	_select_any(REWARD_KEY)


# ⚠ 札を選ぶ（⚠ ほかのボードの研究なら、そのボードへ移る）。⚠ 新しく開いた研究なら栞を外す。
func _select_any(id: String) -> void:
	if id != REWARD_KEY and GameManager.get_research_board_of(id) != _board:
		_show_board(GameManager.get_research_board_of(id))
	_selected = id
	_view.select("" if id == REWARD_KEY else id)
	if id != REWARD_KEY and GameManager.is_research_new(id):
		GameManager.mark_research_seen(id)   # ⚠ 合図で描き直す
		return
	_rebuild_detail()


func _on_unlock_pressed(node_id: String) -> void:
	var cost: Dictionary = GameManager.get_research_unlock_cost(node_id)
	if ItemSourceWindow.open_if_short(self, str(cost.get(GameManager.RESEARCH_COST_MATERIAL_ID, "")),
			int(cost.get(GameManager.RESEARCH_COST_AMOUNT, 0)), {}):
		return
	# 戻り値は見ない。成功なら research_node_unlocked 経由で描画し直される。
	var _ok: bool = GameManager.unlock_research_node(node_id)


func _open_source(material_id: String, amount: int) -> void:
	var _shown: bool = ItemSourceWindow.open_if_short(self, material_id, amount, {})


func _on_claim_pressed() -> void:
	var _ok: bool = GameManager.claim_research_board_reward(_board)


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)


# --- シグナル ---

func _on_research_changed(_node_id: String) -> void:
	_refresh_all()


func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	_refresh_all()


func _refresh_all() -> void:
	if _view != null:
		_view.refresh()
	_rebuild_nav()
	_rebuild_summary()
	_rebuild_detail()
