class_name GoalHud
extends CanvasLayer

# 目標の表示（2026-10-09・回AUTO-1・`EXEC_GOAL.md`・人間「⚠ １あか別枠のサイドバー」）。
#
# ⚠ 形は2つ（⚠ 設定の画面の「表示」で選ぶ・`GameSettings.goal_style()`・人間「⚠ １う」）：
#   ⚠ 上の帯＝画面の上の縁の余白に細い札を垂らす。⚠ 押すと目標の紙を窓で出す
#   ⚠ サイドバー＝右の縁につまみ。⚠ 押すと右から目標の紙が開く（⚠ 開いたかは `SceneManager.remember()`）
# ⚠ 目標が無ければ何も出さない。
# ⚠ 置き場は `ResourceHud` と同じく root の常駐（⚠ `SceneManager` が生やす・Autoload を増やさない）。
#   ⚠ 出す・隠すも `ResourceHud.set_shown()` に合わせる（⚠ ポモドーロの集中中は出さない）。
# ⚠ 値は Theme の `Goal` 型と `GoalStripButton` / `GoalTabButton`。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const LAYER_INDEX: int = 45   # ⚠ 右上の通貨（40）より上・窓（200）より下

static var _instance: GoalHud = null
static var _pending_shown: bool = true

var _field: Control = null
var _strip: Button = null
var _tab: Button = null
var _sidebar: PaperSheet = null
var _sidebar_sheet: GoalSheet = null


static func spawn_into(root: Node) -> GoalHud:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: GoalHud = GoalHud.new()
	made.name = "GoalHud"
	root.add_child.call_deferred(made)
	_instance = made
	return made


static func get_instance() -> GoalHud:
	return _instance if _instance != null and is_instance_valid(_instance) and _instance._field != null else null


static func set_shown(value: bool) -> void:
	_pending_shown = value
	var hud: GoalHud = get_instance()
	if hud != null:
		hud._field.visible = value


# ⚠ 形を変えたとき（⚠ 設定を書いたあと）に呼ぶ。
static func refresh() -> void:
	var hud: GoalHud = get_instance()
	if hud != null:
		hud._refresh()


func _ready() -> void:
	layer = LAYER_INDEX
	_field = Control.new()
	_field.name = "Field"
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.visible = _pending_shown
	add_child(_field)

	_strip = Button.new()
	_strip.name = "GoalStrip"
	_strip.theme_type_variation = &"GoalStripButton"
	_strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_strip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_strip.pressed.connect(_on_strip_pressed)
	_field.add_child(_strip)

	_tab = Button.new()
	_tab.name = "GoalTab"
	_tab.theme_type_variation = &"GoalTabButton"
	_tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tab.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tab.pressed.connect(_on_tab_pressed)
	_field.add_child(_tab)

	_sidebar = PaperSheet.new()
	_sidebar.name = "GoalSidebar"
	_sidebar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_sidebar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var width: float = float(_field.get_theme_constant(&"sidebar_width", &"Goal"))
	_sidebar.custom_minimum_size = Vector2(width, 0.0)
	_sidebar.offset_left = -width
	_sidebar.offset_top = float(_field.get_theme_constant(&"sidebar_top", &"Goal"))
	_field.add_child(_sidebar)

	GameManager.goal_changed.connect(_refresh)
	GameManager.material_changed.connect(_on_amount_changed)
	GameManager.resource_changed.connect(_on_amount_changed)
	GameManager.inventory_changed.connect(_on_amount_changed)
	_refresh()


func _on_amount_changed(_a: Variant = null, _b: Variant = null) -> void:
	_refresh_strip_text()


func _refresh() -> void:
	var has: bool = GameManager.has_goal()
	var sidebar_style: bool = GameSettings.goal_style() == GameSettings.GOAL_STYLE_SIDEBAR
	var open: bool = bool(SceneManager.recall(TransferKeys.MEMORY_GOAL_SIDEBAR_OPEN, false))
	_strip.visible = has and not sidebar_style
	_tab.visible = has and sidebar_style
	_sidebar.visible = has and sidebar_style and open
	# ⚠ つまみは開いた紙の左の縁に付ける（⚠ 開いていれば紙の幅だけ左へ）。
	_tab.offset_right = -_sidebar.custom_minimum_size.x if _sidebar.visible else 0.0
	_tab.offset_left = _tab.offset_right
	# ⚠ 縦書き＝1字ずつ改行（⚠ ja.csv の `\n` は取り込みで改行になるか確かめていないので、⚠ コードで割る）。
	var tab_text: String = tr("ui_goal_tab_close" if _sidebar.visible else "ui_goal_tab")
	var chars: PackedStringArray = []
	for i: int in range(tab_text.length()):
		chars.append(tab_text[i])
	_tab.text = "\n".join(chars)
	if _sidebar.visible and _sidebar_sheet == null:
		_sidebar_sheet = GoalSheet.create()
		_sidebar.add_child(_sidebar_sheet)
	elif not _sidebar.visible and _sidebar_sheet != null:
		_sidebar.remove_child(_sidebar_sheet)
		_sidebar_sheet.queue_free()
		_sidebar_sheet = null
	_refresh_strip_text()


func _refresh_strip_text() -> void:
	if _strip == null or not GameManager.has_goal():
		return
	_strip.text = tr("ui_goal_strip") % GoalSheet.summary_text()


func _on_strip_pressed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not GameManager.has_goal():
		return
	var sheet: GoalSheet = GoalSheet.create()
	var window: ModalDialog = Modal.notify(scene, "", [], false, {
		Modal.OPTION_CONTENT: sheet,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})
	if window != null:
		sheet.emptied.connect(window.close)


func _on_tab_pressed() -> void:
	var open: bool = bool(SceneManager.recall(TransferKeys.MEMORY_GOAL_SIDEBAR_OPEN, false))
	SceneManager.remember(TransferKeys.MEMORY_GOAL_SIDEBAR_OPEN, not open)
	_refresh()
