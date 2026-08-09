class_name GameDate
extends RefCounted

# 1日の区切りは毎朝4:00（DATA_SCHEMA.md 2-4で確定）。
# ポモドーロの加護選択・ストリーク・ショップのリフレッシュで
# 基準がズレないよう、日付判定は必ずこのクラスを経由すること。
#
# 【重要】Godot 4 の Time.get_unix_time_from_system() はUTC基準の値を返し、
# Time.get_datetime_dict_from_unix_time() もUTCとして解釈する。
# そのまま使うと「4時」がUTCの4時になり、日本時間では13時が境界になってしまう。
# よってタイムゾーンのオフセットを足してからローカル時刻として扱う。

const DAY_BOUNDARY_HOUR: int = 4
const SECONDS_PER_DAY: int = 86400


# 「ゲーム内の今日」を表す文字列（例: "2026-08-09"）を返す。
# 深夜0:00〜3:59は前日として扱う。
# unix_time に負値を渡すと現在時刻を使う。
static func get_game_date_string(unix_time: float = -1.0) -> String:
	var t: float = unix_time
	if t < 0.0:
		t = Time.get_unix_time_from_system()

	# UTCのunix時刻に、システムのタイムゾーン差（分）を秒に直して足す。
	# これでローカル時刻として解釈できる値になる。
	var local_t: int = int(t) + _get_timezone_offset_sec()

	# 4時より前なら、前日の日付として扱う
	if _get_hour(local_t) < DAY_BOUNDARY_HOUR:
		local_t -= SECONDS_PER_DAY

	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(local_t)
	return "%04d-%02d-%02d" % [int(dt.year), int(dt.month), int(dt.day)]


# 2つの時刻が「ゲーム内の同じ日」かどうか
static func is_same_game_day(unix_time_a: float, unix_time_b: float) -> bool:
	return get_game_date_string(unix_time_a) == get_game_date_string(unix_time_b)


# システムのタイムゾーン差を秒で返す（日本なら +32400）。
# get_time_zone_from_system() の bias は分単位。
static func _get_timezone_offset_sec() -> int:
	var tz: Dictionary = Time.get_time_zone_from_system()
	return int(tz.get("bias", 0)) * 60


static func _get_hour(local_unix_time: int) -> int:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(local_unix_time)
	return int(dt.hour)
