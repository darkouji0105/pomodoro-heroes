extends Control

# PomodoroController
# ポモドーロ画面のメイン管理。子ビューの切り替え、タイマー進行、報酬計算を行う。
#
# 【タイマーの扱い】
# time_left_sec / is_timer_active を書き換えてよいのは _start_phase_timer() と
# _stop_phase_timer() と _process() のみ。各ビューの分岐から直接触らないこと。
# 3箇所から書き換えると、どこか1つ抜けたときにタイマーが止まる。
# ⚠ 2026-10-05（回P-3）：⚠ 例外は「＋5分」の `_extend_focus()`（⚠ 残りと長さを同じだけ足すだけ）。
#   ⚠ 一時停止は `is_timer_active` を触らない（⚠ `_paused` で `_process()` が減らさないだけ＝小窓もそのまま）。
#   ⚠ 減らす量はフレームの差分ではなく**時計の差分**（⚠ PC のスリープをまたいでもずれない）。

enum State { PROTECTION_SELECT, FOCUS, REFLECTION, BREAK }

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"

var current_state: State = State.PROTECTION_SELECT
var current_preset: PomodoroPreset = null
var current_total_sets: int = 4
var current_set_index: int = 0 # 0-based
var time_left_sec: float = 0.0
var is_timer_active: bool = false
var session_accumulated_focus_min: int = 0
var set_titles: Array[String] = []
# ⚠ セットごとにリストから選んだタスク（2026-10-04・`TK-5`・`TK-11`）。⚠ "" なら選んでいない＝🍅をどれにも数えない。
var set_task_ids: Array[String] = []
var reflections: Array[Dictionary] = [] # { text: String, skipped: bool }

# 現在表示中のビュー。view_container.get_child(0) を使わないこと。
# queue_free() は遅延実行のため、切り替え直後は古いビューが index 0 に残る。
var _current_view: Node = null

@onready var view_container: Control = $Margin/Layout/CurrentViewContainer
# ⚠ セットの進みは**器が持つ**（2026-09-09）。⚠ 前は集中中のビューだけが持っていて、
#   ⚠ 休憩・振り返りでは消えていた。⚠ フェーズが変わるたびに目線が動く原因だった。
# ⚠⚠ 人間のモック「D案＋輪」で **「1 / 4 Sets」の文字 → 点**になった。
@onready var set_dots: SetDots = $Margin/Layout/TopBar/Center/SetDots

# ⚠ いまのフェーズの長さ。⚠ 輪と点が「どこまで満ちたか」を出すのに要る。
#   ⚠ 書き換えてよいのは _start_phase_timer() と FOCUS の分岐だけ（タイマーと同じ決まり）。
var phase_total_sec: float = 0.0


func _ready() -> void:
	# ⚠ 右上の通貨を隠す（2026-09-09・人間の指示「ポモドーロは直して」）。
	#   ⚠ 集中を邪魔しない画面にする決まり。⚠ 戻すのは `SceneManager` の役目
	#   （⚠ 画面を変えるたびに既定へ戻る）。⚠ ここで戻そうとしないこと。
	ResourceHud.set_shown(false)

	GameManager.reset_daily_pomodoro_state_if_needed()
	# ⚠ 朝4:00 の移し（2026-10-04・`TK-6`）。⚠ 選ぶ窓に昨日終えたものを出さない。
	var _moved: int = GameManager.roll_over_done_tasks()

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
	# ⚠ 集中と休憩の長さは遊ぶ人の設定（2026-09-28・設定の画面・人間「⚠ 2あ」）。⚠ マスターのプリセットは書き換えない（⚠ 複製）。
	#   ⚠ 長い休憩・間隔・セット数はプリセットのまま。
	current_preset = current_preset.duplicate()
	current_preset.focus_duration_sec = GameSettings.focus_minutes() * 60
	current_preset.short_break_sec = GameSettings.break_minutes() * 60

	current_total_sets = current_preset.default_total_sets
	set_titles.resize(current_total_sets)
	set_titles.fill("")
	set_task_ids.resize(current_total_sets)
	set_task_ids.fill("")

	_build_debug_panel()
	_build_sidebar()
	_build_controls()
	# ⚠ 窓を閉じたら「やめる」と同じに確定する（2026-10-05・回P-1・人間「⚠ ｑ１　あ」）。⚠ 書くのは SaveManager。
	SaveManager.quitting.connect(_settle_session)

	if GameManager.has_selected_protection_today():
		_switch_view(State.FOCUS)
	else:
		_switch_view(State.PROTECTION_SELECT)


