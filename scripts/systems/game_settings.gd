class_name GameSettings
extends RefCounted

# 遊ぶ人の設定（2026-09-28・回UI-仕組み③・手本 Settings・決定 `BS-13`）。
#
# ⚠⚠ **ゲームのセーブと別のファイル**（`user://settings.cfg`）。⚠ セーブを消しても設定は残る。
# ⚠ 持つもの（⚠ 人間「⚠ 1あ　⚠ 2あ」）：⚠ 全画面か ／ 音量（全体・効果音・BGM・0〜100%）／ 集中と休憩の長さ（分）。
# ⚠ 値を変えたら `set_value()`（⚠ すぐ書く）→ ⚠ 反映は呼ぶ側（⚠ 音＝`SoundManager.refresh_volumes()` ／ 表示＝`apply_display()`）。
# ⚠ 検査（debug_boot）は `use_path()` で置き場所を差し替える（⚠ 遊んでいる人の設定を上書きしない）。

const SECTION_DISPLAY: String = "display"
const SECTION_AUDIO: String = "audio"
const SECTION_POMODORO: String = "pomodoro"
const KEY_FULLSCREEN: String = "fullscreen"
const KEY_MASTER: String = "master_pct"
const KEY_SE: String = "se_pct"
const KEY_BGM: String = "bgm_pct"
const KEY_FOCUS_MINUTES: String = "focus_minutes"
const KEY_BREAK_MINUTES: String = "break_minutes"
const KEY_LONG_BREAK_MINUTES: String = "long_break_minutes"
# ⚠ 集中の道具（2026-09-29・回UI-仕組み⑤）。⚠ 値は `FocusTool.TOOL_*`（⚠ 最初から全部持っている＝見た目の好みなので設定に置く）。
const KEY_FOCUS_TOOL: String = "focus_tool"
# ⚠ 小窓（2026-09-29・回UI-仕組み⑥・人間「⚠ 4あ」＝既定はオフ）／ ⚠ 小窓をいつも前に出す（既定オン）。
const KEY_MINI_WINDOW: String = "mini_window"
const KEY_MINI_ON_TOP: String = "mini_window_on_top"
# ⚠ 小窓にするかをもう聞いたか（10-06・PLAN_POMODORO_USABILITY 不便7・人間「⚠ 初回だけ聞く」）。
const KEY_MINI_ASKED: String = "mini_window_asked"
# ⚠ 回P-3（2026-10-05）：⚠ 休憩明けに次の集中を自動で始める（既定オフ）／ ⚠ 1日の目標（分・0＝なし・既定なし）。
const KEY_AUTO_START: String = "auto_start_focus"
const KEY_DAILY_GOAL: String = "daily_goal_minutes"
# ⚠ タスクの期限の札「今週中」が入れる曜日（2026-10-05・`TK-17`・人間「⚠ 設定に足す・既定は土曜」）。⚠ 値は曜日の番号（0＝日 … 6＝土・Godot の `weekday` と同じ）。
const SECTION_TASK: String = "task"
const KEY_WEEK_END: String = "week_end_weekday"
# ⚠ 演出の速さ（2026-10-07・回UI-便 K・人間「⚠ Kは５で」）：⚠ 0〜4 の段（⚠ 倍率は下の `EFFECT_SPEEDS`）。
const KEY_EFFECT_SPEED: String = "effect_speed"
const WEEK_END_CHOICES: Array[int] = [5, 6, 0]
const VOLUME_MAX_PCT: int = 100
# ⚠ 演出の速さの5段（⚠ ふつう・1.5倍・2倍・3倍・とばす）。⚠ 「とばす」は 20倍＝ほぼ一瞬（⚠ 演出の終わりで次へ進む作りを崩さない）。
const EFFECT_SPEEDS: Array[float] = [1.0, 1.5, 2.0, 3.0, 20.0]
const DEFAULT_PATH: String = "user://settings.cfg"
# ⚠⚠ 置き場所の差し替えは Engine のメタに持つ（⚠ static 変数は途中で台本が読み直されると初期値に戻る＝
#   ⚠ 09-28 に検査が本物の `settings.cfg` を書いた）。
const META_PATH: StringName = &"game_settings_path"

# ⚠ 読んだファイルの控え（⚠ 消えても次に読み直すだけ）。
static var _file: ConfigFile = null
static var _loaded_path: String = ""


static func path() -> String:
	return str(Engine.get_meta(META_PATH, DEFAULT_PATH))


# 置き場所を差し替えて読み直す（⚠ 検査用＝遊んでいる人の設定を書かない）。
static func use_path(new_path: String) -> void:
	Engine.set_meta(META_PATH, new_path)
	reload()


