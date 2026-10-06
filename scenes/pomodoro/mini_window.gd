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
# ⚠⚠ 2026-10-06（見る回・人間「⚠ 小窓でも、リストを出し入れできるように」→「⚠ リストのサイドバーをそのまま」→「⚠ 上にリストを出して追加はいらないかも」）：
#   ⚠ 上の「リスト」で窓が**上へ**伸び、⚠ ポモドーロの右のサイドバー（`TaskSidebar`）をタイマーの上に出す（⚠ 行＝替える・四角＝終える）。
#   ⚠ ペンは出さない・⚠ 「足す」欄は出す（⚠ 同じ日・人間「⚠ 小窓のリストからもタスクを追加できるように　大きな方の窓と同じアセットを」）。⚠ 伸びる高さは Theme の `list_top_height`。
# ⚠ 時間の下に [一時停止][次へ]（10-06・人間「⚠ 次へ行くボタンは真ん中付近に」）：⚠ 画面の真ん中と同じ丸いアイコン（`MiniTimerButton`）。
#   ⚠ 次へ＝始める前はじめる ／ 集中中は集中を終える ／ 休憩はとばす（⚠ 器の `end_phase()`）。
# ⚠ 上の「リスト」「大きく」はアイコン（⚠ 字だと「これから集中」のとき上の行が 300 に入りきらなかった＝人間「⚠ いりきってないボタンがある」）。
# ⚠ 「タスクを終える」はタスクの行の右の ✓（⚠ 行を1つ減らす）。
# ⚠ 振り返りも小窓（10-06・人間「⚠ 振り返りも小窓でできるように」）：⚠ 1行の欄と「確定」・あと何文字。⚠ 判定と確定は振り返りの画面の口（器が通す）。
# ⚠ 窓を動かすときは**小窓にしたときの画面**の右下（10-06・人間「⚠ リストを開くと複数モニターの場合モニター間を移動してしまう」）。
#   ⚠ 先に位置、あとから大きさ（⚠ 大きさを先に変えると隣の画面へはみ出し、⚠ その画面の右下へ飛んだ）。
# ⚠ 小窓になるのは**タイマーが動いている集中と休憩のあいだだけ**（⚠ 振り返り＝文字を打つ・次のセットの「開始」は元の大きさ）。
# ⚠ 窓を小さくするとき、⚠ 画面の論理の大きさ（`content_scale_size`）も小窓の大きさにする（⚠ 1280×720 のまま縮めると字が潰れる）。
# ⚠ 窓の操作はヘッドレスでは何もしない（⚠ 中身の出し入れだけは動く＝検査が見る）。⚠ 値は Theme の `MiniWindow` 型。

const THEME_TYPE: StringName = &"MiniWindow"
const LAYER: int = 90

signal expand_requested
# ⚠ 2026-10-05（回P-2）：⚠ 小窓のまま押せるもの。⚠ 中身は器（`pomodoro.gd`）がやる＝ここは知らせるだけ。
signal next_requested
# ⚠ 振り返り（10-06）。
signal reflection_changed(text: String)
signal reflection_submitted
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
var _next_button: Button = null
var _controls: HBoxContainer = null
var _reflection_line: HBoxContainer = null
var _reflection_edit: LineEdit = null
var _reflection_ok: Button = null
var _reflection_hint: Label = null
# ⚠ 小窓にしたときの画面（⚠ 伸び縮みしても同じ画面の右下）。
var _screen: int = -1
var _pause_button: Button = null
var _list_button: Button = null
var _sidebar: TaskSidebar = null
var _list_open: bool = false
var _list_current: String = ""


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
	_screen = DisplayServer.window_get_current_screen()
	_saved_mode = DisplayServer.window_get_mode()
	_saved_position = DisplayServer.window_get_position()
	_saved_size = DisplayServer.window_get_size()
	_saved_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	_saved_on_top = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, GameSettings.mini_window_on_top())
	_place_window(mini_size)


# ⚠ 小窓にしたときの画面の使える範囲（⚠ タスクバーを除く）の右下へ。⚠ 先に位置・あとから大きさ。
func _place_window(mini_size: Vector2i) -> void:
	var screen: int = _screen if _screen >= 0 else DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin: int = _c(&"margin")
	DisplayServer.window_set_position(usable.position + usable.size - mini_size - Vector2i(margin, margin))
	DisplayServer.window_set_size(mini_size)
	DisplayServer.window_set_position(usable.position + usable.size - mini_size - Vector2i(margin, margin))


