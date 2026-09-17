class_name UnitView
extends Node2D

# BattleUnit の状態を購読して表示するノード。
# 読み取り専用。HP の変動は BattleController が take_damage() を呼ぶ形で行う。
#
# ⚠⚠ 2026-09-16 に人間のモック「戦闘まわり UI 決定」§3・§4 の形へ作り替えた。
#   ⚠ 幅 74 固定 ／ 名前は幅いっぱいで省略記号 ／ HP とシールドは1本 ／
#   ⚠ 状態のマスは本体の下端に重ねる。
# ⚠ **見た目の値はここに1つも書かない**。⚠ Theme の `BattleUnitView` と
#   `CharacterAvatar` から引く（AGENTS.md「値を持つのは theme_builder だけ」）。
# ⚠ `Node2D` は `get_theme_*()` を持たない。⚠ 引くのは子の Control（`$Body`）から。

const THEME_TYPE: StringName = &"BattleUnitView"
const AVATAR_TYPE: StringName = &"CharacterAvatar"

# ⚠ 味方以外の本体の色を引くときの鍵。⚠ `CharacterAvatar` の表に足してある
#   （`bg_enemy` / `bg_boss`）。⚠ 味方はキャラのIDでそのまま引く。
const BODY_KEY_ENEMY: String = "enemy"
const BODY_KEY_BOSS: String = "boss"
const BODY_KEY_FALLBACK: String = "fallback"

var _unit: BattleUnit = null
# ⚠ 行動中（いまチャージを溜めている）か。⚠ 枠線と名前の色が変わる（モック §3-2）。
var _active: bool = false


func _ready() -> void:
	# デフォルト非表示。setup() 後に表示する想定。
	hide()


func setup(unit: BattleUnit) -> void:
	_unit = unit
	var body: Panel = $Body
	var name_label: Label = $NameLabel
	var bar: BattleBar = $Bar

	var is_party: bool = unit.team == BattleUnit.TEAM_PARTY

	# ⚠ 名前は器の幅で切る（モック §3-1）。⚠ `.tscn` 側で clip_text と省略記号を
	#   立ててある。⚠ ここでやるのは大きさと色だけ。
	name_label.text = tr(unit.unit_name_key)
	name_label.add_theme_font_size_override(
		&"font_size", body.get_theme_constant(&"name_size", THEME_TYPE)
	)

	_paint_body(unit)

	# 体の上に出す絵文字（段階19-a）。⚠ 対応表は Glyphs の1本だけ。
	# ⚠ ここで master_id を見て分岐を書かないこと。
	# ⚠ modulate を掛けない（カラー絵文字なので色が濁る）。色は本体が受け持つ。
	var glyph_label: Label = $GlyphLabel
	glyph_label.text = Glyphs.for_unit(
		unit.master_id, is_party, unit.is_summon
	)
	glyph_label.add_theme_font_size_override(
		&"font_size", body.get_theme_constant(&"glyph", THEME_TYPE)
	)

	bar.setup(is_party, true)
	bar.set_values(unit.hp, unit.max_hp, 0, 0)

	# 状態のマスは横並び（本体の下端に重ねる）。⚠ 2026-09-16 から味方も同じ場所
	#   （⚠ それまでは味方だけスキルボタンの左に縦で出していた）。
	$StatusChips.setup(false, Balance.adventure.status_chip_max_px)
	position.x = unit.x
	_refresh_name_color()
	show()


# 本体の色（モック §3）。⚠ 味方は `CharacterAvatar` の色表をそのまま使う
#   （⚠ 育成・スキル設定と同じ顔色。⚠ 戦闘だけ別の色にしない）。
func _paint_body(unit: BattleUnit) -> void:
	var body: Panel = $Body
	var key: String = unit.master_id
	if unit.is_boss:
		key = BODY_KEY_BOSS
	elif unit.team != BattleUnit.TEAM_PARTY:
		key = BODY_KEY_ENEMY
	if not body.has_theme_color(StringName("bg_" + key), AVATAR_TYPE):
		key = BODY_KEY_FALLBACK

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = body.get_theme_color(StringName("bg_" + key), AVATAR_TYPE)
	style.set_corner_radius_all(body.get_theme_constant(&"corner_radius", THEME_TYPE))
	if _active:
		# ⚠ 行動中は枠線を足す（モック §3-2）。⚠ 枠の太さぶん中身が縮まないよう、
		#   ⚠ `StyleBoxFlat` の枠は外側に描かれないので位置は動かない。
		var width: int = body.get_theme_constant(&"active_width", THEME_TYPE)
		style.set_border_width_all(width)
		style.border_color = body.get_theme_color(&"active_border", THEME_TYPE)
	body.add_theme_stylebox_override(&"panel", style)
	$GlyphLabel.add_theme_color_override(
		&"font_color", body.get_theme_color(StringName("fg_" + key), AVATAR_TYPE)
	)


