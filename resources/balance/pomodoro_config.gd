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
@export var chest_contents: Array[ChestContentConfig]
@export var session_title_max_length: int

@export var potion_focus_minutes_per_unit: int = 25
@export var stamina_potion_recovery: int = 50

@export var reflection_min_chars: int = 20
@export var reflection_time_limit_sec: int = 120
