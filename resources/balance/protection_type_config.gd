class_name ProtectionTypeConfig
extends Resource

# 加護1種の宝箱スケジュール（DATA_SCHEMA.md 2-3準拠）。
# 加護は報酬倍率ではなく「いつ・どの宝箱がもらえるか」だけを決める。
# しきい値はその日の累計作業分で判定する（1セッションではない）。

@export var schedule: Array[ChestScheduleEntry]
