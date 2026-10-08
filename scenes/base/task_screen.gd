# res://scenes/base/task_screen.gd
# タスクの画面（2026-10-04・DECISIONS.md `TK-1`〜`TK-17`・PLAN_TASK_MEMO.md §3-2）。
#
# ⚠ 左の紙＝一覧（足す・チェック・並べ替え・タグで絞る）／ ⚠ 右の紙＝選んだタスクを詳しく（名前・期限・色・メモ・タグ・消す）。
#   ⚠ 決められるのは メモ ／ 期限 ／ 並べる順 ／ 色・タグ（`TK-7`）。⚠ 見込みのポモドーロ数は入れない。
# ⚠ 終えたタスクはその日のうちは線を引いて残る（`TK-6`）。⚠ 朝4:00 の移しは開いたときに走らせる。
# ⚠ 期限を過ぎた・今日が期限のものは小さい判（`TK-13`）。⚠ 並びは自分で決めた順のまま。
# ⚠ 2026-10-05（モック2・3）：⚠ 1行1段（四角・色・題・タグ・時間・日付・判）／ ⚠ ▲▼は選んだ行にだけ ／
#   ⚠ 絞っているときは「◯ の n件を出しています」「ほかのタグの n件は隠れています」／ ⚠ 期限は「なし・今日・明日・今週中・日付を選ぶ」＋カレンダー ／
#   ⚠ 詳しくは中を送り、⚠ 下に「これまでの集中」と「このタスクを消す」。
# ⚠ 入口は拠点の壁の紙（`TK-3`）。⚠ 「戻る」で拠点。⚠ 書き換えは全部 `GameManager` の口（⚠ ここで TASKS を触らない）。
# ⚠ 再描画に await を持たせない（CLAUDE.md 5番）。⚠ 押した札を押している最中に外さない＝⚠ 描き直しは次のフレーム。

class_name TaskScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"
const THEME_TYPE: StringName = &"Task"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var list_sheet: PaperSheet = $Margin/Layout/Main/ListSheet
@onready var list_body: VBoxContainer = $Margin/Layout/Main/ListSheet/ListBody
@onready var detail_sheet: PaperSheet = $Margin/Layout/Main/DetailSheet
@onready var detail_body: VBoxContainer = $Margin/Layout/Main/DetailSheet/DetailBody

var _selected_id: String = ""
# ⚠ 絞り込みのタグ（⚠ "" なら全部・`TK-12`）。
var _filter_tag: String = ""
var _list_heading: SheetHeading = null
var _new_edit: LineEdit = null
var _filter_box: HFlowContainer = null
var _filter_note: Label = null
var _hidden_note: Label = null
var _list: VBoxContainer = null
var _detail: TaskDetailPanel = null
var _list_dirty: bool = false
var _detail_dirty: bool = false
# ⚠ 10-09（回TK-F）：⚠ 名前を書き換えているフォルダ（⚠ "" なら無し）と、⚠ フォルダを作る欄。
var _renaming_folder: String = ""
var _folder_edit: LineEdit = null


func _ready() -> void:
	SceneManager.consume_transfer_data()
	var _moved: int = GameManager.roll_over_done_tasks()
	# ⚠ 10-07（H）：⚠ タグの絞り込みを覚える（⚠ そのタグが無くなっていれば一覧を描くときに外れる）。
	_filter_tag = str(SceneManager.recall(TransferKeys.MEMORY_TASK_FILTER, ""))
	header.back_pressed.connect(_on_back_pressed)
	list_sheet.custom_minimum_size.x = float(get_theme_constant(&"list_width", THEME_TYPE))
	detail_sheet.custom_minimum_size.x = float(get_theme_constant(&"detail_width", THEME_TYPE))
	_build_list_frame()
	_build_detail()
	GameManager.tasks_changed.connect(_on_tasks_changed)
	_rebuild_list()


# --- 左：一覧 ----------------------------------------------------------------

