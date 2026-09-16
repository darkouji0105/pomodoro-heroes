class_name SkillTile
extends Button

# 戦闘のスキルのマス（2026-09-16・人間のモック「戦闘まわり UI 決定」§7・§8・§10）。
#
# ⚠⚠ 3種を1つの部品で描く。⚠ **動きの向きで区別する**（⚠ 色は補助でしかない）。
#   ⚠ 通常CD（instant）… ⚠ 暗い幕が上へ引いて、⚠ **下から明るくなる**。明けた瞬間だけ枠が光る
#   ⚠ チャージ（charge）… ⚠ 待機中は右下に目印。⚠ 溜めている間は枠 2px（青 → 窓の中は琥珀）
#   ⚠ recast … ⚠ 待機中から枠 2px の青緑。⚠ 構えの間は層が**上から減る**。右上に残りの段数
# ⚠ チャージの進み具合は**ここに出さない**（モック §9-1「中央のバーのみ」）。
#   ⚠ 中央のバーができるまでは、⚠ パネルの細いゲージ（`BattleController`）が受け持つ。
# ⚠ `toggle` は作っていない（⚠ 実データ0件・実行時に動かない）。
#
# ⚠ `Button` を継ぐ。⚠ `pressed` / `button_down` / `button_up` と `disabled` を
#   ⚠ 今までの配線のまま使うため（⚠ チャージは離した瞬間に撃つ）。
# ⚠ 絵は全部 `_draw()`。⚠ 値は Theme の `SkillTile` 型から引く（⚠ ここに色も寸法も書かない）。
# ⚠ 状態は持たない。⚠ 毎フレーム `set_state()` で外から受け取る
#   （⚠ `UnitView` と同じ形。⚠ `BattleUnit` を握らない）。
# ⚠ 使うのは戦闘だけなので `scenes/adventure/`（AGENTS.md）。

enum Kind { COOLDOWN, CHARGE, RECAST }

const THEME_TYPE: StringName = &"SkillTile"
# ⚠ 絵が無いスキル（⚠ 検証用）の代わりに出す字数。
const FALLBACK_CHARS: int = 1
# ⚠ クールダウンの段の境は Theme の `cd_edge_0`〜`cd_edge_2`（⚠ 百分率・大きい順）。
const STAGE_EDGE_COUNT: int = 3

var kind: Kind = Kind.COOLDOWN

var _icon: Texture2D = null
var _fallback_text: String = ""
var _style: StyleBoxFlat = StyleBoxFlat.new()

var _off: bool = false
var _cd_left: float = 0.0
var _cd_total: float = 0.0
var _charging: bool = false
var _in_just: bool = false
var _recast_left: float = 0.0
var _recast_window: float = 0.0
var _phases_left: int = 0

# ⚠ 一瞬だけの演出の残り秒。⚠ 0 なら出していない。
var _flash_left: float = 0.0
var _pulse_left: float = 0.0


func setup(tile_kind: Kind, skill_id: String, name_text: String, size_px: int) -> void:
	kind = tile_kind
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	# ⚠ 名前はマスに書かない（⚠ 38px に入らない）。⚠ ホバーで出す。
	tooltip_text = name_text
	custom_minimum_size = Vector2(size_px, size_px)
	_icon = IconTextures.for_skill(skill_id)
	_fallback_text = name_text.left(FALLBACK_CHARS)
	set_process(false)


# 毎フレーム呼んでよい。⚠ 変わった瞬間（明けた・段が進んだ）はここで拾う。
#
# ⚠ `phases_left` は「あと何回押せるか」。⚠ 構えていなければ 0。
func set_state(
	off: bool, cd_left: float, cd_total: float,
	charging: bool, in_just: bool,
	recast_left: float, recast_window: float, phases_left: int,
) -> void:
	# ⚠ 明けた瞬間（モック §8「復帰の演出」）。⚠ ずっと光らせない。
	if not off and _cd_left > 0.0 and cd_left <= 0.0:
		_flash_left = _ms(&"flash_ms")
	# ⚠ 段が進んだ瞬間（モック §10「発動の瞬間」）。⚠ 構えの始まり（0 → n）も含む。
	if kind == Kind.RECAST and phases_left != _phases_left and (
		phases_left < _phases_left or _phases_left == 0
	) and phases_left > 0:
		_pulse_left = _ms(&"pulse_ms")

	_off = off
	_cd_left = maxf(cd_left, 0.0)
	_cd_total = maxf(cd_total, 0.0)
	_charging = charging
	_in_just = in_just
	_recast_left = maxf(recast_left, 0.0)
	_recast_window = maxf(recast_window, 0.0)
	_phases_left = phases_left
	if _flash_left > 0.0 or _pulse_left > 0.0:
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	if _flash_left <= 0.0 and _pulse_left <= 0.0:
		set_process(false)
	queue_redraw()


func _ms(key: StringName) -> float:
	return float(get_theme_constant(key, THEME_TYPE)) / 1000.0


func _color(key: String) -> Color:
	return get_theme_color(StringName(key), THEME_TYPE)


