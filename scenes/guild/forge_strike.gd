class_name ForgeStrike
extends Control

# 鍛える演出（2026-09-28・見る回・人間「⚠ 鍛冶場で鍛えるとき、演出を入れたい　⚠ 別の画面でやる」）。
#
# ⚠ 画面いっぱいに被せる「鍛冶の場」：⚠ 金床の上の品を槌で打つ（`strike_count` 回・火花・揺れ）→
#   ⚠ 最後の一打で成功は金に弾け、⚠ 失敗は火花が消えて暗く沈む → ⚠ `finished`（⚠ 呼ぶ側が結果の画面を出す）。
# ⚠ 押すと飛ばす。⚠ 判定と状態の変更は済んでから呼ぶ（⚠ ここは見せるだけ）。⚠ 絵は無い＝線と面で描く。
# ⚠ 右上の資源の表示は隠す（⚠ 別の画面に見せる）・⚠ 終われば戻す。⚠ 値は Theme の `Forge` 型（`strike_*`）。

signal finished

const THEME_TYPE: StringName = &"Forge"
const HAMMER_RAISED: float = 1.0    # ⚠ 振り上げた角度（ラジアン・⚠ 正＝時計回り＝柄の先が上がる）
const SPARK_SPREAD: float = 2.4     # ⚠ 火花の広がり（⚠ 上向きの扇・ラジアン）

var success: bool = true
var _hammer: float = 0.0            # ⚠ 0＝振り上げ ／ 1＝打った
var _spark: float = 1.0             # ⚠ 0＝打った瞬間 ／ 1＝消えた
var _flash: float = 0.0
var _dim: float = 0.0
var _shake: Vector2 = Vector2.ZERO
var _final: bool = false
var _angles: PackedFloat32Array = PackedFloat32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _icon_holder: Control = null
var _tween: Tween = null
var _done: bool = false


static func play(host: Control, item_id: String, grade: int, p_success: bool) -> ForgeStrike:
	var strike: ForgeStrike = ForgeStrike.new()
	strike.name = "ForgeStrike"
	strike.success = p_success
	strike.mouse_filter = Control.MOUSE_FILTER_STOP
	strike.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(strike)
	strike._start(item_id, grade)
	return strike


func _start(item_id: String, grade: int) -> void:
	ResourceHud.set_shown(false)
	_rng.seed = 7
	# ⚠ 品の絵（⚠ 器は素の Control＝大きさの演出が効く）。
	_icon_holder = Control.new()
	_icon_holder.name = "IconHolder"
	_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_holder)
	var icon: ItemIcon = ItemIcon.create(item_id, grade)
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_holder.add_child(icon)
	_icon_holder.scale = Vector2.ONE * float(get_theme_constant(&"strike_icon_scale_pct", THEME_TYPE)) / 100.0
	var caption: Label = Label.new()
	caption.name = "Caption"
	caption.theme_type_variation = &"HeaderTitleLabel"
	caption.text = tr("ui_forge_striking")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	caption.offset_top = float(get_theme_constant(&"strike_caption_y", THEME_TYPE))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	var hint: Label = Label.new()
	hint.name = "SkipHint"
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr("ui_forge_strike_skip")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -float(get_theme_constant(&"strike_caption_y", THEME_TYPE)) - 24.0
	hint.offset_bottom = -float(get_theme_constant(&"strike_caption_y", THEME_TYPE))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	resized.connect(_place_icon)
	gui_input.connect(_on_gui_input)
	_place_icon()
	_build_tween()


