class_name Toast
extends CanvasLayer

# 画面の上の小さな知らせ（2026-10-07・回UI-便 F・人間「⚠ 判断がいらないものをとりあえずぜんぶ」）。
#
# ⚠ 窓を出さずに上の真ん中へ流し、しばらくすると消える（⚠ 押さなくてよい・操作を止めない）。
# ⚠ いま流すのは**作業場の完成**と**鍛冶のレベルが上がった**（10-09・`EQ-5`）と**初回の記録**（10-09・`EQ-9`）だけ（⚠ 作業場は時間で勝手に進むので、どの画面にいても気づけない）。
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
var _first_records: int = 0   # ⚠ このフレームに増えた初回の記録（⚠ まとめて1本で知らせる）


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
	# ⚠ 10-09（回SYS-2・`EQ-5`・人間「⚠ ４あ」）：⚠ 鍛冶のレベルが上がったら知らせる（⚠ 鍛える・作るの直後に気づけるように）。
	GameManager.forge_level_changed.connect(_on_forge_level_changed)
	# ⚠ 10-09（回SYS-3・`EQ-9`・人間「⚠ ３あ」）：⚠ 初回の記録が増えたら知らせる。⚠ 宝箱などで一度に何件も増えるので、⚠ そのフレームの分を1本にまとめる。
	GameManager.first_record_added.connect(_on_first_record_added)


func _on_forge_level_changed(level: int) -> void:
	show_message(tr("ui_toast_forge_level_up") % level)


func _on_first_record_added(_item_id: String) -> void:
	_first_records += 1
	if _first_records == 1:
		_flush_first_records.call_deferred()


func _flush_first_records() -> void:
	var count: int = _first_records
	_first_records = 0
	if count <= 0:
		return
	var parts: Array[String] = []
	var per: Dictionary = GameManager.get_first_record_bonus_per_record()
	for stat_key: String in GameManager.get_stat_keys():
		if per.has(stat_key):
			parts.append("%s +%d%s" % [tr("ui_training_stat_" + stat_key), int(per[stat_key]) * count, "%" if GameManager.is_percent_stat(stat_key) else ""])
	show_message(tr("ui_toast_first_record") % [count, "  ".join(parts)])


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
