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
