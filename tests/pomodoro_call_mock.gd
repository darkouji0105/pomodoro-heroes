extends Control

# 区切りの呼びかけの試作（2026-11-08・imakore を参考に）。
# 人間の言葉「振り返りはいらない　いったん、別の場所でそこのモックを作ってみよう」。
#
# 確かめること：
#   1. 振り返りなしの流れ（集中 → 区切り → 休憩 → 区切り → 集中）で使いやすいか
#   2. 本体とは別の窓（右下の小窓）が Godot で出せるか・押せるか・入力を奪わないか
#   3. 本体を最小化しても時間が進み、小窓が出るか
#
# 本番のコード・セーブ・設定には触らない（SaveManager.begin_session() を呼ばない）。
# 文字は tr() を通さない開発者向け（debug_overlay.gd と同じ扱い）。数値も試作の仮。
# 本番に入れるときに消す。時刻は「終了時刻」で持つ（imakore の endsAt と同じ）。
#
# 自動の確かめ：-- auto=1 shot_dir=<パス>（--headless を付けない）

enum Phase { IDLE, WORK, TO_BREAK, BREAK, TO_WORK }

const FOCUS_MIN: float = 25.0
const BREAK_MIN: float = 5.0
const RING_INTERVAL_SEC: float = 3.0
const START_SHOW_SEC: float = 8.0
const LOG_LINES: int = 10

var _phase: Phase = Phase.IDLE
var _round: int = 1
var _ends_at: float = 0.0
var _paused_left: float = -1.0
var _warned: bool = false
var _warn_open: bool = false
var _start_open_until: float = 0.0
var _ring_last: float = 0.0
var _pip_was_visible: bool = false
var _log_lines: Array[String] = []

# 選べるもの（既定は「1あ」＝区切りで待つ・音は1回）。
var _unit: float = 1.0 # 1「分」が実時間の何秒か
var _wait_at_boundary: bool = true
var _ring_until_pressed: bool = false
var _warn_min: float = 2.0
var _pip_always: bool = false

var _phase_label: Label
var _time_label: Label
var _forecast_label: Label
var _start_button: Button
var _pause_button: Button
var _next_button: Button
var _log_label: Label

var _pip: Window
var _pip_title: Label
var _pip_big: Label
var _pip_button: Button


func _ready() -> void:
	_build_main()
	_build_pip()
	_refresh()
	_hide_dev_parts()
	var args: Dictionary = _user_args()
	if args.has("auto"):
		_run_auto(str(args.get("shot_dir", "")))


# 右上の通貨とデバッグの札を隠す（試作の切り替えに被るため）。札は SceneManager が遅れて作る。
func _hide_dev_parts() -> void:
	ResourceHud.set_shown(false)
	await get_tree().process_frame
	var overlay: Node = get_tree().root.get_node_or_null("DebugOverlay")
	if overlay != null:
		overlay.set("visible", false)


func _user_args() -> Dictionary:
	var result: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return result


func _now() -> float:
	return Time.get_unix_time_from_system()


func _process(_delta: float) -> void:
	_tick()
	_refresh()


# --- 流れ ---

func _tick() -> void:
	var now: float = _now()
	if _start_open_until > 0.0 and now >= _start_open_until:
		_start_open_until = 0.0
	if (_phase == Phase.WORK or _phase == Phase.BREAK) and _paused_left < 0.0:
		var left: float = _ends_at - now
		if _phase == Phase.WORK and _warn_min > 0.0 and not _warned and left > 0.0 and left <= _warn_min * _unit:
			_warned = true
			_warn_open = true
			SoundManager.play_se(SoundIds.ALARM_BREAK_END)
			_add_log("予告（あと %d 分）" % int(_warn_min))
		if left <= 0.0:
			_advance()
	if _phase == Phase.TO_BREAK or _phase == Phase.TO_WORK:
		if _ring_until_pressed and now - _ring_last >= RING_INTERVAL_SEC:
			_ring()


