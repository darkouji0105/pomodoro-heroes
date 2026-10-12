class_name DepthFloor
extends Node2D

# 少し上から見下ろす床（2026-10-12・人間「⚠ 近接キャラが重なったら見えなくなっちゃうのをなんとかしたい」→
#   「⚠ 上から見下ろすタイプにする　ペーパーマリオとか、トリッカルみたいに少し上からみおろす」→「⚠ あ：見た目だけ」「⚠ 重なった時だけわかれる　⚠ ハウジングとかにもりゅうようできるよね」）。
#
# ⚠ 持つのは3つだけ：⚠ 斜めの床を描く ／ ⚠「横の位置・奥行き」を「画面の位置・大きさ・描く順」に変える ／ ⚠ 重なったものの奥行きを決める。
# ⚠ 戦闘のことを知らない（⚠ ハウジングの部屋の床にもそのまま使う）。⚠ 計算（当たるか・距離）は横の位置だけのまま＝⚠ ここは見た目だけ。
# ⚠ 奥行き depth は -1（奥）〜 0（真ん中）〜 1（手前）。⚠ 手前ほど下・大きく・上に描く。
# ⚠ 値（寸法・色）は持たない。⚠ 使う側が Theme から引いて `setup()` に渡す（⚠ Node2D は Theme を引けない）。

# 床の真ん中の高さ（⚠ 奥行き 0 の足元）。
var center_y: float = 0.0
# 奥行き 1 ぶんの上下のずれ（px）。
var depth_px: float = 60.0
# 奥・手前の大きさ（⚠ 真ん中は 1.0）。
var back_scale: float = 0.9
var front_scale: float = 1.08
# 奥の横の縮み（⚠ 真ん中は 1.0・手前は 2 - 奥）。⚠ 横の真ん中は center_x。
var back_width: float = 0.94
var center_x: float = 640.0
# 床を描く横の範囲。
var floor_left: float = 0.0
var floor_right: float = 1280.0
var floor_color: Color = Color(1, 1, 1, 0.04)
var line_color: Color = Color(1, 1, 1, 0.06)


func setup(p_center_x: float, p_center_y: float, p_depth_px: float, p_back_scale: float, p_front_scale: float,
		p_back_width: float, p_left: float, p_right: float, p_floor: Color, p_line: Color) -> void:
	center_x = p_center_x
	center_y = p_center_y
	depth_px = p_depth_px
	back_scale = p_back_scale
	front_scale = p_front_scale
	back_width = p_back_width
	floor_left = p_left
	floor_right = p_right
	floor_color = p_floor
	line_color = p_line
	queue_redraw()


# 横の位置と奥行き → 画面の位置（⚠ この Node2D と同じ座標）。
func screen_pos(x: float, depth: float) -> Vector2:
	return Vector2(center_x + (x - center_x) * _width_at(depth), center_y + depth * depth_px)


func scale_at(depth: float) -> float:
	if depth < 0.0:
		return lerpf(1.0, back_scale, -depth)
	return lerpf(1.0, front_scale, depth)


# 描く順（⚠ 手前ほど大きい）。⚠ 同じ親の中で比べる。
func z_at(depth: float) -> int:
	return int(round(depth * 100.0))


func _width_at(depth: float) -> float:
	return lerpf(1.0, back_width, -depth) if depth < 0.0 else lerpf(1.0, 2.0 - back_width, depth)


# 重なったものの奥行き（⚠ 重なっていなければ 0＝真ん中）。
# items：[{"id", "x", "order"}]（⚠ order＝段を決める順＝いつも同じ順にする。⚠ 横の位置の順にすると、
#   ほぼ同じ位置の2つがフレームごとに入れ替わり、段も入れ替わって重なったまま止まる）。
# width：これより近いと重なりとみなす横の距離。⚠ 返すのは {id: 奥行き}。
# ⚠ order の順に1つずつ、すでに置いたものと重ならない段に置く（⚠ 段は LANES の順に試す）。⚠ 全部ふさがっていたら一番重なりの少ない段。
const LANES: Array = [0.0, -1.0, 1.0, -0.5, 0.5]


static func spread_depths(items: Array, width: float) -> Dictionary:
	var sorted: Array = items.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	var out: Dictionary = {}
	var placed: Array = []
	for item: Dictionary in sorted:
		var near: Array = []
		for other: Dictionary in placed:
			if absf(float(item["x"]) - float(other["x"])) < width:
				near.append(float(other["lane"]))
		var lane: float = 0.0
		var best_count: int = 999
		for raw_lane: Variant in LANES:
			var count: int = near.count(float(raw_lane))
			if count < best_count:
				lane = float(raw_lane)
				best_count = count
		out[item["id"]] = lane
		placed.append({"x": item["x"], "lane": lane})
	return out


# 今の奥行きを目標へなめらかに近づける（⚠ rate＝1秒あたりの寄り方）。
static func approach(current: float, target: float, delta: float, rate: float) -> float:
	return lerpf(current, target, clampf(delta * rate, 0.0, 1.0))


# 床：⚠ 奥が狭い台形 ＋ ⚠ 奥・真ん中・手前の薄い線。
func _draw() -> void:
	var back_y: float = center_y - depth_px * 1.6
	var front_y: float = center_y + depth_px * 1.6
	var back_l: float = center_x + (floor_left - center_x) * back_width
	var back_r: float = center_x + (floor_right - center_x) * back_width
	draw_colored_polygon(PackedVector2Array([
		Vector2(back_l, back_y), Vector2(back_r, back_y), Vector2(floor_right, front_y), Vector2(floor_left, front_y),
	]), floor_color)
	for d: float in [-1.0, 0.0, 1.0]:
		var y: float = center_y + d * depth_px
		var w: float = _width_at(d)
		draw_line(Vector2(center_x + (floor_left - center_x) * w, y), Vector2(center_x + (floor_right - center_x) * w, y), line_color, 1.0)