# ⚠ 動かない部分（見出し・足す行・絞り込みの置き場・送りの器）。⚠ 描き直すのは中身だけ。
func _build_list_frame() -> void:
	_list_heading = SheetHeading.new()
	_list_heading.name = "ListHeading"
	_list_heading.title_key = "ui_task_list_title"
	list_body.add_child(_list_heading)
	var add_row: HBoxContainer = HBoxContainer.new()
	add_row.name = "AddRow"
	list_body.add_child(add_row)
	_new_edit = LineEdit.new()
	_new_edit.name = "NewTaskEdit"
	_new_edit.max_length = Balance.pomodoro.session_title_max_length
	_new_edit.placeholder_text = tr("ui_task_new_placeholder")
	_new_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_edit.text_submitted.connect(_on_new_submitted)
	add_row.add_child(_new_edit)
	var add_button: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_task_add")
	add_button.name = "AddTaskButton"
	add_button.pressed.connect(_on_add_pressed)
	add_row.add_child(add_button)
	_filter_box = HFlowContainer.new()
	_filter_box.name = "TagFilter"
	list_body.add_child(_filter_box)
	_filter_note = _caption_label("FilterNote")
	list_body.add_child(_filter_note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_body.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_list)
	_hidden_note = _caption_label("HiddenNote")
	inner.add_child(_hidden_note)
	# ⚠ 10-09（回TK-F・`TK-18`）：⚠ 一覧の下にフォルダを作る欄。
	var folder_row: HBoxContainer = HBoxContainer.new()
	folder_row.name = "FolderAddRow"
	inner.add_child(folder_row)
	_folder_edit = LineEdit.new()
	_folder_edit.name = "NewFolderEdit"
	_folder_edit.max_length = Balance.pomodoro.session_title_max_length
	_folder_edit.placeholder_text = tr("ui_task_folder_new_placeholder")
	_folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_edit.text_submitted.connect(_on_folder_submitted)
	folder_row.add_child(_folder_edit)
	var folder_button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_task_folder_add")
	folder_button.name = "AddFolderButton"
	folder_button.pressed.connect(_on_add_folder_pressed)
	folder_row.add_child(folder_button)


func _caption_label(label_name: String) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.theme_type_variation = &"CaptionLabel"
	return label


func _on_tasks_changed() -> void:
	_queue_list()


func _queue_list() -> void:
	if _list_dirty:
		return
	_list_dirty = true
	_rebuild_list.call_deferred()


func _queue_detail() -> void:
	if _detail_dirty:
		return
	_detail_dirty = true
	_rebuild_detail.call_deferred()


func _rebuild_list() -> void:
	_list_dirty = false
	if not is_inside_tree():
		return
	var tasks: Array = GameManager.get_tasks()
	var tags: Array[String] = GameManager.get_task_tags()
	if _filter_tag != "" and not (_filter_tag in tags):
		_filter_tag = ""
	var done_today: int = tasks.size() - GameManager.get_open_tasks().size()
	_list_heading.right_text = tr("ui_task_list_counts") % [GameManager.get_open_tasks().size(), done_today]
	_rebuild_filter(tags)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if tasks.is_empty():
		_list.add_child(EmptyState.create("ui_task_list_empty", "ui_task_list_empty_hint"))
	var shown: int = 0
	# ⚠ 10-09（回TK-F・`TK-18`）：⚠ フォルダごとに見出し（⚠ 押すと畳む）。⚠ フォルダが無ければ見出しは出さない（⚠ 前のまま）。
	#   ⚠ ▲▼の端は「同じフォルダの中の端」（⚠ `GameManager.move_task()` も同じフォルダの中で動く）。
	#   ⚠ 10-09（回TK-F2）：⚠ フォルダごとの箱（`TaskFolderBox`）の中に並べる。
	var show_headers: bool = not GameManager.get_task_folders().is_empty()
	_list.theme_type_variation = &"TaskFolderStack" if show_headers else &""
	for raw_group: Variant in GameManager.get_task_groups(tasks):
		var group: Dictionary = raw_group as Dictionary
		var members: Array = group.get(GameManager.TASK_GROUP_TASKS, []) as Array
		var visible_members: Array = []
		for raw: Variant in members:
			if _filter_tag == "" or (_filter_tag in ((raw as Dictionary).get(GameStateKeys.TASK_TAGS, []) as Array)):
				visible_members.append(raw)
		var parent: Node = _list
		var box: TaskFolderBox = null
		if show_headers:
			# ⚠ 絞っているときは、⚠ 当たる行の無いフォルダは出さない。
			if _filter_tag != "" and visible_members.is_empty():
				continue
			box = _folder_box(group, visible_members.size())
			_list.add_child(box)
			parent = box.rows
			if bool(group.get(GameManager.TASK_GROUP_COLLAPSED, false)):
				shown += visible_members.size()
				box.finish()
				continue
		for raw: Variant in visible_members:
			var task: Dictionary = raw as Dictionary
			var index: int = members.find(raw)
			shown += 1
			parent.add_child(_task_row(task, index == 0, index == members.size() - 1))
		if box != null:
			box.finish()
	_filter_note.visible = _filter_tag != ""
	_filter_note.text = tr("ui_task_filter_note") % [_filter_tag, shown] if _filter_tag != "" else ""
	_hidden_note.visible = _filter_tag != "" and tasks.size() > shown
	_hidden_note.text = tr("ui_task_hidden_note") % (tasks.size() - shown) if _hidden_note.visible else ""


