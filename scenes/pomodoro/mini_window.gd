class_name MiniWindow
extends CanvasLayer

# デスクトップの小窓（2026-09-29・回UI-仕組み⑥・手本 Companion）。
#
# ⚠ 人間「⚠ 1あ　⚠ 2あ　⚠ 3い　⚠ 4あ」：⚠ **ゲームの窓そのもの**を小さくしてデスクトップの隅へ（⚠ 終われば元の大きさ・位置）／
#   ⚠ 話しかけない ／ ⚠ 設定の既定はオフ。
# ⚠⚠ 2026-10-05（回P-2・人間「⚠ 小窓中にもポモドーロの機能を充実させたい　⚠ タイマーと最小限のものを」→「⚠ q１あ　ｑｗ　あ　ｑ３　い」）：
#   ⚠ 部屋の絵（暖炉・人・z z）はやめて**タイマーが真ん中**。⚠ 上＝集中／休憩・セットの点・「大きく」／ 真ん中＝残り時間 ／
#   ⚠ その下＝いまのタスク（色の印と名前）／ ⚠ 下＝集中中は「タスクを終える」（⚠ 選んでいるときだけ）・休憩中は「休憩をとばす」。
#   ⚠ 回P-3（10-05）：⚠ 下に「一時停止」⇔「再開」も（⚠ 止めているあいだは上が「集中（停止中）」）。
# ⚠⚠ 2026-10-06（見る回・人間「⚠ 小窓でも、リストを出し入れできるように」）：⚠ 上の「リスト」で窓が下へ伸び、まだのタスクが並ぶ
#   （⚠ 行＝いまのタスクにする・四角＝終える＝サイドバーと同じ口）。⚠ もう一度押すと縮む。⚠ 伸びる高さは Theme の `list_height`。
# ⚠ 小窓になるのは**タイマーが動いている集中と休憩のあいだだけ**（⚠ 振り返り＝文字を打つ・次のセットの「開始」は元の大きさ）。
# ⚠ 窓を小さくするとき、⚠ 画面の論理の大きさ（`content_scale_size`）も小窓の大きさにする（⚠ 1280×720 のまま縮めると字が潰れる）。
# ⚠ 窓の操作はヘッドレスでは何もしない（⚠ 中身の出し入れだけは動く＝検査が見る）。⚠ 値は Theme の `MiniWindow` 型。

const THEME_TYPE: StringName = &"MiniWindow"
const LAYER: int = 90

signal expand_requested
# ⚠ 2026-10-05（回P-2）：⚠ 小窓のまま押せるもの。⚠ 中身は器（`pomodoro.gd`）がやる＝ここは知らせるだけ。
signal skip_requested
signal finish_task_requested
# ⚠ 回P-3（2026-10-05）：⚠ 一時停止 ⇔ 再開。
signal pause_requested
# ⚠ 10-06：⚠ 小窓のリスト（⚠ サイドバーの `task_pressed` / `task_checked` と同じ形）。
signal task_pressed(task_id: String)
signal task_checked(task_id: String, done: bool)

var _active: bool = false
var _saved_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
var _saved_position: Vector2i = Vector2i.ZERO
var _saved_size: Vector2i = Vector2i.ZERO
var _saved_borderless: bool = false
var _saved_on_top: bool = false
var _saved_scale_size: Vector2i = Vector2i.ZERO
var _root: Control = null
var _phase_label: Label = null
var _dots: SetDots = null
var _time_label: Label = null
var _task_line: HBoxContainer = null
var _task_mark: TaskColorMark = null
var _task_label: Label = null
var _finish_button: Button = null
var _skip_button: Button = null
var _pause_button: Button = null
var _list_button: Button = null
var _list_scroll: ScrollContainer = null
var _list_box: VBoxContainer = null
var _list_open: bool = false
var _list_current: String = ""
var _list_dirty: bool = false


static func create() -> MiniWindow:
	var mini: MiniWindow = MiniWindow.new()
	mini.name = "MiniWindow"
	mini.layer = LAYER
	mini.visible = false
	return mini


func is_active() -> bool:
	return _active


# 小窓にする（⚠ 2回呼んでも1回ぶん）。
func enter() -> void:
	if _active:
		return
	_active = true
	_build()
	visible = true
	var mini_size: Vector2i = _mini_size()
	var root_window: Window = get_tree().root
	_saved_scale_size = root_window.content_scale_size
	root_window.content_scale_size = mini_size
	if DisplayServer.get_name() == "headless":
		return
	_saved_mode = DisplayServer.window_get_mode()
	_saved_position = DisplayServer.window_get_position()
	_saved_size = DisplayServer.window_get_size()
	_saved_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_saved_on_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, GameSettings.mini_window_on_top())
	DisplayServer.window_set_size(mini_size)
	# ⚠ いまの画面の使える範囲（⚠ タスクバーを除く）の右下。
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var margin: int = _c(&"margin")
	DisplayServer.window_set_position(usable.position + usable.size - mini_size - Vector2i(margin, margin))