func _process(_delta: float) -> void:
	if not is_timer_active:
		return
	# ⚠ 時計の差分で減らす（2026-10-05・回P-3）。⚠ 止めているあいだは減らさない（⚠ 時計の基準だけ進める）。
	var now: float = Time.get_unix_time_from_system()
	var elapsed: float = maxf(0.0, now - _last_wall)
	_last_wall = now
	if _paused:
		return

	time_left_sec -= elapsed

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
		_current_view.update_timer(int(ceil(time_left_sec)), phase_total_sec)
	_update_set_dots()
	_push_mini_state()


func _start_phase_timer(seconds: float) -> void:
	time_left_sec = seconds
	phase_total_sec = seconds
	is_timer_active = true
	_paused = false
	_last_wall = Time.get_unix_time_from_system()
	_update_view_timer()
	_update_mini_window()
	_refresh_controls()


func _stop_phase_timer() -> void:
	is_timer_active = false
	_paused = false
	_update_mini_window()
	_refresh_controls()


# --- 一時停止・延長・目標・キー（2026-10-05・回P-3・人間「⚠ 全部作って一気に確認したい」） ---

var _paused: bool = false
var _last_wall: float = 0.0
# ⚠ このセットで延ばした秒（⚠ 振り返りで報酬と今日の分に足す）。⚠ 振り返りから先へ移ると 0。
var _extended_sec: float = 0.0
var _pause_button: UiButton = null
var _extend_button: UiButton = null
var _goal_label: Label = null


func is_paused() -> bool:
	return _paused


# ⚠ 一時停止 ⇔ 再開。⚠ タイマーが動いている集中（始めたあと）と休憩だけ。
func toggle_pause() -> void:
	if not _can_pause():
		return
	_paused = not _paused
	_last_wall = Time.get_unix_time_from_system()
	_refresh_controls()
	_push_mini_state()


func _can_pause() -> bool:
	return is_timer_active and (current_state == State.BREAK or (current_state == State.FOCUS and _focus_started))


# ⚠ 「＋5分」：⚠ 集中中だけ。⚠ 残りと長さを同じだけ延ばす（⚠ 輪の進みが跳ねない）。
func _extend_focus() -> void:
	if not (is_timer_active and current_state == State.FOCUS and _focus_started):
		return
	var add_sec: float = float(Balance.pomodoro.extend_minutes * 60)
	time_left_sec += add_sec
	phase_total_sec += add_sec
	_segment_left += add_sec
	_extended_sec += add_sec
	_update_view_timer()


# ⚠ 上の段の右：[一時停止][＋5分][やめる]（⚠ やめるは .tscn にあるものを入れる）／ ⚠ セットの点の右に今日の分。
func _build_controls() -> void:
	var quit: Control = $Margin/Layout/TopBar/QuitButton
	var top_bar: Control = quit.get_parent()
	var right: HBoxContainer = HBoxContainer.new()
	right.name = "TopControls"
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_bar.add_child(right)
	_pause_button = UiButton.create(UiButton.Variant.GHOST, "ui_pomodoro_pause")
	_pause_button.name = "PauseButton"
	_pause_button.pressed.connect(toggle_pause)
	right.add_child(_pause_button)
	_extend_button = UiButton.create(UiButton.Variant.GHOST, "")
	_extend_button.name = "ExtendButton"
	_extend_button.text = tr("ui_pomodoro_extend") % Balance.pomodoro.extend_minutes
	_extend_button.pressed.connect(_extend_focus)
	right.add_child(_extend_button)
	top_bar.remove_child(quit)
	right.add_child(quit)
	var center: Node = set_dots.get_parent()
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "DotsLine"
	center.remove_child(set_dots)
	center.add_child(line)
	line.add_child(set_dots)
	set_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal_label = Label.new()
	_goal_label.name = "GoalLabel"
	_goal_label.theme_type_variation = &"CaptionLabel"
	_goal_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_goal_label)
	_refresh_goal()
	_refresh_controls()


