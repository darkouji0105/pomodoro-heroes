class_name UnitView
extends Node2D

# BattleUnit の状態を購読して表示するノード。
# 読み取り専用。HP の変動は BattleController が take_damage() を呼ぶ形で行う。

# 体の色（EXEC §5：本タスク限定の例外）。
# ⚠ 頭上に浮かぶ数値の色とは別物で、こちらは定数のまま。
#   Inspector から触りたくなったら、下と同じ形で AdventureConfig に出す。
const COLOR_PARTY: Color = Color(0.3, 0.5, 0.9)   # 青
const COLOR_ENEMY: Color = Color(0.9, 0.35, 0.3)  # 赤
const COLOR_BOSS: Color = Color(0.6, 0.3, 0.8)    # 紫

# 頭上に浮かぶ数値の色と大きさは Balance.adventure（AdventureConfig）から引く。
# ⚠ ここに const で持たないこと。2箇所に数値があると、Inspector で直しても
#   変わらない状態になり、どちらが効いているか実機でしか分からなくなる
#   （AGENTS.md「マスターデータと状態を同期する型」で書いた「直したのに変わらない」と同じ形）。
# ⚠ Balance.adventure が null のときのフォールバックは書かない。
#   battle_formula.gd が同じく素で読んでおり、null なら戦闘はどのみち起動しない。
#   ここだけ既定色で描くと、設定漏れが「色が古いまま」という分かりにくい形で出る。

var _unit: BattleUnit = null


func _ready() -> void:
	# デフォルト非表示。setup() 後に表示する想定。
	hide()


func setup(unit: BattleUnit) -> void:
	_unit = unit
	var body: ColorRect = $Body
	var hp_bar: ProgressBar = $HpBar
	var name_label: Label = $NameLabel

	name_label.text = tr(unit.unit_name_key)

	if unit.is_boss:
		body.color = COLOR_BOSS
	elif unit.team == BattleUnit.TEAM_PARTY:
		body.color = COLOR_PARTY
	else:
		body.color = COLOR_ENEMY

	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.hp
	position.x = unit.x
	show()


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
	$HpBar.value = _unit.hp


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
