extends Control

# 集中中のビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 「1 / 4 Sets」は**器（pomodoro.tscn）が持つ**ようになった。
#   ⚠ 休憩・振り返りでも同じ位置に出したいため。ここでは触らない。
# ⚠ 見出しは無いが `HeadingSlot`（空の HeadingLabel）で**高さだけ確保している**。
#   ⚠ これが無いと、休憩・振り返りへ移った瞬間にタイマーが上下に跳ねる。

# ⚠ `task_id` はリストから選んだタスク（⚠ 選ばずに始めたら ""＝🍅をどれにも数えない・`TK-11`）。
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
# ⚠ タスクのメモ（2026-10-04・`TK-10`）：⚠ 1行の題は残し、⚠ 横に「リストから選ぶ」「リストに足す」。
#   ⚠ 選んだあとに題を書き換えると、⚠ タスクの名前が変わる（⚠ 紐付けは残る）。
var _task_id: String = ""
var _task_box: VBoxContainer = null
var _task_link_label: Label = null
var _pick_button: Button = null
var _add_button: Button = null
var _pick_dialog: ModalDialog = null


func setup(preset: PomodoroPreset) -> void:
	# ⚠ 集中中は輪の代わりに選んだ道具の絵（2026-09-29・回UI-仕組み⑤・人間「⚠ 2あ」・`GameSettings.focus_tool()`）。
	timer_ring.use_tool(GameSettings.focus_tool())
	update_timer(preset.focus_duration_sec, float(preset.focus_duration_sec))
	title_edit.max_length = Balance.pomodoro.session_title_max_length

	instruction_label.text = tr("ui_pomodoro_input_title")
	# ⚠ 入力欄の下書きの字（2026-09-09）。⚠ `.tscn` に日本語が直書きされていて、
	#   ⚠ ここでも上書きしていなかった＝⚠ 翻訳表を通っていない唯一の文字だった。
	title_edit.placeholder_text = tr("ui_pomodoro_title_placeholder")
	# ⚠ 開始前だけ「集中の道具」「ポモドーロの設定」（2026-09-29・`PomodoroLinks`）。⚠ 2回目からは加護を選ぶビューを通らないため。
	if _links == null:
		_links = PomodoroLinks.create()
		_links.alignment = BoxContainer.ALIGNMENT_CENTER
		start_button.get_parent().add_child(_links)
	if _task_box == null:
		_build_task_buttons()


# ⚠ 前のセットのタイトルを引き継ぐ口（2026-09-09）。
#   ⚠ 前は器が `view.get_node("TitleEdit")` で中を掴んでいた。
#   ⚠ ノード名を変えた瞬間に黙って壊れるので、関数にした。
func set_title_text(value: String) -> void:
	title_edit.text = value


func _on_start_pressed() -> void:
	var title: String = title_edit.text.strip_edges()
	if title == "":
		title = "Work"
	# ⚠ 始めたらタスクは選び直させない（⚠ 消さずに透明＝上が跳ねない）。
	if _task_box != null:
		_task_box.modulate.a = 0.0
		_pick_button.disabled = true
		_add_button.disabled = true

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


# --- タスクのメモ（2026-10-04・`TK-10`・`TK-11`） ---

func _build_task_buttons() -> void:
	_task_box = VBoxContainer.new()
	_task_box.name = "TaskBox"
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "TaskButtons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_task_box.add_child(row)
	_pick_button = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_task_pick")
	_pick_button.name = "PickTaskButton"
	_pick_button.pressed.connect(_on_pick_pressed)
	row.add_child(_pick_button)
	_add_button = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_task_add")
	_add_button.name = "AddToListButton"
	_add_button.pressed.connect(_on_add_to_list_pressed)
	row.add_child(_add_button)
	_task_link_label = Label.new()
	_task_link_label.name = "TaskLinkLabel"
	_task_link_label.theme_type_variation = &"MutedLabel"
	_task_link_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_box.add_child(_task_link_label)
	var block: Node = title_edit.get_parent()
	block.add_child(_task_box)
	block.move_child(_task_box, title_edit.get_index() + 1)
	title_edit.text_changed.connect(_on_title_text_changed)
	_refresh_task_link()


# いま選んでいるタスク（⚠ 無ければ ""）。
func get_task_id() -> String:
	return _task_id


# タスクを選ぶ（⚠ "" で選ばない）。⚠ 題をタスクの名前にする。⚠ 器が前のセットを引き継ぐのにも使う。
func set_task(task_id: String) -> void:
	var task: Dictionary = GameManager.get_task(task_id)
	_task_id = "" if task.is_empty() else task_id
	if _task_id != "":
		title_edit.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	_refresh_task_link()


func _refresh_task_link() -> void:
	if _task_link_label == null:
		return
	_task_link_label.text = tr("ui_pomodoro_task_linked") if _task_id != "" else ""
	_add_button.disabled = _task_id != "" or title_edit.text.strip_edges() == ""


# ⚠ 選んだあとに題を書き換えると、タスクの名前が変わる（`TK-10`）。⚠ 空にしたときは変えない（⚠ 打ち直しの途中）。
func _on_title_text_changed(text: String) -> void:
	if _task_id != "":
		var _renamed: bool = GameManager.rename_task(_task_id, text)
	_refresh_task_link()


func _on_add_to_list_pressed() -> void:
	var task_id: String = GameManager.add_task(title_edit.text)
	if task_id != "":
		set_task(task_id)


# 選ぶ窓：⚠ まだのタスクの一覧 ＋ 「選ばない」（`TK-11`）。⚠ 押したらすぐ選んで窓を閉じる。
func _on_pick_pressed() -> void:
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "TaskPickList"
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = float(get_theme_constant(&"pick_height", &"Task"))
	content.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var open_tasks: Array = GameManager.get_open_tasks()
	if open_tasks.is_empty():
		list.add_child(EmptyState.create("ui_pomodoro_task_pick_empty", "ui_pomodoro_task_pick_empty_hint"))
	for raw: Variant in open_tasks:
		var task: Dictionary = raw as Dictionary
		var task_id: String = str(task.get(GameStateKeys.TASK_ID, ""))
		var row: LedgerRow = _pick_row("Pick_" + task_id, str(task.get(GameStateKeys.TASK_TITLE, "")), task_id == _task_id, int(task.get(GameStateKeys.TASK_COLOR, 0)))
		row.pressed.connect(_on_task_picked.bind(task_id))
		list.add_child(row)
	var none: LedgerRow = _pick_row("PickNone", tr("ui_pomodoro_task_pick_none"), _task_id == "", -1)
	none.pressed.connect(_on_task_picked.bind(""))
	list.add_child(none)
	_pick_dialog = Modal.notify(self, "", [], false, {
		Modal.OPTION_TITLE: tr("ui_pomodoro_task_pick"),
		Modal.OPTION_CONTENT: content,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
	})


# ⚠ `color` が -1 なら色の印を出さない（⚠ 「選ばない」の行）。
func _pick_row(row_name: String, text: String, is_selected: bool, color: int) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = row_name
	row.compact = true
	row.selected = is_selected
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	if color >= 0:
		line.add_child(TaskColorMark.create(color))
	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.text = text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(title)
	return row


func _on_task_picked(task_id: String) -> void:
	set_task(task_id)
	# ⚠ 窓を閉じる（⚠ 木から外れると窓は自分で「閉じた」を出す＝`ModalDialog._exit_tree()`）。
	if _pick_dialog != null and is_instance_valid(_pick_dialog):
		_pick_dialog.queue_free()
	_pick_dialog = null
