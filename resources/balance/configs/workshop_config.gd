class_name WorkshopConfig
extends Resource

# 作業場関連の数値調整用Config。
# レシピそのもの（消費・産出・所要時間）は resources/balance/master/recipes.json が正。
# ここに置くのは「レシピをまたいで効く数値」だけにすること。

# recipes.json で duration_sec を書かなかったレシピに使う既定値。
# 0 以下のときは GameManager 側の DEFAULT_CRAFT_DURATION_SEC が使われる。
@export var base_craft_duration_sec: int = 1800

# 同時に進行できる製作の本数。第1弾は 1。
# ハードコードしないこと（PLAN_GUILD_WORKSHOP.md §5-6）。
@export var max_queue_slots: int = 1

# level_up_material_id は CharacterConfig へ一本化したため削除した（EXEC_GUILD_TRAINING §5-4）。
# 作業場と育成の両方に同名の @export があり、どちらが正なのか判別できない状態だったため。