# 小窓の大きさ（⚠ リストを開いているあいだは下へ伸びる）。
func _mini_size() -> Vector2i:
	return Vector2i(_c(&"width"), _c(&"height") + (_c(&"list_height") if _list_open else 0))


func is_list_open() -> bool:
	return _list_open


# リストを出し入れする（⚠ 窓ごと伸び縮み・⚠ 右下に付いたまま）。
func toggle_list() -> void:
	_list_open = not _list_open
	_list_scroll.visible = _list_open
	_list_button.text = tr("ui_mini_list_close") if _list_open else tr("ui_mini_list_open")
	if _list_open:
		_rebuild_list()
	if not _active:
		return
	var mini_size: Vector2i = _mini_size()
	get_tree().root.content_scale_size = mini_size
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(mini_size)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var margin: int = _c(&"margin")
	DisplayServer.window_set_position(usable.position + usable.size - mini_size - Vector2i(margin, margin))


func _refresh_list() -> void:
	if not _list_open or _list_dirty:
		return
	_list_dirty = true
	_rebuild_list.call_deferred()


# ⚠ まだのタスクを並べる（⚠ いまのタスクは「▶」）。⚠ 押した行を押している最中に外さない＝⚠ 知らせは次のフレーム・描き直しも次のフレーム。
func _rebuild_list() -> void:
	_list_dirty = false
	if _list_box == null:
		return
	for child: Node in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var open: Array = GameManager.get_open_tasks()
	if open.is_empty():
		var empty: Label = Label.new()
		empty.name = "MiniListEmpty"
		empty.theme_type_variation = &"MiniTimeLabel"
		empty.text = tr("ui_pomodoro_task_pick_empty")
		_list_box.add_child(empty)
		return
	for raw: Variant in open:
		var task: Dictionary = raw as Dictionary
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "MiniTask_" + task_id
		_list_box.add_child(line)
		# ⚠ 四角は小さい札「□」（⚠ CheckBox は Theme の箱が大きく、行が高くなって4行しか入らなかった＝撮った絵）。⚠ 押すと終える。
		var check: Button = _make_button("MiniCheck", "ui_mini_list_check", _on_list_checked.bind(true, task_id))
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(check)
		var mark: TaskColorMark = TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0)))
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(mark)
		var title: String = str(task.get(GameStateKeys.TASK_TITLE, ""))
		var row: Button = _make_button("MiniRow", "", _on_list_row_pressed.bind(task_id))
		row.text = tr("ui_mini_list_current") % title if task_id == _list_current else title
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(row)


func _on_list_row_pressed(task_id: String) -> void:
	task_pressed.emit.call_deferred(task_id)


func _on_list_checked(on: bool, task_id: String) -> void:
	task_checked.emit.call_deferred(task_id, on)


# 元の大きさ・位置に戻す。
func leave() -> void:
	if not _active:
		return
	_active = false
	visible = false
	get_tree().root.content_scale_size = _saved_scale_size
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, _saved_on_top)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, _saved_borderless)
	DisplayServer.window_set_size(_saved_size)
	DisplayServer.window_set_position(_saved_position)
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(_saved_mode)


# いまの姿を出す（⚠ 器が毎フレーム呼ぶ）。⚠ `task` は選んでいるタスク（⚠ 無ければ空）。
func set_state(seconds: int, focusing: bool, set_index: int = -1, set_total: int = 0, ratio: float = 0.0, task: Dictionary = {}, paused: bool = false, can_pause: bool = false) -> void:
	if _time_label == null:
		return
	_phase_label.text = tr("ui_mini_phase_focus") if focusing else tr("ui_mini_phase_break")
	if paused:
		_phase_label.text = tr("ui_mini_paused") % _phase_label.text
	_pause_button.visible = can_pause
	_pause_button.text = tr("ui_pomodoro_resume") if paused else tr("ui_pomodoro_pause")
	_time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if set_total > 0 and _dots_total != set_total:
		_dots_total = set_total
		_dots.setup(set_total)
	_dots.set_state(set_index, ratio)
	var has_task: bool = not task.is_empty()
	# ⚠ いまのタスクが変わったらリストの「▶」を描き直す。
	var current: String = str(task.get(GameStateKeys.TASK_ID, "")) if has_task else ""
	if current != _list_current:
		_list_current = current
		_refresh_list()
	_task_line.visible = has_task
	if has_task:
		var title: String = str(task.get(GameStateKeys.TASK_TITLE, ""))
		if _task_label.text != title:
			_task_label.text = title
			# ⚠ 名前の長さまで縮める（⚠ 幅を固定すると短い名前で色の印と離れた＝撮った絵）。⚠ 長い名前は `task_width` で … 。
			var font: Font = _task_label.get_theme_font(&"font")
			var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _task_label.get_theme_font_size(&"font_size")).x
			_task_label.custom_minimum_size.x = minf(ceilf(width), float(_c(&"task_width")))
		_task_mark.color_index = int(task.get(GameStateKeys.TASK_COLOR, 0))
	_finish_button.visible = focusing and has_task
	_skip_button.visible = not focusing


