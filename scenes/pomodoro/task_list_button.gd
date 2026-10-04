class_name TaskListButton
extends UiButton

# ポモドーロ中にタスクのリストを見る（2026-10-04・人間「⚠ ポモドーロ中にリストを見れるように　メニューと同じように」）。
#
# ⚠ 形は地図の右上のメニュー（`RunMenuButton`）と同じ：⚠ 押すと小さな板が下に開き、⚠ 外を押すと閉じる（`PopupPanel`）。
# ⚠ 中身は紙（⚠ 字が墨になる）：⚠ まだのタスクを全部（⚠ 拠点の紙と同じ並び・`TK-3`）・色の印・期限の判（`TK-13`）・ポモドーロの回数。
#   ⚠ いま数えているタスク（⚠ 選んだもの）は明るい紙の行。⚠ 見るだけ（⚠ 書き換えはタスクの画面）。
# ⚠ 開くたびに作り直す（⚠ 開いている間に🍅が増えても次に開けば合う）。⚠ 再描画に await を持たせない（CLAUDE.md 5番）。
# ⚠ ポモドーロの画面だけで使う＝scenes/pomodoro/（AGENTS.md 置き場のルール）。

const THEME_TYPE: StringName = &"Task"

# いま数えているタスクの task_id を返す口（⚠ 画面が渡す。⚠ 無ければ ""）。
var current_task_provider: Callable = Callable()

var _popup: PopupPanel = null
var _list: VBoxContainer = null
var _heading: SheetHeading = null


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
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	pressed.connect(_open)


func _ready() -> void:
	super._ready()
	text = tr(label_key)
	var scroll: Control = _list.get_parent() as Control
	scroll.custom_minimum_size = Vector2(float(get_theme_constant(&"wall_width", THEME_TYPE)), float(get_theme_constant(&"pick_height", THEME_TYPE)))


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


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var current: String = str(current_task_provider.call()) if current_task_provider.is_valid() else ""
	var open_tasks: Array = GameManager.get_open_tasks()
	_heading.right_text = tr("ui_task_count") % open_tasks.size()
	if open_tasks.is_empty():
		_list.add_child(EmptyState.create("ui_pomodoro_task_pick_empty", "ui_pomodoro_task_list_empty_hint"))
		return
	for raw: Variant in open_tasks:
		var task: Dictionary = raw as Dictionary
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var row: LedgerRow = LedgerRow.new()
		row.name = "List_" + task_id
		row.compact = true
		row.selected = task_id == current
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		line.add_child(TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0))))
		var title: Label = Label.new()
		title.name = "TitleLabel"
		title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(title)
		var stamp_key: String = TaskWallNote.due_stamp_key(GameManager.get_task_due_state(task))
		if stamp_key != "":
			var stamp: Stamp = Stamp.new()
			stamp.name = "DueStamp"
			stamp.label_key = stamp_key
			stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(stamp)
		var count: int = int(task.get(GameStateKeys.TASK_POMODORO_COUNT, 0))
		if count > 0:
			var count_label: Label = Label.new()
			count_label.name = "CountLabel"
			count_label.theme_type_variation = &"CaptionLabel"
			count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			count_label.text = tr("ui_task_pomodoro_count") % count
			line.add_child(count_label)
		_list.add_child(row)
