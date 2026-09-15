class_name ItemDragCursor
extends Control

# つまんでいる品をマウスカーソルにする（2026-09-15・人間の指示「カーソルをアイコンに」）。
#
# ⚠⚠ 窓の中に描く写し（set_drag_preview）をやめた理由：⚠ 写しは元の窓の中にしか描けず、
#   ⚠ 窓の縁で切れる（⚠ 人間が実機で「窓の外にアイテムがいかない」）。
#   ⚠ OS のカーソルなら、⚠ ゲームの窓・インベントリの窓・OS の別窓をまたいで付いてくる。
# ⚠ 絵は ItemIcon と同じ材料で1枚に組む（⚠ 暗い地 ／ 等級の色の枠線 ／ 等級の色の線画）。
#   ⚠ 色と大きさは Balance.icon（IconConfig）。⚠ ここに数字を書かない。
#   ⚠ 線画が無い品（⚠ 絵文字に落ちる品）は、⚠ 地と枠線だけ（⚠ 絵文字は画像にできない）。
#   ⚠ 左上の1文字と右下の個数は出さない（⚠ カーソルは小さく、⚠ 何をつまんだかは枠と絵で足りる）。
#
# ⚠⚠ 戻し方：⚠ この Control を「見えない写し」として set_drag_preview に渡す。
#   ⚠ Godot はドラッグが終わると写しを必ず消す（⚠ 落とした・弾かれた・Esc のどれでも）。
#   ⚠ 消えるときの _exit_tree() でカーソルを戻す。
#   ⚠ つまんだマスのほうで戻さないこと（⚠ 装備するとマス目が作り直され、⚠ マスが先に消える）。
# ⚠ 2画面以上で使う ItemSlot の部品なので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

# ドラッグ中に Godot が切り替えるカーソルの形。⚠ 全部に同じ絵を付ける
#   （⚠ 1つでも漏れると、⚠ その形の間だけ OS の矢印に戻ってちらつく）。
const CURSOR_SHAPES: Array[Input.CursorShape] = [
	Input.CURSOR_ARROW,
	Input.CURSOR_DRAG,
	Input.CURSOR_CAN_DROP,
	Input.CURSOR_FORBIDDEN,
]

# 検証用（⚠ 設計役はカーソルを見られない）。⚠ いまカーソルが品の絵か。
static var _active: bool = false


# カーソルを品の絵にして、⚠ set_drag_preview に渡す見えない写しを返す。
static func begin(item_id: String, grade: int) -> ItemDragCursor:
	var image: Image = build_image(item_id, grade)
	if image != null:
		var hotspot: Vector2 = Vector2(image.get_width(), image.get_height()) * 0.5
		for shape: Input.CursorShape in CURSOR_SHAPES:
			Input.set_custom_mouse_cursor(image, shape, hotspot)
		_active = true
	var holder: ItemDragCursor = ItemDragCursor.new()
	holder.name = "ItemDragCursor"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return holder


static func is_active() -> bool:
	return _active


# カーソルの絵。⚠ Balance.icon が無ければ null（⚠ カーソルは OS のまま）。
static func build_image(item_id: String, grade: int) -> Image:
	var config: IconConfig = Balance.icon
	if config == null:
		push_error("[ItemDragCursor] Balance.icon が未割り当て。カーソルを作れない")
		return null
	var size: int = maxi(1, config.icon_size_px)
	var grade_color: Color = config.color_of_grade(
		int(ItemIcon.grade_of(item_id, grade).get(ItemIcon.RESULT_GRADE, config.default_grade))
	)

	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(config.icon_bg_color)
	var border: int = clampi(config.icon_border_width, 0, size / 2)
	for i: int in range(border):
		image.fill_rect(Rect2i(0, i, size, 1), grade_color)
		image.fill_rect(Rect2i(0, size - 1 - i, size, 1), grade_color)
		image.fill_rect(Rect2i(i, 0, 1, size), grade_color)
		image.fill_rect(Rect2i(size - 1 - i, 0, 1, size), grade_color)

	# ⚠ 線画の大きさと位置は ItemIcon._refresh() と同じ決め方（⚠ 真ん中）。
	var glyph_size: int = clampi(config.glyph_font_size, 1, size)
	_blend_tinted(image, IconTextures.for_item(item_id), glyph_size, grade_color)
	_blend_tinted(
		image, IconTextures.inner_for_item(item_id),
		maxi(1, int(float(glyph_size) * ItemIcon.INNER_RATIO)), grade_color
	)
	return image


# 白の線画を色に塗って、⚠ 真ん中へ重ねる。⚠ 絵が無ければ何もしない。
static func _blend_tinted(target: Image, texture: Texture2D, draw_size: int, color: Color) -> void:
	if texture == null:
		return
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	source.resize(draw_size, draw_size, Image.INTERPOLATE_BILINEAR)
	for y: int in range(draw_size):
		for x: int in range(draw_size):
			var pixel: Color = source.get_pixel(x, y)
			source.set_pixel(x, y, Color(
				pixel.r * color.r, pixel.g * color.g, pixel.b * color.b, pixel.a * color.a
			))
	var offset: int = (target.get_width() - draw_size) / 2
	target.blend_rect(source, Rect2i(0, 0, draw_size, draw_size), Vector2i(offset, offset))


# ⚠ ドラッグが終わって写しが消えた。⚠ カーソルを OS のものへ戻す。
func _exit_tree() -> void:
	for shape: Input.CursorShape in CURSOR_SHAPES:
		Input.set_custom_mouse_cursor(null, shape)
	_active = false
