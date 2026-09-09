class_name TimerRing
extends Control

# タイマーを囲む輪（2026-09-09・人間のモック「D案＋輪」）。
#
# ⚠ **満ちる向き**（人間の決定）。⚠ 12時から時計回りに真鍮が増えていく。
#   ⚠ もう1案（満円から減る）は「急かされる印象が強い」としてモック側が比較用に置いていた。
#   ⚠ 向きを変えるなら `_draw()` の `_ratio` を `1.0 - _ratio` にするだけ。
# ⚠ 溝は**開始前から見えている**。⚠ 場所を先に取っておかないと、
#   ⚠ 「開始」を押した瞬間に上下が動く（⚠ モックの狙い）。
# ⚠ 色と寸法は Theme が持つ（`tools/theme_builder.gd` の `_build_pomodoro()`）。
#   ⚠ ここに数値を書かない。
# ⚠ 1画面（ポモドーロ）でしか使わないので `scenes/pomodoro/`（AGENTS.md）。
#
# ⚠ 丸い線端（モックの `stroke-linecap:round`）は入っていない。
#   ⚠ `draw_arc()` に線端の指定が無いため。⚠ 見て気になるようなら別途考える。

const SCENE_PATH: String = "res://scenes/pomodoro/timer_ring.tscn"

# 弧の分割数。⚠ 240px の円なのでこれくらい無いと角が見える。
const ARC_POINTS: int = 128

# ⚠⚠ 数字のラベルは「**在れば使う／無ければ作る**」（2026-09-09）。
#   ⚠ `.tscn` をバックグラウンドの Godot が書き換えることがあり、
#   ⚠ 子が**消えたり戻ったり**する。⚠ どちらかを決め打ちすると事故る。
#   ⚠⚠ 実際に事故った：⚠ 「消される」前提でコードから作ったら、⚠ `.tscn` 側に子が戻っていて
#   ⚠ **数字が2枚重なった**（人間が実機で発見「タイマーが二重になってる」）。
var timer_label: Label = null

# 0.0 〜 1.0。⚠ 満ちた量。
var _ratio: float = 0.0


func _ready() -> void:
	var diameter: int = get_theme_constant(&"diameter", &"TimerRing")
	custom_minimum_size = Vector2(diameter, diameter)

	# ⚠ 先に探す。⚠ `.tscn` が持っていたらそれを使う（⚠ 2枚重ねない）。
	timer_label = get_node_or_null(NodePath("TimerLabel")) as Label
	if timer_label == null:
		timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(timer_label)

	# ⚠ 見た目は `.tscn` 側に在っても無くても同じになるよう、ここで揃えておく。
	timer_label.theme_type_variation = &"TimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ⚠ 輪の上を数字が横切らないように、⚠ 当たり判定を持たせない。
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	queue_redraw()


# 残り時間と全体の長さを渡す。⚠ 表示と輪を1本の口で更新する
#   （⚠ 2つに分けると、片方だけ呼んで輪だけ止まる事故が起きる）。
func set_time(remaining_sec: int, total_sec: float) -> void:
	var m: int = remaining_sec / 60
	var s: int = remaining_sec % 60
	# ⚠ `_ready()` より先に器から呼ばれることがある（⚠ 器は add_child の直後に流し込む）。
	if timer_label != null:
		timer_label.text = "%02d:%02d" % [m, s]

	_ratio = 0.0 if total_sec <= 0.0 else clampf(1.0 - (float(remaining_sec) / total_sec), 0.0, 1.0)
	queue_redraw()


func get_ratio() -> float:
	return _ratio


func _draw() -> void:
	var stroke: int = get_theme_constant(&"stroke", &"TimerRing")
	var diameter: int = get_theme_constant(&"diameter", &"TimerRing")
	var center: Vector2 = Vector2(diameter, diameter) * 0.5
	# ⚠ 線は中心をなぞるので、⚠ 半径から線の半分を引かないと外へはみ出す。
	var radius: float = (float(diameter) - float(stroke)) * 0.5

	# ⚠ 溝。⚠ 満ちていないときも1周ぶん見えている。
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, get_theme_color(&"groove", &"TimerRing"), stroke, true)

	if _ratio <= 0.0:
		return

	# ⚠ 12時から時計回り。⚠ Godot の角度は3時が 0 で時計回りなので、開始は -PI/2。
	var start: float = -PI * 0.5
	draw_arc(
		center, radius, start, start + TAU * _ratio, ARC_POINTS,
		get_theme_color(&"fill", &"TimerRing"), stroke, true,
	)
