class_name BaseTodaySheet
extends PaperSheet

# 本部の机の「今日の紙」（2026-10-07・回HB-1・`NAV-21`・人間「⚠ ５あ」）。
#
# ⚠ 今日の集中の分 ／ ⚠ 用事のある施設の一覧（⚠ 1行＝1つの用事。⚠ 押すとその画面へ）。
# ⚠ 用事の判定は帯のしおり紐と**同じ口**（`BaseFacilityBar.attention_of()`）＝⚠ ここに2本目を書かない。
#   ⚠ 帯の紐が「どこに用事があるか」、⚠ この紙が「何の用事か」を読ませる。
# ⚠ 大きさは Theme の `BaseDesk` 型（⚠ 高さは壁の紙と揃える＝`Task/wall_height`）。
# ⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

const THEME_TYPE: StringName = &"BaseDesk"
const KEY_ID: String = "id"
const KEY_TEXT: String = "text"
const KEY_PATH: String = "path"

# ⚠ 並び＝帯の並び。⚠ 鍛冶場の用事は作業場の完成＝「作る」タブ（作業場の画面）へ。
static func errands() -> Array[Dictionary]:
	return [
		{KEY_ID: BaseFacilityBar.HQ, KEY_TEXT: "ui_base_today_hq", KEY_PATH: "res://scenes/base/chest_screen.tscn"},
		{KEY_ID: BaseFacilityBar.TRAINING, KEY_TEXT: "ui_base_today_training", KEY_PATH: "res://scenes/guild/training_list_screen.tscn"},
		{KEY_ID: BaseFacilityBar.FORGE, KEY_TEXT: "ui_base_today_forge", KEY_PATH: "res://scenes/guild/workshop_screen.tscn"},
		{KEY_ID: BaseFacilityBar.RESEARCH, KEY_TEXT: "ui_base_today_research", KEY_PATH: "res://scenes/guild/research_screen.tscn"},
		{KEY_ID: BaseFacilityBar.BELONGINGS, KEY_TEXT: "ui_base_today_belongings", KEY_PATH: "res://scenes/guild/warehouse_screen.tscn"},
		{KEY_ID: BaseFacilityBar.SHOP, KEY_TEXT: "ui_base_today_shop", KEY_PATH: "res://scenes/guild/shop_screen.tscn"},
	]


static func create() -> BaseTodaySheet:
	var sheet: BaseTodaySheet = BaseTodaySheet.new()
	sheet.name = "TodaySheet"
	return sheet


var _list: VBoxContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(
		float(get_theme_constant(&"today_width", THEME_TYPE)),
		float(get_theme_constant(&"wall_height", &"Task")))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	add_child(body)
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "TodayHeading"
	heading.title_key = "ui_base_today_title"
	body.add_child(heading)
	body.add_child(ValueRow.create(tr("ui_records_focus_today"), tr("ui_records_minutes") % GameManager.get_cumulative_focus_minutes_today()))
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_base_today_errands")
	body.add_child(caption)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "Errands"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_rebuild()
	GameManager.pending_chests_changed.connect(_on_changed_int)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.crafting_queue_changed.connect(_rebuild)
	GameManager.research_node_unlocked.connect(_on_changed_str)
	GameManager.character_growth_changed.connect(_on_changed_str)
	GameManager.shop_changed.connect(_on_changed_str)
	GameManager.inventory_changed.connect(_on_changed_str)


# ⚠ いま出す用事（⚠ 検査からも引く）。
static func current_errands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in errands():
		var id: String = str(entry[KEY_ID])
		if BaseFacilityBar.is_open(id) and BaseFacilityBar.attention_of(id):
			result.append(entry)
	return result


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var shown: Array[Dictionary] = current_errands()
	if shown.is_empty():
		var none: Label = Label.new()
		none.name = "NoErrands"
		none.text = tr("ui_base_today_none")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(none)
		return
	for entry: Dictionary in shown:
		var button: Button = UiButton.create_paper_choice(str(entry[KEY_TEXT]))
		button.name = "Errand_" + str(entry[KEY_ID])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(SceneManager.change_scene.bind(str(entry[KEY_PATH])))
		_list.add_child(button)


func _on_changed_int(_value: int) -> void:
	_rebuild()


func _on_changed_str(_value: String) -> void:
	_rebuild()


func _on_material_changed(_material_id: String, _amount: int) -> void:
	_rebuild()
