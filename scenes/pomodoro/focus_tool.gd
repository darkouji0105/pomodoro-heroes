class_name FocusTool
extends Control

# 集中の道具（2026-09-29・回UI-仕組み⑤・手本 Focus / FocusSkins / PomoSkin）。
#
# ⚠ 人間「⚠ 1あ　⚠ 2あ　⚠ 3あ」：⚠ 砂時計・ろうそく・柱時計（⚠ 最初から全部持っている）／ ⚠ 集中中は輪の代わりに道具の絵 ／
#   ⚠ **時間の進みに合わせて変わる**（⚠ 砂が落ちる・ろうそくが短くなる・柱時計の針が回る）。
# ⚠ 絵（画像）は使わず線と面で描く（⚠ 砂時計 `Hourglass`・宝箱 `ChestBox` と同じ流儀）。⚠ 形の割合（0〜1 の升目）はここ、色は Theme の `FocusTool` 型。
# ⚠ `progress`＝0（始め）〜1（終わり）。⚠ 炎のゆらぎと振り子だけは時間で動く（`_process`）。
# ⚠ ポモドーロでしか使わないので scenes/pomodoro/（AGENTS.md）。

const THEME_TYPE: StringName = &"FocusTool"
const TOOL_HOURGLASS: String = "hourglass"
const TOOL_CANDLE: String = "candle"
const TOOL_CLOCK: String = "clock"
# ⚠ 目録の並び（⚠ 持っている3つ）。⚠ ID はリリース後に改名しない（⚠ 設定のファイルに残る）。
const OWNED_TOOLS: Array[String] = [TOOL_HOURGLASS, TOOL_CANDLE, TOOL_CLOCK]
const CURVE_STEPS: int = 16

var tool_id: String = TOOL_HOURGLASS:
	set(value):
		tool_id = value
		queue_redraw()
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
# ⚠ 炎と振り子を動かすか（⚠ 目録の小さな絵は止めておく）。
var animated: bool = true
var _time: float = 0.0


static func create(p_tool_id: String, side: float, p_animated: bool = true) -> FocusTool:
	var tool: FocusTool = FocusTool.new()
	tool.tool_id = p_tool_id
	tool.animated = p_animated
	tool.custom_minimum_size = Vector2(side, side)
	tool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return tool


func _process(delta: float) -> void:
	if not animated or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	match tool_id:
		TOOL_CANDLE:
			_draw_candle()
		TOOL_CLOCK:
			_draw_clock()
		_:
			_draw_hourglass()


func _color(key: StringName) -> Color:
	return get_theme_color(key, THEME_TYPE)


func _line_width() -> float:
	return maxf(1.5, size.x * float(get_theme_constant(&"line_pct", THEME_TYPE)) / 1000.0)


# 砂時計：⚠ 上の砂が減り、⚠ 下の砂が増える（⚠ 真ん中に細い流れ）。
func _draw_hourglass() -> void:
	var w: float = size.x
	var h: float = size.y
	var brass: Color = _color(&"brass")
	var glass: Color = _color(&"glass")
	var sand: Color = _color(&"sand")
	var line: float = _line_width()
	var top: float = h * 0.07
	var bottom: float = h * 0.93
	var cx: float = w * 0.5
	var edge: float = w * 0.30
	var neck: float = w * 0.03
	# ⚠ ガラスの外形（⚠ 片側を曲線で・左は写す）。
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(CURVE_STEPS + 1):
		var t: float = float(i) / float(CURVE_STEPS)
		var y: float = lerpf(top, bottom, t)
		# ⚠ 上下の端で広く・真ん中の首で細い（⚠ u＝首からの離れ具合 0〜1）。⚠ 球らしく丸めるため指数で曲げる。
		var u: float = absf(t - 0.5) * 2.0
		var bulge: float = pow(sin(u * PI * 0.5), 0.6)
		right.append(Vector2(cx + lerpf(neck, edge, bulge), y))
	var outline: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in right:
		outline.append(point)
	for i: int in range(right.size() - 1, -1, -1):
		outline.append(Vector2(2.0 * cx - right[i].x, right[i].y))
	draw_colored_polygon(outline, glass)
	# ⚠ 上の砂（⚠ 残りの量＝1−progress・首の側に寄る）。
	var mid: float = (top + bottom) * 0.5
	var remain: float = 1.0 - progress
	if remain > 0.01:
		var sand_top: float = lerpf(mid, top + h * 0.08, remain)
		draw_colored_polygon(_bulb_slice(right, cx, sand_top, mid), sand)
	# ⚠ 下の砂（⚠ 山の形で積もる）。
	if progress > 0.01:
		var pile_h: float = (bottom - mid) * 0.8 * progress
		var pile: PackedVector2Array = PackedVector2Array([
			Vector2(cx - edge * 0.95, bottom), Vector2(cx + edge * 0.95, bottom),
			Vector2(cx + edge * 0.5, bottom - pile_h * 0.6), Vector2(cx, bottom - pile_h), Vector2(cx - edge * 0.5, bottom - pile_h * 0.6),
		])
		draw_colored_polygon(pile, sand)
	# ⚠ 流れ（⚠ 落ちている間だけ）。
	if remain > 0.01 and progress > 0.0:
		draw_line(Vector2(cx, mid), Vector2(cx, bottom - (bottom - mid) * 0.8 * progress), sand, maxf(1.0, line * 0.5))
	draw_polyline(outline + PackedVector2Array([outline[0]]), brass, line, true)
	# ⚠ 上下の真鍮の横木。
	draw_line(Vector2(cx - edge * 1.15, top), Vector2(cx + edge * 1.15, top), brass, line * 2.0)
	draw_line(Vector2(cx - edge * 1.15, bottom), Vector2(cx + edge * 1.15, bottom), brass, line * 2.0)


