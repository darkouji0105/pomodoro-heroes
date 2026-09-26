class_name DungeonEdgeLines
extends Control

# ランのマップの通路を線で描く（段階19-e・人間の指示 → 2026-09-19 にモック v2「手描きの道」）。
#
# ⚠⚠ 人間の言葉：「⚠ 通路用のグラフィックを用意したほうがいい。⚠ 今ノードだけで、
#   通路が見えない状態」。⚠ 19-c-2 まではマスの前に絵文字を付けるだけで、
#   ⚠ 「どのマスからどのマスへ繋がっているか」が画面に1本も出ていなかった。
#
# ⚠ この部品は GameManager を1行も知らない。⚠ 線の一覧をもらって描くだけ。
#   ⚠ 知らせると、⚠ 「どの通路に効果があるか」の判定が2箇所になる。
# ⚠ 使うのは RunMapView（scenes/ui/components/）の中だけ（2026-09-19）。⚠ 画面は直接触らない。
#   ⚠ 置き場所と名前はそのまま残した（⚠ 移すと uid の手当てが要る。⚠ 宿題）。
# ⚠ マウスを取らない（mouse_filter = ignore）。⚠ 取るとマスのボタンが押せなくなる。

# 線1本ぶんのキー。⚠ 文字列リテラルを画面側と2箇所に書かないための定数。
const LINE_FROM: String = "from"
const LINE_TO: String = "to"
const LINE_COLOR: String = "color"
const LINE_WIDTH: String = "width"
# ⚠ 通路の真ん中に出す字（段階20-c・人間の指示「⚠ 通路にアイコンは、通路の真ん中に表示して」）。
#   ⚠ "" なら何も出さない。
const LINE_LABEL: String = "label"
# ⚠ 線の描き方（2026-09-19・モック v2）。⚠ 曲線＝ふつう ／ 折れ線＝罠 ／ 点線＝見えない。
const LINE_STYLE: String = "style"
const STYLE_CURVE: String = "curve"
const STYLE_ZIGZAG: String = "zigzag"
const STYLE_DASHED: String = "dashed"
# ⚠ 字の台（菱形）の枠の色。⚠ 無ければ既定の枠。
const LINE_BADGE_BORDER: String = "badge_border"
# ⚠⚠ 点線で描くか（2026-09-26・人間「⚠ 道は点線にしてほしい　⚠ すでに行った場所を赤いラインに」）。
#   ⚠ 形（曲線・折れ線）はそのまま、⚠ 線だけ点線にする。⚠ 通った道だけ実線（⚠ 渡す側が false にする）。
const LINE_DASHED: String = "dashed"

# ⚠⚠ 区画の切れ目（2026-09-19・モック v2）は 2026-09-20 に消した（人間の指示
#   「⚠ 区画の切れ目の表示は消して」）。⚠ 線・字・`SEAM_*` の綴り・`get_seam_count()` ごと。
#   ⚠ 区画そのものは残っている（⚠ 消したのは見た目だけ）。

# 通路の字の大きさと、字を置く箱の大きさ（段階20-c）。
#
# ⚠⚠ 箱を固定にして中央寄せする。⚠ そうしないと「線の中点」に置けない
#   （⚠ Label の実際の大きさはレイアウトが終わるまで分からない）。
const LABEL_FONT_SIZE: int = 11
const LABEL_BOX: Vector2 = Vector2(28.0, 24.0)

# ⚠ 手描きの揺れ（モック v2「揺れは ±6px」）。⚠ 曲線の制御点・折れ線の曲がりの横ずれ。
const WOBBLE: float = 6.0
# ⚠ 曲線を何本の直線で近似するか。⚠ 09-26：横に長い道がかくつくので 16 → 24。
const CURVE_SEGMENTS: int = 24
# ⚠ 曲線の取っ手（⚠ 両端から高さの何割か）と、⚠ 取っ手の横の揺れの幅（⚠ 人間の参考 HTML を測った値）。
const CURVE_HANDLE: float = 0.45
const CURVE_JITTER: float = 14.0
# ⚠ 点線の点の長さ（モック `stroke-dasharray: 2 6` をそのまま）。
const DASH: float = 4.0
# ⚠ 道の点線の1片と間（⚠ 人間の参考 HTML `stroke-dasharray="5 5"`）。
const ROAD_DASH: float = 5.0

