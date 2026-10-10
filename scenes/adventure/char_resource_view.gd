class_name CharResourceView
extends Control

# キャラ固有の資源（2026-10-10・回CH-1・`EXEC_CHAR_RESOURCE.md` §4）。
#
# ⚠⚠ 出す場所は2つ（人間「⚠ う」）：⚠ 下部パネルの自分の枠（HP の帯の下）／ 戦場のキャラの下（敵の SP の棒と同じ段）。
# ⚠⚠ 形は種類で変える（人間「⚠ ２あ」）：ゲージ＝棒 ／ ストック＝丸を max 個 ／ 状態＝札に文字。
# ⚠ 「◯回ごと」の回数は出さない（人間「⚠ ３い」）。
# ⚠ 値を持たない。⚠ 外から `set_values()` を毎フレーム受け取るだけ（`SpBar` と同じ形）。
# ⚠ 色と大きさは Theme の `BattleUnitView` 型（⚠ ここに書かない）。
# ⚠ 高さは中身で決まる（⚠ 行の数と種類）。⚠ 資源が無ければ隠す（⚠ 高さも取らない）。

const THEME_TYPE: StringName = &"BattleUnitView"

var _defs: Array = []
var _values: Dictionary = {}


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 定義（`BattleUnit.resource_defs`）といまの値（`BattleUnit.resources`）。⚠ 毎フレーム呼んでよい。
func set_values(defs: Array, values: Dictionary) -> void:
	if defs.size() == _defs.size() and values == _values:
		return
	_defs = defs
	_values = values.duplicate()
	visible = not _defs.is_empty()
	var height: float = content_height()
	custom_minimum_size.y = height
	size.y = height
	queue_redraw()


# 中身の高さ。⚠ 行の間は `res_row_gap`。
func content_height() -> float:
	var total: float = 0.0
	for i: int in range(_defs.size()):
		if i > 0:
			total += get_theme_constant(&"res_row_gap", THEME_TYPE)
		total += _row_height(_defs[i] as Dictionary)
	return total


func _row_height(def: Dictionary) -> float:
	match str(def.get("kind", "")):
		BattleUnit.RESOURCE_KIND_GAUGE:
			return get_theme_constant(&"res_gauge_height", THEME_TYPE)
		BattleUnit.RESOURCE_KIND_STOCK:
			return get_theme_constant(&"res_pip_size", THEME_TYPE)
		BattleUnit.RESOURCE_KIND_STATE:
			return get_theme_constant(&"res_label_height", THEME_TYPE)
	return 0.0


func _draw() -> void:
	var y: float = 0.0
	for i: int in range(_defs.size()):
		if i > 0:
			y += get_theme_constant(&"res_row_gap", THEME_TYPE)
		var def: Dictionary = _defs[i] as Dictionary
		var height: float = _row_height(def)
		var value: int = int(_values.get(str(def.get("id", "")), 0))
		var max_value: int = maxi(1, int(def.get("max", 1)))
		match str(def.get("kind", "")):
			BattleUnit.RESOURCE_KIND_GAUGE:
				_draw_gauge(y, height, value, max_value)
			BattleUnit.RESOURCE_KIND_STOCK:
				_draw_pips(y, height, value, max_value)
			BattleUnit.RESOURCE_KIND_STATE:
				_draw_label(y, height, def, value)
		y += height


func _draw_gauge(y: float, height: float, value: int, max_value: int) -> void:
	draw_rect(Rect2(0.0, y, size.x, height), get_theme_color(&"groove", THEME_TYPE))
	if value <= 0:
		return
	var fill: Color = get_theme_color(&"res_full" if value >= max_value else &"res_fill", THEME_TYPE)
	draw_rect(Rect2(0.0, y, size.x * float(value) / float(max_value), height), fill)


# ⚠ 丸の大きさは幅に収まるまで縮める（⚠ max が多いキャラでも1行に収める）。
func _draw_pips(y: float, height: float, value: int, max_value: int) -> void:
	var gap: float = get_theme_constant(&"res_pip_gap", THEME_TYPE)
	var pip: float = minf(height, (size.x - gap * float(max_value - 1)) / float(max_value))
	pip = maxf(1.0, pip)
	var total_width: float = pip * float(max_value) + gap * float(max_value - 1)
	var x: float = (size.x - total_width) * 0.5
	var full: bool = value >= max_value
	for i: int in range(max_value):
		var color: Color
		if i < value:
			color = get_theme_color(&"res_full" if full else &"res_fill", THEME_TYPE)
		else:
			color = get_theme_color(&"groove", THEME_TYPE)
		draw_circle(Vector2(x + pip * 0.5, y + height * 0.5), pip * 0.5, color)
		x += pip + gap


func _draw_label(y: float, height: float, def: Dictionary, value: int) -> void:
	draw_rect(Rect2(0.0, y, size.x, height), get_theme_color(&"groove", THEME_TYPE))
	var labels: Variant = def.get("labels", [])
	if not (labels is Array) or value < 0 or value >= (labels as Array).size():
		return
	var text: String = tr(str((labels as Array)[value]))
	var font: Font = get_theme_font(&"font", &"Label")
	var font_size: int = get_theme_constant(&"res_label_size", THEME_TYPE)
	var ascent: float = font.get_ascent(font_size)
	var text_height: float = font.get_height(font_size)
	var baseline: float = y + (height - text_height) * 0.5 + ascent
	draw_string(
		font, Vector2(0.0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size,
		get_theme_color(&"res_label", THEME_TYPE)
	)
