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
var shadow_color: Color = Color(0, 0, 0, 0.35)
# 足元の影（⚠ 床に立っている感じを出す）。⚠ [Vector3(足元の x, 足元の y, 横の半径)]。⚠ 使う側が毎フレーム渡す。
var _shadows: Array = []


# 影を差し替える。⚠ 縦の半径は横の 0.3 倍（⚠ 斜めから見た円）。
func set_shadows(shadows: Array) -> void:
	_shadows = shadows
	queue_redraw()


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
# items：[{"id", "x", "order", "side"}]
#   ⚠ order＝段を決める順（⚠ 小さいほど先に置く＝動かない側。⚠ 戦闘では「先に殴り始めた方」）。⚠ 同じ値のときの順も使う側がいつも同じにする（⚠ 入れ替わるとちらつく）。
#   ⚠ side＝ずれるときに先に試す向き（-1 奥 ／ 1 手前）。⚠ 使う側がランダムに1回決めて、重なっている間は変えない。
#   ⚠ group＝同じ group どうしだけを重なりとして数える（⚠ 戦闘では味方・敵＝殴り合う相手とは段を取り合わない）。⚠ 書かなければ全部同じ。
# width：これより近いと重なりとみなす横の距離。⚠ 返すのは {id: 奥行き}。
# ⚠ order の順に1つずつ、すでに置いたものと重ならない段に置く（⚠ 真ん中 → side → 反対 → その間）。⚠ 全部ふさがっていたら一番重なりの少ない段。
static func spread_depths(items: Array, width: float) -> Dictionary:
	var sorted: Array = items.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["order"]) < float(q["order"]))
	var out: Dictionary = {}
	var placed: Array = []
	for item: Dictionary in sorted:
		# ⚠ 段を固定したもの（"lane"）はその段のまま・ほかの邪魔にならない（2026-10-12・バイク＝真ん中の線だけを走る）。
		if item.has("lane"):
			out[item["id"]] = float(item["lane"])
			continue
		var near: Array = []
		for other: Dictionary in placed:
			if str(other["group"]) == str(item.get("group", "")) and absf(float(item["x"]) - float(other["x"])) < width:
				near.append(float(other["lane"]))
		var side: float = -1.0 if float(item.get("side", -1.0)) < 0.0 else 1.0
		var lane: float = 0.0
		var best_count: int = 999
		for raw_lane: Variant in [0.0, side, -side, side * 0.5, -side * 0.5]:
			var count: int = near.count(float(raw_lane))
			if count < best_count:
				lane = float(raw_lane)
				best_count = count
		out[item["id"]] = lane
		placed.append({"x": item["x"], "lane": lane, "group": str(item.get("group", ""))})
	return out


# 奥行きを目標へ歩いて近づける（2026-10-12・人間「⚠ ずれ方があまりにも一瞬で自然な感じがしない　キャラの目的地をずらす形で歩き方とかは変えずに」）。
# ⚠ speed_px＝そのものの歩く速さ（1秒あたりの px）。⚠ 奥行き 1 は depth_px ぶん＝同じ速さで床の上を歩く。
func walk_depth(current: float, target: float, delta: float, speed_px: float) -> float:
	if depth_px <= 0.0:
		return target
	return move_toward(current, target, delta * maxf(speed_px, 1.0) / depth_px)


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
	for raw: Variant in _shadows:
		var sh: Vector3 = raw as Vector3
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(24):
			var a: float = TAU * float(i) / 24.0
			points.append(Vector2(sh.x + cos(a) * sh.z, sh.y + sin(a) * sh.z * 0.3))
		draw_colored_polygon(points, shadow_color)
