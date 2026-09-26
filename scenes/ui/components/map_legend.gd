class_name MapLegend
extends PaperSheet

# 地図の凡例「しるし」（2026-09-26・人間の参考画像）。⚠ 地図の右上に重ねる小さな紙。
#
# ⚠ 1行＝マスの絵＋名前。⚠ 並べる中身（絵と翻訳済みの名前）は画面が渡す（`RUN-5`：部品は翻訳済みの文字を受け取る）。
#   ⚠ シナリオと難ダンジョンでマスの種類が違う（⚠ 商人・宝箱）ので、⚠ ここで種類を持たない。
# ⚠ 絵の色と大きさは Theme の `MapLegend` 型。
# ⚠ `.new()` で作ってから `set_entries()`。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const THEME_TYPE: StringName = &"MapLegend"
const ENTRY_ICON: String = "icon"
const ENTRY_TEXT: String = "text"


func _init() -> void:
	super._init()
	name = "MapLegend"
	show_corners = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_entries(title_text: String, entries: Array[Dictionary]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"TightList"
	add_child(column)
	var title: Label = Label.new()
	title.theme_type_variation = &"CaptionLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = title_text
	column.add_child(title)
	var side: float = float(get_theme_constant(&"icon", THEME_TYPE))
	for entry: Dictionary in entries:
		var row: HBoxContainer = HBoxContainer.new()
		row.theme_type_variation = &"ChipRow"
		var icon: TextureRect = TextureRect.new()
		icon.texture = entry.get(ENTRY_ICON, null) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(side, side)
		icon.self_modulate = get_theme_color(&"icon", THEME_TYPE)
		row.add_child(icon)
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = str(entry.get(ENTRY_TEXT, ""))
		row.add_child(label)
		column.add_child(row)


# 地図の上の真ん中に重ねる題の札（⚠ 小さい字＝どこか ／ 明朝＝何階か）。
static func make_plaque(caption: String, title: String) -> PaperSheet:
	var plaque: PaperSheet = PaperSheet.new()
	plaque.name = "MapPlaque"
	plaque.show_corners = false
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"TightList"
	plaque.add_child(column)
	var small: Label = Label.new()
	small.theme_type_variation = &"CaptionLabel"
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.text = caption
	column.add_child(small)
	var big: Label = Label.new()
	big.theme_type_variation = &"SheetHeadingLabel"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.text = title
	column.add_child(big)
	return plaque
