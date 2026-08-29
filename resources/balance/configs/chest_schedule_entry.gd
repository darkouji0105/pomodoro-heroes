class_name ChestScheduleEntry
extends Resource

# 加護の宝箱スケジュール1件分。
# 「その日の累計作業分が threshold_min に達したら chest_type の宝箱がもらえる」を表す。

@export var threshold_min: int
@export var chest_type: String
