class_name PulseFrame
extends Control

# 脈打つ枠（2026-09-28・出撃の準備・人間「⚠ わからない　⚠ dragできるようにするか、入れ替えるためのガイドを派手にしないとわからない
#   ⚠ 枠を囲むとか派手な色で」）。
#
# ⚠ 親の矩形の**外側**に、⚠ 派手な色の太い線を重ねて引き、⚠ 太さと明るさを周期で揺らす（⚠ 光って見える）。
# ⚠ 強さは2段：`STRONG`（ガイド・入れ替え元の枠・出撃していない名簿の札）／ `SOFT`（⚠ 09-28 からは使っていない）。
# ⚠ 押下は拾わない（⚠ 下の枠や名簿がそのまま押せる）。⚠ 値は Theme の `Sortie` 型（`pulse_*`）。
# ⚠ 出撃の準備でしか使わないので scenes/adventure/（AGENTS.md）。

const THEME_TYPE: StringName = &"Sortie"

enum Strength { SOFT, STRONG }

var strength: Strength = Strength.STRONG
# ⚠ 内側に引く（⚠ スクロールの中の札など＝外へ広げると切れる所）。
var inward: bool = false
# ⚠ 描く矩形（⚠ 親の座標）。⚠ 空なら自分の大きさいっぱい。
var target_rect: Rect2 = Rect2()
var _time: float = 0.0


# 親いっぱいに重ねる（⚠ 親が `Container` のときは中身の矩形に置かれる＝外側へ広げて描くので、⚠ 見た目は親の縁の外）。
static func attach(parent: Control, p_strength: Strength) -> PulseFrame:
	var frame: PulseFrame = PulseFrame.new()
	frame.name = "PulseFrame"
	frame.strength = p_strength
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(frame)
	return frame


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var period: float = maxf(0.05, float(get_theme_constant(&"pulse_period_ms", THEME_TYPE)) / 1000.0)
	# ⚠ 0〜1 を行き来する（⚠ 正弦）。
	var wave: float = 0.5 + 0.5 * sin(_time * TAU / period)
	var strong: bool = strength == Strength.STRONG
	var color: Color = get_theme_color(&"pulse_strong" if strong else &"pulse_soft", THEME_TYPE)
	var width: float = float(get_theme_constant(&"pulse_width" if strong else &"pulse_soft_width", THEME_TYPE))
	var grow: float = float(get_theme_constant(&"pulse_grow", THEME_TYPE))
	# ⚠ 既定は親の縁（⚠ 親が `PanelContainer` だと自分は中身の矩形に置かれる＝親の大きさから取り直す）。
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if target_rect.size != Vector2.ZERO:
		rect = target_rect
	elif get_parent() is Control:
		rect = Rect2(-position, (get_parent() as Control).size)
	# ⚠ 内側に濃い線 ＋ 外へ広がる薄い光（⚠ 3重）。
	for i: int in range(3):
		var ring: Color = color
		ring.a = color.a * (1.0 - float(i) * 0.33) * (0.55 + 0.45 * wave)
		var spread: float = grow + float(i) * width * (0.8 + 0.6 * wave)
		if inward:
			# ⚠ 内側は浅く重ねる（⚠ 深く引くと札の上の字を覆った）。
			spread = -(width * 0.5 + float(i) * width * 0.4 * wave)
		draw_rect(rect.grow(spread), ring, false, width)
