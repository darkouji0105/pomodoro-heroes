extends Control

# 集中中のビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 「1 / 4 Sets」は**器（pomodoro.tscn）が持つ**ようになった。
#   ⚠ 休憩・振り返りでも同じ位置に出したいため。ここでは触らない。
# ⚠ 見出しは無いが `HeadingSlot`（空の HeadingLabel）で**高さだけ確保している**。
#   ⚠ これが無いと、休憩・振り返りへ移った瞬間にタイマーが上下に跳ねる。

# ⚠ `task_id` はリストから選んだタスク（⚠ 選ばずに始めたら ""＝時間をどれにも記録しない・`TK-11`）。
signal start_requested(title: String, task_id: String)

@onready var timer_ring: TimerRing = $Layout/TimerRing
@onready var instruction_label: Label = $Layout/InputBlock/InstructionLabel
@onready var title_edit: LineEdit = $Layout/InputBlock/TitleEdit
# ⚠ 作業中に出す大きいタイトル（2026-09-09・人間の宿題「作業中のタイトルを大きく」）。
#   ⚠ 入力欄と**同じ場所・同じ幅**に出す。⚠ 上（タイマーの輪）は1pxも動かない。
#   ⚠ 2行で打ち切る（`max_lines_visible = 2`）。⚠ 長い題で下のボタンを押し下げないため。
@onready var work_title: Label = $Layout/InputBlock/WorkTitle
@onready var start_button: UiButton = $Layout/StartButton
var _links: PomodoroLinks = null
# ⚠ タスクのメモ（2026-10-04・`TK-10`）：⚠ 1行の題は残し、⚠ 下に「リストから選ぶ」「リストに足す」。
#   ⚠ 選んだあとに題を書き換えると、⚠ タスクの名前が変わる（⚠ 紐付けは残る）。
# ⚠ 2026-10-05（モック4・5）：⚠ 選んでいない＝「リストから選ぶ　まだ n件」（主役寄り）と「書いた題をリストに足す」／
#   ⚠ 選んだ＝題の欄の左に色の印・下に紙の帯（「リストのタスク」の判・これまでの集中・期限の判・選び直す・外す）。
var _task_id: String = ""
var _task_box: VBoxContainer = null
var _choose_row: HBoxContainer = null
var _pick_button: Button = null
var _add_button: Button = null
var _linked_band: PaperSheet = null
var _linked_line: HBoxContainer = null
var _rename_note: Label = null
var _title_mark: TaskColorMark = null
var _pick_dialog: ModalDialog = null
var _pick_list: VBoxContainer = null
var _pick_filter_box: HFlowContainer = null
var _pick_filter: String = ""
var _pick_new_edit: LineEdit = null
var _pick_dirty: bool = false
# ⚠ 始めたあと（⚠ 帯を描き直しても「選び直す」「外す」を押せないままにする＝透明なので押せると困る）。
var _started: bool = false


func setup(preset: PomodoroPreset) -> void:
	# ⚠ 集中中は輪の代わりに選んだ道具の絵（2026-09-29・回UI-仕組み⑤・人間「⚠ 2あ」・`GameSettings.focus_tool()`）。
	timer_ring.use_tool(GameSettings.focus_tool())
	update_timer(preset.focus_duration_sec, float(preset.focus_duration_sec))
	title_edit.max_length = Balance.pomodoro.session_title_max_length

	instruction_label.text = tr("ui_pomodoro_input_title")
	# ⚠ 2026-10-05（モック4）：⚠ 説明の1行は出さない（⚠ 題の欄の下書き「何に集中しますか（空のままでも始められます）」が同じことを言う）。
	#   ⚠ 始めた瞬間に跳ねないよう、⚠ 最初から出さない（⚠ 透明にする `_on_start_pressed()` の手前で消えている）。
	instruction_label.visible = false
	# ⚠ 入力欄の下書きの字（2026-09-09）。⚠ `.tscn` に日本語が直書きされていて、
	#   ⚠ ここでも上書きしていなかった＝⚠ 翻訳表を通っていない唯一の文字だった。
	title_edit.placeholder_text = tr("ui_pomodoro_title_placeholder")
	# ⚠ 開始前だけ「集中の道具」「ポモドーロの設定」（2026-09-29・`PomodoroLinks`）。⚠ 2回目からは加護を選ぶビューを通らないため。
	if _links == null:
		_links = PomodoroLinks.create()
		_links.alignment = BoxContainer.ALIGNMENT_CENTER
		start_button.get_parent().add_child(_links)
	if _task_box == null:
		_build_task_box()