# 小窓の大きさ（⚠ リストを開いているあいだは上へ伸びる）。
func _mini_size() -> Vector2i:
	return Vector2i(_c(&"width"), _c(&"height") + (_c(&"list_top_height") if _list_open else 0))


func is_list_open() -> bool:
	return _list_open


# リストを出し入れする（⚠ 窓ごと伸び縮み・⚠ 右下に付いたまま）。
func toggle_list() -> void:
	_list_open = not _list_open
	_sidebar.visible = _list_open
	_list_button.tooltip_text = tr("ui_mini_list_close") if _list_open else tr("ui_mini_list_open")
	if _list_open:
		_sidebar.refresh()
	if not _active:
		return
	var mini_size: Vector2i = _mini_size()
	get_tree().root.content_scale_size = mini_size
	if DisplayServer.get_name() == "headless":
		return
	_place_window(mini_size)


func _current_for_list() -> String:
	return _list_current


func _on_side_pressed(task_id: String) -> void:
	task_pressed.emit(task_id)


func _on_side_checked(task_id: String, done: bool) -> void:
	task_checked.emit(task_id, done)


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
	DisplayServer.window_set_position(_saved_position)
	DisplayServer.window_set_size(_saved_size)
	DisplayServer.window_set_position(_saved_position)
	_screen = -1
	if _saved_mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(_saved_mode)


# いまの姿を出す（⚠ 器が毎フレーム呼ぶ）。⚠ `task` は選んでいるタスク（⚠ 無ければ空）。
func set_state(seconds: int, focusing: bool, set_index: int = -1, set_total: int = 0, ratio: float = 0.0, task: Dictionary = {}, paused: bool = false, can_pause: bool = false, waiting: bool = false, next_tip: String = "") -> void:
	if _time_label == null:
		return
	_phase_label.text = tr("ui_mini_phase_focus") if focusing else tr("ui_mini_phase_break")
	if waiting:
		_phase_label.text = tr("ui_mini_phase_ready")
	_next_button.visible = next_tip != ""
	_next_button.tooltip_text = next_tip
	if paused:
		_phase_label.text = tr("ui_mini_paused") % _phase_label.text
	_pause_button.visible = can_pause
	_pause_button.icon = IconTextures.for_timer(IconTextures.NAME_TIMER_PLAY if paused else IconTextures.NAME_TIMER_PAUSE)
	_pause_button.tooltip_text = tr("ui_pomodoro_resume") if paused else tr("ui_pomodoro_pause")
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
		if _list_open:
			_sidebar.refresh()
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
	# ⚠ 上＝サイドバー（⚠ 「リスト」のあいだだけ）／ ⚠ 下＝タイマーの柱。
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "MiniBody"
	body.theme_type_variation = &"MiniBody"
	margin.add_child(body)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"MiniColumn"
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(column)
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
	_list_button = _make_button("MiniListButton", "", toggle_list)
	_list_button.theme_type_variation = &"MiniIconButton"
	_list_button.icon = IconTextures.for_timer(IconTextures.NAME_MINI_LIST)
	_list_button.tooltip_text = tr("ui_mini_list_open")
	top.add_child(_list_button)
	var expand: Button = _make_button("ExpandButton", "", _on_expand_pressed)
	expand.theme_type_variation = &"MiniIconButton"
	expand.icon = IconTextures.for_timer(IconTextures.NAME_MINI_EXPAND)
	expand.tooltip_text = tr("ui_mini_expand")
	top.add_child(expand)
	# ⚠ 真ん中：残り時間（⚠ 大きく）。
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.theme_type_variation = &"MiniBigTimeLabel"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_time_label)
	# ⚠ 時間のすぐ下：[一時停止][次へ]（10-06）。
	var controls: HBoxContainer = HBoxContainer.new()
	controls.name = "Controls"
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	_controls = controls
	_pause_button = _make_button("MiniPauseButton", "", _on_pause_pressed)
	_pause_button.theme_type_variation = &"MiniTimerButton"
	controls.add_child(_pause_button)
	_next_button = _make_button("MiniNextButton", "", _on_next_pressed)
	_next_button.theme_type_variation = &"MiniTimerButton"
	_next_button.icon = IconTextures.for_timer(IconTextures.NAME_TIMER_NEXT)
	controls.add_child(_next_button)
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
	# ⚠ 「タスクを終える」＝行の右の ✓（10-06）。
	_finish_button = _make_button("FinishTaskButton", "", _on_finish_pressed)
	_finish_button.theme_type_variation = &"MiniIconButton"
	_finish_button.icon = IconTextures.for_task_finish()
	_finish_button.tooltip_text = tr("ui_mini_finish_task")
	_task_line.add_child(_finish_button)
	# ⚠ 振り返り（10-06）：⚠ 1行の欄と「確定」・その下にあと何文字。⚠ 振り返りのあいだだけ。
	_reflection_line = HBoxContainer.new()
	_reflection_line.name = "ReflectionLine"
	_reflection_line.visible = false
	column.add_child(_reflection_line)
	_reflection_edit = LineEdit.new()
	_reflection_edit.name = "MiniReflectionEdit"
	_reflection_edit.placeholder_text = tr("ui_mini_reflection_placeholder")
	_reflection_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reflection_edit.text_changed.connect(_on_reflection_text_changed)
	_reflection_edit.text_submitted.connect(_on_reflection_text_submitted)
	_reflection_line.add_child(_reflection_edit)
	_reflection_ok = _make_button("MiniReflectionOk", "ui_mini_reflection_ok", _on_reflection_ok_pressed)
	_reflection_line.add_child(_reflection_ok)
	_reflection_hint = Label.new()
	_reflection_hint.name = "MiniReflectionHint"
	_reflection_hint.theme_type_variation = &"MiniTimeLabel"
	_reflection_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reflection_hint.visible = false
	column.add_child(_reflection_hint)
	# ⚠ リスト（10-06）：⚠ ポモドーロのサイドバーと同じ部品。⚠ 開いているあいだだけ。
	_sidebar = TaskSidebar.create()
	_sidebar.name = "MiniSidebar"
	_sidebar.show_edit = false
	_sidebar.show_hint = false
	_sidebar.current_task_provider = _current_for_list
	_sidebar.task_pressed.connect(_on_side_pressed)
	_sidebar.task_checked.connect(_on_side_checked)
	_sidebar.visible = _list_open
	body.add_child(_sidebar)
	body.move_child(_sidebar, 0)
	# ⚠ 小窓の幅に合わせる（⚠ サイドバーは自分で 320 を取る＝小窓 300 からはみ出す）・⚠ 高さは伸びたぶん。
	_sidebar.custom_minimum_size = Vector2(0.0, float(_c(&"list_top_height") - _c(&"gap")))


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


