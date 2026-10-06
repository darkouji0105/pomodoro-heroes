extends Control

# 集中中のビュー（2026-09-09 に絶対座標からコンテナへ組み替えた）。
#
# ⚠ 「1 / 4 Sets」は**器（pomodoro.tscn）が持つ**ようになった。
#   ⚠ 休憩・振り返りでも同じ位置に出したいため。ここでは触らない。
# ⚠ 見出しは無いが `HeadingSlot`（空の HeadingLabel）で**高さだけ確保している**。
#   ⚠ これが無いと、休憩・振り返りへ移った瞬間にタイマーが上下に跳ねる。

# ⚠ `task_id` はリストから選んだタスク（⚠ 選ばずに始めたら ""＝時間をどれにも記録しない・`TK-11`）。
signal start_requested(title: String, task_id: String)
# ⚠ 選んでいるタスクが変わった（⚠ 器が右のサイドバーの明るい行を直す）。
signal task_selected(task_id: String)

@onready var timer_ring: TimerRing = $Layout/TimerRing
@onready var instruction_label: Label = $Layout/InputBlock/InstructionLabel
@onready var title_edit: LineEdit = $Layout/InputBlock/TitleEdit
# ⚠ 作業中に出す大きいタイトル（2026-09-09・人間の宿題「作業中のタイトルを大きく」）。
#   ⚠ 入力欄と**同じ場所・同じ幅**に出す。⚠ 上（タイマーの輪）は1pxも動かない。
#   ⚠ 2行で打ち切る（`max_lines_visible = 2`）。⚠ 長い題で下のボタンを押し下げないため。
@onready var work_title: Label = $Layout/InputBlock/WorkTitle
@onready var start_button: UiButton = $Layout/StartButton
var _links: PomodoroLinks = null
# ⚠ タスクのメモ（2026-10-04・`TK-10`）：⚠ 1行の題は残す。⚠ 選んだあとに題を書き換えると、⚠ タスクの名前が変わる（⚠ 紐付けは残る）。
# ⚠ 2026-10-05（人間「⚠ やることリストはサイドバーにする」「⚠ ポモドーロがめんがもっとこんぱくとに」）：
#   ⚠ 選ぶのは右のサイドバー（`TaskSidebar`）の行＝⚠ 「リストから選ぶ」と選ぶ窓は外した。
#   ⚠ ここに残すのは ⚠ 選んだ＝題の欄の左に色の印・下に紙の帯（「リストのタスク」の判・これまでの集中・期限の判・外す）／
#   ⚠ 選んでいない＝題を打ったときだけ「書いた題をリストに足す」。⚠ 「題を書き換えると名前も変わる」は題の欄のツールチップ。
var _task_id: String = ""
var _task_box: VBoxContainer = null
var _add_button: Button = null
var _linked_band: PaperSheet = null
var _linked_line: HBoxContainer = null
var _title_mark: TaskColorMark = null
# ⚠ リストが空のときの促し（10-06・見る回・人間「⚠ もしくは追加するよう促す」）。
var _empty_prompt: Label = null
# ⚠ 始めたあと（⚠ 帯を描き直しても「外す」を押せないままにする＝透明なので押せると困る）。
var _started: bool = false


func setup(preset: PomodoroPreset) -> void:
	# ⚠ 集中中は輪の代わりに選んだ道具の絵（2026-09-29・回UI-仕組み⑤・人間「⚠ 2あ」・`GameSettings.focus_tool()`）。
	timer_ring.use_tool(GameSettings.focus_tool())
	update_timer(preset.focus_duration_sec, float(preset.focus_duration_sec))
	title_edit.max_length = Balance.pomodoro.session_title_max_length

	instruction_label.text = tr("ui_pomodoro_input_title")
	# ⚠ 2026-10-05（モック4）：⚠ 説明の1行は出さない（⚠ 題の欄の下書き「何に集中しますか（空のままでも始められます）」が同じことを言う）。
	#   ⚠ 始めた瞬間に跳ねないよう、⚠ 最初から出さない。
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
	_refresh_task_link()


func _on_start_pressed() -> void:
	var title: String = title_edit.text.strip_edges()
	if title == "":
		title = "Work"
	# ⚠ 始めたらこの帯は触らせない（⚠ 消さずに透明＝上が跳ねない）。⚠ 替えるのは右のサイドバーから。
	_started = true
	if _task_box != null:
		_task_box.modulate.a = 0.0
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


# ⚠ 「開始」を押したのと同じ（2026-10-05・回P-3）：⚠ 休憩明けの自動開始とスペースキーが呼ぶ。⚠ 始めたあとは何もしない。
func start_now() -> void:
	if _started:
		return
	_on_start_pressed()


func update_timer(seconds: int, total_sec: float) -> void:
	timer_ring.set_time(seconds, total_sec)