func _set_phase(phase: Phase, duration_sec: float = 0.0) -> void:
	_phase = phase
	_ends_at = _now() + duration_sec
	_paused_left = -1.0
	_warned = false
	_warn_open = false
	_start_open_until = 0.0
	if phase == Phase.WORK:
		_start_open_until = _now() + minf(START_SHOW_SEC, duration_sec * 0.3)
	_add_log(_phase_name(phase))
	print("[CallMock] phase -> %s" % _phase_name(phase))


func _ring() -> void:
	_ring_last = _now()
	SoundManager.play_se(SoundIds.ALARM_FOCUS_END if _phase == Phase.TO_BREAK else SoundIds.ALARM_BREAK_END)


# 時間が来た ／ 「次へ」。
func _advance() -> void:
	match _phase:
		Phase.WORK:
			if _wait_at_boundary:
				_set_phase(Phase.TO_BREAK)
				_ring()
			else:
				SoundManager.play_se(SoundIds.ALARM_FOCUS_END)
				_start_break()
		Phase.BREAK:
			if _wait_at_boundary:
				_set_phase(Phase.TO_WORK)
				_ring()
			else:
				SoundManager.play_se(SoundIds.ALARM_BREAK_END)
				_start_next_work()
		Phase.TO_BREAK:
			_start_break()
		Phase.TO_WORK:
			_start_next_work()


func _start_break() -> void:
	_set_phase(Phase.BREAK, BREAK_MIN * _unit)


func _start_next_work() -> void:
	_round += 1
	_set_phase(Phase.WORK, FOCUS_MIN * _unit)


func _on_start_pressed() -> void:
	_round = 1
	_set_phase(Phase.WORK, FOCUS_MIN * _unit)


func _on_quit_pressed() -> void:
	_set_phase(Phase.IDLE)


func _on_pause_pressed() -> void:
	if _paused_left >= 0.0:
		_ends_at = _now() + _paused_left
		_paused_left = -1.0
	else:
		_paused_left = _ends_at - _now()


func _on_pip_button_pressed() -> void:
	if _phase == Phase.WORK:
		_warn_open = false
		_start_open_until = 0.0
	else:
		_advance()


func _left_sec() -> float:
	if _phase != Phase.WORK and _phase != Phase.BREAK:
		return 0.0
	return _paused_left if _paused_left >= 0.0 else maxf(0.0, _ends_at - _now())


# --- 表示 ---

func _phase_name(phase: Phase) -> String:
	match phase:
		Phase.WORK:
			return "集中"
		Phase.TO_BREAK:
			return "区切り（休憩を待つ）"
		Phase.BREAK:
			return "休憩"
		Phase.TO_WORK:
			return "区切り（集中を待つ）"
	return "始める前"


func _clock(seconds: float) -> String:
	# 「分」の単位に合わせて出す（早回しでも 25:00 に見えるように）。
	var total: int = int(ceil(seconds * 60.0 / _unit))
	return "%02d:%02d" % [total / 60, total % 60]


func _clock_at(unix: float) -> String:
	var local: float = unix + float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(local))
	return "%02d:%02d" % [int(d["hour"]), int(d["minute"])]


func _refresh() -> void:
	var running: bool = _phase != Phase.IDLE
	var timed: bool = _phase == Phase.WORK or _phase == Phase.BREAK
	_phase_label.text = "%s　%d 回目" % [_phase_name(_phase), _round] if running else _phase_name(_phase)
	_time_label.text = _clock(_left_sec()) if timed else _clock(FOCUS_MIN * _unit)
	if _paused_left >= 0.0:
		_forecast_label.text = "一時停止中"
	elif _phase == Phase.WORK:
		_forecast_label.text = "%s に終わる　次：休憩 %d 分" % [_clock_at(_ends_at), int(BREAK_MIN)]
	elif _phase == Phase.BREAK:
		_forecast_label.text = "%s に終わる　次：集中 %d 分" % [_clock_at(_ends_at), int(FOCUS_MIN)]
	elif running:
		_forecast_label.text = "押すまで待っています"
	else:
		_forecast_label.text = "いま始めると %s に終わる" % _clock_at(_now() + FOCUS_MIN * _unit)
	_start_button.disabled = running
	_pause_button.disabled = not timed
	_pause_button.text = "再開" if _paused_left >= 0.0 else "一時停止"
	_next_button.disabled = not running
	_refresh_pip()


