class_name AimMarker
extends Node2D

# 狙いが動く溜めの円（回GM-1・人間「⚠ ２あ」＝溜めている間に狙いの円が右へ動き、離した場所に撃つ）。
#
# ⚠ 値を持たない。位置と半径は BattleController が毎フレーム渡す（`SpBar` と同じ形）。
# ⚠ .tscn を作らない。コードで組み立てる（ProjectileView と同じ理由）。
# ⚠ 色は ProjectileView と同じく定数で持つ（⚠ 戦場の演出の色はまだ Theme に寄せていない）。

const COLOR_RING: Color = Color(1.0, 0.85, 0.45, 0.95)
const COLOR_FILL: Color = Color(1.0, 0.85, 0.45, 0.18)
const RING_WIDTH: float = 2.0
# ⚠ 戦場は横の1次元。円は横長の楕円で地面に置いた形にする（⚠ 当たりは横の幅＝radius だけ）。
const FLATTEN: float = 0.35

var _radius: float = 0.0


func show_at(x: float, ground_y: float, radius: float) -> void:
	position = Vector2(x, ground_y)
	if not is_equal_approx(radius, _radius):
		_radius = radius
		queue_redraw()
	show()


func _draw() -> void:
	if _radius <= 0.0:
		return
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(49):
		var a: float = TAU * float(i) / 48.0
		points.append(Vector2(cos(a) * _radius, sin(a) * _radius * FLATTEN))
	draw_colored_polygon(points.slice(0, 48), COLOR_FILL)
	draw_polyline(points, COLOR_RING, RING_WIDTH, true)
