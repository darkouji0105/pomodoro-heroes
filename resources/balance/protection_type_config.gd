class_name ProtectionTypeConfig
extends Resource

# 加護1種のしきい値・倍率（DATA_SCHEMA.md 2-3準拠）。
# light/middle: bonus_multiplier + after_multiplier を使用
# hard: before_multiplier + after_multiplier を使用（bonus_multiplier は未使用）

@export var threshold_min: int
@export var bonus_multiplier: float
@export var before_multiplier: float
@export var after_multiplier: float