func _refresh_pip() -> void:
	var title: String = ""
	var big: String = _clock(_left_sec())
	var button: String = ""
	match _phase:
		Phase.WORK:
			if _warn_open:
				title = "もうすぐ休憩です"
				button = "わかった"
			elif _start_open_until > 0.0:
				title = "集中の時間です"
				button = "わかった"
			elif _pip_always:
				title = "集中"
		Phase.TO_BREAK:
			title = "%d 回目が終わりました" % _round
			big = "休憩の時間"
			button = "休憩に入る"
		Phase.BREAK:
			title = "休憩"
			button = "休憩を終える"
		Phase.TO_WORK:
			title = "休憩が終わりました"
			big = "集中の時間"
			button = "集中を始める"
	var show_pip: bool = title != ""
	if show_pip:
		_pip_title.text = title
		_pip_big.text = big
		_pip_button.text = button
		_pip_button.visible = button != ""
	if show_pip != _pip_was_visible:
		_pip_was_visible = show_pip
		if show_pip:
			_place_pip()
		_pip.visible = show_pip


# マウスのあるモニターの右下へ（imakore と同じ）。
func _place_pip() -> void:
	var mouse: Vector2i = DisplayServer.mouse_get_position()
	var screen: int = DisplayServer.get_primary_screen()
	for i: int in DisplayServer.get_screen_count():
		if Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i)).has_point(mouse):
			screen = i
			break
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin: int = ThemeDB.get_project_theme().get_constant(&"margin", MiniWindow.THEME_TYPE)
	_pip.position = usable.position + usable.size - _pip.size - Vector2i(margin, margin)


func _add_log(text: String) -> void:
	_log_lines.append("%s　%s" % [_clock_at(_now()), text])
	if _log_lines.size() > LOG_LINES:
		_log_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)


# --- 組み立て ---

func _build_main() -> void:
	var back: PanelContainer = PanelContainer.new()
	back.theme_type_variation = &"BackgroundPanel"
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"ScreenMargin"
	back.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.theme_type_variation = &"WideRow"
	margin.add_child(row)

	var left: VBoxContainer = VBoxContainer.new()
	left.theme_type_variation = &"SectionStack"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(left)
	_phase_label = _centered_label(&"HeadingLabel")
	left.add_child(_phase_label)
	_time_label = _centered_label(&"TimerLabel")
	left.add_child(_time_label)
	_forecast_label = _centered_label(&"")
	left.add_child(_forecast_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.theme_type_variation = &"ButtonRow"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(buttons)
	_start_button = _button(buttons, "はじめる", _on_start_pressed, &"PrimaryButton")
	_pause_button = _button(buttons, "一時停止", _on_pause_pressed)
	_next_button = _button(buttons, "次へ", _advance)
	_button(buttons, "やめる", _on_quit_pressed)

	var right: VBoxContainer = VBoxContainer.new()
	right.theme_type_variation = &"PanelStack"
	right.custom_minimum_size.x = 440.0
	row.add_child(right)
	var heading: Label = Label.new()
	heading.theme_type_variation = &"HeadingLabel"
	heading.text = "試作の切り替え"
	right.add_child(heading)
	_option(right, "速さ", ["1秒＝1分（早回し）", "本当の長さ"], func(i: int) -> void:
		_unit = 1.0 if i == 0 else 60.0)
	_option(right, "区切り", ["押すまで待つ", "自動で進む"], func(i: int) -> void:
		_wait_at_boundary = i == 0)
	_option(right, "区切りの音", ["1回だけ", "押すまで鳴らす"], func(i: int) -> void:
		_ring_until_pressed = i == 1)
	_option(right, "終わる前の予告", ["2分前", "なし", "5分前"], func(i: int) -> void:
		_warn_min = [2.0, 0.0, 5.0][i])
	_option(right, "小窓", ["知らせるときだけ", "集中中もいつも"], func(i: int) -> void:
		_pip_always = i == 1)
	_button(right, "本体を最小化する（小窓だけ残るか見る）", func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED))
	_log_label = Label.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_log_label)