# 字の台（菱形）。⚠ モック `.edge-badge`（20px の正方形を45度回したもの）。
const BADGE_HALF: float = 14.0

# 線の一覧。⚠ [{from, to, color, width, label, style, badge_border}]
var _lines: Array = []
# ⚠ 通路の字の数（⚠ 検証が読む）。
var _label_count: int = 0


# 線を差し替える。⚠ 呼ぶのは RunMapView の1箇所だけ。
#
# ⚠ ここで queue_redraw() する。⚠ 呼ぶ側で描き直しを覚えないこと。
# ⚠ 字は Label で置く（⚠ draw_string ではない）。⚠ カラー絵文字（COLR/CPAL）が
#   Label では出ることを実測済みで、⚠ draw_string では確かめていないため。
# ⚠ 再描画に await を持たせない。⚠ remove_child() してから queue_free()（AGENTS.md）。
func set_lines(lines: Array) -> void:
	_lines = lines
	_label_count = 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var text: String = str(line.get(LINE_LABEL, ""))
		if text == "":
			continue
		var label: Label = _make_label(text, LABEL_FONT_SIZE)
		label.size = LABEL_BOX
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# ⚠ 線の中点に置く。⚠ 箱のぶんだけ左上へずらして中央に合わせる。
		label.position = _mid(line) - LABEL_BOX * 0.5
		add_child(label)
		_label_count += 1
	queue_redraw()


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _mid(line: Dictionary) -> Vector2:
	return (line.get(LINE_FROM, Vector2.ZERO) + line.get(LINE_TO, Vector2.ZERO)) * 0.5


# 通路の真ん中に出ている字の数。⚠ 検証の道具（scenario=layout）が読む。
func get_label_count() -> int:
	return _label_count


# 一番横に長い線の、横に動いた距離（段階20-g）。⚠ 検証の道具が読む。
#
# ⚠⚠ 絵は取れないが「線がどれだけ斜めか」は取れる。⚠ 人間の指摘
#   「⚠ 左から右に行く道がやたら生成される」がそのまま数字で出る。
# ⚠ 列を揃えたので、⚠ 隣の列ぶん（マスの幅＋間隔）までに収まるのが正解。
func get_max_horizontal_span() -> float:
	var worst: float = 0.0
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var dx: float = absf(
			(line.get(LINE_TO, Vector2.ZERO) as Vector2).x
			- (line.get(LINE_FROM, Vector2.ZERO) as Vector2).x
		)
		worst = maxf(worst, dx)
	return worst


# いま引いている線の本数。⚠ 検証の道具（scenario=layout）が読む。
#
# ⚠⚠ 絵は取れないが「何本引いたか」は取れる。⚠ 0 本なら通路が1本も見えていない
#   （⚠ 人間が実機で報告した「通路が見えない状態」がそのまま数字で出る）。
func get_line_count() -> int:
	return _lines.size()


