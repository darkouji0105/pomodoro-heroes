class_name Hourglass
extends Control

# 砂時計（2026-09-27・回UI-4・手本 Pomodoro の加護のカード）。
#
# ⚠ 絵（画像）を使わず線と面で描く（⚠ 紙の部品と同じ流儀）。⚠ 上下の真鍮の横木・ガラス・上と下の砂。
# ⚠ 砂の量は加護の重さ（⚠ 見た目だけ。⚠ 時間の進みとは結びつけていない）。
# ⚠ 値は Theme の `Hourglass` 型（⚠ 色・大きさ・砂の %）。⚠ `Hourglass.create(index)` で作る。
# ⚠ ポモドーロでしか使わないので scenes/pomodoro/（AGENTS.md）。

const THEME_TYPE: StringName = &"Hourglass"
# ⚠ ガラスの形を 0〜1 の升目で持つ（⚠ 片側だけ。⚠ 左は写す）。⚠ 値ではなく形なのでここに置く。
const GLASS_TOP: float = 0.07
const GLASS_BOTTOM: float = 0.93
const GLASS_EDGE: float = 0.84
const NECK_HALF: float = 0.035
const CURVE_STEPS: int = 16

var _index: int = 0


static func create(index: int) -> Hourglass:
	var glass: Hourglass = Hourglass.new()
	glass._index = index
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return glass


func _ready() -> void:
	custom_minimum_size = Vector2(
		float(get_theme_constant(&"width", THEME_TYPE)),
		float(get_theme_constant(&"height", THEME_TYPE))
	)


# ⚠ 右半分の上の球（上端 → くびれ）。⚠ 0〜1 の升目。
func _upper_right() -> PackedVector2Array:
	var p0: Vector2 = Vector2(GLASS_EDGE, GLASS_TOP)
	var p1: Vector2 = Vector2(GLASS_EDGE, 0.30)
	var p2: Vector2 = Vector2(0.5 + NECK_HALF, 0.38)
	var p3: Vector2 = Vector2(0.5 + NECK_HALF, 0.5)
	var points: PackedVector2Array = PackedVector2Array([p0])
	for step: int in range(1, CURVE_STEPS + 1):
		var t: float = float(step) / float(CURVE_STEPS)
		var u: float = 1.0 - t
		points.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return points


func _mirror_x(p: Vector2) -> Vector2:
	return Vector2(1.0 - p.x, p.y)


func _flip_y(p: Vector2) -> Vector2:
	return Vector2(p.x, 1.0 - p.y)


func _scaled(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * size)
	return out


# ⚠ ガラスの輪郭（時計回り）。⚠ 右上 → くびれ → 右下 → 左下 → くびれ → 左上。
func _glass_outline() -> PackedVector2Array:
	var upper: PackedVector2Array = _upper_right()
	var outline: PackedVector2Array = PackedVector2Array()
	outline.append_array(upper)
	for i: int in range(upper.size() - 1, -1, -1):
		outline.append(_flip_y(upper[i]))
	for p: Vector2 in upper:
		outline.append(_mirror_x(_flip_y(p)))
	for i: int in range(upper.size() - 1, -1, -1):
		outline.append(_mirror_x(upper[i]))
	return outline


# ⚠ 上の球の砂：くびれから高さ `level`（0〜1）ぶん。⚠ 右の曲線の y が境より下の点だけを使う。
func _sand_upper(level: float) -> PackedVector2Array:
	var y_limit: float = 0.5 - (0.5 - GLASS_TOP) * level
	var right: PackedVector2Array = PackedVector2Array()
	var upper: PackedVector2Array = _upper_right()
	for i: int in upper.size():
		var p: Vector2 = upper[i]
		if p.y >= y_limit:
			if right.is_empty() and i > 0:
				var q: Vector2 = upper[i - 1]
				var t: float = (y_limit - q.y) / maxf(p.y - q.y, 0.0001)
				right.append(q.lerp(p, t))
			right.append(p)
	var poly: PackedVector2Array = PackedVector2Array(right)
	for i: int in range(right.size() - 1, -1, -1):
		poly.append(_mirror_x(right[i]))
	return poly


# ⚠ 下の球の砂：底から高さ `level`（0〜1）ぶん。⚠ 上の球の上端側を切り出して上下に返す。
func _sand_lower(level: float) -> PackedVector2Array:
	var y_limit: float = GLASS_TOP + (0.5 - GLASS_TOP) * level
	var right: PackedVector2Array = PackedVector2Array()
	var upper: PackedVector2Array = _upper_right()
	for i: int in upper.size():
		var p: Vector2 = upper[i]
		if p.y <= y_limit:
			right.append(p)
		else:
			var q: Vector2 = upper[i - 1]
			var t: float = (y_limit - q.y) / maxf(p.y - q.y, 0.0001)
			right.append(q.lerp(p, t))
			break
	var poly: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in right:
		poly.append(_flip_y(p))
	for i: int in range(right.size() - 1, -1, -1):
		poly.append(_flip_y(_mirror_x(right[i])))
	return poly


func _draw() -> void:
	var frame: Color = get_theme_color(&"frame", THEME_TYPE)
	var glass: Color = get_theme_color(&"glass", THEME_TYPE)
	var sand: Color = get_theme_color(&"sand", THEME_TYPE)
	var line: float = float(get_theme_constant(&"line", THEME_TYPE))
	var cap: float = float(get_theme_constant(&"cap", THEME_TYPE))
	var top_level: float = float(get_theme_constant(StringName("sand_top_%d" % _index), THEME_TYPE)) / 100.0
	var bottom_level: float = float(get_theme_constant(StringName("sand_bottom_%d" % _index), THEME_TYPE)) / 100.0

	var outline: PackedVector2Array = _scaled(_glass_outline())
	draw_colored_polygon(outline, glass)
	if top_level > 0.0:
		draw_colored_polygon(_scaled(_sand_upper(top_level)), sand)
		# ⚠ 落ちている砂の細い筋（⚠ くびれ → 下の砂の上面）。
		var fall_to: float = 1.0 - (GLASS_TOP + (0.5 - GLASS_TOP) * bottom_level)
		draw_line(Vector2(0.5, 0.5) * size, Vector2(0.5, fall_to) * size, sand, 1.5)
	if bottom_level > 0.0:
		draw_colored_polygon(_scaled(_sand_lower(bottom_level)), sand)
	var closed: PackedVector2Array = PackedVector2Array(outline)
	closed.append(outline[0])
	draw_polyline(closed, frame, line, true)
	# ⚠ 上下の横木（⚠ ガラスより少し広い）。
	for y: float in [GLASS_TOP, GLASS_BOTTOM]:
		var left: Vector2 = Vector2(0.08, y) * size
		var right: Vector2 = Vector2(0.92, y) * size
		draw_line(left, right, frame, cap)
