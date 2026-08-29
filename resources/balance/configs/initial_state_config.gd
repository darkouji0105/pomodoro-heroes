class_name InitialStateConfig
extends Resource

# 新規開始時（SaveManager.has_save() == false）のGameManager初期値。
# GameManagerは_ready()でこの値を使って自身を初期化する。

@export var starting_gold: int
@export var starting_gems: int
@export var starting_stamina_max: int
@export var starting_stamina_current: int
@export var starting_materials: Dictionary
@export var initially_unlocked_screens: Array[String]
@export var starting_scenario_chapter: int
@export var save_version: int