func _build_tween() -> void:
	var strike: float = float(get_theme_constant(&"strike_ms", THEME_TYPE)) / 1000.0
	var count: int = maxi(1, get_theme_constant(&"strike_count", THEME_TYPE))
	_tween = create_tween()
	_tween.tween_interval(strike * 0.4)
	for i: int in range(count):
		_tween.tween_method(_set_hammer, 0.0, 1.0, strike * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(_on_hit.bind(i == count - 1))
		_tween.tween_method(_set_spark, 0.0, 1.0, strike * 0.7)
		_tween.parallel().tween_method(_set_hammer, 1.0, 0.0, strike * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var final: float = float(get_theme_constant(&"strike_final_ms", THEME_TYPE)) / 1000.0
	if success:
		_tween.tween_method(_set_flash, 1.0, 0.0, final)
	else:
		_tween.tween_method(_set_dim, 0.0, 1.0, final)
	_tween.tween_callback(_finish)


func _set_hammer(value: float) -> void:
	_hammer = value
	queue_redraw()


func _set_spark(value: float) -> void:
	_spark = value
	_shake = Vector2.ZERO if value > 0.3 else Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * float(get_theme_constant(&"strike_shake_px", THEME_TYPE)) * (1.0 - value / 0.3)
	_place_icon()
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_dim(value: float) -> void:
	_dim = value
	if _icon_holder != null:
		_icon_holder.modulate = Color.WHITE.lerp(get_theme_color(&"fx_dim", THEME_TYPE), value)
	queue_redraw()


# 打った瞬間：火花の向きを振り直す。⚠ 最後の一打は成否で火花の数と色が変わる。
func _on_hit(last: bool) -> void:
	_final = last
	_angles.clear()
	var count: int = get_theme_constant(&"strike_sparks", THEME_TYPE)
	if last:
		count = count * 2 if success else maxi(3, count / 3)
	for i: int in range(count):
		_angles.append(-PI * 0.5 + _rng.randf_range(-SPARK_SPREAD, SPARK_SPREAD) * 0.5)
	if last and success:
		_flash = 1.0


func _center() -> Vector2:
	return size * 0.5 + Vector2(0.0, float(get_theme_constant(&"strike_anvil_y", THEME_TYPE))) + _shake


func _hit_point() -> Vector2:
	return _center() + Vector2(0.0, -float(get_theme_constant(&"strike_icon_lift", THEME_TYPE)))


func _place_icon() -> void:
	if _icon_holder == null or _icon_holder.get_child_count() == 0:
		return
	var icon: Control = _icon_holder.get_child(0) as Control
	var shown: Vector2 = icon.get_combined_minimum_size() * _icon_holder.scale
	_icon_holder.position = _hit_point() - Vector2(shown.x * 0.5, shown.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"strike_bg", THEME_TYPE))
	var line: Color = get_theme_color(&"strike_line", THEME_TYPE)
	var metal: Color = get_theme_color(&"strike_metal", THEME_TYPE)
	var c: Vector2 = _center()
	# ⚠ 品の絵の高さ（⚠ 槌が当たる所＝品の上）。
	var shown_h: float = 0.0
	if _icon_holder != null and _icon_holder.get_child_count() > 0:
		shown_h = (_icon_holder.get_child(0) as Control).get_combined_minimum_size().y * _icon_holder.scale.y
	var strike_point: Vector2 = Vector2(c.x, _hit_point().y - shown_h)
	# 金床（⚠ 天板・角・胴・台）。
	var top: Rect2 = Rect2(c + Vector2(-110.0, 0.0), Vector2(220.0, 26.0))
	var horn: PackedVector2Array = PackedVector2Array([c + Vector2(110.0, 0.0), c + Vector2(175.0, 6.0), c + Vector2(110.0, 22.0)])
	var waist: Rect2 = Rect2(c + Vector2(-45.0, 26.0), Vector2(90.0, 40.0))
	var foot: Rect2 = Rect2(c + Vector2(-90.0, 66.0), Vector2(180.0, 22.0))
	for rect: Rect2 in [top, waist, foot]:
		draw_rect(rect, metal)
		draw_rect(rect, line, false, 2.0)
	draw_colored_polygon(horn, metal)
	draw_polyline(PackedVector2Array([horn[0], horn[1], horn[2]]), line, 2.0)
	# 火花（⚠ 打った点から上へ扇に飛ぶ・伸びながら消える）。
	if _spark < 1.0 and not _angles.is_empty():
		var spark_color: Color = get_theme_color(&"strike_spark" if (success or not _final) else &"strike_spark_fail", THEME_TYPE)
		var length: float = float(get_theme_constant(&"strike_spark_len", THEME_TYPE)) * (2.0 if _final and success else 1.0)
		var origin: Vector2 = strike_point
		for angle: float in _angles:
			var direction: Vector2 = Vector2.from_angle(angle)
			var head: Vector2 = origin + direction * length * _spark
			var tail: Vector2 = origin + direction * length * maxf(0.0, _spark - 0.35)
			var color: Color = spark_color
			color.a *= 1.0 - _spark
			draw_line(tail, head, color, 2.0)
	# 槌（⚠ 柄の端を軸に振り下ろす・⚠ 頭が品の上に当たる高さ）。⚠ 頭の下の縁が品の上に来る。
	var pivot: Vector2 = strike_point + Vector2(190.0, -26.0)
	var angle: float = lerpf(HAMMER_RAISED, 0.0, _hammer)
	draw_set_transform(pivot, angle)
	draw_line(Vector2.ZERO, Vector2(-170.0, 0.0), line, 6.0)
	var head_rect: Rect2 = Rect2(Vector2(-200.0, -26.0), Vector2(44.0, 52.0))
	draw_rect(head_rect, metal)
	draw_rect(head_rect, line, false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0)
	# 最後の一打：⚠ 成功＝金の光 ／ 失敗＝暗く沈む。
	if _flash > 0.0:
		var flash: Color = get_theme_color(&"fx_flash", THEME_TYPE)
		flash.a *= _flash
		draw_rect(Rect2(Vector2.ZERO, size), flash)
	if _dim > 0.0:
		var dim: Color = get_theme_color(&"fx_flash_fail", THEME_TYPE)
		dim.a *= _dim
		draw_rect(Rect2(Vector2.ZERO, size), dim)


# ⚠ `gui_input` のシグナルで受ける（⚠ 宝箱の台と同じ形＝検査がシグナルで押せる）。
func _on_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		skip()


# 飛ばす（⚠ すぐ終わる）。
func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	ResourceHud.set_shown(true)
	finished.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func is_playing() -> bool:
	return not _done
