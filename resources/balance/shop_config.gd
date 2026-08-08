class_name ShopConfig
extends Resource

# ショップ関連の数値調整用Config（最小スケルトン）。
# 詳細な抽選テーブルは各ギルドEXECで拡張する。

@export var daily_slot_count: int
@export var weekly_slot_count: int
@export var monthly_slot_count: int
@export var item_pool: Array[String]