static func _ensure_loaded() -> void:
	if _file != null and _loaded_path == path():
		return
	_file = ConfigFile.new()
	_loaded_path = path()
	var error: Error = _file.load(_loaded_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("[GameSettings] %s を読めない（%d）。既定値で始める" % [_loaded_path, error])


# 読み直す。
static func reload() -> void:
	_file = null
	_ensure_loaded()


static func _default(section: String, key: String) -> Variant:
	match key:
		KEY_FULLSCREEN:
			return false
		KEY_MASTER, KEY_SE, KEY_BGM:
			return VOLUME_MAX_PCT
		KEY_FOCUS_MINUTES:
			return Balance.pomodoro.default_focus_minutes if Balance.pomodoro != null else 25
		KEY_BREAK_MINUTES:
			return Balance.pomodoro.default_break_minutes if Balance.pomodoro != null else 5
		KEY_LONG_BREAK_MINUTES:
			return Balance.pomodoro.default_long_break_minutes if Balance.pomodoro != null else 30
		KEY_FOCUS_TOOL:
			return "hourglass"
		KEY_MINI_WINDOW:
			return false
		KEY_MINI_ON_TOP:
			return true
		KEY_MINI_ASKED:
			return false
		KEY_AUTO_START:
			return false
		KEY_DAILY_GOAL:
			return 0
		KEY_WEEK_END:
			return 6
		KEY_EFFECT_SPEED:
			return 0
	push_warning("[GameSettings] 知らない設定 %s/%s" % [section, key])
	return null


static func get_value(section: String, key: String) -> Variant:
	_ensure_loaded()
	return _file.get_value(section, key, _default(section, key))


static func set_value(section: String, key: String, value: Variant) -> void:
	_ensure_loaded()
	_file.set_value(section, key, value)
	var error: Error = _file.save(path())
	if error != OK:
		push_warning("[GameSettings] %s に書けない（%d）" % [path(), error])


# --- 読む口（⚠ 型をそろえる＝ConfigFile から戻る数値は int のことも float のこともある） ---

static func is_fullscreen() -> bool:
	return bool(get_value(SECTION_DISPLAY, KEY_FULLSCREEN))


static func volume_pct(key: String) -> int:
	return clampi(int(get_value(SECTION_AUDIO, key)), 0, VOLUME_MAX_PCT)


static func focus_minutes() -> int:
	return int(get_value(SECTION_POMODORO, KEY_FOCUS_MINUTES))


static func break_minutes() -> int:
	return int(get_value(SECTION_POMODORO, KEY_BREAK_MINUTES))


# 長い休憩（⚠ 4回ごと・10-06）。
static func long_break_minutes() -> int:
	return int(get_value(SECTION_POMODORO, KEY_LONG_BREAK_MINUTES))


static func mini_window() -> bool:
	return bool(get_value(SECTION_POMODORO, KEY_MINI_WINDOW))


static func mini_window_asked() -> bool:
	return bool(get_value(SECTION_POMODORO, KEY_MINI_ASKED))


static func mini_window_on_top() -> bool:
	return bool(get_value(SECTION_POMODORO, KEY_MINI_ON_TOP))


static func auto_start_focus() -> bool:
	return bool(get_value(SECTION_POMODORO, KEY_AUTO_START))


static func daily_goal_minutes() -> int:
	return maxi(0, int(get_value(SECTION_POMODORO, KEY_DAILY_GOAL)))


# 演出の速さの倍率（⚠ 鍛冶・宝箱・判・出撃の署名の Tween に `set_speed_scale()` で掛ける）。
static func effect_speed_index() -> int:
	return clampi(int(get_value(SECTION_DISPLAY, KEY_EFFECT_SPEED)), 0, EFFECT_SPEEDS.size() - 1)


static func effect_speed() -> float:
	return EFFECT_SPEEDS[effect_speed_index()]


# 週の終わりの曜日（⚠ 0〜6 の外なら土曜）。
static func week_end_weekday() -> int:
	var value: int = int(get_value(SECTION_TASK, KEY_WEEK_END))
	return value if value >= 0 and value <= 6 else 6


# 選んだ集中の道具（⚠ 知らない値なら砂時計＝設定のファイルを手で書き換えられても落ちない）。
static func focus_tool() -> String:
	var value: String = str(get_value(SECTION_POMODORO, KEY_FOCUS_TOOL))
	return value if value in FocusTool.OWNED_TOOLS else FocusTool.TOOL_HOURGLASS


# 全画面か窓か（⚠ 起動時は SceneManager が呼ぶ）。⚠ ヘッドレスでは何もしない。
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
