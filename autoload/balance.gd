extends Node

# 数値調整用Resourceの集約。AGENTS.mdの「数値管理ルール」を実現する本体。
# シーン（balance.tscn）として登録し、Inspectorから各Configの.tresを差し替えられるようにする。

@export var pomodoro: PomodoroConfig
@export var shop: ShopConfig
@export var research: ResearchConfig
@export var workshop: WorkshopConfig
@export var character: CharacterConfig
@export var initial_state: InitialStateConfig
@export var adventure: AdventureConfig
@export var sound: SoundConfig
# ⚠ 等級・鍛冶・分解の数値（EXEC_MATERIAL_TIERS.md）。
#   割り当てを忘れると null になり、装備画面と倉庫が落ちる。
@export var equipment: EquipmentConfig
# ⚠ 装飾（段階上げ・壊したときの戻り）の数値（EXEC_DECORATION.md）。
#   割り当てを忘れると null になり、装備画面の枠と倉庫の装飾が止まる。
@export var part: PartConfig