# 上の球の、⚠ `from_y`〜`to_y` の間の形（⚠ 曲線の内側）。
func _bulb_slice(right: PackedVector2Array, cx: float, from_y: float, to_y: float) -> PackedVector2Array:
	var slice: PackedVector2Array = PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in right:
		if point.y >= from_y and point.y <= to_y:
			var inset: float = maxf(0.0, point.x - cx - 2.0)
			slice.append(Vector2(cx + inset, point.y))
			left.append(Vector2(cx - inset, point.y))
	if slice.size() < 2:
		return PackedVector2Array([Vector2(cx - 1, from_y), Vector2(cx + 1, from_y), Vector2(cx, to_y)])
	left.reverse()
	return slice + left


# ろうそく：⚠ 蝋が短くなる（⚠ 残り＝1−progress）・⚠ 炎がゆらぐ。
func _draw_candle() -> void:
	var w: float = size.x
	var h: float = size.y
	var line: float = _line_width()
	var cx: float = w * 0.5
	var base_y: float = h * 0.93
	var body_w: float = w * 0.22
	var full_h: float = h * 0.55
	var body_h: float = lerpf(full_h * 0.12, full_h, 1.0 - progress)
	var body_top: float = base_y - h * 0.06 - body_h
	# ⚠ 受け皿。
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.3, base_y - h * 0.06), Vector2(cx + w * 0.3, base_y - h * 0.06),
		Vector2(cx + w * 0.22, base_y), Vector2(cx - w * 0.22, base_y),
	]), _color(&"brass"))
	# ⚠ 蝋。
	var body: Rect2 = Rect2(Vector2(cx - body_w * 0.5, body_top), Vector2(body_w, body_h))
	draw_rect(body, _color(&"wax"))
	draw_rect(body, _color(&"wax_edge"), false, maxf(1.0, line * 0.5))
	# ⚠ 芯と炎（⚠ ゆらぎ＝時間 ／ 燃え尽きたら消える）。
	if progress < 1.0:
		var wick_top: float = body_top - h * 0.03
		draw_line(Vector2(cx, body_top), Vector2(cx, wick_top), _color(&"wick"), maxf(1.0, line * 0.5))
		var sway: float = sin(_time * 7.0) * w * 0.012
		var flame_h: float = h * (0.16 + 0.015 * sin(_time * 11.0))
		var radius: float = w * 0.07
		var center: Vector2 = Vector2(cx, wick_top - radius)
		draw_colored_polygon(_flame(center, radius, Vector2(cx + sway, wick_top - flame_h)), _color(&"flame"))
		draw_colored_polygon(_flame(center + Vector2(0.0, radius * 0.35), radius * 0.5,
			Vector2(cx + sway * 0.6, wick_top - flame_h * 0.55)), _color(&"flame_core"))


# 涙の形（⚠ 下半分の円 ＋ 先端）。
func _flame(center: Vector2, radius: float, tip: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(CURVE_STEPS + 1):
		var a: float = PI * float(i) / float(CURVE_STEPS)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	points.append(tip)
	return points


# 柱時計：⚠ 文字盤の針が progress で1周 ／ ⚠ 振り子が揺れる。
func _draw_clock() -> void:
	var w: float = size.x
	var h: float = size.y
	var line: float = _line_width()
	var cx: float = w * 0.5
	var case_rect: Rect2 = Rect2(Vector2(cx - w * 0.26, h * 0.05), Vector2(w * 0.52, h * 0.9))
	draw_rect(case_rect, _color(&"case"))
	draw_rect(case_rect, _color(&"brass"), false, line)
	var face_c: Vector2 = Vector2(cx, h * 0.3)
	var face_r: float = w * 0.19
	draw_circle(face_c, face_r, _color(&"face"))
	draw_arc(face_c, face_r, 0.0, TAU, 48, _color(&"brass"), maxf(1.0, line * 0.5), true)
	# ⚠ 過ぎた時間を扇で薄く塗る（⚠ 12時から時計回り）。
	if progress > 0.0:
		var fan: PackedVector2Array = PackedVector2Array([face_c])
		var steps: int = maxi(2, int(48.0 * progress))
		for i: int in range(steps + 1):
			var a: float = -PI * 0.5 + TAU * progress * float(i) / float(steps)
			fan.append(face_c + Vector2(cos(a), sin(a)) * face_r * 0.92)
		draw_colored_polygon(fan, _color(&"face_passed"))
	var hand_a: float = -PI * 0.5 + TAU * progress
	draw_line(face_c, face_c + Vector2(cos(hand_a), sin(hand_a)) * face_r * 0.8, _color(&"hand"), line)
	draw_circle(face_c, line * 1.2, _color(&"hand"))
	# ⚠ 振り子（⚠ 時間で揺れる）。
	var pivot: Vector2 = Vector2(cx, face_c.y + face_r + h * 0.03)
	var swing: float = sin(_time * TAU / 2.0) * 0.28 if animated else 0.0
	var bob: Vector2 = pivot + Vector2(sin(swing), cos(swing)) * h * 0.38
	draw_line(pivot, bob, _color(&"brass"), maxf(1.0, line * 0.6))
	draw_circle(bob, w * 0.06, _color(&"brass"))
