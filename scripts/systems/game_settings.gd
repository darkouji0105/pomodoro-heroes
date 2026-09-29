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
# ⚠ 集中の道具（2026-09-29・回UI-仕組み⑤）。⚠ 値は `FocusTool.TOOL_*`（⚠ 最初から全部持っている＝見た目の好みなので設定に置く）。
const KEY_FOCUS_TOOL: String = "focus_tool"
const VOLUME_MAX_PCT: int = 100
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
		KEY_FOCUS_TOOL:
			return "hourglass"
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
