class_name SortieSignature
extends Control

# 出撃の署名（2026-09-28・手本 Sign・人間「⚠ 出撃時サインを各演出が欲しい」→「⚠ 2い」＝詰所（出撃の準備）の枠の中で書く）。
#
# ⚠ 枠の下の1行：⚠ 罫線の上に、⚠ その人の名前を1字ずつ書き、⚠ 最後に印を線で引く（⚠ `progress` 0→1）。
# ⚠ 書き方はキャラごと（⚠ 人間「⚠ 3あ」＝`characters.json` の `sign_style`（brush / pen / soft）と `sign_mark`（cross / arrow / halo））。
#   ⚠ 手本は書体も変える（Yuji Boku / Klee One / Zen Kurenaido）が、⚠ 手書きの書体は入っていない＝⚠ 今の書体で
#   ⚠ 大きさ・太さ（縁取り）・傾き・色で差を付ける（⚠ 値は Theme の `Sortie` 型の `sign_<書き方>_*`）。
# ⚠ 押下は拾わない。⚠ 出撃の準備でしか使わないので scenes/adventure/（AGENTS.md）。

const THEME_TYPE: StringName = &"Sortie"
const STYLE_BRUSH: String = "brush"
const STYLE_PEN: String = "pen"
const STYLE_SOFT: String = "soft"
const MARK_CROSS: String = "cross"
const MARK_ARROW: String = "arrow"
const MARK_HALO: String = "halo"
# ⚠ 名前に使う割合（⚠ 残りで印を引く）。
const TEXT_SHARE: float = 0.75

var character_id: String = ""
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


static func create(p_character_id: String) -> SortieSignature:
	var signature: SortieSignature = SortieSignature.new()
	signature.character_id = p_character_id
	signature.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return signature


func _ready() -> void:
	custom_minimum_size.y = float(get_theme_constant(&"sign_height", THEME_TYPE))


func style() -> String:
	var value: String = str(MasterDataLoader.get_character(character_id).get("sign_style", STYLE_PEN))
	return value if value in [STYLE_BRUSH, STYLE_PEN, STYLE_SOFT] else STYLE_PEN


func mark() -> String:
	return str(MasterDataLoader.get_character(character_id).get("sign_mark", ""))


func _draw() -> void:
	# ⚠ 罫線（⚠ 書く前から引いておく＝ここに書く、の合図）。
	var rule: Color = get_theme_color(&"sign_rule", THEME_TYPE)
	draw_line(Vector2(0.0, size.y - 1.0), Vector2(size.x, size.y - 1.0), rule, 1.0)
	if progress <= 0.0:
		return
	var kind: String = style()
	var font: Font = get_theme_font(&"font", &"SheetHeadingLabel") if kind == STYLE_BRUSH else get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_constant(StringName("sign_%s_size" % kind), THEME_TYPE)
	var outline: int = get_theme_constant(StringName("sign_%s_outline" % kind), THEME_TYPE)
	var tilt: float = deg_to_rad(float(get_theme_constant(StringName("sign_%s_tilt_ddeg" % kind), THEME_TYPE)) / 10.0)
	var ink: Color = get_theme_color(StringName("sign_%s" % kind), THEME_TYPE)
	# ⚠ 左下を軸に傾ける（⚠ 手本 `transform-origin: left bottom`）。
	var origin: Vector2 = Vector2(float(get_theme_constant(&"sign_indent", THEME_TYPE)), size.y - float(get_theme_constant(&"sign_lift", THEME_TYPE)))
	draw_set_transform(origin, tilt)
	var text: String = tr(str(MasterDataLoader.get_character(character_id).get("name_key", character_id)))
	var text_progress: float = clampf(progress / TEXT_SHARE, 0.0, 1.0)
	var written: float = text_progress * float(text.length())
	var x: float = 0.0
	for i: int in range(text.length()):
		var char_code: int = text.unicode_at(i)
		var advance: float = font.get_char_size(char_code, font_size).x
		if float(i) < written:
			var color: Color = ink
			# ⚠ 書いている途中の字は薄い（⚠ 筆が走っている感じ）。
			color.a = ink.a * clampf(written - float(i), 0.0, 1.0)
			if outline > 0:
				draw_char_outline(font, Vector2(x, 0.0), text.substr(i, 1), font_size, outline, color)
			draw_char(font, Vector2(x, 0.0), text.substr(i, 1), font_size, color)
		x += advance
	var mark_progress: float = clampf((progress - TEXT_SHARE) / (1.0 - TEXT_SHARE), 0.0, 1.0)
	if mark_progress > 0.0:
		var h: float = float(font_size) * 0.8
		var gap: float = float(get_theme_constant(&"sign_mark_gap", THEME_TYPE))
		var width: float = maxf(1.5, float(outline) + 1.5)
		for stroke: PackedVector2Array in _mark_strokes(mark(), h):
			_draw_partial(stroke, Vector2(x + gap, 0.0), mark_progress, ink, width)
	draw_set_transform(Vector2.ZERO, 0.0)


