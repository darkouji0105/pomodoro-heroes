extends Control

# PomodoroController
# ポモドーロ画面のメイン管理。子ビューの切り替え、タイマー進行、報酬計算を行う。
#
# 【タイマーの扱い】
# time_left_sec / is_timer_active を書き換えてよいのは _start_phase_timer() と
# _stop_phase_timer() と _process() のみ。各ビューの分岐から直接触らないこと。
# 3箇所から書き換えると、どこか1つ抜けたときにタイマーが止まる。

enum State { PROTECTION_SELECT, FOCUS, REFLECTION, BREAK }

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const REFLECTION_TIME_LIMIT_SEC: float = 120.0

var current_state: State = State.PROTECTION_SELECT
var current_preset: PomodoroPreset = null
var current_total_sets: int = 4
var current_set_index: int = 0 # 0-based
var time_left_sec: float = 0.0
var is_timer_active: bool = false
var session_accumulated_focus_min: int = 0
var set_titles: Array[String] = []
var reflections: Array[Dictionary] = [] # { text: String, skipped: bool }

# 現在表示中のビュー。view_container.get_child(0) を使わないこと。
# queue_free() は遅延実行のため、切り替え直後は古いビューが index 0 に残る。
var _current_view: Node = null

@onready var view_container: Control = $CurrentViewContainer


func _ready() -> void:
	GameManager.reset_daily_pomodoro_state_if_needed()

	# プリセット初期化
	for p in Balance.pomodoro.presets:
		if p.preset_id == "standard":
			current_preset = p
			break
	if current_preset == null:
		if Balance.pomodoro.presets.size() > 0:
			current_preset = Balance.pomodoro.presets[0]
		else:
			push_error("[Pomodoro] No presets found in Balance.pomodoro")
			SceneManager.change_scene(BASE_PATH)
			return

	current_total_sets = current_preset.default_total_sets
	set_titles.resize(current_total_sets)
	set_titles.fill("")

	_build_debug_panel()

	if GameManager.has_selected_protection_today():
		_switch_view(State.FOCUS)
	else:
		_switch_view(State.PROTECTION_SELECT)


func _process(delta: float) -> void:
	if not is_timer_active:
		return

	time_left_sec -= delta

	if time_left_sec <= 0.0:
		time_left_sec = 0.0
		is_timer_active = false
		_update_view_timer()
		_on_timer_finished()
		return

	_update_view_timer()


# 現在のビューにだけ残り時間を通知する。
func _update_view_timer() -> void:
	if _current_view == null or not is_instance_valid(_current_view):
		return
	if _current_view.has_method("update_timer"):
		_current_view.update_timer(int(ceil(time_left_sec)))


func _start_phase_timer(seconds: float) -> void:
	time_left_sec = seconds
	is_timer_active = true
	_update_view_timer()


func _stop_phase_timer() -> void:
	is_timer_active = false


# --- ビュー切り替え ---

func _switch_view(new_state: State) -> void:
	current_state = new_state
	_stop_phase_timer()

	for child in view_container.get_children():
		child.queue_free()
	_current_view = null

	var scene_path: String = ""
	match new_state:
		State.PROTECTION_SELECT:
			scene_path = "res://scenes/pomodoro/protection_select_view.tscn"
		State.FOCUS:
			scene_path = "res://scenes/pomodoro/focus_view.tscn"
		State.REFLECTION:
			scene_path = "res://scenes/pomodoro/reflection_view.tscn"
		State.BREAK:
			scene_path = "res://scenes/pomodoro/break_view.tscn"

	var view: Node = load(scene_path).instantiate()
	view_container.add_child(view)
	_current_view = view

	match new_state:
		State.PROTECTION_SELECT:
			view.protection_selected.connect(_on_protection_selected)

		State.FOCUS:
			var prev_title: String = ""
			if current_set_index > 0:
				prev_title = set_titles[current_set_index - 1]
			view.setup(current_preset, current_set_index + 1, current_total_sets)
			if prev_title != "":
				view.get_node("TitleEdit").text = prev_title
			view.start_requested.connect(_on_focus_started)
			# ここではタイマーを走らせない。開始ボタンを押すまで待つ
			time_left_sec = float(current_preset.focus_duration_sec)
			_update_view_timer()

		State.REFLECTION:
			view.reflection_completed.connect(_on_reflection_completed)
			_start_phase_timer(REFLECTION_TIME_LIMIT_SEC)

		State.BREAK:
			var is_long: bool = ((current_set_index + 1) % current_preset.long_break_interval == 0)
			var duration: int = current_preset.long_break_sec if is_long else current_preset.short_break_sec
			view.setup(duration, is_long)
			view.skip_requested.connect(_on_break_skipped)
			_start_phase_timer(float(duration))


