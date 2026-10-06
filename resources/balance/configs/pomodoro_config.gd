class_name PomodoroConfig
extends Resource

# ポモドーロ関連の数値調整用Config。
# 加護3種・換算レート・プリセット配列・ユーザー設定範囲を保持する。

@export var protection_light: ProtectionTypeConfig
@export var protection_middle: ProtectionTypeConfig
@export var protection_hard: ProtectionTypeConfig
@export var gold_per_focus_minute: float
@export var stamina_per_focus_minute: float
@export var materials_per_focus_minute: float
@export var presets: Array[PomodoroPreset]
@export var min_sets: int
@export var max_sets: int
@export var min_long_break_minutes: int
@export var max_long_break_minutes: int
@export var min_long_break_interval: int
@export var max_long_break_interval: int
# ⚠ chest_contents は消した（EXEC_CHEST_REGISTRY.md §3-H）。
#   宝箱の中身は chests.json が持つ。ここに戻さないこと——.tres は E118 が
#   見られず、素材IDの改名から漏れて無音で壊れる（EXEC_STAGE_DROPS.md §11）。
@export var session_title_max_length: int

# ⚠ 設定の画面で選べる集中と休憩の長さ（2026-09-28・回UI-仕組み③・手本 Settings・人間「⚠ 2あ」）。⚠ 分。
#   ⚠ 選んだ値は `user://settings.cfg`（`GameSettings`・`BS-13`）。⚠ 長い休憩・セット数はプリセットのまま。
@export var focus_minute_choices: Array[int] = [25, 45, 50]
@export var break_minute_choices: Array[int] = [5, 10, 15]
@export var default_focus_minutes: int = 25
@export var default_break_minutes: int = 5
# ⚠ 1日の目標（⚠ 今日集中した分＝`CUMULATIVE_FOCUS_MINUTES_TODAY`）。⚠ 0＝目標なし。⚠ 選んだ値は `GameSettings`。
@export var daily_goal_minute_choices: Array[int] = [0, 60, 120, 180, 240]

@export var potion_focus_minutes_per_unit: int = 25
@export var stamina_potion_recovery: int = 50

@export var reflection_min_chars: int = 20
@export var reflection_time_limit_sec: int = 120

# ⚠ タスクのメモの色の数（2026-10-04・`TK-12`・人間「⚠ ６色で」）。⚠ 色そのものは Theme の `TaskColor` 型（`tools/theme_builder.gd`）。
#   ⚠ Theme に並べた色より多くしない（⚠ 足りない番号は色が引けない）。
@export var task_color_count: int = 6
