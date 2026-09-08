class_name ResourceDisplay
extends HBoxContainer

# 表示アイコン。TextureRect の texture に流し込む。
# ⚠ 直に画像を入れることもできるが、⚠ ふつうは `resource_id` を渡す（下）。
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			_refresh()

# 何の資源か（2026-09-09）。⚠ 入れると絵が自動で付く。
#
# ⚠⚠ 2026-09-09 まで `icon_texture` は **全画面で空**だった（⚠ 絵が1枚も無かったため）。
#   ⚠ 線画が入ったので、⚠ ここにIDを入れるだけで付くようにした。
# ⚠ IDは `GameStateKeys.GOLD` などの通貨か、⚠ 素材・持ち物の `item_id`。
#   ⚠ 振り分けは `IconTextures.for_resource()` の1本（⚠ ここで分岐を書かない）。
# ⚠ 絵が無いIDなら null が返り、⚠ アイコンは出ないまま（⚠ 数字だけになる）。
@export var resource_id: String = "":
	set(value):
		resource_id = value
		icon_texture = IconTextures.for_resource(resource_id) if resource_id != "" else null

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
	# ⚠ 絵が無いときは器ごと消す（⚠ 空の四角ぶんの隙間が空かないように）。
	icon.visible = icon_texture != null
	if show_max:
		value_label.text = "%d/%d" % [value, max_value]
	else:
		value_label.text = str(value)
