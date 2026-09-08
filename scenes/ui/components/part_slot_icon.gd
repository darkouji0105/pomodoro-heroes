class_name PartSlotIcon
extends Panel

# 装飾の枠 1つぶんのマス（2026-09-08・人間のモック「⚠ 枠の種類」）。
#
# ⚠ 前は文字1行（`  [1] 宝石 （空き）`）だった。⚠ 7枠あると7行になり、
#   ⚠ 詳細が枠の説明で埋まっていた。⚠ モックは **1行に7個のマス**。
#
# ⚠⚠ 状態は2つ。⚠ **未開放の枠はそもそも作らない**（⚠ 2026-09-08・人間の指示
#   「⚠ 未開放は、そもそもスロットを表示しないように」）。⚠ 出すかを決めるのは `PartSlotRow`。
#   ⚠ 空き   … 種類の絵文字を薄く。⚠ **枠線＝そこに刺さる種類の色**
#   ⚠ 装填済 … 刺さっているものの絵文字を明るく。⚠ **枠線＝その等級の色**
#
# ⚠⚠ 枠線の色が言うことが、⚠ 空きと装填済で違う（⚠ 2026-09-08・人間の指示
#   「⚠ スロットの周りの枠で何を付けられるかわかるようにしたい」）。
#   ⚠ 刺さってしまえば「何が刺さるか」は要らないので、⚠ 1つの枠線を使い分ける。
#   ⚠ 対応表は `IconConfig.color_of_part_slot_kinds()` の1本。
# ⚠⚠ ワイルド枠（⚠ 頭・胴・脚だけが持つ）の空きは **虹色**（2026-09-08・人間の指示）。
#   ⚠ 1色では「どれでも受ける」を言えない。⚠ `StyleBoxFlat` の枠線は1色しか持てないので、
#   ⚠ そのときだけ `_draw()` で自前で描く。
# ⚠ 等級の色は `ItemIcon.grade_and_number()` に聞く。⚠ 段階→等級の表をここに写さない
#   （⚠ 写すとアイコンと枠で色が食い違う）。
# ⚠ 絵文字は `Glyphs.for_part_slot()` の1本。⚠ ここに種類ごとの分岐を書かない。
# ⚠ 大きさと色は `Balance.icon`（`IconConfig`）。⚠ ここに直書きしない。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

# 虹の枠を描くときの角の分割数。⚠ 見た目の滑らかさだけ。⚠ バランス数値ではないので
#   Config に置かない（⚠ 上げても色の並びは変わらない）。
const WILD_CORNER_STEPS: int = 4

var _view: Dictionary = {}
var _is_open: bool = false
# ワイルド枠の「空き」か。⚠ このときだけ枠を自前で描く（⚠ 虹は StyleBox で出せない）。
var _draw_rainbow: bool = false

var _glyph_label: Label = null


# 枠1つを作る。⚠ `view` は `GameManager.get_part_slot_defs()` /
#   `get_part_entries()` が返すもの（⚠ `PART_VIEW_ENTRY` は個体のときだけ入っている）。
# ⚠ `grade` は装備の等級。⚠ 開いているかの判定は `GameManager` の1本に聞く。
static func create(view: Dictionary, grade: int) -> PartSlotIcon:
	var icon: PartSlotIcon = PartSlotIcon.new()
	icon.setup(view, grade)
	return icon


# 枠の名前の翻訳キー。⚠ 刺さる種類が1つならその種類、⚠ 複数ならワイルド枠。
#
# ⚠⚠ ここが唯一の対応表。⚠ 種類ごとに if を分岐させないこと（⚠ 種類が増えても変わらない）。
# ⚠ 2026-09-07 に `equipment_screen.gd` から `ItemDetail` へ移し、
#   ⚠ 2026-09-08 にここへ移した（⚠ 枠を描く部品と同じ場所に置くため。
#   ⚠ `ItemDetail` に置いたままだと `ItemDetail` ⇄ `PartSlotIcon` の循環参照になる）。
static func part_slot_label_key(view: Dictionary) -> String:
	var kinds: Variant = view.get(GameManager.PART_VIEW_KINDS, [])
	if kinds is Array and (kinds as Array).size() == 1:
		return "ui_part_slot_kind_" + str((kinds as Array)[0])
	return "ui_part_slot_kind_wild"


func _init() -> void:
	_glyph_label = Label.new()
	_glyph_label.name = "GlyphLabel"
	_glyph_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# ⚠ ツールチップは親（この Panel）が出す。⚠ 子が入力を拾うと出なくなる。
	_glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glyph_label)
	# ⚠ 虹の枠は大きさから座標を作るので、⚠ 伸び縮みしたら描き直す。
	resized.connect(queue_redraw)


func setup(view: Dictionary, grade: int) -> void:
	_view = view.duplicate(true)
	_is_open = GameManager.is_part_slot_open(view, grade)
	_refresh()


# 刺さっているもの。⚠ 空き・未開放なら空の Dictionary。
func get_part_entry() -> Dictionary:
	var entry: Variant = _view.get(GameManager.PART_VIEW_ENTRY, null)
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}


func is_open() -> bool:
	return _is_open