# クールダウンの段（0〜4）。⚠ 4 は「残り warn_ms 未満」。
func _cd_stage() -> int:
	if _cd_left < _ms(&"warn_ms"):
		return 4
	var ratio: float = _cd_left / _cd_total if _cd_total > 0.0 else 0.0
	for i: int in range(STAGE_EDGE_COUNT):
		if ratio * 100.0 >= float(get_theme_constant(StringName("cd_edge_%d" % i), THEME_TYPE)):
			return i
	return 3


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, size)
	var width: int = get_theme_constant(&"border", THEME_TYPE)
	var strong: int = get_theme_constant(&"border_strong", THEME_TYPE)
	var recasting: bool = kind == Kind.RECAST and _recast_left > 0.0
	var cooling: bool = _cd_left > 0.0 and not recasting

	var bg: Color
	var border: Color
	var icon_color: Color
	if _off:
		bg = _color("off_bg")
		border = _color("off_border")
		icon_color = _color("off_icon")
	elif kind == Kind.RECAST and (recasting or not cooling):
		# ⚠ recast は待機中から青緑の枠（モック §10）。⚠ 構えが切れて CD に入ったら琥珀系に戻る。
		var pulse: bool = _pulse_left > 0.0
		bg = _color("recast_pulse_bg" if pulse else "recast_bg")
		border = _color("recast_pulse_border" if pulse else "recast_border")
		icon_color = _color("recast_pulse_icon" if pulse else "recast_icon")
		width = strong
	elif cooling:
		var stage: int = _cd_stage()
		bg = _color("cd%d_bg" % stage)
		border = _color("cd%d_border" % stage)
		icon_color = _color("cd%d_icon" % stage)
	else:
		bg = _color("ready_bg")
		border = _color("ready_border")
		icon_color = _color("ready_icon")

	if _charging and not _off:
		border = _color("charge_just" if _in_just else "charge_border")
		width = strong
	elif _flash_left > 0.0 and not _off:
		var t: float = _flash_left / maxf(_ms(&"flash_ms"), 0.001)
		border = border.lerp(_color("flash"), t)
		width = int(round(lerpf(float(width), float(strong), t)))

	_style.bg_color = bg
	_style.border_color = border
	_style.set_border_width_all(width)
	_style.set_corner_radius_all(get_theme_constant(&"corner_radius", THEME_TYPE))
	draw_style_box(_style, box)

	# ⚠ recast の層。⚠ 窓の残りで**上から減る**（⚠ 下に溜まっている量が減っていく）。
	if recasting and _recast_window > 0.0:
		var percent: int = get_theme_constant(
			&"recast_pulse_layer_percent" if _pulse_left > 0.0 else &"recast_layer_percent",
			THEME_TYPE
		)
		var layer_h: float = size.y * clampf(_recast_left / _recast_window, 0.0, 1.0)
		var layer: Color = _color("recast_border")
		layer.a = float(percent) / 100.0
		draw_rect(Rect2(0.0, size.y - layer_h, size.x, layer_h), layer)

	var icon_px: float = minf(size.x, size.y) * float(get_theme_constant(&"icon_percent", THEME_TYPE)) / 100.0
	var font: Font = get_theme_default_font()
	if _icon != null:
		var at: Vector2 = (size - Vector2(icon_px, icon_px)) * 0.5
		draw_texture_rect(_icon, Rect2(at, Vector2(icon_px, icon_px)), false, icon_color)
	elif font != null:
		_draw_centered(font, _fallback_text, get_theme_constant(&"number_size", THEME_TYPE), icon_color)

	# ⚠ クールダウンの幕。⚠ 残りの割合ぶん**上側**を覆う＝⚠ 下から明るくなる。
	if cooling and not _off and _cd_total > 0.0:
		var veil_h: float = size.y * clampf(_cd_left / _cd_total, 0.0, 1.0)
		var veil: Color = Color.BLACK
		veil.a = float(get_theme_constant(&"veil_percent", THEME_TYPE)) / 100.0
		draw_rect(Rect2(0.0, 0.0, size.x, veil_h), veil)
		if font != null:
			var stage: int = _cd_stage()
			var number_key: String = "cd_number"
			if stage == 4:
				number_key = "cd_number_warn"
			elif stage == 3:
				number_key = "cd_number_near"
			# ⚠ 切り上げ（モック §8）。⚠ 残り0.3秒で「0」と出して押せそうに見せない。
			_draw_centered(
				font, str(int(ceil(_cd_left))),
				get_theme_constant(&"number_size", THEME_TYPE), _color(number_key)
			)

	var small: int = get_theme_constant(&"corner_number_size", THEME_TYPE)
	var pad: float = float(get_theme_constant(&"corner_pad", THEME_TYPE))
	# ⚠ recast の残りの段数（右上）。⚠ 残り1回は琥珀（⚠ 通常CDの「残り2秒」と同じ扱い）。
	if recasting and _phases_left > 0 and font != null:
		var count_color: Color = _color("cd_number_warn" if _phases_left == 1 else "recast_icon")
		var label: String = str(_phases_left)
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		draw_string(
			font, Vector2(size.x - w - pad, font.get_ascent(small) + pad * 0.5),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, small, count_color
		)

	# ⚠ チャージ型の目印（右下）。⚠ 待機中から種別が分かるように常に出す。
	if kind == Kind.CHARGE and font != null:
		var mark_size: int = get_theme_constant(&"mark_size", THEME_TYPE)
		var mark: String = Glyphs.SKILL_CHARGE_MARK
		var mw: float = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size).x
		draw_string(
			font, Vector2(size.x - mw - pad * 0.5, size.y - pad),
			mark, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size, Color.WHITE
		)


func _draw_centered(font: Font, label: String, font_size: int, color: Color) -> void:
	var baseline: float = (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(
		font, Vector2(0.0, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, color
	)
