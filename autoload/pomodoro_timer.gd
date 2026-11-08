extends Node

# ポモドーロの時計（2026-11-08・imakore を参考に・人間「autoload追加していいよ」）。
#
# 画面の外に置いた時計。残り時間は「終わる時刻」で持つ（数を減らしていく形にしない）。
# ＝PC のスリープや、窓を閉じていたあいだの時間も正しく進む。
#
# ここが持つのは時間だけ。集中か休憩か・セットの数・報酬は `pomodoro.gd` が持つ。
# 残り時間を書き換えてよいのは、このファイルの関数だけ。
#
# 終わる時刻（`_ends_at`）は `Time.get_unix_time_from_system()` の秒。
# 止めているあいだは `_paused_left` に残りを持ち、`_ends_at` は使わない（-1.0 ＝ 止めていない）。

# 残りが 0 になった（1回だけ）。
signal finished

var _active: bool = false
var _ends_at: float = 0.0
var _total_sec: float = 0.0
var _paused_left: float = -1.0
# 動いていないときに画面へ見せる残り（始める前の「25:00」など）。
var _idle_left: float = 0.0


func _process(_delta: float) -> void:
	if not _active or is_paused():
		return
	if _ends_at - _now() <= 0.0:
		_active = false
		_idle_left = 0.0
		finished.emit()


func _now() -> float:
	return Time.get_unix_time_from_system()


func start(seconds: float) -> void:
	_active = true
	_total_sec = seconds
	_ends_at = _now() + seconds
	_paused_left = -1.0


func stop() -> void:
	_idle_left = left_sec()
	_active = false
	_paused_left = -1.0


func is_active() -> bool:
	return _active


func is_paused() -> bool:
	return _paused_left >= 0.0


# 動いていなければ何もしない。
func toggle_pause() -> void:
	if not _active:
		return
	if is_paused():
		_ends_at = _now() + _paused_left
		_paused_left = -1.0
	else:
		_paused_left = maxf(0.0, _ends_at - _now())


func left_sec() -> float:
	if not _active:
		return _idle_left
	if is_paused():
		return _paused_left
	return maxf(0.0, _ends_at - _now())


func total_sec() -> float:
	return _total_sec


func set_left_sec(seconds: float) -> void:
	if not _active:
		_idle_left = seconds
	elif is_paused():
		_paused_left = seconds
	else:
		_ends_at = _now() + seconds


func set_total_sec(seconds: float) -> void:
	_total_sec = seconds


# セーブに載せる形。
func snapshot() -> Dictionary:
	return {
		GameStateKeys.POMODORO_TIMER_ENDS_AT: _ends_at,
		GameStateKeys.POMODORO_TIMER_TOTAL: _total_sec,
		GameStateKeys.POMODORO_TIMER_PAUSED_LEFT: _paused_left,
		GameStateKeys.POMODORO_TIMER_LEFT_AT_SAVE: left_sec(),
	}


# セーブから戻す。`frozen` なら、保存したときの残りで止める（長く放っておいたあとの精算用）。
func restore(data: Dictionary, frozen: bool = false) -> void:
	_active = true
	_total_sec = float(data.get(GameStateKeys.POMODORO_TIMER_TOTAL, 0.0))
	_ends_at = float(data.get(GameStateKeys.POMODORO_TIMER_ENDS_AT, 0.0))
	_paused_left = float(data.get(GameStateKeys.POMODORO_TIMER_LEFT_AT_SAVE, 0.0)) if frozen else float(data.get(GameStateKeys.POMODORO_TIMER_PAUSED_LEFT, -1.0))


# 検査用：時計が `seconds` 進んだことにする（スリープ明けの確かめ）。
func shift_clock_for_test(seconds: float) -> void:
	_ends_at -= seconds