func _refresh_controls() -> void:
	if _pause_button == null:
		return
	_pause_button.visible = _can_pause()
	_pause_button.label_key = "ui_pomodoro_resume" if _paused else "ui_pomodoro_pause"
	_extend_button.visible = is_timer_active and current_state == State.FOCUS and _focus_started


# ⚠ 今日集中した分 ／ 目標（⚠ 目標なしなら今日の分だけ）。⚠ 届いたら「達成」。
func _refresh_goal() -> void:
	if _goal_label == null:
		return
	var today: int = GameManager.get_cumulative_focus_minutes()
	var goal: int = GameSettings.daily_goal_minutes()
	if goal <= 0:
		_goal_label.text = tr("ui_pomodoro_today_minutes") % today
	elif today >= goal:
		_goal_label.text = tr("ui_pomodoro_goal_reached") % [today, goal]
	else:
		_goal_label.text = tr("ui_pomodoro_goal_progress") % [today, goal]


# ⚠ スペース＝始める（集中の前）・止める／再開（⚠ 字を打っている欄があるときは欄が先に取る＝ここへ来ない）。
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_SPACE:
		return
	if _can_pause():
		toggle_pause()
	elif current_state == State.FOCUS and not _focus_started and _current_view != null and _current_view.has_method("start_now"):
		_current_view.call("start_now")
	else:
		return
	get_viewport().set_input_as_handled()


# --- デスクトップの小窓（2026-09-29・回UI-仕組み⑥・`MiniWindow`） ---
#   ⚠ 小窓になるのは設定がオンで、⚠ タイマーが動いている集中と休憩のあいだだけ（⚠ 振り返りと次の「開始」は元の大きさ）。
#   ⚠ 「大きく」を押したら、⚠ そのフェーズのあいだは元の大きさ（⚠ フェーズが変わると小窓に戻る）。

var _mini: MiniWindow = null
var _mini_expanded: bool = false


func _update_mini_window() -> void:
	var want: bool = GameSettings.mini_window() and is_timer_active and not _mini_expanded \
		and (current_state == State.FOCUS or current_state == State.BREAK)
	if want and _mini == null:
		_mini = MiniWindow.create()
		_mini.expand_requested.connect(_on_mini_expand)
		_mini.skip_requested.connect(_on_mini_skip)
		_mini.finish_task_requested.connect(_on_mini_finish_task)
		_mini.pause_requested.connect(toggle_pause)
		add_child(_mini)
	if _mini == null:
		return
	if want:
		_mini.enter()
		_push_mini_state()
	else:
		_mini.leave()
	_fit_sidebar()


# 設定の窓で長さを変えたとき（2026-10-02・`PomodoroLinks`）。⚠ 集中を始める前なら、⚠ 待っている時間もすぐ変える。
#   ⚠ 動いているタイマーは変えない（⚠ 設定の窓は始める前にしか開けない＝念のため）。
func apply_settings() -> void:
	if current_preset == null:
		return
	current_preset.focus_duration_sec = GameSettings.focus_minutes() * 60
	current_preset.short_break_sec = GameSettings.break_minutes() * 60
	if current_state == State.FOCUS and not is_timer_active:
		time_left_sec = float(current_preset.focus_duration_sec)
		phase_total_sec = time_left_sec
		_update_view_timer()


func _on_mini_expand() -> void:
	_mini_expanded = true
	_update_mini_window()


# ⚠ 小窓に今の姿を渡す（2026-10-05・回P-2）：⚠ 残り時間・集中か休憩か・セットの点・いまのタスク。
func _push_mini_state() -> void:
	if _mini == null or not _mini.is_active():
		return
	var ratio: float = 0.0 if phase_total_sec <= 0.0 else 1.0 - time_left_sec / phase_total_sec
	var focusing: bool = current_state == State.FOCUS
	var task: Dictionary = GameManager.get_task(_current_task_id()) if focusing else {}
	_mini.set_state(int(ceil(time_left_sec)), focusing, current_set_index, current_total_sets, ratio, task, _paused, _can_pause())


# ⚠ 小窓の「休憩をとばす」（⚠ 休憩の画面の「とばす」と同じ口）。⚠ 休憩のあいだだけ。
func _on_mini_skip() -> void:
	if current_state != State.BREAK:
		return
	_on_break_skipped()


