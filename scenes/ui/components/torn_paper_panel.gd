class_name TornPaperPanel
extends PanelContainer

# 縁がちぎれた羊皮紙（2026-09-26・人間の参考画像「難ダンジョンの地図（地図らしく・いまの形）」）。
#
# ⚠ 地図の後ろに横いっぱいに敷く紙。⚠ 縁は**ぎざぎざの多角形**で描く（⚠ 画像は使わない＝素材待ちにしない）。
#   ⚠ ぎざぎざは毎回同じ形（⚠ 決まった種から作る＝開くたびに縁が変わらない）。
# ⚠ 中の字は墨（⚠ 紙のテーマを持つ＝`UI-14`）。⚠ 色は `PaperPanel` の地、⚠ 裂け目の細かさは Theme の `TornPaper` 型。
# ⚠ 使う画面：難ダンジョンとシナリオの地図（⚠ 2画面以上＝components）。

const THEME_TYPE: StringName = &"TornPaper"
# ⚠ ぎざぎざの種（⚠ 数字は形を決めるだけ。⚠ バランスの値ではない）。
const TEAR_SEED: int = 7

## ⚠ 右下に方位を描くか。
var show_compass: bool = true:
	set(value):
		show_compass = value
		queue_redraw()


func _init() -> void:
	theme = PaperSheet.PAPER_THEME
	theme_type_variation = &"TornPaperPanel"


func _draw() -> void:
	var paper: StyleBoxFlat = get_theme_stylebox(&"panel", &"PaperPanel") as StyleBoxFlat
	var fill: Color = paper.bg_color if paper != null else Color.WHITE
	var step: float = float(get_theme_constant(&"tear_step", THEME_TYPE))
	var depth: float = float(get_theme_constant(&"tear_depth", THEME_TYPE))
	var outline: PackedVector2Array = _outline(step, depth)
	var shadow: PackedVector2Array = PackedVector2Array()
	var offset: Vector2 = Vector2(0.0, float(get_theme_constant(&"shadow_offset", THEME_TYPE)))
	for p: Vector2 in outline:
		shadow.append(p + offset)
	draw_colored_polygon(shadow, get_theme_color(&"shadow", THEME_TYPE))
	draw_colored_polygon(outline, fill)
	# ⚠ 焼け（⚠ 縁の内側を少し暗く）。⚠ 手本「焼けは内側の影」。
	draw_polyline(outline + PackedVector2Array([outline[0]]), get_theme_color(&"burn", THEME_TYPE), depth, true)
	if show_compass:
		_draw_compass()


# ⚠⚠ 方位（2026-09-26・人間「⚠ 山とかそういうのも今は書いといて」）。⚠ 紙の右下。⚠ 画像は使わず線で描く。
#   ⚠ 円 ／ 4方向の細い菱形（⚠ 北だけ塗る）／ 「N」。⚠ 色と大きさは Theme の `TornPaper`（`compass` / `compass_radius`）。
func _draw_compass() -> void:
	var r: float = float(get_theme_constant(&"compass_radius", THEME_TYPE))
	var inset: float = float(get_theme_constant(&"compass_inset", THEME_TYPE))
	var c: Vector2 = size - Vector2(inset, inset)
	var ink: Color = get_theme_color(&"compass", THEME_TYPE)
	draw_arc(c, r, 0.0, TAU, 40, ink, 1.2, true)
	draw_arc(c, r * 0.82, 0.0, TAU, 40, Color(ink, ink.a * 0.6), 0.8, true)
	for k: int in range(4):
		var angle: float = float(k) * PI * 0.5 - PI * 0.5
		var tip: Vector2 = c + Vector2.from_angle(angle) * r * 1.15
		var side_a: Vector2 = c + Vector2.from_angle(angle + PI * 0.5) * r * 0.16
		var side_b: Vector2 = c + Vector2.from_angle(angle - PI * 0.5) * r * 0.16
		var shape: PackedVector2Array = PackedVector2Array([tip, side_a, c, side_b, tip])
		if k == 0:
			draw_colored_polygon(PackedVector2Array([tip, side_a, c, side_b]), ink)
		else:
			draw_polyline(shape, ink, 1.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_constant(&"compass_font", THEME_TYPE)
	var north: Vector2 = c + Vector2(0.0, -r * 1.15 - 4.0)
	draw_string(font, north - Vector2(font_size * 0.3, 0.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


# 四辺をぎざぎざにした輪郭（⚠ 時計回り）。⚠ 各辺を `step` ごとに区切り、⚠ 内側へ 0〜`depth` だけ凹ませる。
func _outline(step: float, depth: float) -> PackedVector2Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = TEAR_SEED
	var points: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]
	var inward: Array[Vector2] = [Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0)]
	for side: int in range(4):
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var count: int = maxi(1, int(a.distance_to(b) / maxf(step, 1.0)))
		for i: int in range(count):
			var t: float = float(i) / float(count)
			points.append(a.lerp(b, t) + inward[side] * rng.randf_range(0.0, depth))
	return points


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
