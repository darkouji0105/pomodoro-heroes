class_name TaskCalendar
extends PopupPanel

# 期限を選ぶカレンダー（2026-10-05・タスクのモック3「先の日はカレンダーで2回押し」）。
#
# ⚠ 「日付を選ぶ ▼」の下に開く板（⚠ 外を押すと閉じる）。⚠ 中は紙（⚠ 字が墨になる）。
# ⚠ 真鍮の輪＝今日（朝4:00 区切り）／ 墨で塗った日＝選んでいる日 ／ 過ぎた日は薄墨（⚠ 選べる）。
# ⚠ 日を押すと `date_picked` を出して閉じる。⚠ 月は ◀ ▶・年は « »（10-05）で送る。⚠ 値は Theme の `Task` 型と `TaskCal*`。
# ⚠ タスクの画面とポモドーロ（詳しくの窓）で使う＝scenes/ui/components/（AGENTS.md・10-05 に scenes/base/ から移した）。

signal date_picked(date: String)

const THEME_TYPE: StringName = &"Task"
const PAST_ALPHA: float = 0.55

var _selected: String = ""
var _year: int = 0
var _month: int = 0
var _title: Label = null
var _grid: GridContainer = null


func _init() -> void:
	name = "TaskCalendar"
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	add_child(sheet)
	var body: VBoxContainer = VBoxContainer.new()
	sheet.add_child(body)
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	body.add_child(head)
	# ⚠ 年も送れる（10-05・人間「⚠ 日付の選択は年も選べるように」）：« ◀ 年月 ▶ »。
	var prev_year: Button = UiButton.create_paper_choice("ui_task_cal_prev_year")
	prev_year.name = "CalPrevYear"
	prev_year.theme_type_variation = &"TaskMoveButton"
	prev_year.tooltip_text = tr("ui_task_cal_prev_year_tip")
	prev_year.pressed.connect(_on_year_step.bind(-1))
	head.add_child(prev_year)
	var prev: Button = UiButton.create_paper_choice("ui_task_cal_prev")
	prev.name = "CalPrev"
	prev.theme_type_variation = &"TaskMoveButton"
	prev.pressed.connect(_on_month_step.bind(-1))
	head.add_child(prev)
	_title = Label.new()
	_title.name = "MonthLabel"
	_title.theme_type_variation = &"SheetHeadingLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var next: Button = UiButton.create_paper_choice("ui_task_cal_next")
	next.name = "CalNext"
	next.theme_type_variation = &"TaskMoveButton"
	next.pressed.connect(_on_month_step.bind(1))
	head.add_child(next)
	var next_year: Button = UiButton.create_paper_choice("ui_task_cal_next_year")
	next_year.name = "CalNextYear"
	next_year.theme_type_variation = &"TaskMoveButton"
	next_year.tooltip_text = tr("ui_task_cal_next_year_tip")
	next_year.pressed.connect(_on_year_step.bind(1))
	head.add_child(next_year)
	_grid = GridContainer.new()
	_grid.name = "Days"
	_grid.columns = 7
	body.add_child(_grid)


# `anchor` の下に開く。⚠ `selected` は "" でもよい（⚠ そのときは今日の月）。
func open_under(anchor: Control, selected: String) -> void:
	_selected = selected
	var base: String = selected if selected != "" else GameDate.get_game_date_string()
	var parts: PackedStringArray = base.split("-")
	_year = int(parts[0])
	_month = int(parts[1])
	_rebuild()
	reset_size()
	var rect: Rect2 = anchor.get_global_rect()
	var popup_size: Vector2 = Vector2(get_contents_minimum_size())
	popup(Rect2i(Vector2i(Vector2(rect.end.x - popup_size.x, rect.end.y)), Vector2i(popup_size)))


func _on_month_step(step: int) -> void:
	_month += step
	if _month < 1:
		_month = 12
		_year -= 1
	elif _month > 12:
		_month = 1
		_year += 1
	_rebuild.call_deferred()


func _on_year_step(step: int) -> void:
	_year += step
	_rebuild.call_deferred()


func _rebuild() -> void:
	_title.text = tr("ui_task_cal_month") % [_year, _month]
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var cell: float = float(get_theme_constant(&"cal_cell", THEME_TYPE))
	for day: int in range(7):
		var weekday: Label = Label.new()
		weekday.theme_type_variation = &"CaptionLabel"
		weekday.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weekday.custom_minimum_size.x = cell
		weekday.text = tr("ui_weekday_%d" % day)
		_grid.add_child(weekday)
	var first: String = "%04d-%02d-01" % [_year, _month]
	for _i: int in range(TaskParts.weekday(first)):
		var blank: Control = Control.new()
		blank.custom_minimum_size = Vector2(cell, cell)
		_grid.add_child(blank)
	var today: String = GameDate.get_game_date_string()
	var date: String = first
	while int(date.split("-")[1]) == _month:
		var button: Button = Button.new()
		button.name = "Day_" + date
		button.text = str(int(date.split("-")[2]))
		button.custom_minimum_size = Vector2(cell, cell)
		button.focus_mode = Control.FOCUS_NONE
		if date == _selected:
			button.theme_type_variation = &"TaskCalSelected"
		elif date == today:
			button.theme_type_variation = &"TaskCalToday"
		else:
			button.theme_type_variation = &"TaskCalDay"
		if date < today:
			button.modulate.a = PAST_ALPHA
		button.pressed.connect(_on_day_pressed.bind(date))
		_grid.add_child(button)
		date = TaskParts.shift_date(date, 1)


func _on_day_pressed(date: String) -> void:
	hide()
	date_picked.emit(date)