# ⚠ 小窓の「タスクを終える」（⚠ サイドバーの四角と同じ口＝`TK-16`）。⚠ 小窓のまま「選んでいない」に戻る。
func _on_mini_finish_task() -> void:
	var task_id: String = _current_task_id()
	if current_state != State.FOCUS or task_id == "":
		return
	finish_task_from_list(task_id, true)
	_push_mini_state()


func is_mini_window_active() -> bool:
	return _mini != null and _mini.is_active()


# --- ビュー切り替え ---

func _switch_view(new_state: State) -> void:
	current_state = new_state
	_focus_started = false
	# ⚠ 延ばした分は振り返りが使ったあと（⚠ 振り返りから先へ移るときに 0）。
	if new_state != State.REFLECTION:
		_extended_sec = 0.0
	# ⚠ フェーズが変わったら「大きく」は解く（⚠ 次の集中・休憩はまた小窓）。
	_mini_expanded = false
	_stop_phase_timer()
	# ⚠ 点の数はセット数で決まる。⚠ 毎フレーム作り直さない（_update_set_dots() は光り方だけ）。
	set_dots.setup(current_total_sets)
	_update_set_dots()

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
	_refresh_sidebar()
	_fit_sidebar()

	match new_state:
		State.PROTECTION_SELECT:
			view.protection_selected.connect(_on_protection_selected)

		State.FOCUS:
			var prev_title: String = ""
			var prev_task: String = ""
			if current_set_index > 0:
				prev_title = set_titles[current_set_index - 1]
				prev_task = set_task_ids[current_set_index - 1]
			view.setup(current_preset)
			if prev_title != "":
				view.set_title_text(prev_title)
			# ⚠ 前のセットで選んだタスクも引き継ぐ（⚠ 名前は今のタスクの名前になる）。
			if prev_task != "":
				view.set_task(prev_task)
			view.start_requested.connect(_on_focus_started)
			view.task_selected.connect(_on_view_task_selected)
			# ここではタイマーを走らせない。開始ボタンを押すまで待つ
			time_left_sec = float(current_preset.focus_duration_sec)
			phase_total_sec = time_left_sec
			_update_view_timer()

		State.REFLECTION:
			view.reflection_completed.connect(_on_reflection_completed)
			_start_phase_timer(_reflection_time_limit_sec())

		State.BREAK:
			var is_long: bool = ((current_set_index + 1) % current_preset.long_break_interval == 0)
			var duration: int = current_preset.long_break_sec if is_long else current_preset.short_break_sec
			view.setup(duration, is_long)
			view.skip_requested.connect(_on_break_skipped)
			_start_phase_timer(float(duration))


# ⚠ 上部バーのセットの点（2026-09-09・人間のモック「D案＋輪」）。
#   ⚠ 加護を選ぶ段はまだ始まっていないので**1つも光らせない**（-1 を渡す）。
# ⚠ 満ちる量は輪と同じ値（＝いまのフェーズの進み）。⚠ 理由は set_dots.gd に書いてある。
func _update_set_dots() -> void:
	if set_dots == null:
		return
	if current_state == State.PROTECTION_SELECT:
		set_dots.set_state(-1, 0.0)
		return
	var ratio: float = 0.0
	if phase_total_sec > 0.0:
		ratio = clampf(1.0 - (time_left_sec / phase_total_sec), 0.0, 1.0)
	set_dots.set_state(current_set_index, ratio)


# ⚠⚠ 振り返りの制限時間（2026-09-12・宿題4）。⚠ **前はここに `120.0` を直書きしていた**。
#   ⚠ `Balance.pomodoro.reflection_time_limit_sec` は**在るのに誰も読んでいなかった**
#   ⚠ ＝AGENTS.md「欄だけ足して実装しないことを禁止する」に引っかかっていた。
# ⚠ 引く形は `reflection_view.gd` の `_min_chars()` と揃えてある（⚠ 同じ Config の別の欄）。
func _reflection_time_limit_sec() -> float:
	return float(Balance.pomodoro.reflection_time_limit_sec)


# --- 各フェーズのハンドラ ---

func _on_protection_selected(protection_id: String) -> void:
	GameManager.set_protection_type(protection_id)
	_switch_view(State.FOCUS)


func _on_focus_started(title: String, task_id: String) -> void:
	set_titles[current_set_index] = title
	set_task_ids[current_set_index] = task_id
	_start_phase_timer(float(current_preset.focus_duration_sec))
	_focus_started = true
	_segment_left = time_left_sec
	_refresh_controls()