func _refresh() -> void:
	var config: IconConfig = Balance.icon
	if config == null:
		push_error("[PartSlotIcon] Balance.icon が未割り当て。枠を描けない")
		return

	var size_px: float = float(config.part_slot_size_px)
	custom_minimum_size = Vector2(size_px, size_px)

	var part_entry: Dictionary = get_part_entry()
	var part_id: String = str(part_entry.get(GameStateKeys.PART_ITEM_ID, ""))

	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = config.icon_bg_color
	box.set_corner_radius_all(config.icon_corner_radius)
	if part_id != "":
		# ⚠ 装填済。⚠ 枠線は **刺さっているものの等級の色**（⚠ 枠そのものの色ではない）。
		#   ⚠ ワイルドでも虹にしない（⚠ 刺さっていれば「何が刺さるか」はもう要らない）。
		_draw_rainbow = false
		var decided: Dictionary = ItemIcon.grade_and_number(part_id, 0)
		box.border_color = config.color_of_grade(
			int(decided.get(ItemIcon.RESULT_GRADE, config.default_grade))
		)
		box.set_border_width_all(maxi(0, config.part_slot_filled_border_width))
	else:
		# ⚠ 空き。⚠ 枠線が「⚠ ここに何が刺さるか」を言う。
		var kinds: Variant = _view.get(GameManager.PART_VIEW_KINDS, [])
		_draw_rainbow = config.is_wild_part_slot(kinds)
		box.border_color = config.color_of_part_slot_kinds(kinds)
		# ⚠ ワイルドは虹を `_draw()` で描くので、⚠ StyleBox 側の枠は消す
		#   （⚠ 残すと虹の下に1色の輪が透けて濁る）。
		box.set_border_width_all(0 if _draw_rainbow else maxi(0, config.part_slot_border_width))
	add_theme_stylebox_override("panel", box)
	queue_redraw()

	# ⚠ 装填済のときは「刺さっているものの種類」を出す（⚠ 枠が何を受けるかではなく）。
	#   ⚠ ワイルド枠に何が刺さっているかは、⚠ これでしか分からない。
	_glyph_label.text = (
		Glyphs.for_item(part_id) if part_id != ""
		else Glyphs.for_part_slot(_view.get(GameManager.PART_VIEW_KINDS, []))
	)
	_glyph_label.add_theme_font_size_override("font_size", config.part_slot_glyph_font_size)
	# ⚠ 空き・未開放は薄く。⚠ 装填済だけ明るい。
	_glyph_label.modulate = Color(1.0, 1.0, 1.0, 1.0 if part_id != "" else config.part_slot_dim_alpha)

	tooltip_text = _tooltip_text(part_id)


# ワイルド枠の虹（2026-09-08・人間の指示）。
#
# ⚠⚠ `StyleBoxFlat` の枠線は1色しか持てない。⚠ だから虹だけ自前で描く。
#   ⚠ 角の丸みは StyleBox と同じ `icon_corner_radius` を使う（⚠ 地と輪郭がずれないように）。
# ⚠ 色相を1周させる。⚠ 彩度と明度は Config（⚠ ここに数字を書かない）。
# ⚠ ワイルドでない枠・装填済の枠では何も描かない（⚠ そちらは StyleBox の枠線が出る）。
func _draw() -> void:
	if not _draw_rainbow:
		return
	var config: IconConfig = Balance.icon
	if config == null:
		return
	var width: float = float(maxi(1, config.part_slot_border_width))
	# ⚠ 線は座標の上に中心が乗るので、⚠ 半分だけ内側に入れる（⚠ 外にはみ出さない）。
	var rect: Rect2 = Rect2(Vector2(width * 0.5, width * 0.5), size - Vector2(width, width))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points: PackedVector2Array = _rounded_rect_points(
		rect, float(config.icon_corner_radius), WILD_CORNER_STEPS
	)
	var colors: PackedColorArray = PackedColorArray()
	var last: int = points.size() - 1
	for i: int in range(points.size()):
		colors.append(Color.from_hsv(
			float(i) / float(maxi(1, last)),
			config.part_slot_wild_saturation,
			config.part_slot_wild_value
		))
	draw_polyline_colors(points, colors, width)


# 角を丸めた四角の輪郭。⚠ 最後に始点へ戻して閉じる。
static func _rounded_rect_points(
	rect: Rect2, radius: float, corner_steps: int
) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var steps: int = maxi(1, corner_steps)
	var points: PackedVector2Array = PackedVector2Array()
	# ⚠ 右下 → 左下 → 左上 → 右上 の順に回る。⚠ 角の中心と、⚠ 弧の始まりの角度。
	var corners: Array = [
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
		[rect.position + Vector2(rect.size.x - r, r), PI * 1.5],
	]
	for corner: Variant in corners:
		var center: Vector2 = (corner as Array)[0]
		var start: float = float((corner as Array)[1])
		for i: int in range(steps + 1):
			var angle: float = start + PI * 0.5 * (float(i) / float(steps))
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
	points.append(points[0])
	return points


# ツールチップ。⚠ マスが小さいので、⚠ 名前はここでしか出せない。
#   ⚠ ワイルド枠は絵文字を持たない（⚠ 何でも刺さるため）＝⚠ ここが唯一の手がかり。
func _tooltip_text(part_id: String) -> String:
	var slot_name: String = tr(part_slot_label_key(_view))
	if part_id == "":
		return "%s（%s）" % [slot_name, tr("ui_part_slot_empty")]
	return "%s：%s" % [slot_name, tr("ui_res_" + part_id)]


# 検証用の1行（⚠ 設計役は画面の絵を取れない）。⚠ ゲームのロジックから呼ばないこと。
func to_text() -> String:
	var part_entry: Dictionary = get_part_entry()
	var part_id: String = str(part_entry.get(GameStateKeys.PART_ITEM_ID, ""))
	if part_id == "":
		# ⚠ 空きのときは枠の種類まで出す。⚠ 枠線の色が種類を言うようになったが、
		#   ⚠ 設計役に色は見えない。⚠ ここが「⚠ どの枠に何が刺さるか」の唯一の確かめ方。
		return "[%s%s]" % [tr("ui_part_slot_empty"), tr(part_slot_label_key(_view))]
	return "[%s]" % tr("ui_res_" + part_id)
