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
	# ⚠ 増えたときの演出の着地先。⚠ `ResourceGainEffect` が同じ `resource_id` の
	#   ⚠ 表示欄をここから探す（⚠ 画面ごとに着地先を配線しないため）。
	add_to_group(ResourceGainEffect.GROUP_DISPLAY)
	_refresh()


# 数値だけ更新する。
func set_value(new_value: int) -> void:
	value = new_value  # setter経由で _refresh() が呼ばれる


# ⚠ 増えたときに「数字が回って増える」（2026-09-09・人間のモック「採用版」）。
#   ⚠ 呼ぶのは `ResourceGainEffect`。⚠ 飛んだアイコンが1個着くたびに1回。
#
# ⚠⚠ **本当の値はもう `value` に入っている**（⚠ 画面が `resource_changed` で先に更新する）。
#   ⚠ なので「`step` ぶん戻した数から今の値へ回す」形にする。⚠ 値そのものは動かさない。
# ⚠ 回している途中でもう1個着いたら、⚠ 前の回転は捨てて引き直す
#   （⚠ 2本走ると数字がちらつく）。
func play_gain(step: int, seconds: float) -> void:
	if not is_inside_tree() or step <= 0 or seconds <= 0.0:
		return
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_display_override = maxi(0, value - step)
	_refresh()
	_count_tween = create_tween()
	_count_tween.tween_method(
		func(shown: int) -> void:
			_display_override = shown
			_refresh(),
		_display_override, value, seconds,
	)
	# ⚠ 終わったら必ず外す。⚠ 外し忘れると次の増減で古い数が出る。
	_count_tween.tween_callback(func() -> void:
		_display_override = -1
		_refresh())


# ⚠ 回っている最中だけ入る「見せかけの数」。⚠ -1 は「素直に value を出す」。
var _display_override: int = -1
var _count_tween: Tween = null


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
	# ⚠ 回っている最中は見せかけの数を出す（`play_gain()`）。
	var shown: int = _display_override if _display_override >= 0 else value
	if show_max:
		value_label.text = "%d/%d" % [shown, max_value]
	else:
		value_label.text = str(shown)