# --- 各フェーズのハンドラ ---

func _on_protection_selected(protection_id: String) -> void:
	GameManager.set_protection_type(protection_id)
	_switch_view(State.FOCUS)


func _on_focus_started(title: String) -> void:
	set_titles[current_set_index] = title
	_start_phase_timer(float(current_preset.focus_duration_sec))


func _on_timer_finished() -> void:
	match current_state:
		State.FOCUS:
			_notify_focus_finished()
			_switch_view(State.REFLECTION)
		State.REFLECTION:
			# 120秒以内に確定しなかった → skipped 扱いで次へ進む
			print("[Pomodoro] reflection timed out -> skipped")
			_on_reflection_completed("", true)
		State.BREAK:
			_go_to_next_set()


func _on_reflection_completed(text: String, skipped: bool = false) -> void:
	# 確定ボタンとタイムアウトの両方から呼ばれうるため、
	# すでに振り返り以外の状態なら二重呼び出しとみなして無視する
	if current_state != State.REFLECTION:
		return

	_stop_phase_timer()
	reflections.append({"text": text, "skipped": skipped})

	if not skipped:
		var focus_min: int = int(current_preset.focus_duration_sec / 60.0)
		session_accumulated_focus_min += focus_min
		_check_thresholds(focus_min)

	if current_set_index + 1 >= current_total_sets:
		_return_to_base()
	else:
		_switch_view(State.BREAK)


func _check_thresholds(added_min: int) -> void:
	GameManager.add_focus_minutes(added_min)
	var new_total: int = GameManager.get_cumulative_focus_minutes()

	var protection_id: String = str(GameManager.get_state().get(GameStateKeys.SELECTED_PROTECTION_TYPE, ""))
	var config: ProtectionTypeConfig = _get_protection_config(protection_id)
	if config == null:
		return

	for entry in config.schedule:
		if entry.threshold_min <= new_total and not GameManager.has_reached_threshold(entry.threshold_min):
			GameManager.record_reached_threshold(entry.threshold_min, entry.chest_type)
			print("[Pomodoro] chest earned at %d min: %s" % [entry.threshold_min, entry.chest_type])


func _get_protection_config(protection_id: String) -> ProtectionTypeConfig:
	match protection_id:
		GameStateKeys.PROTECTION_LIGHT:
			return Balance.pomodoro.protection_light
		GameStateKeys.PROTECTION_MIDDLE:
			return Balance.pomodoro.protection_middle
		GameStateKeys.PROTECTION_HARD:
			return Balance.pomodoro.protection_hard
	return null


func _on_break_skipped() -> void:
	_stop_phase_timer()
	_go_to_next_set()


func _go_to_next_set() -> void:
	current_set_index += 1
	_switch_view(State.FOCUS)


# --- 通知 ---

# 作業終了をOSに知らせる。体験版向けの暫定対応。
# 本番ではトースト通知など別方式を検討する（PROJECT_STATUS.md 未確定事項）。
func _notify_focus_finished() -> void:
	DisplayServer.window_request_attention()
	print("[Pomodoro] focus finished - requested window attention")


# --- 終了処理 ---

func quit_session() -> void:
	_return_to_base()


func _return_to_base() -> void:
	_stop_phase_timer()

	var potion_count: int = GameManager.grant_stamina_potions(session_accumulated_focus_min)
	GameManager.apply_pomodoro_rewards({})
	var claimed_chest_count: int = GameManager.claim_pending_chests()
	print("[Pomodoro] potions=%d, claimed_chests=%d" % [potion_count, claimed_chest_count])

	SceneManager.change_scene(BASE_PATH)


