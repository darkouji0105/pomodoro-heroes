class_name UnitView
extends Node2D

# BattleUnit の状態を購読して表示するノード。
# 読み取り専用。HP の変動は BattleController が take_damage() を呼ぶ形で行う。

# 色定数（EXEC §5：本タスク限定の例外）
const COLOR_PARTY: Color = Color(0.3, 0.5, 0.9)   # 青
const COLOR_ENEMY: Color = Color(0.9, 0.35, 0.3)  # 赤
const COLOR_BOSS: Color = Color(0.6, 0.3, 0.8)    # 紫

var _unit: BattleUnit = null


func _ready() -> void:
	# デフォルト非表示。setup() 後に表示する想定。
	hide()


func setup(unit: BattleUnit) -> void:
	_unit = unit
	var body: ColorRect = $Body
	var hp_bar: ProgressBar = $HpBar
	var name_label: Label = $NameLabel

	name_label.text = tr(unit.unit_name_key)

	if unit.is_boss:
		body.color = COLOR_BOSS
	elif unit.team == BattleUnit.TEAM_PARTY:
		body.color = COLOR_PARTY
	else:
		body.color = COLOR_ENEMY

	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	position.x = unit.x
	show()


# 毎フレーム位置と HP バーを同期する
func _process(_delta: float) -> void:
	if _unit == null:
		return
	if not _unit.is_alive():
		# 死亡時は hide() するだけ。ノードは消さない（参照が残るため）
		hide()
		return
	if not visible:
		show()
	position.x = _unit.x
	$HpBar.value = _unit.hp
