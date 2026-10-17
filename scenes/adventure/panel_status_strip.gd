class_name PanelStatusStrip
extends VBoxContainer

# 下部パネルの各キャラの区画の上側に出す、大きな HP と固有の資源（2026-10-12・人間「⚠ 固有リソースはキャラのエリアの上側に○○使う感じで見れるように　HPもそういう感じで大きく」→「⚠ あ：2段」「⚠ 消す」）。
#
# ⚠ 1段目＝「HP」・帯・「132/170」。⚠ 2段目から資源1つにつき1段＝名前・丸か棒か札・「6/10」（⚠ 札は数を出さない）。
# ⚠ 顔の下の細い HP の帯と小さな資源は消した（⚠ 同じものを2か所に出さない）。
# ⚠ 帯は `BattleBar`、資源は `CharResourceView` を使い回す（⚠ 寸法だけ Theme の `BattlePanelStatus` で大きくする）。
# ⚠ 値を持たない。⚠ 外から毎フレーム `set_hp()` ／ `set_shield()` ／ `set_resources()` を受け取るだけ。

const THEME_TYPE: StringName = &"BattlePanelStatus"

var _bar: BattleBar = null
var _hp_text: Label = null
var _res_views: Array = []
var _res_texts: Array = []
var _defs: Array = []
var _chips: StatusChips = null


# ⚠ ツリーに入れてから呼ぶ（⚠ Theme を引くため）。
# ⚠ rows＝パーティの中で一番多い資源の数。⚠ 足りない分は空の段で埋める（⚠ 隣のキャラとスキルの行の高さをそろえる）。
func setup(defs: Array, rows: int = 0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", get_theme_constant(&"row_gap", THEME_TYPE))
	_defs = defs
	var hp_row: HBoxContainer = _make_row()
	_add_label(hp_row, tr("ui_battle_panel_hp"), true)
	_bar = BattleBar.new()
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.custom_minimum_size.y = get_theme_constant(&"hp_bar_height", THEME_TYPE)
	hp_row.add_child(_bar)
	_bar.setup(true, true)
	_hp_text = _add_label(hp_row, "", false)
	for raw: Variant in defs:
		var def: Dictionary = raw as Dictionary
		var row: HBoxContainer = _make_row()
		_add_label(row, tr(str(def.get("name_key", ""))), true)
		var view: CharResourceView = CharResourceView.new()
		view.theme_type = THEME_TYPE
		view.pips_left = true
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(view)
		_res_views.append(view)
		_res_texts.append(_add_label(row, "", false))
	for _i: int in range(maxi(0, rows - defs.size())):
		_add_label(_make_row(), "", true)


# 状態の札の段（10-17・`BT-40`・人間「⚠ 味方のばふでばふを画面の下側から確認できるように詳細も書く」→「⚠ １あ」）。
# ⚠ 駒の下と同じ札（`StatusChips`）・⚠ マウスを乗せると吹き出し（⚠ 文は describer が作る）。⚠ 1行まで（⚠ 区画の高さをそろえる）。
# ⚠ 資源の段の下に置く（⚠ 札が無くても段を取る）。
func add_status_row(describer: Callable) -> void:
	_chips = StatusChips.new()
	_chips.name = "PanelStatusChips"
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_chips)
	_chips.setup(false, 0.0)
	_chips.set_hoverable(describer, 1)


func set_status_entries(entries: Array) -> void:
	if _chips != null:
		_chips.set_entries(entries)


func set_hp(hp: int, max_hp: int) -> void:
	if _bar == null:
		return
	_bar.set_hp(hp, max_hp)
	_hp_text.text = "%d/%d" % [maxi(hp, 0), max_hp]


# ⚠ シールドは HP の帯の右に継ぎ足す（`BattleBar` の merged）。
func set_shield(hp: int, max_hp: int, shield: int, shield_total: int) -> void:
	if _bar == null:
		return
	_bar.set_values(hp, max_hp, shield, shield_total)
	_hp_text.text = "%d/%d" % [maxi(hp, 0), max_hp]


func set_resources(defs: Array, values: Dictionary) -> void:
	for i: int in range(mini(_res_views.size(), defs.size())):
		var def: Dictionary = defs[i] as Dictionary
		(_res_views[i] as CharResourceView).set_values([def], values)
		var label: Label = _res_texts[i] as Label
		if str(def.get("kind", "")) == BattleUnit.RESOURCE_KIND_STATE:
			label.text = ""
		else:
			label.text = "%d/%d" % [int(values.get(str(def.get("id", "")), 0)), int(def.get("max", 0))]


func _make_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", get_theme_constant(&"col_gap", THEME_TYPE))
	add_child(row)
	return row


# ⚠ 左の名前は幅をそろえる（⚠ 帯の左端が段ごとにずれないように）。⚠ 右の数は右寄せ。
func _add_label(row: HBoxContainer, text: String, is_name: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", get_theme_constant(&"label_size", THEME_TYPE))
	label.add_theme_color_override(&"font_color", get_theme_color(&"label", THEME_TYPE))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_name:
		label.custom_minimum_size.x = get_theme_constant(&"name_width", THEME_TYPE)
		label.clip_text = true
	else:
		label.custom_minimum_size.x = get_theme_constant(&"value_width", THEME_TYPE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	return label
