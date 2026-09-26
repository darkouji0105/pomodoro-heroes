class_name RunMenuButton
extends UiButton

# ランの中の右上のメニュー（2026-09-26・人間「⚠ その場で降りるボタンは消す　⚠ メニューからいけるようにする右上の」）。
#
# ⚠ 押すと小さな板が下に開き、⚠ 画面が渡した項目を縦に並べる（⚠ 中断・レリックを見る・降りる）。
# ⚠ 項目の字は**翻訳済み**で受け取る（`RUN-5`：部品は翻訳済みの文字を受け取る）。
# ⚠ 取り返しのつかない項目（⚠ 降りる）は赤（`MD-5`）。⚠ 確かめの窓を出すのは画面の側（⚠ 押した先の口）。
# ⚠ 板は `PopupPanel`（⚠ 外を押すと閉じる）。⚠ 見た目は Theme の `PopupPanel`。
# ⚠ `.new()` で作る。⚠ シナリオと難ダンジョンの両方で使うので scenes/ui/components/（AGENTS.md）。

var _popup: PopupPanel = null
var _list: VBoxContainer = null


func _init() -> void:
	super._init()
	name = "MenuButton"
	label_key = "ui_common_menu"
	_popup = PopupPanel.new()
	_popup.name = "MenuPopup"
	_list = VBoxContainer.new()
	_list.theme_type_variation = &"TightList"
	_popup.add_child(_list)
	add_child(_popup)
	pressed.connect(_open)


func _ready() -> void:
	super._ready()
	text = tr(label_key)


# 項目を1つ足す。⚠ 押したら板を閉じてから `handler` を呼ぶ（⚠ 窓が重ならないように）。
func add_item(text_value: String, handler: Callable, danger: bool = false) -> UiButton:
	var item: UiButton = UiButton.new()
	item.variant = UiButton.Variant.DANGER if danger else UiButton.Variant.SECONDARY
	item.text = text_value
	item.pressed.connect(func() -> void:
		_popup.hide()
		handler.call()
	)
	_list.add_child(item)
	return item


# ⚠ ボタンの右下に合わせて開く（⚠ 右上に置くので、⚠ 板は左へ伸ばす）。
func _open() -> void:
	_popup.reset_size()
	var rect: Rect2 = get_global_rect()
	var popup_size: Vector2 = Vector2(_popup.get_contents_minimum_size())
	var pos: Vector2 = Vector2(rect.end.x - popup_size.x, rect.end.y)
	_popup.popup(Rect2i(Vector2i(pos), Vector2i(popup_size)))
