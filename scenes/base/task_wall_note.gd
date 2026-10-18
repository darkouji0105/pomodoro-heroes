class_name TaskWallNote
extends VBoxContainer

# 本部の「やること」（2026-10-04・DECISIONS.md `TK-3`・`TK-13`・PLAN_TASK_MEMO.md §3-2）。
#
# ⚠⚠ 10-18（回UI-1018-6・web版の手本 `05_base_desk.png`）：⚠ 1枚の紙をやめ、⚠ **今日の紙（`BaseTodaySheet`）の中の欄**にした。
#   ⚠ 行の左に四角（`TaskCheck`）＝⚠ 押すと終えたことになる（`TK-4`）。⚠ 今日終えたものは薄墨＋線で残る（⚠ 朝4:00 に記録へ＝`TK-6`）。
#   ⚠ 下の「＋ やることを足す」でタスクの画面へ（⚠ 前の「ひらく」と同じ口・同じ名前）。
# ⚠ まだのタスクを**全部**出す（⚠ 件数で切らない・⚠ 溢れたら欄の中で送る＝`TK-3`）。⚠ 並びは一覧と同じ（`TK-13`）。
# ⚠ 期限を過ぎた・今日が期限のものは小さい判（`TK-13`）。⚠ 行を押すとタスクの画面へ（⚠ `SceneManager` 経由）。
# ⚠ 拠点の画面だけで使う＝scenes/base/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

const TASK_SCREEN_PATH: String = "res://scenes/base/task_screen.tscn"
const THEME_TYPE: StringName = &"Task"

var _count: Label = null
var _due_summary: Label = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _more: Label = null


static func create() -> TaskWallNote:
	var note: TaskWallNote = TaskWallNote.new()
	note.name = "TaskWallNote"
	return note


