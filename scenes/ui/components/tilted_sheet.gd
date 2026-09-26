class_name TiltedSheet
extends Control

# 傾けた紙（2026-09-27・わかれ道の2枚のカード。⚠ `RelicCard` と同じ置き方）。
#
# ⚠ `Container` は子の回転を並べるたびに 0 に戻すので、⚠ この部品は**並べない器**（素の `Control`）で、
#   ⚠ 中の紙（`sheet`）を自分で広げて回す。⚠ 器の最小の大きさは紙の最小に合わせる（⚠ 並べる側が幅を決める）。
# ⚠ 傾きは Theme の `PaperPanel` の `tilt_<n>`（⚠ 並びの番号で順に使う）。
# ⚠ 中身は `sheet` に足す。⚠ `TiltedSheet.create(index)` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const TILT_COUNT: int = 3

var sheet: PaperSheet = null
var _tilt_index: int = 0


static func create(index: int) -> TiltedSheet:
	var holder: TiltedSheet = TiltedSheet.new()
	holder._tilt_index = index % TILT_COUNT
	holder.sheet = PaperSheet.new()
	holder.sheet.name = "Sheet"
	holder.add_child(holder.sheet)
	holder.sheet.minimum_size_changed.connect(holder._fit)
	holder.resized.connect(holder._fit)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	return holder


func _ready() -> void:
	_fit()


func _fit() -> void:
	if sheet == null:
		return
	custom_minimum_size = sheet.get_combined_minimum_size()
	sheet.position = Vector2.ZERO
	sheet.size = size
	sheet.pivot_offset = size * 0.5
	if is_inside_tree():
		var tenths: int = get_theme_constant(StringName("tilt_%d" % _tilt_index), &"PaperPanel")
		sheet.rotation = deg_to_rad(float(tenths) * 0.1)
