class_name EmptyState
extends VBoxContainer

# 「ここには何も無い」を出す置き場（2026-09-09・人間の指示「基本的なコンポーネントの見直し・追加」）。
#
# ⚠⚠ 2026-09-08 に倉庫の宝箱タブだけがこの形になった（⚠ 絵 ＋ 2行）。
#   ⚠ 他の画面（⚠ 図鑑・ショップ・装備の一覧）は **文字1行**のままで、
#   ⚠ 「⚠ 壊れて空なのか、⚠ もともと無いのか」が読み取れなかった。⚠ ここに1本化する。
#
# ⚠ 絵は省ける（⚠ 渡さなければ文字だけ）。⚠ 2行目（手がかり）も省ける。
# ⚠ 文字は必ず翻訳キーで受け取る（⚠ ここで日本語を書かない）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

# 1行目と2行目の翻訳キー。⚠ 2行目は空でよい。
var _message_key: String = ""
var _hint_key: String = ""


# 作る。⚠ `icon` は `IconTextures` から引いたもの（⚠ null なら絵を出さない）。
static func create(message_key: String, hint_key: String = "", icon: Texture2D = null) -> EmptyState:
	var box: EmptyState = EmptyState.new()
	box.name = "EmptyState"
	box.setup(message_key, hint_key, icon)
	return box


func setup(message_key: String, hint_key: String = "", icon: Texture2D = null) -> void:
	_message_key = message_key
	_hint_key = hint_key

	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	for child in get_children():
		remove_child(child)
		child.queue_free()

	if icon != null:
		var rect: TextureRect = TextureRect.new()
		rect.name = "Icon"
		# ⚠ 大きさは絵文字と同じ段（⚠ ここに px を書かない）。⚠ Config が無ければ出さない。
		var size_px: float = float(maxi(1, Balance.icon.glyph_font_size)) if Balance.icon != null else 20.0
		rect.custom_minimum_size = Vector2(size_px, size_px)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)

	var message: Label = Label.new()
	message.name = "MessageLabel"
	message.text = tr(message_key)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(message)

	if hint_key == "":
		return
	var hint: Label = Label.new()
	hint.name = "HintLabel"
	hint.text = tr(hint_key)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


# 検証用（⚠ 設計役は絵を見られない）。⚠ ゲームのロジックから呼ばないこと。
func to_text() -> String:
	var parts: Array[String] = []
	for child in get_children():
		if child is Label:
			parts.append((child as Label).text)
	return " / ".join(parts)
