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
# 床そのもの（台形と線）を描くか（⚠ 直線の戦場では描かない＝影と範囲だけ）。
var show_floor: bool = true
# 範囲を楕円で描く高さ（⚠ 床を描かないとき＝直線の戦場の縦の半径 px）。
var flat_zone_half_height: float = 18.0
# 地面の範囲（2026-10-12）。⚠ [{"x", "radius", "color"}]。⚠ 横は本当の半径・縦は奥〜手前の段を覆う。
var _zones: Array = []
# 一瞬光る扇形（2026-10-16・ショットガン）。⚠ [{"x", "dir", "radius", "color", "left", "life"}]。⚠ 時間で薄れて消える。
var _fans: Array = []
# 足元の影（⚠ 床に立っている感じを出す）。⚠ [Vector3(足元の x, 足元の y, 横の半径)]。⚠ 使う側が毎フレーム渡す。
var _shadows: Array = []


# 範囲を差し替える。⚠ 毎フレーム呼んでよい。
func set_zones(zones: Array) -> void:
	if zones.is_empty() and _zones.is_empty():
		return
	_zones = zones
	queue_redraw()


# 扇形を一瞬光らせる（2026-10-16・人間「⚠ 範囲ダメージ用の表示もいると思う」）。⚠ 見た目だけ（⚠ 当たり判定は横の位置と半径）。
#   ⚠ dir は前の向き（1 か -1）。⚠ life 秒で薄れて消える。
#   ⚠ depth は撃った人の今の奥行き（⚠ 重なりを避けて奥・手前へ寄っていても足元から開く）。
func flash_fan(x: float, dir: float, radius: float, color: Color, life: float, depth: float = 0.0) -> void:
	_fans.append({"x": x, "dir": signf(dir) if dir != 0.0 else 1.0, "radius": radius, "color": color, "left": life, "life": maxf(life, 0.01), "depth": depth})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _fans.is_empty():
		set_process(false)
		return
	var keep: Array = []
	for raw: Variant in _fans:
		var f: Dictionary = raw as Dictionary
		f["left"] = float(f["left"]) - delta
		if float(f["left"]) > 0.0:
			keep.append(f)
	_fans = keep
	queue_redraw()


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
	if show_floor:
		_draw_floor()
	_draw_zones()
	_draw_fans()
	_draw_shadows()


# 扇形：⚠ 使う人の足元から前へ開く（⚠ ±40°・縦は床に沿って平たく＝奥行きの段の 0.7 倍）。⚠ 残り時間で薄れる。
func _draw_fans() -> void:
	for raw: Variant in _fans:
		var f: Dictionary = raw as Dictionary
		var depth: float = float(f.get("depth", 0.0))
		var apex: Vector2 = screen_pos(float(f["x"]), depth)
		var rx: float = float(f["radius"]) * _width_at(depth)
		var ry: float = depth_px * 0.7 if show_floor else flat_zone_half_height
		var dir: float = float(f["dir"])
		var fade: float = clampf(float(f["left"]) / float(f["life"]), 0.0, 1.0)
		var points: PackedVector2Array = PackedVector2Array([apex])
		for i: int in range(17):
			var a: float = deg_to_rad(-40.0 + 80.0 * float(i) / 16.0)
			points.append(apex + Vector2(cos(a) * rx * dir, sin(a) * ry))
		var color: Color = f["color"] as Color
		var fill: Color = color
		fill.a = 0.35 * fade
		draw_colored_polygon(points, fill)
		var edge: Color = color
		edge.a = 0.8 * fade
		points.append(apex)
		draw_polyline(points, edge, 2.0)


# 範囲：⚠ 塗りは薄く・縁は濃く。⚠ 縦は奥（-1）〜手前（1）の段を覆う（⚠ 床を描かないときは低く）。
func _draw_zones() -> void:
	for raw: Variant in _zones:
		var z: Dictionary = raw as Dictionary
		var center: Vector2 = screen_pos(float(z["x"]), 0.0)
		var rx: float = float(z["radius"]) * _width_at(0.0)
		var ry: float = depth_px * 1.3 if show_floor else flat_zone_half_height
		var color: Color = z["color"] as Color
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(40):
			var a: float = TAU * float(i) / 40.0
			points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		var fill: Color = color
		fill.a = 0.16
		draw_colored_polygon(points, fill)
		var edge: Color = color
		edge.a = 0.55
		points.append(points[0])
		draw_polyline(points, edge, 2.0)


func _draw_floor() -> void:
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


func _draw_shadows() -> void:
	for raw: Variant in _shadows:
		var sh: Vector3 = raw as Vector3
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in range(24):
			var a: float = TAU * float(i) / 24.0
			points.append(Vector2(sh.x + cos(a) * sh.z, sh.y + sin(a) * sh.z * 0.3))
		draw_colored_polygon(points, shadow_color)