# ⚠ フォルダの見出し（10-09・回TK-F）：⚠ 押すと畳む ／ ⚠ 右に「名前を変える」「消す」（⚠ フォルダなしには出さない）。
#   ⚠ 名前を書き換えている間は、⚠ 右に名前の欄と「決める」。
#   ⚠ 10-09（回TK-F2）：⚠ 箱ごと返す（⚠ 見出しは箱の上の帯・中のタスクは `box.rows` へ）。
func _folder_box(group: Dictionary, count: int) -> TaskFolderBox:
	var box: TaskFolderBox = TaskFolderBox.create(group, count)
	var header: TaskFolderHeader = box.header
	var folder_id: String = header.folder_id
	if folder_id == "":
		return box
	if folder_id == _renaming_folder:
		var edit: LineEdit = LineEdit.new()
		edit.name = "FolderNameEdit"
		edit.max_length = Balance.pomodoro.session_title_max_length
		edit.text = str(group.get(GameManager.TASK_GROUP_NAME, ""))
		edit.custom_minimum_size.x = float(get_theme_constant(&"folder_edit_width", THEME_TYPE))
		edit.text_submitted.connect(func(text: String) -> void: _on_folder_rename_submitted(folder_id, text))
		header.actions.add_child(edit)
		var decide: Button = UiButton.create_paper_choice("ui_task_folder_rename_ok")
		decide.name = "FolderRenameOk"
		decide.theme_type_variation = &"TaskMoveButton"
		decide.pressed.connect(func() -> void: _on_folder_rename_submitted(folder_id, edit.text))
		header.actions.add_child(decide)
		return box
	for spec: Array in [["FolderRename", "ui_task_folder_rename"], ["FolderDelete", "ui_task_folder_delete"]]:
		var button: Button = UiButton.create_paper_choice(str(spec[1]))
		button.name = str(spec[0])
		button.theme_type_variation = &"TaskMoveButton"
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.actions.add_child(button)
		if str(spec[0]) == "FolderRename":
			button.pressed.connect(_on_folder_rename_pressed.bind(folder_id))
		else:
			button.pressed.connect(_on_folder_delete_pressed.bind(folder_id))
	return box


func _on_folder_submitted(_text: String) -> void:
	_on_add_folder_pressed()


func _on_add_folder_pressed() -> void:
	if GameManager.add_task_folder(_folder_edit.text) == "":
		return
	_folder_edit.text = ""


func _on_folder_rename_pressed(folder_id: String) -> void:
	_renaming_folder = folder_id
	_queue_list()


func _on_folder_rename_submitted(folder_id: String, text: String) -> void:
	_renaming_folder = ""
	if not GameManager.rename_task_folder(folder_id, text):
		_queue_list()


