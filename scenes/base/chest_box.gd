class_name ChestBox
extends Control

# 届いた宝箱の画面の、⚠ 台の上の箱（2026-09-27・回UI-組 宝箱・手本 Chest）。
#
# ⚠ 絵（画像）を使わず線と面で描く（⚠ 砂時計 `Hourglass` と同じ流儀）。⚠ 革の面に真鍮の線・前に2本の帯。
# ⚠ 閉じた姿 ＝ 蓋が箱の上に乗る四角 ／ ⚠ 開いた姿 ＝ 蓋が上に開いた台形（⚠ 手本の絵）。
# ⚠⚠ 高レアの演出（2026-09-27 の見る回・人間「⚠ 宝箱は高レアの場合は演出を入れるほうがいい」→「⚠ 4あ」）：
#   ⚠ 閉じた箱がレア度の色の光輪に包まれて震え、⚠ 光の筋が回ってから蓋が開き、⚠ 光が引く。⚠ 強い演出は筋が倍・長く・強く震える。
#   ⚠ 画面は `play_fx()` の Tween を待ってから札を並べる。⚠ `stop_fx()` で途中で止められる（⚠ 台を押すと飛ばす）。
# ⚠ 値は Theme の `ChestScreen` 型（⚠ 色・大きさ・線の太さ・演出の時間と強さ）。
# ⚠ 宝箱の画面でしか使わないので scenes/base/（AGENTS.md）。

const THEME_TYPE: StringName = &"ChestScreen"

@export var opened: bool = false:
	set(value):
		opened = value
		queue_redraw()

# ⚠ 演出の強さ（0〜1）・色・筋の数・回り・震え。⚠ `play_fx()` の Tween が動かす。
var fx_amount: float = 0.0
var _fx_color: Color = Color(0, 0, 0, 0)
var _fx_rays: int = 0
var _fx_phase: float = 0.0
var _fx_shake_px: float = 0.0
var _shake: Vector2 = Vector2.ZERO
var _fx_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(
		float(get_theme_constant(&"box_width", THEME_TYPE)),
		float(get_theme_constant(&"box_height", THEME_TYPE))
	)


# 高レアの演出を流す（⚠ 閉じた箱から始めて、⚠ 最後に蓋が開く）。⚠ 戻りの Tween の finished を待てばよい。
func play_fx(color: Color, strong: bool) -> Tween:
	stop_fx()
	opened = false
	_fx_color = color
	var prefix: String = "fx_strong_" if strong else "fx_"
	_fx_rays = get_theme_constant(StringName(prefix + "rays"), THEME_TYPE)
	_fx_shake_px = float(get_theme_constant(StringName(prefix + "shake"), THEME_TYPE))
	var build: float = float(get_theme_constant(StringName(prefix + "ms"), THEME_TYPE)) / 1000.0
	var fade: float = float(get_theme_constant(&"fx_fade_ms", THEME_TYPE)) / 1000.0
	_fx_tween = create_tween()
	_fx_tween.tween_method(_fx_step, 0.0, 1.0, build)
	_fx_tween.tween_callback(_fx_open)
	_fx_tween.tween_property(self, "fx_amount", 0.0, fade)
	_fx_tween.parallel().tween_method(_fx_redraw, 0.0, 1.0, fade)
	return _fx_tween


# 途中で止める（⚠ 蓋は開けて、光は消す）。
func stop_fx() -> void:
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
		_fx_tween.finished.emit()
	_fx_tween = null
	fx_amount = 0.0
	_shake = Vector2.ZERO
	queue_redraw()


func is_playing_fx() -> bool:
	return _fx_tween != null and _fx_tween.is_valid() and _fx_tween.is_running()


# ⚠ t は 0〜1。⚠ 光は育ち、筋は回り、震えは強まっていく（⚠ 開く直前がいちばん強い）。
func _fx_step(t: float) -> void:
	fx_amount = t
	_fx_phase = t * TAU * 0.5
	var strength: float = _fx_shake_px * t
	_shake = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	queue_redraw()


func _fx_open() -> void:
	_shake = Vector2.ZERO
	opened = true


func _fx_redraw(_t: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fx_amount > 0.0:
		_draw_fx()
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	_draw_box()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# 光輪と光の筋（⚠ 箱の後ろ）。⚠ 箱の枠の外まで描く（⚠ Control は描画を切らない）。
func _draw_fx() -> void:
	var center: Vector2 = size * 0.5
	var halo: float = float(get_theme_constant(&"fx_halo", THEME_TYPE))
	var ray_len: float = float(get_theme_constant(&"fx_ray_len", THEME_TYPE))
	var ray_width: float = float(get_theme_constant(&"fx_ray_width", THEME_TYPE))
	var glow: Color = _fx_color
	glow.a = float(get_theme_constant(&"fx_halo_alpha_pct", THEME_TYPE)) / 100.0 * fx_amount
	draw_circle(center, halo * fx_amount, glow)
	var ray_color: Color = _fx_color
	ray_color.a = fx_amount
	for i: int in range(_fx_rays):
		var angle: float = TAU * float(i) / float(maxi(1, _fx_rays)) + _fx_phase
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var inner: float = halo * 0.6
		draw_line(center + dir * inner, center + dir * (inner + ray_len * fx_amount), ray_color, ray_width)


func _draw_box() -> void:
	var line: Color = get_theme_color(&"box_line", THEME_TYPE)
	var fill: Color = get_theme_color(&"box_fill", THEME_TYPE)
	var width: float = float(get_theme_constant(&"box_line", THEME_TYPE))
	var lid: float = float(get_theme_constant(&"box_lid", THEME_TYPE))
	var band: float = float(get_theme_constant(&"box_band", THEME_TYPE))
	var w: float = size.x
	var h: float = size.y
	var half: float = width * 0.5
	# ⚠ 演出の最中は線をレア度の色に寄せる（⚠ 光っている箱）。
	if fx_amount > 0.0:
		line = line.lerp(_fx_color, fx_amount)
	# 箱の胴（⚠ 蓋の下から底まで）。
	var body: Rect2 = Rect2(Vector2(half, lid), Vector2(w - width, h - lid - half))
	draw_rect(body, fill)
	draw_rect(body, line, false, width)
	# 前の2本の帯。
	for x: float in [band, w - band]:
		draw_line(Vector2(x, lid), Vector2(x, h - half), line, width)
	if opened:
		# ⚠ 開いた蓋＝胴の上の縁から外へ開く台形（⚠ 手本の絵）。
		var inset: float = band * 0.8
		var lid_shape: PackedVector2Array = PackedVector2Array([
			Vector2(half, lid), Vector2(inset, half), Vector2(w - inset, half), Vector2(w - half, lid),
		])
		draw_colored_polygon(lid_shape, get_theme_color(&"box_inside", THEME_TYPE))
		lid_shape.append(Vector2(half, lid))
		draw_polyline(lid_shape, line, width)
	else:
		# ⚠ 閉じた蓋＝胴の上に乗る四角。
		var cover: Rect2 = Rect2(Vector2(half, half), Vector2(w - width, lid - half))
		draw_rect(cover, fill)
		draw_rect(cover, line, false, width)
		# 錠前。
		var lock: Vector2 = Vector2(w * 0.5, lid)
		draw_rect(Rect2(lock - Vector2(band * 0.3, band * 0.3), Vector2(band * 0.6, band * 0.6)), line)