func _on_timer_finished() -> void:
	match current_state:
		State.FOCUS:
			_notify_focus_finished()
			_flush_task_time()
			_switch_view(State.REFLECTION)
		State.REFLECTION:
			# 制限時間内に確定しなかった → skipped 扱いで次へ進む
			print("[Pomodoro] reflection timed out (%.0f sec) -> skipped" % (
				_reflection_time_limit_sec()
			))
			_on_reflection_completed("", true)
		State.BREAK:
			_notify_break_finished()
			_go_to_next_set()
			# ⚠ 休憩明けの自動開始（2026-10-05・回P-3・設定・既定オフ）。⚠ 前のセットの題とタスクのまま始める。
			if GameSettings.auto_start_focus() and _current_view != null and _current_view.has_method("start_now"):
				_current_view.call("start_now")


func _on_reflection_completed(text: String, skipped: bool = false) -> void:
	# 確定ボタンとタイムアウトの両方から呼ばれうるため、
	# すでに振り返り以外の状態なら二重呼び出しとみなして無視する
	if current_state != State.REFLECTION:
		return

	_stop_phase_timer()
	reflections.append({"text": text, "skipped": skipped})

	if not skipped:
		# ⚠ 延ばした分も入れる（2026-10-05・回P-3）。
		var focus_min: int = int((float(current_preset.focus_duration_sec) + _extended_sec) / 60.0)
		session_accumulated_focus_min += focus_min
		_check_thresholds(focus_min)
		_refresh_goal()

	if current_set_index + 1 >= current_total_sets:
		_return_to_base()
	else:
		# ⚠ セットが終わるたびに自動セーブ（2026-10-05・回P-1）。⚠ 最後のセットは拠点へ移るときに書く。
		SaveManager.autosave()
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


# ⚠⚠ タスクに集中した時間（2026-10-05・`TK-5` を覆した・人間「⚠ タスクごとにチェックさせてその時のタイマーの時間を記録したい」）。
#   ⚠ 区切りから区切りまでの秒をそのタスクに足す。⚠ 区切り＝集中を始めた ／ 替えた ／ 終えた ／ タイマーが0 ／ やめた。
#   ⚠ 選ばずに始めた区間はどれにも記録しない（`TK-11`）。⚠ 報酬とは繋げない（`TK-14`）。
var _focus_started: bool = false
# ⚠ いまの区切りが始まったときの残り時間（秒）。
var _segment_left: float = 0.0


func _flush_task_time() -> void:
	if current_state != State.FOCUS or not _focus_started or current_set_index >= set_task_ids.size():
		return
	var elapsed: int = int(round(_segment_left - time_left_sec))
	_segment_left = time_left_sec
	var task_id: String = set_task_ids[current_set_index]
	if task_id == "" or elapsed <= 0:
		return
	var written: bool = GameManager.add_task_focus_seconds(task_id, elapsed)
	print("[Pomodoro] task focus +%d sec: %s -> %s" % [elapsed, task_id, str(written)])


# 集中中のリストで行を押した（⚠ いまのタスクを替える）。⚠ 始める前なら集中のビューで選び直す。
func switch_task(task_id: String) -> void:
	if GameManager.get_task(task_id).is_empty() or task_id == _current_task_id():
		return
	if current_state == State.FOCUS and not _focus_started:
		if _current_view != null and _current_view.has_method("set_task"):
			_current_view.call("set_task", task_id)
		return
	_flush_task_time()
	set_task_ids[current_set_index] = task_id
	_show_running_title()
	_refresh_sidebar()


# 集中中のリストで四角を押した（⚠ 終えた・戻した）。⚠ いまのタスクを終えたら、⚠ そこまでの時間を記録して「選んでいない」に戻す。
func finish_task_from_list(task_id: String, done: bool) -> void:
	if GameManager.get_task(task_id).is_empty():
		return
	if done and task_id == _current_task_id():
		if current_state == State.FOCUS and not _focus_started:
			if _current_view != null and _current_view.has_method("set_task"):
				_current_view.call("set_task", "")
		else:
			_flush_task_time()
			set_task_ids[current_set_index] = ""
	var _changed: bool = GameManager.set_task_done(task_id, done)


