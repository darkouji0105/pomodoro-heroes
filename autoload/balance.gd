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
# ⚠ フロア探索の数値（段階14・PLAN_SCENARIO_MAP.md）。層の出現比・宝箱・
#   たいまつ・フロア内ショップ。割り当てを忘れると null になり、
#   フロアに入った瞬間に落ちる（scenario=floor が起動時に見張る＝E131）。
@export var floor: FloorConfig
# ⚠ 仮アセット（文字のアイコン）の色と大きさ。等級10色と、宝箱のレアリティ4色を
#   1本にまとめたもの。割り当てを忘れると null になり、アイコンを出す画面
#   （倉庫・装備・ショップ・レリック選択）と宝箱の演出が落ちる（E132 が見張る）。
@export var icon: IconConfig
# ⚠ 難ダンジョンの数値（段階17-a・PLAN_HARD_DUNGEON.md）。層の出現比・戦利品の
#   出方・鞄の枠・一時通貨の伸び。⚠ FloorConfig（シナリオ側）とは別枠。混ぜないこと。
#   割り当てを忘れると null になり、ランに入った瞬間に落ちる（E133 が起動時に見張る）。
@export var dungeon: DungeonConfig
# 持ち物のマス目（段階18-b・PLAN_INVENTORY.md）。⚠ 倉庫の容量はここ1本。
@export var inventory: InventoryConfig
