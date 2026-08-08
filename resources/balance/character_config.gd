class_name CharacterConfig
extends Resource

# 育成関連の数値調整用Config（最小スケルトン）。
# 詳細なレベルアップ素材・成長曲線は各ギルドEXECで拡張する。

@export var level_up_material_id: String
@export var base_level_up_cost: int
@export var cost_growth_per_level: float
