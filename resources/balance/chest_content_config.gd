class_name ChestContentConfig
extends Resource

# chest_type 1種ぶんの中身。
# レア素材・レシピ・装飾が実装されたら項目を増やす。

@export var chest_type: String
@export var materials: Dictionary   # material_id -> 個数

# 装備。item_id -> 個数。
# 宝箱の rewards の inventory に入れると、GameManager.add_to_inventory() が
# 装備を個体（eq_N）として作る。ここに書くだけでコード側の追加処理は要らない。
@export var equipment: Dictionary