func _centered_label(variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(parent: Control, text: String, callback: Callable, variation: StringName = &"") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _option(parent: Control, caption_text: String, items: Array, callback: Callable) -> void:
	var line: HBoxContainer = HBoxContainer.new()
	line.theme_type_variation = &"ButtonRow"
	parent.add_child(line)
	var caption: Label = Label.new()
	caption.text = caption_text
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(caption)
	var option: OptionButton = OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.item_selected.connect(callback)
	line.add_child(option)


func _build_pip() -> void:
	# 埋め込まずに OS の窓として出す。
	get_viewport().gui_embed_subwindows = false
	var theme_data: Theme = ThemeDB.get_project_theme()
	_pip = Window.new()
	_pip.name = "CallPip"
	_pip.title = "ポモドーロ"
	_pip.size = Vector2i(theme_data.get_constant(&"width", MiniWindow.THEME_TYPE), theme_data.get_constant(&"height", MiniWindow.THEME_TYPE))
	_pip.borderless = true
	_pip.always_on_top = true
	_pip.unfocusable = true # キー入力を奪わない
	_pip.unresizable = true
	_pip.transient = false # 本体を最小化しても残す
	_pip.visible = false
	add_child(_pip)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pip.add_child(root)
	var back: ColorRect = ColorRect.new()
	back.color = theme_data.get_color(&"wall", MiniWindow.THEME_TYPE)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = &"MiniMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"MiniColumn"
	margin.add_child(column)
	_pip_title = _centered_label(&"MiniTimeLabel")
	column.add_child(_pip_title)
	_pip_big = _centered_label(&"MiniBigTimeLabel")
	_pip_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pip_big.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_pip_big)
	_pip_button = _button(column, "", _on_pip_button_pressed)


# --- 自動の確かめ ---

func _wait_until(condition: Callable, limit_sec: float = 15.0) -> bool:
	var started: float = _now()
	while not condition.call():
		if _now() - started > limit_sec:
			print("[CallMock] TIMEOUT")
			return false
		await get_tree().process_frame
	return true


func _shot(target: Viewport, shot_dir: String, shot_name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	if shot_dir == "":
		return
	var image: Image = target.get_texture().get_image()
	var err: Error = image.save_png(shot_dir.path_join(shot_name + ".png"))
	print("[CallMock] shot %s err=%d size=%s" % [shot_name, err, str(image.get_size())])


func _run_auto(shot_dir: String) -> void:
	_unit = 0.4
	await get_tree().create_timer(0.5).timeout
	await _shot(get_viewport(), shot_dir, "main_idle")
	_start_button.pressed.emit()
	await _shot(_pip, shot_dir, "pip_start")
	await _shot(get_viewport(), shot_dir, "main_work")
	var pip_id: int = _pip.get_window_id()
	print("[CallMock] windows=%s pip_id=%d embedded=%s on_top=%s no_focus=%s" % [
		str(DisplayServer.get_window_list()), pip_id, str(_pip.is_embedded()),
		str(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, pip_id)),
		str(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, pip_id)),
	])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	print("[CallMock] main minimized mode=%d" % DisplayServer.window_get_mode())
	await _wait_until(func() -> bool: return _warn_open)
	print("[CallMock] warn while minimized left=%.1f pip_visible=%s" % [_left_sec(), str(_pip.visible)])
	await _shot(_pip, shot_dir, "pip_warn_minimized")
	await _wait_until(func() -> bool: return _phase == Phase.TO_BREAK)
	await _shot(_pip, shot_dir, "pip_to_break_minimized")
	_pip_button.pressed.emit()
	print("[CallMock] after pip press phase=%s" % _phase_name(_phase))
	await _shot(_pip, shot_dir, "pip_break_minimized")
	await _wait_until(func() -> bool: return _phase == Phase.TO_WORK)
	await _shot(_pip, shot_dir, "pip_to_work_minimized")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_pip_button.pressed.emit()
	print("[CallMock] after pip press phase=%s round=%d" % [_phase_name(_phase), _round])
	await get_tree().create_timer(0.3).timeout
	print("[CallMock] DONE")
	get_tree().quit()
