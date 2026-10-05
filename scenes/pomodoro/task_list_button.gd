class_name TaskListButton
extends UiButton

# ポモドーロ中にタスクのリストを見る（2026-10-04・人間「⚠ ポモドーロ中にリストを見れるように　メニューと同じように」）。
#
# ⚠ 形は地図の右上のメニュー（`RunMenuButton`）と同じ：⚠ 押すと板が下に開き、⚠ 外を押すと閉じる（`PopupPanel`）。
# ⚠ 中身は紙（⚠ 字が墨になる）：⚠ 一覧と同じ（⚠ まだのもの ＋ 今日終えたもの＝線）・色の印・集中した時間・期限の判。
# ⚠ 2026-10-05（モック6・人間「⚠ タスクごとにチェックさせてその時のタイマーの時間を記録したい」）：
#   ⚠ 四角を押すと終わり（`task_checked`）／ ⚠ 行を押すといまのタスクを替える（`task_pressed`）。⚠ 時間の区切りは画面（`pomodoro.gd`）が持つ。
#   ⚠ いま数えているタスクは明るい行。⚠ 板は画面の右端に寄せ、砂時計に被らない幅（Theme `Task/running_*`）。
# ⚠ 開いている間に中身が変わったら次のフレームで描き直す。⚠ 再描画に await を持たせない（CLAUDE.md 5番）。
# ⚠ ポモドーロの画面だけで使う＝scenes/pomodoro/（AGENTS.md 置き場のルール）。

signal task_pressed(task_id: String)
signal task_checked(task_id: String, done: bool)

const THEME_TYPE: StringName = &"Task"

# いま数えているタスクの task_id を返す口（⚠ 画面が渡す。⚠ 無ければ ""）。
var current_task_provider: Callable = Callable()

var _popup: PopupPanel = null
var _list: VBoxContainer = null
var _heading: SheetHeading = null
var _dirty: bool = false
var _hint: Label = null


func _init() -> void:
	super._init()
	name = "TaskListButton"
	variant = UiButton.Variant.GHOST
	label_key = "ui_pomodoro_task_list"
	_popup = PopupPanel.new()
	_popup.name = "TaskListPopup"
	add_child(_popup)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	_popup.add_child(sheet)
	var body: VBoxContainer = VBoxContainer.new()
	sheet.add_child(body)
	_heading = SheetHeading.new()
	_heading.name = "ListHeading"
	_heading.title_key = "ui_task_wall_title"
	body.add_child(_heading)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.theme_type_variation = &"CaptionLabel"
	body.add_child(_hint)
	pressed.connect(_open)


func _ready() -> void:
	super._ready()
	text = tr(label_key)
	_hint.text = tr("ui_pomodoro_task_list_hint")
	var scroll: Control = _list.get_parent() as Control
	scroll.custom_minimum_size = Vector2(float(get_theme_constant(&"running_width", THEME_TYPE)), float(get_theme_constant(&"running_height", THEME_TYPE)))
	GameManager.tasks_changed.connect(_queue_rebuild)


func is_open() -> bool:
	return _popup.visible


# ⚠ ボタンの右下に合わせて開く（⚠ 右上に置くので、⚠ 板は左へ伸ばす＝`RunMenuButton` と同じ）。
func _open() -> void:
	_rebuild()
	_popup.reset_size()
	var rect: Rect2 = get_global_rect()
	var popup_size: Vector2 = Vector2(_popup.get_contents_minimum_size())
	var pos: Vector2 = Vector2(rect.end.x - popup_size.x, rect.end.y)
	_popup.popup(Rect2i(Vector2i(pos), Vector2i(popup_size)))


func _queue_rebuild() -> void:
	if _dirty or not _popup.visible:
		return
	_dirty = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var current: String = str(current_task_provider.call()) if current_task_provider.is_valid() else ""
	var tasks: Array = GameManager.get_tasks()
	_heading.right_text = tr("ui_task_count") % GameManager.get_open_tasks().size()
	if tasks.is_empty():
		_list.add_child(EmptyState.create("ui_pomodoro_task_pick_empty", "ui_pomodoro_task_list_empty_hint"))
		return
	for raw: Variant in tasks:
		var task: Dictionary = raw as Dictionary
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var done: bool = int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0
		var row: LedgerRow = LedgerRow.new()
		row.name = "List_" + task_id
		row.compact = true
		row.selected = task_id == current
		if done:
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			row.pressed.connect(_on_row_pressed.bind(task_id))
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var check: TaskCheck = TaskCheck.create(done)
		check.toggled.connect(_on_check_toggled.bind(task_id))
		line.add_child(check)
		var mark: TaskColorMark = TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0)))
		if done:
			mark.modulate.a = 0.4
		line.add_child(mark)
		var title: Label = Label.new()
		title.name = "TitleLabel"
		title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if done:
			title.theme_type_variation = &"TaskDoneLabel"
			title.draw.connect(_draw_strike.bind(title))
		line.add_child(title)
		var seconds: int = int(task.get(GameStateKeys.TASK_FOCUS_SEC, 0))
		if seconds >= 60:
			var focus: Label = Label.new()
			focus.name = "FocusLabel"
			focus.theme_type_variation = &"CaptionLabel"
			focus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			focus.text = GameManager.task_focus_text(seconds)
			line.add_child(focus)
		var stamp: Stamp = TaskParts.due_stamp(task)
		if stamp != null:
			line.add_child(stamp)
		_list.add_child(row)


func _draw_strike(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = label.size.y * 0.5
	label.draw_line(Vector2(0.0, y), Vector2(width, y), label.get_theme_color(&"font_color"), float(get_theme_constant(&"strike", THEME_TYPE)))


func _on_row_pressed(task_id: String) -> void:
	task_pressed.emit(task_id)
	_dirty = true
	_rebuild.call_deferred()


func _on_check_toggled(on: bool, task_id: String) -> void:
	task_checked.emit(task_id, on)
