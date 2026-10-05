class_name TaskParts
extends RefCounted

# タスクの見せ方の小さな口（2026-10-05・タスクのモック）。
#
# ⚠ 期限の判・日付の字・「あと◯日」・「今週中」の日付。⚠ 拠点の紙・タスクの画面・ポモドーロ・記録で同じ字にするため1か所に置く。
# ⚠ 静的な関数なので `tr()` は使えない＝`TranslationServer.translate()`（AGENTS.md）。
# ⚠ 「今日」は朝4:00 区切り（`GameDate`）。⚠ 日付の計算は昼の12時で行う（⚠ 夏時間・時差で日がずれないように）。
# ⚠ 4画面で使う＝scenes/ui/components/（AGENTS.md）。

const SECONDS_PER_DAY: int = 86400


# 期限の判の字（⚠ 判を押さないなら ""）。
static func due_stamp_key(due_state: int) -> String:
	match due_state:
		GameManager.TASK_DUE_OVERDUE:
			return "ui_task_due_overdue"
		GameManager.TASK_DUE_TODAY:
			return "ui_task_due_today"
	return ""


# 期限の小さい判（⚠ 押さないなら null）。⚠ 行の中で題を切らない大きさ（`Stamp.small`）。
static func due_stamp(task: Dictionary, small: bool = true) -> Stamp:
	var key: String = due_stamp_key(GameManager.get_task_due_state(task))
	if key == "":
		return null
	var stamp: Stamp = Stamp.new()
	stamp.name = "DueStamp"
	stamp.label_key = key
	stamp.small = small
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return stamp


static func _unix(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")


# `date` に `days` 日足した日付（⚠ "YYYY-MM-DD"）。
static func shift_date(date: String, days: int) -> String:
	return Time.get_date_string_from_unix_time(_unix(date) + days * SECONDS_PER_DAY)


# 曜日（⚠ 0＝日 … 6＝土）。
static func weekday(date: String) -> int:
	return int(Time.get_datetime_dict_from_unix_time(_unix(date)).get("weekday", 0))


# 「10/03」。
static func short_date(date: String) -> String:
	var parts: PackedStringArray = date.split("-")
	if parts.size() != 3:
		return date
	return "%s/%s" % [parts[1], parts[2]]


# 「10/03（土）」。
static func long_date(date: String) -> String:
	return TranslationServer.translate("ui_task_date_long") % [short_date(date), TranslationServer.translate("ui_weekday_%d" % weekday(date))]


# 今日から何日後か（⚠ 過ぎていれば負）。
static func days_from_today(date: String) -> int:
	return roundi(float(_unix(date) - _unix(GameDate.get_game_date_string())) / float(SECONDS_PER_DAY))


# 「今週中」＝今日から数えて次の週の終わりの日（⚠ 今日がその曜日なら今日・`TK-17`）。
static func week_end_date() -> String:
	var today: String = GameDate.get_game_date_string()
	var days: int = (GameSettings.week_end_weekday() - weekday(today) + 7) % 7
	return shift_date(today, days)
