class_name ValueRow
extends HBoxContainer

# 「左に名前・右に値」の1行（2026-09-09・人間の指示「基本的なコンポーネントの見直し・追加」）。
#
# ⚠⚠ 2026-09-08 に `ItemDetail` の中で作ったものを、⚠ ここへ出した。
#   ⚠ 装備・育成・研究が **同じ形を手組み**していて、⚠ そちらは値が右に寄っていない。
#   ⚠ 「⚠ 名前と値が1行に並ぶ」画面はこの部品を使う。
#
# ⚠ 値の色は Theme の型 variation（⚠ 増える＝`GainLabel` ／ 減る＝`ErrorLabel`）。
#   ⚠ 色をここに書かない（AGENTS.md）。⚠ 空を渡せば色を変えない（⚠ 個数やコスト）。
# ⚠ 絵（線画）は名前の前に出す。⚠ 無ければ出さない。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

# 値の色。⚠ 名前は `tools/theme_builder.gd` と揃えること。
const VARIATION_GAIN: StringName = &"GainLabel"
const VARIATION_LOSS: StringName = &"ErrorLabel"
const VARIATION_PLAIN: StringName = &""

var _name_label: Label = null
var _value_label: Label = null
var _icon_rect: TextureRect = null


# 1行を作る。⚠ `variation` は上の3つのどれか。⚠ `icon` は `IconTextures` から引いたもの。
static func create(
	name_text: String,
	value_text: String,
	variation: StringName = VARIATION_PLAIN,
	icon: Texture2D = null
) -> ValueRow:
	var row: ValueRow = ValueRow.new()
	row.setup(name_text, value_text, variation, icon)
	return row


# 数値の行を作る（⚠ 符号と色を自分で決める）。⚠ 0 でも出す（⚠ 出すかは呼ぶ側が決める）。
#
# ⚠⚠ 「+ を付けるか」「緑か赤か」を呼ぶ側に書かせない。⚠ 3箇所で書き方がずれていた。
static func create_signed(
	name_text: String, value: int, value_text: String, icon: Texture2D = null
) -> ValueRow:
	var sign_text: String = "+" if value > 0 else ("-" if value < 0 else "")
	var variation: StringName = VARIATION_PLAIN
	if value > 0:
		variation = VARIATION_GAIN
	elif value < 0:
		variation = VARIATION_LOSS
	return create(name_text, sign_text + value_text, variation, icon)


func setup(
	name_text: String,
	value_text: String,
	variation: StringName = VARIATION_PLAIN,
	icon: Texture2D = null
) -> void:
	name = "ValueRow"

	for child in get_children():
		remove_child(child)
		child.queue_free()

	if icon != null:
		_icon_rect = TextureRect.new()
		_icon_rect.name = "Icon"
		_icon_rect.texture = icon
		# ⚠ 大きさは文字と同じ段（⚠ ここに px を書かない）。
		var icon_size: float = float(Balance.icon.grade_font_size + 6) if Balance.icon != null else 16.0
		_icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon_rect)

	_name_label = Label.new()
	_name_label.name = "Name"
	_name_label.text = name_text
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_name_label)

	_value_label = Label.new()
	_value_label.name = "Value"
	_value_label.text = value_text
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if variation != VARIATION_PLAIN:
		_value_label.theme_type_variation = variation
	add_child(_value_label)


# 検証用（⚠ 設計役は絵を見られない）。⚠ ゲームのロジックから呼ばないこと。
func to_text() -> String:
	var parts: Array[String] = []
	if _icon_rect != null and _icon_rect.texture != null:
		parts.append("[%s]" % _icon_rect.texture.resource_path.get_file().get_basename())
	if _name_label != null:
		parts.append(_name_label.text)
	if _value_label != null:
		parts.append(_value_label.text)
	return "  ".join(parts)
