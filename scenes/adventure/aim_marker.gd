class_name AimMarker
extends Node2D

# 狙いが動く溜めの円（回GM-1・人間「⚠ ２あ」＝溜めている間に狙いの円が右へ動き、離した場所に撃つ）。
#
# ⚠ 値を持たない。位置と半径は BattleController が毎フレーム渡す（`SpBar` と同じ形）。
# ⚠ .tscn を作らない。コードで組み立てる（ProjectileView と同じ理由）。
# ⚠ 色は ProjectileView と同じく定数で持つ（⚠ 戦場の演出の色はまだ Theme に寄せていない）。

const COLOR_RING: Color = Color(1.0, 0.85, 0.45, 0.95)
const COLOR_FILL: Color = Color(1.0, 0.85, 0.45, 0.18)
# 天井（回GS-1）。
const COLOR_CEILING: Color = Color(0.75, 0.75, 0.8, 0.9)
const RING_WIDTH: float = 2.0
# ⚠ 戦場は横の1次元。円は横長の楕円で地面に置いた形にする（⚠ 当たりは横の幅＝radius だけ）。
const FLATTEN: float = 0.35

var _radius: float = 0.0
# 跳ね返りの道筋（回GS-1）。⚠ 使う人までの横の差（狙い → 使う人）と天井の高さ。⚠ 高さ 0 なら出さない。
var _from_dx: float = 0.0
var _ceiling: float = 0.0


func set_bounce(from_dx: float, ceiling: float) -> void:
	if is_equal_approx(from_dx, _from_dx) and is_equal_approx(ceiling, _ceiling):
		return
	_from_dx = from_dx
	_ceiling = ceiling
	queue_redraw()


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
	# 天井で跳ね返る道筋（回GS-1）。⚠ 使う人 → 天井（真ん中の真上）→ 狙い。⚠ 天井は横線で見せる。
	if _ceiling > 0.0:
		var top: Vector2 = Vector2(_from_dx * 0.5, -_ceiling)
		draw_line(Vector2(_from_dx, 0.0), top, COLOR_RING, 1.5, true)
		draw_line(top, Vector2.ZERO, COLOR_RING, 1.5, true)
		draw_line(top + Vector2(-60.0, 0.0), top + Vector2(60.0, 0.0), COLOR_CEILING, 3.0, true)
