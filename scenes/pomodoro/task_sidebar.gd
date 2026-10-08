class_name TaskSidebar
extends PaperSheet

# ポモドーロの右のサイドバー「やること」（2026-10-05・人間「⚠ やることリストはサイドバーにする」「⚠ ポモドーロ中もやることリストを追加できるように」）。
#
# ⚠ 前は右上の「リスト」で開く板（`TaskListButton`・10-04）。⚠ どのフェーズでもいつも出す（⚠ 集中を始める前・集中中・振り返り・休憩）。
# ⚠ 行を押す＝いまのタスクにする（⚠ 始める前は選ぶ・集中中は替える＝`TK-16`）／ ⚠ 四角＝終えた・戻した ／ ⚠ 下の欄で足す（⚠ 選びはしない）。
# ⚠ 中身＝一覧と同じ（⚠ まだのもの ＋ 今日終えたもの＝線）・色の印・集中した時間（`TK-5`）・期限の小さい判（`TK-13`）。
# ⚠ 時間の区切りは画面（`pomodoro.gd`）が持つ。⚠ ここは知らせるだけ（`task_pressed` / `task_checked`）。
# ⚠ 2026-10-05（人間「⚠ 詳しいこともポモドーロ中に決められるように」）：⚠ まだの行の右にメモのアイコン（⚠ 同じ日に「詳しく」の字から替えた）＝紙の窓でタスクの画面と同じ中身
#   （`TaskDetailPanel`・⚠ 消すは出さない＝窓の上に確かめの窓は重ねられない）。⚠ タイマーは止めない。
# ⚠ 選んでいる行は下にメモを出す（⚠ 同じ日・人間「⚠ 選択中のタスクは、メモを見れるように」）。
# ⚠ 大きさは Theme の `Task/side_*`。⚠ ポモドーロの画面だけで使う＝scenes/pomodoro/（AGENTS.md 置き場のルール）。
# ⚠ 描き直しは次のフレーム（⚠ 押した四角・行を押している最中に外さない）。⚠ 再描画に await を持たせない（CLAUDE.md 5番）。

signal task_pressed(task_id: String)
signal task_checked(task_id: String, done: bool)

const THEME_TYPE: StringName = &"Task"

# いま数えているタスクの task_id を返す口（⚠ 画面が渡す。⚠ 無ければ ""）。
var current_task_provider: Callable = Callable()
# ⚠ 行の右のペン（⚠ 小窓に置いたときは出さない＝窓が小さく、紙の窓が収まらない・10-06）。
var show_edit: bool = true
# ⚠ 下の「足す」欄と案内（⚠ 小窓では出さない＝10-06 人間「⚠ 追加はいらないかも　とりあえず」）。⚠ `_ready()` より前に決める。
var show_add: bool = true
# ⚠ 下の案内（⚠ 小窓では出さない＝狭い）。⚠ `_ready()` より前に決める。
var show_hint: bool = true

var _heading: SheetHeading = null
var _list: VBoxContainer = null
var _new_edit: LineEdit = null
var _dirty: bool = false


static func create() -> TaskSidebar:
	var sidebar: TaskSidebar = TaskSidebar.new()
	sidebar.name = "TaskSidebar"
	return sidebar


func _ready() -> void:
	custom_minimum_size.x = float(get_theme_constant(&"side_width", THEME_TYPE))
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	add_child(body)
	_heading = SheetHeading.new()
	_heading.name = "SideHeading"
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
	# ⚠ 足す（⚠ ポモドーロ中も足せる＝人間の指示）。
	var add_line: HBoxContainer = HBoxContainer.new()
	add_line.name = "AddLine"
	body.add_child(add_line)
	_new_edit = LineEdit.new()
	_new_edit.name = "SideNewEdit"
	_new_edit.max_length = Balance.pomodoro.session_title_max_length
	_new_edit.placeholder_text = tr("ui_task_new_placeholder")
	_new_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_edit.text_submitted.connect(_on_new_submitted)
	add_line.add_child(_new_edit)
	var add: Button = UiButton.create_paper_choice("ui_task_add")
	add.name = "SideAddButton"
	add.pressed.connect(_on_add_pressed)
	add_line.add_child(add)
	var hint: Label = Label.new()
	hint.name = "HintLabel"
	hint.theme_type_variation = &"CaptionLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = tr("ui_pomodoro_task_list_hint")
	body.add_child(hint)
	add_line.visible = show_add
	hint.visible = show_add and show_hint
	GameManager.tasks_changed.connect(refresh)
	_rebuild()


