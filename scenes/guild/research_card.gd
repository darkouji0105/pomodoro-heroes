class_name ResearchCard
extends Control

# 研究の札1枚（2026-10-18・回UI-1018-7・web版の手本 `04_research_b1.png`・決定 `GR-10`〜`GR-12`）。
#
# ⚠ コルク板に画鋲で留めた札：⚠ 左に効果のアイコン ／ 題 ／ 効果 ／ ⚠ 右下に素材の札（⚠ 足りなければ赤）。
# ⚠ 見え方は状態で変わる（`state_of()`）：⚠ 済み＝墨の札に「済」／ ⚠ いま開ける＝光る札に赤い画鋲 ／ ⚠ 素材が足りない＝ふつうの札
#   ／ ⚠ 前の研究が先＝薄い札 ／ ⚠ ボードが閉じている＝さらに薄い。⚠ 新しく開いた研究は赤い栞（`GameManager.is_research_new()`）。
# ⚠ 札は並べない器（`Control`）＝⚠ 素材の札と画鋲を札の縁からはみ出して置ける。⚠ 押すと `pressed`。
# ⚠ 寸法と色は Theme の `Research` 型。⚠ 研究の画面だけで使う＝scenes/guild/（AGENTS.md）。
# ⚠ 「完成の報酬」の札も同じ器（`create_reward()`）。

signal pressed

const THEME_TYPE: StringName = &"Research"

enum State { DONE, OPEN, SHORT, WAIT, CLOSED }

const NAME_KEY: String = "name_key"


static func state_of(node_id: String) -> State:
	var node: Dictionary = GameManager.get_research_tree().get(node_id, {})
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		return State.DONE
	if not GameManager.is_research_board_open(GameManager.get_research_board_of(node_id)):
		return State.CLOSED
	if not GameManager.can_unlock_research_node(node_id):
		return State.WAIT
	return State.OPEN if GameManager.can_afford_research_node(node_id) else State.SHORT


static func name_of(node_id: String) -> String:
	return TranslationServer.translate(str(MasterDataLoader.get_research_node(node_id).get(NAME_KEY, node_id)))


static func category_of(node_id: String) -> String:
	return str(MasterDataLoader.get_research_node(node_id).get(GameManager.RESEARCH_NODE_CATEGORY, ""))


static func effect_text(node_id: String) -> String:
	var node: Dictionary = GameManager.get_research_tree().get(node_id, {})
	var value: int = int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	match str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")):
		GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			return TranslationServer.translate("ui_research_effect_cap") % value
		GameStateKeys.EFFECT_STAT_BOOST_ALL:
			# ⚠ target_stat が "all" でなければ軸1本だけの加算（段階10）。⚠ 軸名は育成画面と同じキーを使い回す。
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, GameManager.STAT_BOOST_ALL_KEY))
			if stat != GameManager.STAT_BOOST_ALL_KEY:
				return TranslationServer.translate("ui_research_effect_stat_axis") % [TranslationServer.translate("ui_training_stat_" + stat), value]
			return TranslationServer.translate("ui_research_effect_stat") % value
		GameStateKeys.EFFECT_CHEST_DRAW_BONUS:
			return TranslationServer.translate("ui_research_effect_chest_draw") % value
		GameStateKeys.EFFECT_CRAFT_SPEED_BONUS:
			return TranslationServer.translate("ui_research_effect_craft_speed") % value
		GameStateKeys.EFFECT_CRAFT_SLOT_BONUS:
			return TranslationServer.translate("ui_research_effect_craft_slot") % value
	return ""