# ⚠ 10-09（人間「⚠ ６い」）：⚠ 中のタスクも一緒に消す＝⚠ 確かめの窓（赤）で件数を出す。⚠ 状態を触るのは「消す」を押したあと。
func _on_folder_delete_pressed(folder_id: String) -> void:
	var name: String = ""
	var count: int = 0
	for folder: Variant in GameManager.get_task_folders():
		if str((folder as Dictionary).get(GameStateKeys.FOLDER_ID, "")) == folder_id:
			name = str((folder as Dictionary).get(GameStateKeys.FOLDER_NAME, ""))
	for task: Variant in GameManager.get_tasks():
		if str((task as Dictionary).get(GameStateKeys.TASK_FOLDER, "")) == folder_id:
			count += 1
	var ok: bool = await Modal.confirm(self, "ui_task_folder_delete_confirm", [name, count], false, {
		Modal.OPTION_TITLE: tr("ui_task_folder_delete_title"),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_task_folder_delete_title",
	})
	if not ok or not is_inside_tree():
		return
	if GameManager.delete_task_folder(folder_id) and GameManager.get_task(_selected_id).is_empty():
		_selected_id = ""
		_queue_detail()


# 絞り込みの札（⚠ 全部 ＋ 一覧に出てくるタグ）。⚠ タグが1つも無ければ出さない。
func _rebuild_filter(tags: Array[String]) -> void:
	for child: Node in _filter_box.get_children():
		_filter_box.remove_child(child)
		child.queue_free()
	_filter_box.visible = not tags.is_empty()
	if tags.is_empty():
		return
	var all: Button = UiButton.create_paper_choice("ui_task_filter_all")
	all.name = "Filter_all"
	if _filter_tag == "":
		all.theme_type_variation = &"PaperChoiceSelected"
	all.pressed.connect(_on_filter_pressed.bind(""))
	_filter_box.add_child(all)
	for tag: String in tags:
		var choice: Button = UiButton.create_paper_choice("")
		choice.name = "Filter_" + tag
		choice.text = tr("ui_task_tag") % tag
		if tag == _filter_tag:
			choice.theme_type_variation = &"PaperChoiceSelected"
		choice.pressed.connect(_on_filter_pressed.bind(tag))
		_filter_box.add_child(choice)


# 1行1段：⚠ 四角 ／ 色 ／ 題 ／ タグ ／ 集中した時間 ／ 期限の日付 ／ 判 ／（選んだ行だけ）▲▼。
func _task_row(task: Dictionary, is_first: bool, is_last: bool) -> LedgerRow:
	var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
	var done: bool = int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0
	var row: LedgerRow = LedgerRow.new()
	row.name = "Task_" + task_id
	row.compact = true
	row.selected = task_id == _selected_id
	row.pressed.connect(_on_row_pressed.bind(task_id))
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	# ⚠ 終わったかは自分でチェック（`TK-4`）。
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
		# ⚠ 終えたものは薄墨＋線（`TK-6`）。
		title.theme_type_variation = &"TaskDoneLabel"
		title.draw.connect(_draw_strike.bind(title))
	line.add_child(title)
	var tags: Array = task.get(GameStateKeys.TASK_TAGS, []) as Array
	if not tags.is_empty():
		var tag_texts: PackedStringArray = PackedStringArray()
		for tag: Variant in tags:
			tag_texts.append(tr("ui_task_tag") % str(tag))
		line.add_child(_row_caption("TagsLabel", " ".join(tag_texts)))
	var seconds: int = int(task.get(GameStateKeys.TASK_FOCUS_SEC, 0))
	if seconds >= 60:
		line.add_child(_row_caption("FocusLabel", GameManager.task_focus_text(seconds)))
	var due: String = str(task.get(GameStateKeys.TASK_DUE, ""))
	if due != "" and not done:
		line.add_child(_row_caption("DueLabel", TaskParts.short_date(due)))
	var stamp: Stamp = TaskParts.due_stamp(task)
	if stamp != null:
		line.add_child(stamp)
	# ⚠ 並べ替え（`TK-7`）は選んだ行にだけ。⚠ 絞っているときは押せない（⚠ 見えていない行と入れ替わるため）。
	if task_id == _selected_id:
		for spec: Array in [["UpButton", "ui_task_move_up", -1, is_first], ["DownButton", "ui_task_move_down", 1, is_last]]:
			var move: Button = UiButton.create_paper_choice(str(spec[1]))
			move.name = str(spec[0])
			move.theme_type_variation = &"TaskMoveButton"
			move.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			move.disabled = bool(spec[3]) or _filter_tag != ""
			move.pressed.connect(_on_move_pressed.bind(task_id, int(spec[2])))
			line.add_child(move)
	return row


