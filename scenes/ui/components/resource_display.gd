class_name ResourceDisplay
extends HBoxContainer

# 表示アイコン。TextureRect の texture に流し込む。
# 未設定でもよい（アイコン画像は後日追加）。
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			_refresh()

# 表示する数値。set_value() 経由でも設定できる。
@export var value: int = 0:
	set(new_value):
		value = new_value
		if is_inside_tree():
			_refresh()

# "current/max" 形式で表示するか（スタミナ用）。
@export var show_max: bool = false
@export var max_value: int = 0


func _ready() -> void:
	_refresh()


# 数値だけ更新する。
func set_value(new_value: int) -> void:
	value = new_value  # setter経由で _refresh() が呼ばれる


# スタミナ用。current と max を同時に設定し、表示を "current/max" 形式に切り替える。
func set_value_with_max(new_current: int, new_max: int) -> void:
	max_value = new_max
	show_max = true
	value = new_current  # setter 経由で _refresh() が呼ばれる


func _refresh() -> void:
	var icon: TextureRect = $Icon
	var value_label: Label = $ValueLabel
	if icon.texture != icon_texture:
		icon.texture = icon_texture
	if show_max:
		value_label.text = "%d/%d" % [value, max_value]
	else:
		value_label.text = str(value)
