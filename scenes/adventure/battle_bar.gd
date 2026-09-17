class_name BattleBar
extends Control

# HP とシールドの帯（2026-09-16・人間のモック「戦闘まわり UI 決定」§4）。
#
# ⚠⚠ **シールドは HP バーの右に継ぎ足す**（`merged = true`）。⚠ 別の行にしない。
#   ⚠ 2026-09-16 までは `UnitView` が HpBar の上にもう1本置いており、
#   ⚠ シールドを持っている剣士だけ縦位置がズレていた（モック §0 の 6）。
# ⚠ 下部パネルだけ `merged = false`（⚠ モック §6 は HP 6px の下にシールド 3px）。
#   ⚠ あちらは器の高さが固定なので、⚠ 行が増えても他の2人はズレない。
#
# ⚠ 色は Theme（`BattleUnitView`）から引く。⚠ このファイルに色を書かない。
# ⚠ `ProgressBar` を使わない。⚠ HP とシールドで幅の配分を変えるので、
#   ⚠ 「満タンに対する割合」しか持てない `ProgressBar` では継ぎ足せない。

const THEME_TYPE: StringName = &"BattleUnitView"

var _is_party: bool = true
var _merged: bool = true
# ⚠ 継ぎ足さないときのシールドの帯の高さ。⚠ 継ぎ足すときは使わない。
var _shield_height: float = 0.0

var _groove: ColorRect = null
var _hp: ColorRect = null
var _shield: ColorRect = null

# ⚠ 最後に受け取った値。⚠ 器の幅は1フレーム遅れて決まるので、
#   ⚠ `resized` で引き直せるように持っておく。
var _hp_now: int = 0
var _hp_max: int = 1
var _shield_now: int = 0
var _shield_max: int = 0


func setup(is_party: bool, merged: bool, shield_height: float = 0.0) -> void:
	_is_party = is_party
	_merged = merged
	_shield_height = shield_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_groove = _make_rect(get_theme_color(&"groove", THEME_TYPE))
	_hp = _make_rect(get_theme_color(&"hp_high", THEME_TYPE))
	_shield = _make_rect(get_theme_color(&"shield", THEME_TYPE))
	if not resized.is_connected(_relayout):
		resized.connect(_relayout)
	_relayout()


func _make_rect(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


# HP だけ差し替える。⚠ シールドは前の値のまま（⚠ 毎フレーム呼ぶのはこちら）。
# ⚠ シールドは `BattleController` が器から引いて `set_values()` で配る。
func set_hp(hp: int, max_hp: int) -> void:
	set_values(hp, max_hp, _shield_now, _shield_max)


# 残量を差し替える。⚠ 毎フレーム呼んでよい（⚠ 幅を入れ直すだけ）。
func set_values(hp: int, max_hp: int, shield: int, shield_total: int) -> void:
	_hp_now = maxi(hp, 0)
	_hp_max = maxi(max_hp, 1)
	_shield_now = maxi(shield, 0)
	_shield_max = maxi(shield_total, 0)
	_relayout()


func _relayout() -> void:
	if _groove == null:
		return
	var full_w: float = size.x
	var full_h: float = size.y
	if full_w <= 0.0 or full_h <= 0.0:
		return

	_groove.position = Vector2.ZERO
	_groove.size = Vector2(full_w, full_h)

	var hp_ratio: float = clampf(float(_hp_now) / float(_hp_max), 0.0, 1.0)
	_hp.color = _hp_color(hp_ratio)

	if _merged:
		# ⚠ HP とシールドで幅を分け合う。⚠ 合計が満タンのときにちょうど帯いっぱい。
		var total: float = float(_hp_max + _shield_max)
		var hp_span: float = full_w * (float(_hp_max) / total) if total > 0.0 else full_w
		_hp.position = Vector2.ZERO
		_hp.size = Vector2(hp_span * hp_ratio, full_h)
		var shield_ratio: float = 0.0
		if _shield_max > 0:
			shield_ratio = clampf(float(_shield_now) / float(_shield_max), 0.0, 1.0)
		_shield.position = Vector2(hp_span, 0.0)
		_shield.size = Vector2((full_w - hp_span) * shield_ratio, full_h)
		_shield.visible = _shield_max > 0 and _shield_now > 0
		return

	# ⚠ 継ぎ足さない形。⚠ HP は帯いっぱい、⚠ シールドはその下に別の帯。
	var hp_height: float = full_h - _shield_height
	_hp.position = Vector2.ZERO
	_hp.size = Vector2(full_w * hp_ratio, hp_height)
	var left_ratio: float = 0.0
	if _shield_max > 0:
		left_ratio = clampf(float(_shield_now) / float(_shield_max), 0.0, 1.0)
	_shield.position = Vector2(0.0, hp_height)
	_shield.size = Vector2(full_w * left_ratio, _shield_height)
	_shield.visible = _shield_max > 0 and _shield_now > 0


# HP の色。⚠ 味方は**残量に関係なくいつも緑**、⚠ 敵は赤。
# ⚠⚠ 2026-09-17 に味方の3段（緑・黄・赤）をやめた（人間「剣士の体力を緑に」→
#   「味方のHPは残量に関係なくいつも緑」）。⚠ 瀕死は名前の赤だけで示す（`is_low()`）。
func _hp_color(_ratio: float) -> Color:
	return get_theme_color(&"hp_high" if _is_party else &"hp_enemy", THEME_TYPE)


# 瀕死か。⚠ 名前の色を変える側（`UnitView`）が同じしきい値を持たないための入口。
func is_low() -> bool:
	var percent: float = clampf(float(_hp_now) / float(_hp_max), 0.0, 1.0) * 100.0
	return percent <= float(get_theme_constant(&"hp_low_percent", THEME_TYPE))