func _row_caption(label_name: String, text: String) -> Label:
	var label: Label = _caption_label(label_name)
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _draw_strike(label: Label) -> void:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var width: float = minf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, label.size.x)
	var y: float = label.size.y * 0.5
	label.draw_line(Vector2(0.0, y), Vector2(width, y), label.get_theme_color(&"font_color"), float(get_theme_constant(&"strike", THEME_TYPE)))


func _on_new_submitted(_text: String) -> void:
	_on_add_pressed()


func _on_add_pressed() -> void:
	var task_id: String = GameManager.add_task(_new_edit.text)
	if task_id == "":
		return
	_new_edit.text = ""
	_selected_id = task_id
	_queue_detail()


func _on_row_pressed(task_id: String) -> void:
	if task_id == _selected_id:
		return
	_selected_id = task_id
	_queue_list()
	_queue_detail()


func _on_done_toggled(pressed: bool, task_id: String) -> void:
	var _changed: bool = GameManager.set_task_done(task_id, pressed)


func _on_move_pressed(task_id: String, delta: int) -> void:
	var _moved: bool = GameManager.move_task(task_id, delta)


func _on_filter_pressed(tag: String) -> void:
	if tag == _filter_tag:
		return
	_filter_tag = tag
	SceneManager.remember(TransferKeys.MEMORY_TASK_FILTER, _filter_tag)
	_queue_list()


# --- 右：詳しく ----------------------------------------------------------------
#   ⚠ 中身は部品（`TaskDetailPanel`・10-05）。⚠ ポモドーロの「詳しく」の窓と同じもの。

func _build_detail() -> void:
	var heading: SheetHeading = SheetHeading.new()
	heading.name = "DetailHeading"
	heading.title_key = "ui_task_detail_title"
	detail_body.add_child(heading)
	_detail = TaskDetailPanel.create(_selected_id)
	_detail.delete_requested.connect(_on_delete_pressed)
	detail_body.add_child(_detail)
	# ⚠ 10-06（`NAV-18`）：⚠ 選んだタスクでそのまま集中へ（⚠ 前は 戻る → ポモドーロ → サイドバーで選び直す）。
	_focus_button = UiButton.create(UiButton.Variant.PRIMARY, "ui_task_focus_this")
	_focus_button.name = "FocusThisButton"
	_focus_button.pressed.connect(_on_focus_this_pressed)
	heading.add_before_right(_focus_button)
	_refresh_focus_button()


func _rebuild_detail() -> void:
	_detail_dirty = false
	if _detail != null:
		_detail.set_task(_selected_id)
	_refresh_focus_button()


var _focus_button: UiButton = null


# ⚠ まだのタスクを選んでいて、⚠ ポモドーロを解放しているときだけ。
func _refresh_focus_button() -> void:
	if _focus_button == null:
		return
	var task: Dictionary = GameManager.get_task(_selected_id)
	_focus_button.visible = not task.is_empty() and int(task.get(GameStateKeys.TASK_DONE_AT, 0)) == 0 \
		and GameManager.is_screen_unlocked(GameStateKeys.SCREEN_POMODORO)


func _on_focus_this_pressed() -> void:
	if GameManager.get_task(_selected_id).is_empty():
		return
	SceneManager.change_scene_with_data(POMODORO_PATH, {TransferKeys.TASK_ID: _selected_id})


# ⚠ 状態を触るのは「消す」を押したあと（CLAUDE.md 6番）。⚠ 窓を待つ間に画面を離れたら何もしない。
func _on_delete_pressed(task_id: String) -> void:
	var title: String = str(GameManager.get_task(task_id).get(GameStateKeys.TASK_TITLE, ""))
	var ok: bool = await Modal.confirm(self, "ui_task_delete_confirm", [title], false, {
		Modal.OPTION_TITLE: tr("ui_task_delete"),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_task_delete",
	})
	if not ok or not is_inside_tree():
		return
	if GameManager.delete_task(task_id) and task_id == _selected_id:
		_selected_id = ""
		_queue_detail()


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
