extends Control

# PomodoroController
# ポモドーロ画面のメイン管理。子ビューの切り替え、タイマー進行、報酬計算を行う。

enum State { PROTECTION_SELECT, FOCUS, REFLECTION, BREAK }

var current_state: State = State.PROTECTION_SELECT
var current_preset: PomodoroPreset = null
var current_total_sets: int = 4
var current_set_index: int = 0 # 0-based
var time_left_sec: float = 0.0
var is_timer_active: bool = false
var session_accumulated_focus_min: int = 0
var set_titles: Array[String] = []
var reflections: Array[Dictionary] = [] # { text: String, skipped: bool }

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
			SceneManager.change_scene("res://scenes/base/base_screen.tscn")
			return
	
	current_total_sets = current_preset.default_total_sets
	set_titles.resize(current_total_sets)
	set_titles.fill("")
	
	if GameManager.has_selected_protection_today():
		_switch_view(State.FOCUS)
	else:
		_switch_view(State.PROTECTION_SELECT)

func _process(delta: float) -> void:
	if is_timer_active:
		time_left_sec -= delta
		if time_left_sec <= 0:
			time_left_sec = 0
			is_timer_active = false
			_on_timer_finished()
		
		# 現在のビューに時間を通知（duck typing）
		var current_view = view_container.get_child(0)
		if current_view.has_method("update_timer"):
			current_view.update_timer(int(time_left_sec))

func _switch_view(new_state: State) -> void:
	current_state = new_state
	for child in view_container.get_children():
		child.queue_free()
	
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
	
	var view = load(scene_path).instantiate()
	view_container.add_child(view)
	
	match new_state:
		State.PROTECTION_SELECT:
			view.protection_selected.connect(_on_protection_selected)
			# 表示内容はスクリプト内で動的に設定可能だが今回は最小構成
		State.FOCUS:
			var prev_title = ""
			if current_set_index > 0:
				prev_title = set_titles[current_set_index - 1]
			view.setup(current_preset, current_set_index + 1, current_total_sets)
			if prev_title != "":
				view.get_node("TitleEdit").text = prev_title
			view.start_requested.connect(_on_focus_started)
			time_left_sec = current_preset.focus_duration_sec
		State.REFLECTION:
			view.reflection_completed.connect(_on_reflection_completed)
			time_left_sec = 120.0
			is_timer_active = true
		State.BREAK:
			var is_long = ((current_set_index + 1) % current_preset.long_break_interval == 0)
			var duration = current_preset.long_break_sec if is_long else current_preset.short_break_sec
			view.setup(duration, is_long)
			view.skip_requested.connect(_on_break_skipped)
			time_left_sec = duration
			is_timer_active = true

func _on_protection_selected(protection_id: String) -> void:
	GameManager.set_protection_type(protection_id)
	_switch_view(State.FOCUS)

func _on_focus_started(title: String) -> void:
	set_titles[current_set_index] = title
	is_timer_active = true

func _on_timer_finished() -> void:
	match current_state:
		State.FOCUS:
			_switch_view(State.REFLECTION)
		State.REFLECTION:
			_on_reflection_completed("", true) # skipped = true
		State.BREAK:
			_go_to_next_set()

func _on_reflection_completed(text: String, skipped: bool = false) -> void:
	is_timer_active = false
	reflections.append({"text": text, "skipped": skipped})
	
	if not skipped:
		var focus_min = int(current_preset.focus_duration_sec / 60.0)
		session_accumulated_focus_min += focus_min
		_check_thresholds(focus_min)
	
	if current_set_index + 1 >= current_total_sets:
		_return_to_base()
	else:
		_switch_view(State.BREAK)

func _check_thresholds(added_min: int) -> void:
	var old_total = GameManager.get_cumulative_focus_minutes()
	GameManager.add_focus_minutes(added_min)
	var new_total = GameManager.get_cumulative_focus_minutes()
	
	# 加護のしきい値判定
	var protection_id = GameManager.get_state().get(GameStateKeys.SELECTED_PROTECTION_TYPE, "")
	var config: ProtectionTypeConfig = null
	if protection_id == GameStateKeys.PROTECTION_LIGHT: config = Balance.pomodoro.protection_light
	elif protection_id == GameStateKeys.PROTECTION_MIDDLE: config = Balance.pomodoro.protection_middle
	elif protection_id == GameStateKeys.PROTECTION_HARD: config = Balance.pomodoro.protection_hard
	
	if config:
		for entry in config.schedule:
			if entry.threshold_min <= new_total and not GameManager.has_reached_threshold(entry.threshold_min):
				GameManager.record_reached_threshold(entry.threshold_min, entry.chest_type)
				print("[Pomodoro] ui_pomodoro_chest_earned")

func _on_break_skipped() -> void:
	is_timer_active = false
	_go_to_next_set()

func _go_to_next_set() -> void:
	current_set_index += 1
	_switch_view(State.FOCUS)

func quit_session() -> void:
	# 確認ダイアログは今回は省略し、即座に _return_to_base
	_return_to_base()

func _return_to_base() -> void:
	is_timer_active = false
	
	# 報酬集計
	var stamina_reward = int(session_accumulated_focus_min * Balance.pomodoro.stamina_per_focus_minute)
	var reward_data = {
		GameStateKeys.REWARD_STAMINA: stamina_reward
	}
	GameManager.apply_pomodoro_rewards(reward_data)
	
	# 宝箱付与
	GameManager.claim_pending_chests()
	
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")

func get_presence_status() -> Dictionary:
	var status_str = "none"
	match current_state:
		State.FOCUS: status_str = "focus"
		State.REFLECTION: status_str = "reflection"
		State.BREAK: status_str = "break"
		
	return {
		"status": status_str,
		"title": set_titles[current_set_index] if current_set_index < set_titles.size() else "",
		"set_index": current_set_index + 1,
		"total_sets": current_total_sets,
		"elapsed_min": int((current_preset.focus_duration_sec - time_left_sec) / 60.0) if current_state == State.FOCUS else 0,
		"remain_min": int(time_left_sec / 60.0)
	}
