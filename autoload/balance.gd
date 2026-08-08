extends Node

# 数値調整用Resourceの集約。AGENTS.mdの「数値管理ルール」を実現する本体。
# シーン（balance.tscn）として登録し、Inspectorから各Configの.tresを差し替えられるようにする。

@export var pomodoro: PomodoroConfig
@export var shop: ShopConfig
@export var research: ResearchConfig
@export var workshop: WorkshopConfig
@export var character: CharacterConfig
@export var initial_state: InitialStateConfig