# ⚠ 押した最中に器が小窓を外すことがある＝⚠ 知らせるのは次のフレーム。
func _on_next_pressed() -> void:
	next_requested.emit.call_deferred()


# 振り返りの姿（⚠ 器が毎フレーム呼ぶ）。⚠ 振り返りのあいだはタスクの行と [一時停止][次へ] を隠す。
func set_reflection_state(reflecting: bool, remaining: int) -> void:
	if _reflection_line == null:
		return
	_reflection_line.visible = reflecting
	_reflection_hint.visible = reflecting
	_controls.visible = not reflecting
	if reflecting:
		_phase_label.text = tr("ui_mini_phase_reflection")
		_task_line.visible = false
		_reflection_ok.disabled = remaining > 0
		_reflection_hint.text = tr("ui_mini_reflection_remaining") % remaining if remaining > 0 else tr("ui_mini_reflection_ready")


# 欄の字を入れる（⚠ 振り返りの始まりで空・⚠ 大きい画面から移ったときはその字）。
func set_reflection_text(value: String) -> void:
	if _reflection_edit != null and _reflection_edit.text != value:
		_reflection_edit.text = value


func _on_reflection_text_changed(text: String) -> void:
	reflection_changed.emit(text)


func _on_reflection_text_submitted(_text: String) -> void:
	_on_reflection_ok_pressed()


# ⚠ 確定で振り返りが終わり、器が休憩へ移る（⚠ 押している最中に外さない＝次のフレーム）。
func _on_reflection_ok_pressed() -> void:
	reflection_submitted.emit.call_deferred()


func _on_finish_pressed() -> void:
	finish_task_requested.emit.call_deferred()


func _on_pause_pressed() -> void:
	pause_requested.emit.call_deferred()