# ⚠ 効果の種類ごとのアイコン（⚠ 研究専用の絵は無い＝既にある線画を借りる）。
static func icon_of(node_id: String) -> Texture2D:
	var node: Dictionary = GameManager.get_research_tree().get(node_id, {})
	match str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")):
		GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			return IconTextures.for_hq(IconTextures.NAME_HQ_GROW)
		GameStateKeys.EFFECT_STAT_BOOST_ALL:
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, GameManager.STAT_BOOST_ALL_KEY))
			return IconTextures.for_stat(GameStateKeys.STAT_HP if stat == GameManager.STAT_BOOST_ALL_KEY else stat)
		GameStateKeys.EFFECT_CHEST_DRAW_BONUS:
			return IconTextures.for_chest()
		GameStateKeys.EFFECT_CRAFT_SPEED_BONUS, GameStateKeys.EFFECT_CRAFT_SLOT_BONUS:
			return IconTextures.for_screen(GameStateKeys.SCREEN_WORKSHOP)
	return IconTextures.for_screen(GameStateKeys.SCREEN_RESEARCH)


static func create(node_id: String) -> ResearchCard:
	var card: ResearchCard = ResearchCard.new()
	card.name = "ResearchCard_" + node_id
	card._node_id = node_id
	return card


static func create_reward(board: int) -> ResearchCard:
	var card: ResearchCard = ResearchCard.new()
	card.name = "RewardCard"
	card._reward_board = board
	return card


var _node_id: String = ""
var _reward_board: int = 0
var selected: bool = false:
	set(value):
		selected = value
		if is_inside_tree():
			_apply_style()
var _panel: PanelContainer = null
var _overlay: Control = null
var _state: State = State.WAIT


func node_id() -> String:
	return _node_id


func is_reward() -> bool:
	return _reward_board > 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(float(get_theme_constant(&"card_width", THEME_TYPE)), float(get_theme_constant(&"card_height", THEME_TYPE)))
	size = custom_minimum_size
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	var circle: PanelContainer = PanelContainer.new()
	circle.name = "IconCircle"
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = float(get_theme_constant(&"icon", THEME_TYPE))
	circle.custom_minimum_size = Vector2(side, side)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(circle)
	var picture: TextureRect = TextureRect.new()
	picture.name = "Icon"
	picture.texture = IconTextures.for_chest() if is_reward() else icon_of(_node_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(picture)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.theme_type_variation = &"TightList"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"ResearchCardTitleLabel"
	title.text = tr("ui_research_reward_title") if is_reward() else name_of(_node_id)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title)
	var effect: Label = Label.new()
	effect.name = "EffectLabel"
	effect.theme_type_variation = &"ResearchCardEffectLabel"
	effect.text = tr("ui_research_reward_short") if is_reward() else effect_text(_node_id)
	effect.clip_text = true
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(effect)
	# ⚠ 素材の札（⚠ 済んだ研究には出さない）／ ⚠ 完成の報酬は「全部で n / m」。
	var chip: Label = Label.new()
	chip.name = "CostChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	# ⚠ 画鋲・「済」の判・栞は札の上に重ねる（⚠ 器の `_draw()` は子の面の下に描かれて隠れた＝10-18 の絵）。
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_marks)
	add_child(_overlay)
	var hit: Button = Button.new()
	hit.name = "Hit"
	hit.theme_type_variation = &"HitButton"
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(_on_hit_pressed)
	add_child(hit)
	refresh()


func _on_hit_pressed() -> void:
	pressed.emit()