# 行動中の表示を切り替える。⚠ 呼ぶのは BattleController の1箇所だけ
#   （⚠ いまチャージを溜めている本人だけが true）。
func set_active(active: bool) -> void:
	if _active == active or _unit == null:
		return
	_active = active
	_paint_body(_unit)
	_refresh_name_color()


# 名前の色（モック §3-2・§4）。⚠ 通常 ／ 行動中 ／ 瀕死の3つ。
# ⚠ 瀕死のしきい値は帯が持つ（`BattleBar.is_low()`）。⚠ ここに割合を書かない。
func _refresh_name_color() -> void:
	var body: Panel = $Body
	var key: StringName = &"name"
	if $Bar.is_low():
		key = &"name_low"
	elif _active:
		key = &"name_active"
	$NameLabel.add_theme_color_override(
		&"font_color", body.get_theme_color(key, THEME_TYPE)
	)


# シールドの残量を表示する。⚠ 呼ぶのは BattleController の1箇所だけ。
#
# ⚠ UnitView に StatusRegistry を持たせないこと。ビューは BattleUnit しか知らない
#   （器を知ると、リトライで器が作り直されたときに古い参照を握る）。
# ⚠ 2026-09-16 から帯は1本。⚠ total が 0 なら帯の中のシールドの区画が消えるだけで、
#   ⚠ 帯そのものは隠さない（⚠ 隠すと縦位置がズレる）。
func set_shield(left: int, total: int) -> void:
	if _unit == null:
		return
	$Bar.set_values(_unit.hp, _unit.max_hp, left, total)


# 状態のマスを差し替える。⚠ 呼ぶのは BattleController の1箇所だけ。
#
# ⚠ set_shield() と同じ形。UnitView に StatusRegistry を持たせないこと
#   （ビューは BattleUnit しか知らない。器を知るとリトライで古い参照を握る）。
# ⚠ _process() の is_alive() ガードより外に置く。あちらは死ぬと return するので、
#   中に書くと死んだ瞬間に更新が止まり、復活したとき古いマスが出る。
func set_status_entries(entries: Array) -> void:
	$StatusChips.set_entries(entries)


# 毎フレーム位置と HP バーを同期する
func _process(_delta: float) -> void:
	if _unit == null:
		return
	if not _unit.is_alive():
		# 死亡時は hide() するだけ。ノードは消さない（参照が残るため）。
		# ここで show() に戻す処理を入れないこと。死体が復活表示される。
		hide()
		return
	position.x = _unit.x
	var bar: BattleBar = $Bar
	var was_low: bool = bar.is_low()
	bar.set_hp(_unit.hp, _unit.max_hp)
	if was_low != bar.is_low():
		_refresh_name_color()


# 被弾した数値を頭上に浮かべて消す。
# is_crit / is_dot の既定値を false にしてあるので、既存の呼び出しは壊れない。
#
# ⚠ 種類で分ける（EXEC_DAMAGE_POP_COLOR.md）。「量に応じて」ではない。
#   毒の 2 と通常の 4 は量がほぼ同じなので、量で分けても見分けられない。
# ⚠ 優先順は is_dot → is_crit。DoT は今のところ会心しないが、両方立ったら
#   種類（毒であること）のほうが情報として上なので DoT の色で出す。
func pop_damage(amount: int, is_crit: bool = false, is_dot: bool = false) -> void:
	var cfg: AdventureConfig = Balance.adventure
	if is_dot:
		pop_label(str(amount), cfg.pop_dot_color, cfg.pop_dot_font_size)
	elif is_crit:
		pop_label(str(amount), cfg.pop_crit_color, cfg.pop_crit_font_size)
	else:
		pop_label(str(amount), cfg.pop_damage_color, cfg.pop_damage_font_size)


# 回復した数値を頭上に浮かべて消す。
# ⚠ pop_damage と分けてあるのは、呼ぶ側（battle_controller）で
#   is_heal による分岐を1回で終わらせるため。色の判断をこちらに持たせない。
func pop_heal(amount: int) -> void:
	pop_label(str(amount), Balance.adventure.pop_heal_color, Balance.adventure.pop_heal_font_size)


# ジャスト成功などの演出用。数値以外の文字を浮かべる。
func pop_just() -> void:
	pop_label(tr("ui_battle_just"), Balance.adventure.pop_just_color, Balance.adventure.pop_just_font_size)


# 文字を頭上に浮かべて消す。
# ラベルは自分の子ではなく親コンテナに乗せる。
# 自分の子にすると、とどめの一撃で hide() された瞬間に
# 文字も一緒に消えてしまい、最後のダメージが読めなくなるため。
func pop_label(text: String, color: Color, font_size: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 100
	parent.add_child(label)
	label.position = position + Vector2(0.0, -40.0)

	# 動きは種類で変えない。変えると読む速さが揃わない。
	var rise_px: float = Balance.adventure.pop_rise_px
	var duration_sec: float = Balance.adventure.pop_duration_sec

	var tween: Tween = parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - rise_px, duration_sec)
	tween.tween_property(label, "modulate:a", 0.0, duration_sec)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