# ⚠ 前のセットのタイトルを引き継ぐ口（2026-09-09）。
#   ⚠ 前は器が `view.get_node("TitleEdit")` で中を掴んでいた。
#   ⚠ ノード名を変えた瞬間に黙って壊れるので、関数にした。
func set_title_text(value: String) -> void:
	title_edit.text = value


func _on_start_pressed() -> void:
	var title: String = title_edit.text.strip_edges()
	if title == "":
		title = "Work"
	# ⚠ 始めたらタスクは選び直させない（⚠ 消さずに透明＝上が跳ねない）。⚠ 替えるのは右上の「リスト」から。
	_started = true
	if _task_box != null:
		_task_box.modulate.a = 0.0
		_pick_button.disabled = true
		_add_button.disabled = true
		for child: Node in _linked_line.get_children():
			if child is BaseButton:
				(child as BaseButton).disabled = true

	# ⚠ 入力欄を大きいタイトルに差し替える。⚠ 説明の字は**消さずに透明**にする
	#   （⚠ 消すと下が詰まって、⚠ 開始を押した瞬間にボタンが上へ跳ねる）。
	instruction_label.modulate.a = 0.0
	title_edit.editable = false
	title_edit.visible = false
	work_title.text = title
	work_title.visible = true
	start_button.disabled = true
	# ⚠ 始めたら道具と設定へは行かせない（⚠ 消さずに透明＝上が跳ねない）。
	if _links != null:
		_links.modulate.a = 0.0
		for child: Node in _links.get_children():
			(child as BaseButton).disabled = true
	start_requested.emit(title, _task_id)


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)


# 集中中に右上の「リスト」でタスクを替えたとき（2026-10-05）。⚠ 大きい題をそのタスクの名前に。
func show_running_title(text: String) -> void:
	work_title.text = text


# --- タスクのメモ（2026-10-04・`TK-10`・`TK-11`） ---

func _build_task_box() -> void:
	_task_box = VBoxContainer.new()
	_task_box.name = "TaskBox"
	# 選んでいない姿。
	_choose_row = HBoxContainer.new()
	_choose_row.name = "TaskButtons"
	_task_box.add_child(_choose_row)
	_pick_button = UiButton.create(UiButton.Variant.SECONDARY, "")
	_pick_button.name = "PickTaskButton"
	_pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_button.pressed.connect(_on_pick_pressed)
	_choose_row.add_child(_pick_button)
	_add_button = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_task_add")
	_add_button.name = "AddToListButton"
	_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button.pressed.connect(_on_add_to_list_pressed)
	_choose_row.add_child(_add_button)
	# 選んだ姿：⚠ 紙の帯（⚠ 角飾りは出さない＝細い帯）。
	_linked_band = PaperSheet.new()
	_linked_band.name = "LinkedBand"
	_linked_band.show_corners = false
	_task_box.add_child(_linked_band)
	_linked_line = HBoxContainer.new()
	_linked_band.add_child(_linked_line)
	_rename_note = Label.new()
	_rename_note.name = "RenameNote"
	_rename_note.theme_type_variation = &"MutedLabel"
	_rename_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_note.text = tr("ui_pomodoro_task_rename_note")
	_task_box.add_child(_rename_note)
	# ⚠ 題の欄の左の色の印（⚠ 欄の左を空ける＝`TaskLinkedEdit`）。
	_title_mark = TaskColorMark.create(0)
	_title_mark.name = "TitleMark"
	title_edit.add_child(_title_mark)
	var block: Node = title_edit.get_parent()
	block.add_child(_task_box)
	block.move_child(_task_box, title_edit.get_index() + 1)
	title_edit.text_changed.connect(_on_title_text_changed)
	title_edit.resized.connect(_place_title_mark)
	GameManager.tasks_changed.connect(_refresh_task_link)
	_refresh_task_link()


# いま選んでいるタスク（⚠ 無ければ ""）。
func get_task_id() -> String:
	return _task_id


# タスクを選ぶ（⚠ "" で選ばない）。⚠ 題をタスクの名前にする。⚠ 器が前のセットを引き継ぐのにも使う。⚠ 終えたものは選ばない。
func set_task(task_id: String) -> void:
	var task: Dictionary = GameManager.get_task(task_id)
	_task_id = "" if task.is_empty() or int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0 else task_id
	if _task_id != "":
		title_edit.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	_refresh_task_link()


