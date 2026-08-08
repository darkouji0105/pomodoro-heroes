class_name PrimaryButton
extends Button

# ボタンに表示するテキスト。tr()で翻訳を通す（AGENTS.md命名規則）。
# label_key に翻訳キーを入れると、tr()を通した文字列が text に反映される。
# 空のままにすれば、使う側が text プロパティを直接書き換えられる。
@export var label_key: String = "":
	set(value):
		label_key = value
		if is_inside_tree():
			text = tr(label_key)


func _ready() -> void:
	if label_key != "":
		text = tr(label_key)
