class_name BattleDebugPanel
extends CanvasLayer

# 戦闘画面の検証用デバッグパネル。
#
# UI をすべてコードで組み立てる。理由：
#  - .tscn を人間が手で作る手間を無くすため
#  - デバッグ用ノードが本番シーンのツリーに残らないようにするため
#
# BattleController が OS.is_debug_build() のときだけ生成する。
# 入力は _unhandled_input で直接キーコードを見る。
# project.godot の Input Map は人間の担当なので触らない。

const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]

var _controller: Node = null
var _root: PanelContainer = null
var _info_label: Label = null
var _help_label: Label = null
var _scale_index: int = 0


func setup(controller: Node) -> void:
	_controller = controller
	layer = 100
	_build_ui()


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = Vector2(8, 8)
	_root.modulate = Color(1, 1, 1, 0.92)
	add_child(_root)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_root.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	margin.add_child(box)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_info_label)

	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_help_label.text = "\n".join([
		"--------------------------------",
		"[F3] パネル表示切替",
		"[1][2][3][4] 速度 1x / 2x / 4x / 8x",
		"[K] 敵を1体たおす",
		"[L] このウェーブの敵を全滅",
		"[J] 味方全員に10ダメージ",
		"[V] 強制的に勝利  [B] 強制的に敗北",
	])
	box.add_child(_help_label)


func _process(_delta: float) -> void:
	if not visible or _info_label == null:
		return
	_info_label.text = _build_info_text()


func _build_info_text() -> String:
	if _controller == null:
		return "controller なし"
	var session: BattleSession = _controller.get_session()
	if session == null:
		return "session なし（初期化前）"

	var lines: Array[String] = []
	lines.append("state=%s  wave=%d/%d  speed=%.0fx" % [
		session.state, session.current_wave, session.total_waves, Engine.time_scale
	])
	lines.append("--------------------------------")
	lines.append("味方")
	for u in session.party_units:
		lines.append(_format_unit(u))
	lines.append("敵")
	for u in session.enemy_units:
		lines.append(_format_unit(u))
	return "\n".join(lines)


func _format_unit(unit: BattleUnit) -> String:
	if unit == null:
		return "  (null)"
	var mark: String = " " if unit.is_alive() else "x"
	var target: String = unit.target_unit_id if unit.target_unit_id != "" else "-"
	return "%s %-12s hp %4d/%-4d x %6.1f atk %3d def %3d tgt %-12s t %.2f/%.2f" % [
		mark, unit.unit_id, unit.hp, unit.max_hp, unit.x,
		unit.atk, unit.def, target, unit.attack_timer, unit.attack_interval_sec
	]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_F3:
			visible = not visible
		KEY_1:
			_set_time_scale(0)
		KEY_2:
			_set_time_scale(1)
		KEY_3:
			_set_time_scale(2)
		KEY_4:
			_set_time_scale(3)
		KEY_K:
			_call_controller("debug_kill_one_enemy")
		KEY_L:
			_call_controller("debug_kill_all_enemies")
		KEY_J:
			_call_controller("debug_damage_party", 10)
		KEY_V:
			_call_controller("debug_force_victory")
		KEY_B:
			_call_controller("debug_force_defeat")
		_:
			return
	get_viewport().set_input_as_handled()


func _set_time_scale(index: int) -> void:
	if index < 0 or index >= TIME_SCALES.size():
		return
	_scale_index = index
	Engine.time_scale = TIME_SCALES[index]
	print("[BattleDebug] time_scale = %.0fx" % Engine.time_scale)


# 引数の数が違うので bind ではなく分岐で呼ぶ
func _call_controller(method: String, arg: Variant = null) -> void:
	if _controller == null:
		return
	if not _controller.has_method(method):
		push_warning("[BattleDebug] controller に %s が無い" % method)
		return
	if arg == null:
		_controller.call(method)
	else:
		_controller.call(method, arg)
