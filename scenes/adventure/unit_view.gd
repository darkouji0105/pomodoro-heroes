class_name UnitView
extends Node2D

# BattleUnit の状態を購読して表示するノード。
# 読み取り専用。HP の変動は BattleController が take_damage() を呼ぶ形で行う。

# 色定数（EXEC §5：本タスク限定の例外）
const COLOR_PARTY: Color = Color(0.3, 0.5, 0.9)   # 青
const COLOR_ENEMY: Color = Color(0.9, 0.35, 0.3)  # 赤
const COLOR_BOSS: Color = Color(0.6, 0.3, 0.8)    # 紫

# ダメージ表示
const DAMAGE_COLOR: Color = Color(1.0, 0.85, 0.3)
const DAMAGE_FONT_SIZE: int = 22
const DAMAGE_RISE_PX: float = 48.0
const DAMAGE_DURATION_SEC: float = 0.6

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
		# 死亡時は hide() するだけ。ノードは消さない（参照が残るため）。
		# ここで show() に戻す処理を入れないこと。死体が復活表示される。
		hide()
		return
	position.x = _unit.x
	$HpBar.value = _unit.hp


# 被弾した数値を頭上に浮かべて消す。
# ラベルは自分の子ではなく親コンテナに乗せる。
# 自分の子にすると、とどめの一撃で hide() された瞬間に
# 数値も一緒に消えてしまい、最後のダメージが読めなくなるため。
func pop_damage(amount: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var label: Label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", DAMAGE_FONT_SIZE)
	label.add_theme_color_override("font_color", DAMAGE_COLOR)
	label.z_index = 100
	parent.add_child(label)
	label.position = position + Vector2(0.0, -40.0)

	var tween: Tween = parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - DAMAGE_RISE_PX, DAMAGE_DURATION_SEC)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_DURATION_SEC)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
