class_name ChestContentConfig
extends Resource

# chest_type 1種ぶんの中身。
# 現状は建築素材のみ。レア素材・レシピ・装飾が実装されたら項目を増やす。

@export var chest_type: String
@export var materials: Dictionary   # material_id -> 個数