# 印の線（⚠ 左下が (0, 0)・上へ負）。⚠ 手本の SVG を粗く写した。
func _mark_strokes(kind: String, h: float) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	match kind:
		MARK_CROSS:
			# ⚠ 交差した二本線（⚠ 剣士）。
			strokes.append(PackedVector2Array([Vector2(0.0, 0.0), Vector2(h, -h)]))
			strokes.append(PackedVector2Array([Vector2(0.15 * h, -0.85 * h), Vector2(0.55 * h, -0.45 * h), Vector2(h * 0.95, -0.05 * h)]))
		MARK_ARROW:
			# ⚠ 矢（⚠ 弓兵）：軸・鏃・矢羽根。
			var y: float = -0.4 * h
			strokes.append(PackedVector2Array([Vector2(0.0, y), Vector2(1.4 * h, y)]))
			strokes.append(PackedVector2Array([Vector2(1.15 * h, y - 0.25 * h), Vector2(1.4 * h, y), Vector2(1.15 * h, y + 0.25 * h)]))
			strokes.append(PackedVector2Array([Vector2(0.0, y), Vector2(0.2 * h, y - 0.25 * h)]))
			strokes.append(PackedVector2Array([Vector2(0.0, y), Vector2(0.2 * h, y + 0.25 * h)]))
		MARK_HALO:
			# ⚠ 光の輪と小さな十字（⚠ 僧侶）。
			var ring: PackedVector2Array = PackedVector2Array()
			for i: int in range(17):
				var angle: float = TAU * float(i) / 16.0
				ring.append(Vector2(0.5 * h + cos(angle) * 0.45 * h, -h + sin(angle) * 0.15 * h))
			strokes.append(ring)
			strokes.append(PackedVector2Array([Vector2(0.5 * h, -0.75 * h), Vector2(0.5 * h, 0.0)]))
			strokes.append(PackedVector2Array([Vector2(0.28 * h, -0.45 * h), Vector2(0.72 * h, -0.45 * h)]))
	return strokes


# 線を途中まで引く（⚠ 印は筆が走るように伸びる）。
func _draw_partial(points: PackedVector2Array, offset: Vector2, amount: float, color: Color, width: float) -> void:
	var total: float = 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var left: float = total * amount
	var drawn: PackedVector2Array = PackedVector2Array([points[0] + offset])
	for i: int in range(1, points.size()):
		var length: float = points[i - 1].distance_to(points[i])
		if left >= length:
			drawn.append(points[i] + offset)
			left -= length
			continue
		if length > 0.0:
			drawn.append(points[i - 1].lerp(points[i], left / length) + offset)
		break
	if drawn.size() >= 2:
		draw_polyline(drawn, color, width, true)