# 描き直す（⚠ 次のフレーム）。⚠ いまのタスクが変わったときは画面が呼ぶ。
func refresh() -> void:
	if _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_dirty = false
	if _list == null or not is_inside_tree():
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var current: String = str(current_task_provider.call()) if current_task_provider.is_valid() else ""
	var tasks: Array = GameManager.get_tasks()
	_heading.right_text = tr("ui_task_count") % GameManager.get_open_tasks().size()
	if tasks.is_empty():
		var empty: EmptyState = EmptyState.create("ui_pomodoro_task_pick_empty", "ui_pomodoro_task_list_empty_hint")
		# ⚠ 案内は折り返す（⚠ 折り返さないとサイドバーが字の長さまで広がった＝撮った絵）。
		for child: Node in empty.get_children():
			if child is Label:
				(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
		return
	# ⚠ 10-09（回TK-F・`TK-18`）：⚠ フォルダごとに見出し（⚠ 押すと畳む＝タスクの画面・拠点の紙と共通）。⚠ フォルダが1つも無ければ見出しは出さない。
	var show_headers: bool = not GameManager.get_task_folders().is_empty()
	for raw_group: Variant in GameManager.get_task_groups(tasks):
		var group: Dictionary = raw_group as Dictionary
		var members: Array = group.get(GameManager.TASK_GROUP_TASKS, []) as Array
		if show_headers:
			_list.add_child(TaskFolderHeader.create(group, members.size()))
			if bool(group.get(GameManager.TASK_GROUP_COLLAPSED, false)):
				continue
		for raw: Variant in members:
			_add_task_row(raw as Dictionary, current)


# ⚠ 1行（⚠ 10-09 回TK-F で `_rebuild()` から切り出した＝中身は前のまま）。
func _add_task_row(task: Dictionary, current: String) -> void:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var done: bool = int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0
	var row: LedgerRow = LedgerRow.new()
	row.name = "Side_" + task_id
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
	# ⚠ 題は1行目いっぱい・⚠ 時間と判は2行目（⚠ 1行に並べると幅 320 で題が「企」まで切れた＝撮った絵）。
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(column)
	var title_line: HBoxContainer = HBoxContainer.new()
	title_line.name = "TitleLine"
	title_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_line)
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if done:
		title.theme_type_variation = &"TaskDoneLabel"
		title.draw.connect(_draw_strike.bind(title))
	title_line.add_child(title)
	if not done and show_edit:
		# ⚠ ペンのアイコン（10-05「⚠ メモのアイコンにしてほしい」→ 10-06「⚠ ペンのアイコンに変える」）。⚠ 字は触れると出る札へ。
		var detail: Button = Button.new()
		detail.name = "DetailButton"
		detail.theme_type_variation = &"TaskMemoButton"
		detail.icon = IconTextures.for_task_edit()
		detail.focus_mode = Control.FOCUS_NONE
		detail.tooltip_text = tr("ui_pomodoro_task_memo_tip")
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		detail.pressed.connect(_on_detail_pressed.bind(task_id))
		title_line.add_child(detail)
	var seconds: int = int(task.get(GameStateKeys.TASK_FOCUS_SEC, 0))
	var stamp: Stamp = TaskParts.due_stamp(task)
	if seconds >= 60 or stamp != null:
		var meta: HBoxContainer = HBoxContainer.new()
		meta.name = "Meta"
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(meta)
		if seconds >= 60:
			var focus: Label = Label.new()
			focus.name = "FocusLabel"
			focus.theme_type_variation = &"CaptionLabel"
			focus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			focus.text = GameManager.task_focus_text(seconds)
			meta.add_child(focus)
		if stamp != null:
			meta.add_child(stamp)
	# ⚠ 選んでいる行だけメモを出す（10-05・人間「⚠ 選択中のタスクは、メモを見れるように」）。⚠ 集中中も見える（⚠ 帯は始めると透明）。
	var memo_text: String = str(task.get(GameStateKeys.TASK_MEMO, "")).strip_edges()
	if row.selected and memo_text != "":
		var memo: Label = Label.new()
		memo.name = "MemoLabel"
		memo.theme_type_variation = &"CaptionLabel"
		memo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memo.max_lines_visible = get_theme_constant(&"side_memo_lines", THEME_TYPE)
		memo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		memo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		memo.text = memo_text
		column.add_child(memo)
	_list.add_child(row)


func _draw_strike(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = label.size.y * 0.5
	label.draw_line(Vector2(0.0, y), Vector2(width, y), label.get_theme_color(&"font_color"), float(get_theme_constant(&"strike", THEME_TYPE)))


func _on_row_pressed(task_id: String) -> void:
	task_pressed.emit(task_id)
	refresh()


func _on_check_toggled(on: bool, task_id: String) -> void:
	task_checked.emit(task_id, on)


# 詳しくの窓（⚠ 画面を移らない＝タイマーは進んだまま）。
func _on_detail_pressed(task_id: String) -> void:
	var panel: TaskDetailPanel = TaskDetailPanel.create(task_id, false, float(get_theme_constant(&"detail_window_height", THEME_TYPE)))
	panel.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	Modal.notify(self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_pomodoro_task_edit_title"),
		Modal.OPTION_CONTENT: panel,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_LARGE,
		# ⚠ 外を押しても閉じる（10-06・人間「⚠ 窓が出たとき画面外をクリックしても閉じるように」）。
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})


func _on_new_submitted(_text: String) -> void:
	_on_add_pressed()


# ⚠ 足すだけ（⚠ いまのタスクは変えない＝集中中に足しても時間の区切りにならない）。
func _on_add_pressed() -> void:
	if GameManager.add_task(_new_edit.text) != "":
		_new_edit.text = ""