# ⚠ 名前・色・期限・時間が変わったら帯を描き直す（`tasks_changed`）。⚠ 打っている題の欄は触らない。
func _refresh_task_link() -> void:
	if _task_box == null:
		return
	var task: Dictionary = GameManager.get_task(_task_id)
	if _task_id != "" and task.is_empty():
		_task_id = ""
	var linked: bool = _task_id != ""
	_choose_row.visible = not linked
	_linked_band.visible = linked
	_rename_note.visible = linked
	_title_mark.visible = linked
	title_edit.theme_type_variation = &"TaskLinkedEdit" if linked else &""
	_pick_button.text = tr("ui_pomodoro_task_pick_count") % GameManager.get_open_tasks().size()
	_add_button.disabled = linked or title_edit.text.strip_edges() == ""
	for child: Node in _linked_line.get_children():
		_linked_line.remove_child(child)
		child.queue_free()
	if not linked:
		return
	_title_mark.color_index = int(task.get(GameStateKeys.TASK_COLOR, 0))
	_place_title_mark()
	var stamp: Stamp = Stamp.new()
	stamp.name = "LinkedStamp"
	stamp.label_key = "ui_pomodoro_task_linked_stamp"
	stamp.small = true
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linked_line.add_child(stamp)
	var focus: Label = Label.new()
	focus.name = "LinkedFocusLabel"
	focus.text = tr("ui_pomodoro_task_so_far") % GameManager.task_focus_text(int(task.get(GameStateKeys.TASK_FOCUS_SEC, 0)))
	focus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linked_line.add_child(focus)
	var due: Stamp = TaskParts.due_stamp(task)
	if due != null:
		_linked_line.add_child(due)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linked_line.add_child(spacer)
	var repick: Button = UiButton.create_paper_choice("ui_pomodoro_task_repick")
	repick.name = "RepickButton"
	repick.pressed.connect(_on_pick_pressed)
	repick.disabled = _started
	_linked_line.add_child(repick)
	var unlink: Button = UiButton.create_paper_choice("ui_pomodoro_task_unlink")
	unlink.name = "UnlinkButton"
	unlink.pressed.connect(_on_unlink_pressed)
	unlink.disabled = _started
	_linked_line.add_child(unlink)


func _place_title_mark() -> void:
	if _title_mark == null:
		return
	var side: float = _title_mark.custom_minimum_size.x
	_title_mark.size = Vector2(side, side)
	_title_mark.position = Vector2((float(get_theme_constant(&"link_pad", &"Task")) - side) * 0.5, (title_edit.size.y - side) * 0.5)


# ⚠ 選んだあとに題を書き換えると、タスクの名前が変わる（`TK-10`）。⚠ 空にしたときは変えない（⚠ 打ち直しの途中）。
func _on_title_text_changed(text: String) -> void:
	if _task_id != "":
		var _renamed: bool = GameManager.rename_task(_task_id, text)
	else:
		_add_button.disabled = text.strip_edges() == ""


func _on_add_to_list_pressed() -> void:
	var task_id: String = GameManager.add_task(title_edit.text)
	if task_id != "":
		set_task(task_id)


# ⚠ 「外す」は帯の中のボタン＝⚠ 押している最中に帯を描き直さない（⚠ 次のフレーム）。
func _on_unlink_pressed() -> void:
	set_task.call_deferred("")


# 選ぶ窓（モック5）：⚠ いちばん上に「選ばない」（`TK-11`）／ タグで絞る札 ／ まだのタスク（時間・期限の判）／ 下でその場で書いて「足して選ぶ」。
#   ⚠ 行を押したらすぐ選んで窓を閉じる。
func _on_pick_pressed() -> void:
	_pick_filter = ""
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "TaskPickList"
	content.custom_minimum_size.x = float(get_theme_constant(&"pick_width", &"Task"))
	var count: Label = Label.new()
	count.name = "PickCount"
	count.theme_type_variation = &"CaptionLabel"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.text = tr("ui_pomodoro_task_pick_open") % GameManager.get_open_tasks().size()
	content.add_child(count)
	var none: LedgerRow = _pick_row("PickNone", tr("ui_pomodoro_task_pick_none"), _task_id == "", {})
	none.pressed.connect(_on_task_picked.bind(""))
	content.add_child(none)
	_pick_filter_box = HFlowContainer.new()
	_pick_filter_box.name = "PickFilter"
	content.add_child(_pick_filter_box)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = float(get_theme_constant(&"pick_height", &"Task"))
	content.add_child(scroll)
	_pick_list = VBoxContainer.new()
	_pick_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_pick_list)
	var add_line: HBoxContainer = HBoxContainer.new()
	content.add_child(add_line)
	_pick_new_edit = LineEdit.new()
	_pick_new_edit.name = "PickNewEdit"
	_pick_new_edit.max_length = Balance.pomodoro.session_title_max_length
	_pick_new_edit.placeholder_text = tr("ui_pomodoro_task_pick_new")
	_pick_new_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pick_new_edit.text_submitted.connect(_on_pick_new_submitted)
	add_line.add_child(_pick_new_edit)
	var add: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_pomodoro_task_pick_add")
	add.name = "PickAddButton"
	add.pressed.connect(_on_pick_add_pressed)
	add_line.add_child(add)
	_rebuild_pick()
	_pick_dialog = Modal.notify(self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_pomodoro_task_pick"),
		Modal.OPTION_CONTENT: content,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_LARGE,
	})