func get_presence_status() -> Dictionary:
	var status_str: String = "none"
	match current_state:
		State.FOCUS:
			status_str = "focus"
		State.REFLECTION:
			status_str = "reflection"
		State.BREAK:
			status_str = "break"

	var elapsed: int = 0
	if current_state == State.FOCUS and current_preset != null:
		elapsed = int((current_preset.focus_duration_sec - time_left_sec) / 60.0)

	return {
		"status": status_str,
		"title": set_titles[current_set_index] if current_set_index < set_titles.size() else "",
		"set_index": current_set_index + 1,
		"total_sets": current_total_sets,
		"elapsed_min": elapsed,
		"remain_min": int(time_left_sec / 60.0)
	}


# ============================================================
# デバッグ機能（デバッグビルドでのみ表示）
# しきい値の検証に45分待つのは現実的でないため、
# 「◯分ぶん経過したことにする」操作を用意する。
# リリースビルドでは OS.is_debug_build() が false になり生成されない。
# ============================================================

var _debug_minutes_edit: LineEdit = null


func _build_debug_panel() -> void:
	if not OS.is_debug_build():
		return

	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "DebugPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)
	add_child(panel)

	var label: Label = Label.new()
	label.text = "DEBUG"
	panel.add_child(label)

	var row: HBoxContainer = HBoxContainer.new()
	panel.add_child(row)

	_debug_minutes_edit = LineEdit.new()
	_debug_minutes_edit.text = "45"
	_debug_minutes_edit.custom_minimum_size = Vector2(60, 0)
	row.add_child(_debug_minutes_edit)

	var add_button: Button = Button.new()
	add_button.text = "分を加算"
	add_button.pressed.connect(_on_debug_add_minutes)
	row.add_child(add_button)

	var skip_button: Button = Button.new()
	skip_button.text = "このフェーズを終わらせる"
	skip_button.pressed.connect(_on_debug_skip_phase)
	panel.add_child(skip_button)

	var reset_button: Button = Button.new()
	reset_button.text = "今日の累計をリセット"
	reset_button.pressed.connect(_on_debug_reset_today)
	panel.add_child(reset_button)

	var state_button: Button = Button.new()
	state_button.text = "状態をprint"
	state_button.pressed.connect(_on_debug_print_state)
	panel.add_child(state_button)


# 入力した分数ぶん、作業したことにする。しきい値判定も走らせる。
func _on_debug_add_minutes() -> void:
	var minutes: int = int(_debug_minutes_edit.text)
	if minutes <= 0:
		print("[Debug] 正の整数を入力してください")
		return
	session_accumulated_focus_min += minutes
	_check_thresholds(minutes)
	print("[Debug] +%d分 -> 累計 %d分 / 受け取り待ちの宝箱 %s" % [
		minutes,
		GameManager.get_cumulative_focus_minutes(),
		str(GameManager.get_unclaimed_chests())
	])


# 現在のフェーズのタイマーを即座に終わらせる。
func _on_debug_skip_phase() -> void:
	if not is_timer_active:
		print("[Debug] タイマーが動いていません（開始ボタン待ちの可能性）")
		return
	time_left_sec = 0.0
	is_timer_active = false
	_update_view_timer()
	_on_timer_finished()


func _on_debug_reset_today() -> void:
	GameManager.reset_daily_pomodoro_state_if_needed()
	print("[Debug] 累計=%d / 到達済みしきい値=%s" % [
		GameManager.get_cumulative_focus_minutes(),
		str(GameManager.get_state().get(GameStateKeys.REACHED_CHEST_THRESHOLDS, []))
	])


func _on_debug_print_state() -> void:
	print("[Debug] state=%s set=%d/%d timer=%.1f active=%s" % [
		State.keys()[current_state], current_set_index + 1, current_total_sets,
		time_left_sec, str(is_timer_active)
	])
	print("[Debug] 累計=%d分 / 到達済み=%s / 受け取り待ち=%s / 未開封宝箱=%d" % [
		GameManager.get_cumulative_focus_minutes(),
		str(GameManager.get_state().get(GameStateKeys.REACHED_CHEST_THRESHOLDS, [])),
		str(GameManager.get_unclaimed_chests()),
		GameManager.get_pending_chest_count()
	])
	print("[Debug] presence=%s" % str(get_presence_status()))