# ⚠ 集中中の大きい題を、いまのタスクの名前に（⚠ 選んでいなければそのまま）。
func _on_view_task_selected(_task_id: String) -> void:
	_refresh_sidebar()


func _refresh_sidebar() -> void:
	if _sidebar != null:
		_sidebar.refresh()


func _show_running_title() -> void:
	var task: Dictionary = GameManager.get_task(_current_task_id())
	if task.is_empty() or _current_view == null or not _current_view.has_method("show_running_title"):
		return
	_current_view.call("show_running_title", str(task.get(GameStateKeys.TASK_TITLE, "")))


# ⚠ 右のサイドバー「やること」（2026-10-05・人間「⚠ やることリストはサイドバーにする」「⚠ ポモドーロ中もやることリストを追加できるように」）。
#   ⚠ 前は右上の「リスト」で開く板（10-04）。⚠ どのフェーズでもいつも出す。⚠ 中身の柱（`Margin`）はサイドバーの手前までにする（⚠ 時計はその真ん中）。
#   ⚠ 行を押す＝いまのタスクにする（⚠ 始める前は選ぶ・集中中は替える＝`TK-16`）／ ⚠ 四角＝終えた・戻した（⚠ そこまでの時間を記録する）。
var _sidebar: TaskSidebar = null


func _build_sidebar() -> void:
	var margin: MarginContainer = $Margin
	var outer: int = margin.get_theme_constant(&"margin_right")
	var gap: int = get_theme_constant(&"side_gap", &"Task")
	_sidebar = TaskSidebar.create()
	_sidebar.current_task_provider = _current_task_id
	_sidebar.task_pressed.connect(switch_task)
	_sidebar.task_checked.connect(finish_task_from_list)
	add_child(_sidebar)
	# ⚠ 小窓（`MiniWindow`）より下に置く（⚠ 小窓は CanvasLayer＝いつも上）。⚠ デバッグのパネルより下。
	move_child(_sidebar, margin.get_index() + 1)
	var width: float = float(get_theme_constant(&"side_width", &"Task"))
	_sidebar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_sidebar.offset_left = -width - float(outer)
	_sidebar.offset_right = -float(outer)
	_sidebar.offset_top = float(margin.get_theme_constant(&"margin_top"))
	_sidebar.offset_bottom = -float(margin.get_theme_constant(&"margin_bottom"))
	_sidebar_room = width + float(gap)
	_fit_sidebar()


# ⚠⚠ 小窓のあいだ ／ 加護を選ぶあいだはサイドバーを隠し、⚠ 中身の柱を画面いっぱいに戻す（2026-10-05）。
#   ⚠ 小窓は画面の論理の大きさを 300×180 にする＝⚠ サイドバーのぶん引くと柱の幅がマイナスになり、
#   ⚠ 折り返しの字の大きさが決まらずに回り続けて落ちた（⚠ ui_flow の小窓の手で実測・exit がアクセス違反）。
#   ⚠ 加護のカード3枚は柱の幅に入らず、⚠ サイドバーの下に潜った（⚠ 撮った絵）＝選ぶのは1日1回なので隠す。
var _sidebar_room: float = 0.0


func _fit_sidebar() -> void:
	if _sidebar == null:
		return
	var tucked: bool = current_state == State.PROTECTION_SELECT or (_mini != null and _mini.is_active())
	_sidebar.visible = not tucked
	($Margin as Control).offset_right = 0.0 if tucked else -_sidebar_room


# いま数えているタスク（⚠ 始める前は集中のビューで選んでいるもの・⚠ 始めたらそのセットで選んだもの）。
func _current_task_id() -> String:
	if current_state == State.FOCUS and not is_timer_active and _current_view != null and _current_view.has_method("get_task_id"):
		return str(_current_view.call("get_task_id"))
	if current_set_index < set_task_ids.size():
		return set_task_ids[current_set_index]
	return ""


# --- 通知 ---

# 作業終了をOSに知らせる。体験版向けの暫定対応。
# 本番ではトースト通知など別方式を検討する（PROJECT_STATUS.md 未確定事項）。
func _notify_focus_finished() -> void:
	SoundManager.play_se(SoundIds.ALARM_FOCUS_END)
	DisplayServer.window_request_attention()
	print("[Pomodoro] focus finished - requested window attention")