var _dots_total: int = 0


func _exit_tree() -> void:
	# ⚠ 小窓のまま画面を離れたら（⚠ やめる・拠点へ）必ず戻す。
	leave()


func _c(key: StringName) -> int:
	return ThemeDB.get_project_theme().get_constant(key, THEME_TYPE)


func get_theme_color_safe(key: StringName) -> Color:
	return ThemeDB.get_project_theme().get_color(key, THEME_TYPE)


# 中身（⚠ 回P-2）：⚠ 暗い地・上の行・残り時間・タスク・下のボタン。⚠ 値は Theme の `MiniWindow` 型と `Mini*` の型。
func _build() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "MiniRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var back: ColorRect = ColorRect.new()
	back.name = "Back"
	back.color = get_theme_color_safe(&"wall")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"MiniMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"MiniColumn"
	margin.add_child(column)
	# ⚠ 上の行：集中／休憩 ・ セットの点 ・ 「大きく」。
	var top: HBoxContainer = HBoxContainer.new()
	top.name = "Top"
	column.add_child(top)
	_phase_label = Label.new()
	_phase_label.name = "PhaseLabel"
	_phase_label.theme_type_variation = &"MiniTimeLabel"
	_phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_phase_label)
	var dots_box: CenterContainer = CenterContainer.new()
	dots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(dots_box)
	_dots = SetDots.new()
	_dots.name = "MiniSetDots"
	dots_box.add_child(_dots)
	# ⚠ リストの出し入れ（10-06）。
	_list_button = _make_button("MiniListButton", "ui_mini_list_open", toggle_list)
	top.add_child(_list_button)
	var expand: Button = Button.new()
	expand.name = "ExpandButton"
	expand.text = tr("ui_mini_expand")
	expand.theme_type_variation = &"MiniButton"
	expand.focus_mode = Control.FOCUS_NONE
	expand.pressed.connect(_on_expand_pressed)
	top.add_child(expand)
	# ⚠ 真ん中：残り時間（⚠ 大きく）。
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.theme_type_variation = &"MiniBigTimeLabel"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_time_label)
	# ⚠ いまのタスク（⚠ 選んでいないときは出さない）。
	_task_line = HBoxContainer.new()
	_task_line.name = "TaskLine"
	_task_line.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_task_line)
	_task_mark = TaskColorMark.create(0)
	_task_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_task_line.add_child(_task_mark)
	_task_label = Label.new()
	_task_label.name = "TaskLabel"
	_task_label.theme_type_variation = &"MiniTimeLabel"
	_task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_task_line.add_child(_task_label)
	# ⚠ 下：集中中は「タスクを終える」・休憩中は「休憩をとばす」（⚠ どちらかだけ出る）。
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(bottom)
	_finish_button = _make_button("FinishTaskButton", "ui_mini_finish_task", _on_finish_pressed)
	bottom.add_child(_finish_button)
	_skip_button = _make_button("SkipBreakButton", "ui_mini_skip_break", _on_skip_pressed)
	bottom.add_child(_skip_button)
	# ⚠ 回P-3：⚠ 一時停止（⚠ 集中を始めたあとと休憩のあいだ）。
	_pause_button = _make_button("MiniPauseButton", "ui_pomodoro_pause", _on_pause_pressed)
	bottom.add_child(_pause_button)
	# ⚠ リスト（10-06）：⚠ 開いているあいだだけ。⚠ 中で送る。
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "MiniList"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.custom_minimum_size.y = float(_c(&"list_height")) - float(_c(&"gap"))
	_list_scroll.visible = _list_open
	column.add_child(_list_scroll)
	_list_box = VBoxContainer.new()
	_list_box.name = "MiniListBox"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list_box)
	GameManager.tasks_changed.connect(_refresh_list)


func _make_button(node_name: String, key: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = tr(key)
	button.theme_type_variation = &"MiniButton"
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	return button


func _on_expand_pressed() -> void:
	expand_requested.emit()


# ⚠ 押した最中に器が小窓を外す（⚠ とばすとタイマーが止まる）＝⚠ 知らせるのは次のフレーム。
func _on_skip_pressed() -> void:
	skip_requested.emit.call_deferred()


func _on_finish_pressed() -> void:
	finish_task_requested.emit.call_deferred()


func _on_pause_pressed() -> void:
	pause_requested.emit.call_deferred()