func _rebuild_pick() -> void:
	_pick_dirty = false
	if _pick_list == null or not is_instance_valid(_pick_list):
		return
	for box: Node in [_pick_list, _pick_filter_box]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var open_tasks: Array = GameManager.get_open_tasks()
	var tags: Array[String] = []
	for raw: Variant in open_tasks:
		for tag: Variant in (raw as Dictionary).get(GameStateKeys.TASK_TAGS, []):
			if not (str(tag) in tags):
				tags.append(str(tag))
	_pick_filter_box.visible = not tags.is_empty()
	if not tags.is_empty():
		var choices: Array[String] = [""]
		choices.append_array(tags)
		for tag: String in choices:
			var choice: Button = UiButton.create_paper_choice("ui_task_filter_all" if tag == "" else "")
			choice.name = "PickFilter_all" if tag == "" else "PickFilter_" + tag
			if tag != "":
				choice.text = tr("ui_task_tag") % tag
			if tag == _pick_filter:
				choice.theme_type_variation = &"PaperChoiceSelected"
			choice.pressed.connect(_on_pick_filter_pressed.bind(tag))
			_pick_filter_box.add_child(choice)
	if open_tasks.is_empty():
		_pick_list.add_child(EmptyState.create("ui_pomodoro_task_pick_empty", "ui_pomodoro_task_pick_empty_hint"))
	for raw: Variant in open_tasks:
		var task: Dictionary = raw as Dictionary
		if _pick_filter != "" and not (_pick_filter in (task.get(GameStateKeys.TASK_TAGS, []) as Array)):
			continue
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var row: LedgerRow = _pick_row("Pick_" + task_id, str(task.get(GameStateKeys.TASK_TITLE, "")), task_id == _task_id, task)
		row.pressed.connect(_on_task_picked.bind(task_id))
		_pick_list.add_child(row)


func _on_pick_filter_pressed(tag: String) -> void:
	if tag == _pick_filter or _pick_dirty:
		return
	_pick_filter = tag
	_pick_dirty = true
	_rebuild_pick.call_deferred()


# ⚠ `task` が空なら色の印も時間も出さない（⚠ 「選ばない」の行）。
func _pick_row(row_name: String, text: String, is_selected: bool, task: Dictionary) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.compact = true
	row.selected = is_selected
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	if not task.is_empty():
		line.add_child(TaskColorMark.create(int(task.get(GameStateKeys.TASK_COLOR, 0))))
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if task.is_empty():
		title.theme_type_variation = &"CaptionLabel"
	line.add_child(title)
	if task.is_empty():
		return row
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
	return row


func _on_pick_new_submitted(_text: String) -> void:
	_on_pick_add_pressed()


# ⚠ その場で書いて足し、⚠ そのまま選ぶ（モック5「足して選ぶ」）。
func _on_pick_add_pressed() -> void:
	if _pick_new_edit == null or not is_instance_valid(_pick_new_edit):
		return
	var task_id: String = GameManager.add_task(_pick_new_edit.text)
	if task_id != "":
		_on_task_picked(task_id)


func _on_task_picked(task_id: String) -> void:
	set_task(task_id)
	# ⚠ 窓を閉じる（⚠ 木から外れると窓は自分で「閉じた」を出す＝`ModalDialog._exit_tree()`）。
	if _pick_dialog != null and is_instance_valid(_pick_dialog):
		_pick_dialog.queue_free()
	_pick_dialog = null
	_pick_list = null