func _draw() -> void:
	for entry: Variant in _lines:
		if not (entry is Dictionary):
			continue
		var line: Dictionary = entry
		var a: Vector2 = line.get(LINE_FROM, Vector2.ZERO)
		var b: Vector2 = line.get(LINE_TO, Vector2.ZERO)
		var color: Color = line.get(LINE_COLOR, Color.WHITE)
		var width: float = float(line.get(LINE_WIDTH, 2.0))
		var style: String = str(line.get(LINE_STYLE, STYLE_CURVE))
		if style == STYLE_DASHED and not line.has(LINE_DASHED):
			draw_dashed_line(a, b, color, width, DASH)
			continue
		var points: PackedVector2Array = _zigzag(a, b) if style == STYLE_ZIGZAG else _curve(a, b)
		if bool(line.get(LINE_DASHED, false)):
			_draw_dashed_polyline(points, color, width, ROAD_DASH)
		else:
			draw_polyline(points, color, width, true)
	# ⚠ 字の台は線の上に描く（⚠ 字の Label はさらにその上＝子）。
	for entry: Variant in _lines:
		var line: Dictionary = entry
		if str(line.get(LINE_LABEL, "")) == "":
			continue
		var c: Vector2 = _mid(line)
		var diamond: PackedVector2Array = PackedVector2Array([
			c + Vector2(0, -BADGE_HALF), c + Vector2(BADGE_HALF, 0),
			c + Vector2(0, BADGE_HALF), c + Vector2(-BADGE_HALF, 0),
		])
		draw_colored_polygon(diamond, get_theme_color(&"badge_bg", &"RunMapView"))
		var outline: PackedVector2Array = diamond.duplicate()
		outline.append(diamond[0])
		draw_polyline(outline, line.get(LINE_BADGE_BORDER, get_theme_color(&"badge_plain", &"RunMapView")), 1.0, true)


# 折れ線に沿った点線（⚠ `draw_dashed_line` は直線しか引けないので、⚠ 長さを数えながら片を置く）。
func _draw_dashed_polyline(points: PackedVector2Array, color: Color, width: float, dash: float) -> void:
	var drawing: bool = true
	var left: float = dash
	for i: int in range(points.size() - 1):
		var p: Vector2 = points[i]
		var q: Vector2 = points[i + 1]
		var remaining: float = p.distance_to(q)
		var direction: Vector2 = (q - p).normalized()
		while remaining > 0.0:
			var step: float = minf(left, remaining)
			var next: Vector2 = p + direction * step
			if drawing:
				draw_line(p, next, color, width, true)
			p = next
			remaining -= step
			left -= step
			if left <= 0.0:
				drawing = not drawing
				left = dash


# 手描きの曲線。⚠⚠ 2026-09-26：人間の参考 HTML と同じ形（⚠ 人間「⚠ 線の曲がり方も参考と全く同じで」）。
#   ⚠ 参考の27本を測った：⚠ **取っ手は両端から高さの 45%**（⚠ 出るときも入るときも縦向き）、
#   ⚠ **取っ手の横の揺れは ±14px**（⚠ 線ごとにばらばら）。⚠ 前は 35% / 65% ・揺れは固定の 6px。
#   ⚠ 揺れは両端の位置から決める（⚠ 描き直しても同じ形＝ちらつかない）。
func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(a.round()) * 7 + Vector2i(b.round()) * 13)
	var dy: float = b.y - a.y
	var c1: Vector2 = Vector2(a.x + rng.randf_range(-CURVE_JITTER, CURVE_JITTER), a.y + dy * CURVE_HANDLE)
	var c2: Vector2 = Vector2(b.x + rng.randf_range(-CURVE_JITTER, CURVE_JITTER), b.y - dy * CURVE_HANDLE)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(CURVE_SEGMENTS + 1):
		var t: float = float(i) / float(CURVE_SEGMENTS)
		var u: float = 1.0 - t
		points.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return points


# 罠の折れ線（モック：22% / 50% / 78% で左右に振る）。
func _zigzag(a: Vector2, b: Vector2) -> PackedVector2Array:
	var d: Vector2 = b - a
	return PackedVector2Array([
		a,
		Vector2(a.x + d.x * 0.22 + WOBBLE, a.y + d.y * 0.26),
		Vector2(a.x + d.x * 0.5 - WOBBLE, a.y + d.y * 0.52),
		Vector2(a.x + d.x * 0.78 + WOBBLE * 0.6, a.y + d.y * 0.76),
		b,
	])
