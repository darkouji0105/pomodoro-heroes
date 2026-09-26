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


func _apply() -> void:
	for index: int in _buttons.size():
		_buttons[index].theme_type_variation = &"PaperTabOpen" if index == current else &"PaperTabClosed"


func _on_tab_pressed(index: int) -> void:
	if index == current:
		return
	current = index
	tab_changed.emit(index)