# 休憩終了を知らせる。休憩明けは自動開始せず「開始」ボタン待ちで止まるため、
# ここで気づけないとセッションが止まりっぱなしになる。
# スキップボタン経由では鳴らさない（自分で押したので終わりは分かっている）。
func _notify_break_finished() -> void:
	SoundManager.play_se(SoundIds.ALARM_BREAK_END)
	DisplayServer.window_request_attention()
	print("[Pomodoro] break finished - requested window attention")


# --- 終了処理 ---

# ⚠⚠ 「やめる」には確認を挟む（2026-09-12・宿題3）。
#
# ⚠ 押した瞬間に**そのセッションが終わる**（⚠ 報酬を確定して拠点へ戻る）。
#   ⚠ 集中の途中で誤って押すと戻せない。⚠ 倉庫の「捨てる」と同じ流儀。
# ⚠ 文言は `ui_pomodoro_quit_confirm`。⚠ **前から在って誰も使っていなかった**
#   （⚠ 宿題5 の「未使用の文言」に挙がっていたが、⚠ 消さずにここで使う）。
# ⚠⚠ 状態を触るのは「はい」のあと（CLAUDE.md 6番「状態を変える前に全部の判定を終える」）。
#   ⚠ タイマーもここでは止めない（⚠ 止めるのは `_return_to_base()` の1箇所だけ）。
# ⚠ 窓が開いている間もタイマーは進む（⚠ 他の確認と同じで `pause` は渡さない）。
#   ⚠ その間にフェーズが終わって画面が変わることがあるので、⚠ 待ったあとに
#   ⚠ 木に居るかを見てから進む。
var _quit_confirming: bool = false


func quit_session() -> void:
	# ⚠ 二重に開かない（⚠ Modal は積むので、⚠ 連打すると窓が2枚並ぶ）。
	if _quit_confirming:
		return
	_quit_confirming = true
	var confirmed: bool = await Modal.confirm(self, "ui_pomodoro_quit_confirm", [], false, {
		Modal.OPTION_TITLE: tr("ui_pomodoro_quit_title"),
	})
	_quit_confirming = false
	if not confirmed:
		return
	if not is_inside_tree():
		return
	_return_to_base()


func _return_to_base() -> void:
	_settle_session()

	# 受け取り報告は拠点に着いてから出す。
	# ここでモーダルを出しても直後の遷移で消えるため、数だけ渡す。
	SceneManager.change_scene_with_data(BASE_PATH, {
		TransferKeys.POMODORO_POTIONS: _settled_potions,
		TransferKeys.POMODORO_CHESTS: _settled_chests,
	})


# ⚠⚠ セッションを確定する口（2026-10-05・回P-1）。⚠ 「やめる」・最後のセット・窓を閉じる（`SaveManager.quitting`）の3つがここを通る。
#   ⚠ 1回だけ（⚠ 閉じる合図と拠点へ移るのが重なっても二重に配らない）。⚠ 画面は移らない（⚠ 移るのは `_return_to_base()`）。
var _settled: bool = false
var _settled_potions: int = 0
var _settled_chests: int = 0


func _settle_session() -> void:
	if _settled:
		return
	_settled = true
	# ⚠ 集中の途中でやめたら、⚠ そこまでの時間を選んでいたタスクに記録する（`TK-5`）。
	_flush_task_time()
	_stop_phase_timer()

	_settled_potions = GameManager.grant_stamina_potions(session_accumulated_focus_min)
	GameManager.apply_pomodoro_rewards({})
	_settled_chests = GameManager.claim_pending_chests()
	print("[Pomodoro] settled: potions=%d, claimed_chests=%d" % [_settled_potions, _settled_chests])


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

	var one_sec_button: Button = Button.new()
	one_sec_button.text = "残り1秒にする"
	one_sec_button.pressed.connect(_on_debug_one_second)
	panel.add_child(one_sec_button)

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


# 残り1秒にする。アラームの確認用。
# 「このフェーズを終わらせる」は _on_timer_finished() を直接呼ぶため
# _process() を通らず、本番と同じ経路にならない。音の確認にはこちらを使う。
func _on_debug_one_second() -> void:
	if not is_timer_active:
		print("[Debug] タイマーが動いていません（開始ボタン待ちの可能性）")
		return
	_start_phase_timer(1.0)
	print("[Debug] 残り1秒にしました")


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