func _ready() -> void:
	theme_type_variation = &"TightList"
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "NoteHead"
	add_child(head)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_hq_todo_caption")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.clip_text = true
	head.add_child(caption)
	_due_summary = Label.new()
	_due_summary.name = "DueSummary"
	_due_summary.theme_type_variation = &"SmallErrorLabel"
	head.add_child(_due_summary)
	_count = Label.new()
	_count.name = "CountLabel"
	_count.theme_type_variation = &"CaptionLabel"
	head.add_child(_count)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.get_v_scroll_bar().value_changed.connect(_on_scrolled)
	_scroll.resized.connect(_update_more)
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 行が並び終わると大きさが変わる＝⚠ そのとき数え直す（⚠ 並ぶ前に数えると 0 になる）。
	_list.resized.connect(_update_more)
	_scroll.add_child(_list)
	_more = Label.new()
	_more.name = "MoreLabel"
	_more.theme_type_variation = &"CaptionLabel"
	add_child(_more)
	var open: Button = UiButton.create_paper_choice("ui_hq_todo_add")
	open.name = "OpenTasksButton"
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.pressed.connect(_open_task_screen)
	add_child(open)
	GameManager.tasks_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	# ⚠ 今日終えたものも残す（⚠ 朝4:00 に記録へ移るまで一覧に居る＝`get_tasks()`）。
	var tasks: Array = GameManager.get_tasks()
	var open_tasks: Array = GameManager.get_open_tasks()
	_count.text = tr("ui_task_count") % open_tasks.size()
	var overdue: int = 0
	var today: int = 0
	for raw: Variant in open_tasks:
		match GameManager.get_task_due_state(raw as Dictionary):
			GameManager.TASK_DUE_OVERDUE:
				overdue += 1
			GameManager.TASK_DUE_TODAY:
				today += 1
	var summary: Array[String] = []
	if overdue > 0:
		summary.append(tr("ui_task_summary_overdue") % overdue)
	if today > 0:
		summary.append(tr("ui_task_summary_today") % today)
	_due_summary.text = tr("ui_task_note_separator").join(summary)
	_due_summary.visible = not summary.is_empty()
	if tasks.is_empty():
		var empty: Control = EmptyState.create("ui_task_wall_empty", "ui_hq_todo_empty_hint")
		# ⚠ 紙の幅に収める（⚠ 折り返さないと今日の紙ごと広がり、机が画面からはみ出した＝10-18 の絵）。
		for label: Node in empty.find_children("*", "Label", true, false):
			(label as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(label as Label).custom_minimum_size.x = 1.0
		_list.add_child(empty)
	# ⚠ 10-09（回TK-F・`TK-18`）：⚠ フォルダごとに見出し（⚠ 押すと畳む＝タスクの画面・ポモドーロと共通）。⚠ フォルダが無ければ前のまま。
	#   ⚠ 10-09（回TK-F2）：⚠ フォルダごとの箱（`TaskFolderBox`）の中に並べる。
	var show_headers: bool = not GameManager.get_task_folders().is_empty()
	_list.theme_type_variation = &"TaskFolderStack" if show_headers else &""
	for raw_group: Variant in GameManager.get_task_groups(tasks):
		var group: Dictionary = raw_group as Dictionary
		var members: Array = group.get(GameManager.TASK_GROUP_TASKS, []) as Array
		if not show_headers:
			for raw: Variant in members:
				_add_row(raw as Dictionary, _list)
			continue
		var box: TaskFolderBox = TaskFolderBox.create(group, members.size())
		_list.add_child(box)
		TaskDrag.attach_folder(box)
		if not bool(group.get(GameManager.TASK_GROUP_COLLAPSED, false)):
			for raw: Variant in members:
				_add_row(raw as Dictionary, box.rows)
		box.finish()
	_update_more.call_deferred()


# ⚠ 1行（⚠ 10-09 回TK-F で `_rebuild()` から切り出した）。⚠ 回TK-F2：⚠ 置き先（`_list` か箱の中）を渡す。
func _add_row(task: Dictionary, parent: Node) -> void:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var done: bool = int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0
	var row: LedgerRow = LedgerRow.new()
	row.name = "Note_" + task_id
	row.compact = true
	row.pressed.connect(_open_task_screen)
	# ⚠ 10-17（人間「⚠ サイドバーと拠点のdragも」・`TK-19`）：⚠ つまんで並べ替え・フォルダへ。
	TaskDrag.attach_row(row, task)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	# ⚠ 10-18：⚠ 終えたかは四角で（`TK-4`）。
	var check: TaskCheck = TaskCheck.create(done)
	check.toggled.connect(_on_done_toggled.bind(task_id))
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
		# ⚠ 終えたものは薄墨＋線（`TK-6`・タスクの画面と同じ）。
		title.theme_type_variation = &"TaskDoneLabel"
		title.draw.connect(_draw_strike.bind(title))
	line.add_child(title)
	if not done:
		var stamp: Stamp = TaskParts.due_stamp(task)
		if stamp != null:
			line.add_child(stamp)
	parent.add_child(row)


func _on_done_toggled(pressed: bool, task_id: String) -> void:
	var _changed: bool = GameManager.set_task_done(task_id, pressed)


func _draw_strike(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = label.size.y * 0.5
	label.draw_line(Vector2(0.0, y), Vector2(width, y), label.get_theme_color(&"font_color"), 1.0)


func _on_scrolled(_value: float) -> void:
	_update_more()


# 「下にあと◯件」＝送りの下に隠れている行の数（⚠ 0 なら出さない）。
func _update_more() -> void:
	if _list == null or not is_inside_tree():
		return
	# ⚠ 10-09（回TK-F2）：⚠ 行は箱の中に入る＝⚠ 画面の上の位置で比べる（⚠ 親からの位置では箱ごとにずれる）。
	var bottom: float = _scroll.get_global_rect().end.y
	var hidden: int = 0
	# ⚠ 数えるのはタスクの行だけ（⚠ フォルダの見出しは数えない・10-09）。
	for row: Node in _list.find_children("Note_*", "", true, false):
		var rect: Rect2 = (row as Control).get_global_rect()
		if rect.position.y + rect.size.y * 0.5 > bottom:
			hidden += 1
	_more.text = tr("ui_task_wall_more") % hidden if hidden > 0 else ""
	_more.visible = hidden > 0


func _open_task_screen() -> void:
	SceneManager.change_scene(TASK_SCREEN_PATH)