# 集中中にサイドバーでタスクを替えたとき（2026-10-05）。⚠ 大きい題をそのタスクの名前に。
func show_running_title(text: String) -> void:
	work_title.text = text


# --- タスクのメモ（2026-10-04・`TK-10`・`TK-11`） ---

func _build_task_box() -> void:
	_task_box = VBoxContainer.new()
	_task_box.name = "TaskBox"
	# 選んでいない姿：⚠ 題を打ったときだけ「書いた題をリストに足す」。
	_add_button = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_task_add")
	_add_button.name = "AddToListButton"
	_add_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_button.pressed.connect(_on_add_to_list_pressed)
	_task_box.add_child(_add_button)
	# ⚠ やることが1件も無いとき（⚠ 選びようが無い）＝⚠ 足すように促す。⚠ 題を打てば「書いた題をリストに足す」が出る。
	_empty_prompt = Label.new()
	_empty_prompt.name = "EmptyPrompt"
	_empty_prompt.theme_type_variation = &"AccentLabel"
	_empty_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_prompt.text = tr("ui_pomodoro_task_empty_prompt")
	_task_box.add_child(_empty_prompt)
	# 選んだ姿：⚠ 紙の帯（⚠ 角飾りは出さない＝細い帯）。
	_linked_band = PaperSheet.new()
	_linked_band.name = "LinkedBand"
	_linked_band.show_corners = false
	_task_box.add_child(_linked_band)
	_linked_line = HBoxContainer.new()
	_linked_band.add_child(_linked_line)
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
	task_selected.emit(_task_id)


# ⚠ 名前・色・期限・時間が変わったら帯を描き直す（`tasks_changed`）。⚠ 打っている題の欄は触らない。
func _refresh_task_link() -> void:
	if _task_box == null:
		return
	var task: Dictionary = GameManager.get_task(_task_id)
	if _task_id != "" and (task.is_empty() or int(task.get(GameStateKeys.TASK_DONE_AT, 0)) != 0):
		_task_id = ""
		task_selected.emit("")
	var linked: bool = _task_id != ""
	_linked_band.visible = linked
	_title_mark.visible = linked
	title_edit.theme_type_variation = &"TaskLinkedEdit" if linked else &""
	title_edit.tooltip_text = tr("ui_pomodoro_task_rename_note") if linked else ""
	_add_button.visible = not linked and title_edit.text.strip_edges() != ""
	_add_button.disabled = _started
	_empty_prompt.visible = not linked and not _started and GameManager.get_open_tasks().is_empty()
	for child: Node in _linked_line.get_children():
		_linked_line.remove_child(child)
		child.queue_free()
	if not linked:
		return
	_title_mark.color_index = int(task.get(GameStateKeys.TASK_COLOR, 0))
	_place_title_mark()
	# ⚠ 「リストのタスク」の判をやめて題を出す（10-06・見る回・人間「⚠ タイトルを表示するように　リストのタスク　ではなく」）。
	# ⚠ 同じ日にもう一度（人間「⚠ 気づけないから選択中にする」）：⚠ 題の左に「選択中」の判。
	var selected_stamp: Stamp = Stamp.new()
	selected_stamp.name = "LinkedStamp"
	selected_stamp.label_key = "ui_pomodoro_task_selected_stamp"
	selected_stamp.small = true
	selected_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linked_line.add_child(selected_stamp)
	var linked_title: Label = Label.new()
	linked_title.name = "LinkedTitle"
	linked_title.text = str(task.get(GameStateKeys.TASK_TITLE, ""))
	linked_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	linked_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_linked_line.add_child(linked_title)
	# ⚠ 題の長さまで取る（⚠ 右の空きと分け合うと「企画書の下書…」で切れた＝撮った絵）。⚠ 長い題は帯の半分で … 。
	var title_font: Font = linked_title.get_theme_font(&"font")
	var title_width: float = title_font.get_string_size(linked_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, linked_title.get_theme_font_size(&"font_size")).x
	linked_title.custom_minimum_size.x = minf(ceilf(title_width), title_edit.size.x * 0.5)
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
	var unlink: Button = UiButton.create_paper_choice("ui_pomodoro_task_unlink")
	unlink.name = "UnlinkButton"
	unlink.theme_type_variation = &"TaskMoveButton"
	unlink.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
		_add_button.visible = text.strip_edges() != ""


func _on_add_to_list_pressed() -> void:
	var task_id: String = GameManager.add_task(title_edit.text)
	if task_id != "":
		set_task(task_id)


# ⚠ 「外す」は帯の中のボタン＝⚠ 押している最中に帯を描き直さない（⚠ 次のフレーム）。
func _on_unlink_pressed() -> void:
	set_task.call_deferred("")
