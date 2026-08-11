class_name WorkshopConfig
extends Resource

# 作業場関連の数値調整用Config（最小スケルトン）。
# 詳細なレシピ・所要時間は各ギルドEXECで拡張する。

@export var base_craft_duration_sec: int

# level_up_material_id は CharacterConfig へ一本化したため削除した（EXEC_GUILD_TRAINING §5-4）。
# 作業場と育成の両方に同名の @export があり、どちらが正なのか判別できない状態だったため。
