class_name PaperTabs
extends HBoxContainer

# 紙の見出しタブ（2026-09-26・回UI-2・手本の「紙の見出しタブ」）。
#
# ⚠ 紙の上の縁から飛び出す見出し。⚠ 開いているタブは紙と同じ色で背が高い（46）、
#   ⚠ ほかは一段濃く低い（38）。⚠ 下の辺をそろえる（⚠ 高さの違いは上に出る）。
# ⚠ 使い方：⚠ 縦の器（`PaperTabStack`＝間0）に「これ → `PaperSheet`」の順で入れる。
# ⚠ 押されたことは `tab_changed(index)` で伝える。⚠ 中身の差し替えは画面がやる。
# ⚠ 値は Theme の `PaperTabOpen` / `PaperTabClosed`。⚠ 文字は翻訳キー。
# ⚠ `.new()` で作る。⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

signal tab_changed(index: int)

var current: int = 0:
	set(value):
		current = value
		_apply()

var _buttons: Array[Button] = []
# ⚠ 見た目の型の頭（⚠ `<頭>Open` / `<頭>Closed`）。⚠ 10-07（見る回22回目）：⚠ 育成の部屋のタブは低い作り（`RoomTab`）。
var variation_prefix: String = "PaperTab"


func _init() -> void:
	theme_type_variation = &"PaperTabRow"


# ⚠ タブを作り直す。⚠ 前のボタンは `remove_child()` してから捨てる（⚠ await を持たない・AGENTS.md）。
func set_tabs(label_keys: Array[String], selected: int = 0) -> void:
	for button: Button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	for index: int in label_keys.size():
		var button: Button = Button.new()
		button.name = "Tab%d" % index
		button.text = tr(label_keys[index])
		button.size_flags_vertical = Control.SIZE_SHRINK_END
		button.pressed.connect(_on_tab_pressed.bind(index))
		add_child(button)
		_buttons.append(button)
	current = clampi(selected, 0, maxi(label_keys.size() - 1, 0))


# ⚠ タブにしおり紐（2026-10-07・⚠ 施設の帯の紐から入ったとき、どのタブを見ればよいか）。
func set_attention(index: int, on: bool) -> void:
	if index >= 0 and index < _buttons.size():
		_buttons[index].set_meta(RibbonMark.META_INSET, 0.0)
		RibbonMark.set_on(_buttons[index], on)


# ⚠ タブに赤い丸の数（2026-10-18・回UI-1018-4・手本 `02_training_nd.png` の「ステータスノード ③」）。⚠ 0 なら消す。
#   ⚠ 字の右に封蝋の丸＋白い数字。⚠ 値は Theme の `PaperTabBadge`。
func set_badge(index: int, count: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	var button: Button = _buttons[index]
	var old: Node = button.get_node_or_null("Badge")
	if old != null:
		button.remove_child(old)
		old.queue_free()
	if count <= 0:
		return
	var badge: Label = Label.new()
	badge.name = "Badge"
	badge.theme_type_variation = &"PaperTabBadge"
	badge.text = str(count)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side: float = float(get_theme_constant(&"badge_size", &"PaperTabBadge"))
	badge.custom_minimum_size = Vector2(side, side)
	badge.size = badge.custom_minimum_size
	button.add_child(badge)
	# ⚠ 字の右へ（⚠ 字の幅ぶん右へ寄せた余白を足す）。
	button.text = button.text.strip_edges() + "        "
	_place_badge(button)
	# ⚠ 丸は作り直すので、⚠ 位置合わせは名前で引く（⚠ 消えた丸を掴まない）。
	if not button.resized.is_connected(_place_badge.bind(button)):
		button.resized.connect(_place_badge.bind(button))


func _place_badge(button: Button) -> void:
	var badge: Control = button.get_node_or_null("Badge") as Control
	if badge == null:
		return
	var side: float = badge.custom_minimum_size.x
	badge.position = Vector2(button.size.x - side - float(get_theme_constant(&"badge_inset", &"PaperTabBadge")), (button.size.y - side) * 0.5)


func get_badge(index: int) -> int:
	if index < 0 or index >= _buttons.size():
		return 0
	var badge: Label = _buttons[index].get_node_or_null("Badge") as Label
	return 0 if badge == null else int(badge.text)


func _apply() -> void:
	for index: int in _buttons.size():
		_buttons[index].theme_type_variation = StringName(variation_prefix + ("Open" if index == current else "Closed"))


func _on_tab_pressed(index: int) -> void:
	if index == current:
		return
	current = index
	tab_changed.emit(index)