# ⚠ 状態から見え方を引き直す（⚠ 研究が開くたびに板が呼ぶ）。
func refresh() -> void:
	var chip: Label = get_node("CostChip") as Label
	if is_reward():
		var progress: Dictionary = GameManager.get_research_board_progress(_reward_board)
		_state = State.DONE if GameManager.is_research_board_reward_claimed(_reward_board) else (
			State.OPEN if GameManager.is_research_board_complete(_reward_board) else State.WAIT)
		chip.text = tr("ui_research_reward_chip") % [int(progress.get("unlocked", 0)), int(progress.get("total", 0))]
		chip.theme_type_variation = &"ResearchChip"
	else:
		_state = state_of(_node_id)
		var cost: Dictionary = GameManager.get_research_unlock_cost(_node_id)
		var material_id: String = str(cost.get(GameManager.RESEARCH_COST_MATERIAL_ID, ""))
		var amount: int = int(cost.get(GameManager.RESEARCH_COST_AMOUNT, 0))
		chip.visible = _state != State.DONE and amount > 0
		chip.text = "%s %d" % [tr("ui_res_" + material_id), amount]
		chip.theme_type_variation = &"ResearchChip" if GameManager.get_material_count(material_id) >= amount else &"ResearchChipShort"
		# ⚠ 栞は札の左上（⚠ 右上は「済」の判＝手本）。⚠ 栞の位置は右からの距離で渡す。
		_overlay.set_meta(RibbonMark.META_INSET, custom_minimum_size.x - float(get_theme_constant(&"ribbon_w", RibbonMark.THEME_TYPE)) - float(get_theme_constant(&"ribbon_left", THEME_TYPE)))
		RibbonMark.set_on(_overlay, GameManager.is_research_new(_node_id))
	chip.size = chip.get_combined_minimum_size()
	chip.position = Vector2(custom_minimum_size.x - chip.size.x - float(get_theme_constant(&"chip_inset", THEME_TYPE)), custom_minimum_size.y - chip.size.y * 0.5)
	_apply_style()
	_overlay.queue_redraw()


func card_state() -> State:
	return _state


func _apply_style() -> void:
	if _panel == null:
		return
	var names: Dictionary = {
		State.DONE: &"ResearchCardDone", State.OPEN: &"ResearchCardOpen", State.SHORT: &"ResearchCardShort",
		State.WAIT: &"ResearchCardWait", State.CLOSED: &"ResearchCardWait",
	}
	_panel.theme_type_variation = names[_state]
	if selected:
		_panel.theme_type_variation = StringName(str(names[_state]) + "Selected")
	var dark: bool = _state == State.DONE
	(get_node("Panel").find_child("IconCircle", true, false) as PanelContainer).theme_type_variation = &"ResearchIconDark" if dark else &"ResearchIconLight"
	(get_node("Panel").find_child("Icon", true, false) as TextureRect).self_modulate = get_theme_color(&"icon_on_dark" if dark else &"icon_on_paper", THEME_TYPE)
	# ⚠ 済んだ札は墨の地＝字は明るい（⚠ 色は字の型が持つ）。
	(get_node("Panel").find_child("TitleLabel", true, false) as Label).theme_type_variation = &"ResearchCardTitleDarkLabel" if dark else &"ResearchCardTitleLabel"
	(get_node("Panel").find_child("EffectLabel", true, false) as Label).theme_type_variation = &"ResearchCardEffectDarkLabel" if dark else &"ResearchCardEffectLabel"
	modulate.a = float(get_theme_constant(&"wait_alpha_pct" if _state == State.WAIT else (&"closed_alpha_pct" if _state == State.CLOSED else &"full_alpha_pct"), THEME_TYPE)) / 100.0


# ⚠ 画鋲（⚠ いま開ける＝赤・ほか＝墨）と「済」の判。
func _draw_marks() -> void:
	var radius: float = float(get_theme_constant(&"pin", THEME_TYPE))
	var center: Vector2 = Vector2(size.x * 0.5, 0.0)
	_overlay.draw_circle(center + Vector2(1.0, 2.0), radius, get_theme_color(&"pin_shadow", THEME_TYPE))
	_overlay.draw_circle(center, radius, get_theme_color(&"pin_red" if _state == State.OPEN else &"pin_dark", THEME_TYPE))
	if _state == State.DONE and not is_reward():
		var seal: float = float(get_theme_constant(&"seal", THEME_TYPE))
		var at: Vector2 = Vector2(size.x - seal * 0.4, seal * 0.1)
		_overlay.draw_circle(at, seal * 0.5, get_theme_color(&"seal", THEME_TYPE))
		var font: Font = get_theme_default_font()
		var font_size: int = get_theme_constant(&"seal_font", THEME_TYPE)
		var text: String = tr("ui_quest_cleared")
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		_overlay.draw_string(font, at + Vector2(-text_size.x * 0.5, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, get_theme_color(&"seal_text", THEME_TYPE))
