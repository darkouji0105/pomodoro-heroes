class_name Toast
extends CanvasLayer

# 画面の上の小さな知らせ（2026-10-07・回UI-便 F・人間「⚠ 判断がいらないものをとりあえずぜんぶ」）。
#
# ⚠ 窓を出さずに上の真ん中へ流し、しばらくすると消える（⚠ 押さなくてよい・操作を止めない）。
# ⚠ いま流すのは**作業場の完成**だけ（⚠ 時間で勝手に進むので、どの画面にいても気づけない）。
#   ⚠ 宝箱・研究などは自分で操作した直後に画面に出るので流さない（⚠ 二重になる）。
# ⚠ 置き場は `ResourceGainEffect` と同じく root の常駐（⚠ `SceneManager` が生やす・Autoload を増やさない）。
# ⚠ 値は Theme の `Toast` 型（⚠ 出ている長さ・消える長さ・上の余白）と `ToastPanel` / `ToastLabel`。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"Toast"
const LAYER_INDEX: int = 250   # ⚠ 窓（200）より上・演出（300）より下
const POLL_SEC: float = 1.0

static var _instance: Toast = null

var _column: VBoxContainer = null
var _completed: Dictionary = {}   # queue_id -> true（⚠ もう知らせた完成）
var _wait: float = 0.0


static func spawn_into(root: Node) -> Toast:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	var made: Toast = Toast.new()
	made.name = "Toast"
	root.add_child.call_deferred(made)
	_instance = made
	return made


static func get_instance() -> Toast:
	return _instance if _instance != null and is_instance_valid(_instance) else null


func _ready() -> void:
	layer = LAYER_INDEX
	var field: Control = Control.new()
	field.name = "Field"
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_column.offset_top = float(field.get_theme_constant(&"top", THEME_TYPE))
	field.add_child(_column)
	# ⚠ 起動したときに既に完成しているものは知らせない（⚠ 前のセッションの完成）。
	_completed = _completed_ids()


func _process(delta: float) -> void:
	_wait += delta
	if _wait < POLL_SEC:
		return
	_wait = 0.0
	GameManager.refresh_crafting_queue_if_needed()
	var now: Dictionary = _completed_ids()
	var fresh: int = 0
	for queue_id: String in now:
		if not _completed.has(queue_id):
			fresh += 1
	_completed = now
	if fresh > 0:
		show_message(tr("ui_toast_craft_done") % fresh)


func _completed_ids() -> Dictionary:
	var ids: Dictionary = {}
	for raw: Variant in GameManager.get_crafting_queue():
		if raw is Dictionary and str((raw as Dictionary).get(GameStateKeys.CRAFT_STATUS, "")) == GameStateKeys.CRAFT_STATUS_COMPLETED:
			ids[str((raw as Dictionary).get(GameStateKeys.CRAFT_QUEUE_ID, ""))] = true
	return ids


# ⚠ 1つ流す。⚠ 重なったら縦に積む。
func show_message(text: String) -> PanelContainer:
	if _column == null:
		return null
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ToastItem"
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.name = "ToastLabel"
	label.theme_type_variation = &"ToastLabel"
	label.text = text
	panel.add_child(label)
	_column.add_child(panel)
	var show_sec: float = float(_column.get_theme_constant(&"show_ms", THEME_TYPE)) / 1000.0
	var fade_sec: float = float(_column.get_theme_constant(&"fade_ms", THEME_TYPE)) / 1000.0
	var tween: Tween = panel.create_tween()
	tween.tween_interval(show_sec)
	tween.tween_property(panel, "modulate:a", 0.0, fade_sec)
	tween.tween_callback(panel.queue_free)
	return panel
