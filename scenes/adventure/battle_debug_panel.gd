class_name BattleDebugPanel
extends CanvasLayer

# 戦闘画面の検証用デバッグパネル。
#
# UI をすべてコードで組み立てる。理由：
#  - .tscn を人間が手で作る手間を無くすため
#  - デバッグ用ノードが本番シーンのツリーに残らないようにするため
#
# BattleController が OS.is_debug_build() のときだけ生成する。
# 入力は _unhandled_input で直接キーコードを見る。
# project.godot の Input Map は人間の担当なので触らない。

const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]

# 検証用ダメージの威力。物理・魔法で同じ値を使う。
# 同じ威力を撃って def と mdef で結果が変わることを見るため、片方だけ変えないこと。
const DEBUG_DAMAGE_POWER: int = 10

# 右上に置くときの想定幅。実サイズが確定する前の1フレームだけ使う。
const PANEL_FALLBACK_WIDTH: float = 620.0

var _controller: Node = null
var _root: PanelContainer = null
var _info_label: Label = null
var _help_label: Label = null
var _scale_index: int = 0


func setup(controller: Node) -> void:
	_controller = controller
	layer = 100
	_build_ui()


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.modulate = Color(1, 1, 1, 0.92)
	add_child(_root)
	# CanvasLayer は Control ではないため、子のアンカー（PRESET_TOP_RIGHT など）は効かない。
	# 右上に出したいので、ビューポートの幅から位置を計算する（debug_overlay.gd と同じ形）。
	# パネルの幅は表示するユニット数で変わるので、_process() でも置き直す。
	_place_top_right()
	get_viewport().size_changed.connect(_place_top_right)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_root.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	margin.add_child(box)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	box.add_child(_info_label)

	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 12)
	_help_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_help_label.text = "\n".join([
		"--------------------------------",
		"[F3] パネル表示切替",
		"[1][2][3][4] 速度 1x / 2x / 4x / 8x",
		"[K] 敵を1体たおす",
		"[L] このウェーブの敵を全滅",
		"[J] 味方全員に物理の一撃（威力%d）" % DEBUG_DAMAGE_POWER,
		"[M] 味方全員に魔法の一撃（威力%d）" % DEBUG_DAMAGE_POWER,
		"[S] スキルCD全リセット",
		"[P] 状態の一覧をコンソールへ出す（1回だけ）",
		"[V] 強制的に勝利  [B] 強制的に敗北",
		"※ 2行目の dmg は非会心のダメージ（会心分は含まない）",
	])
	box.add_child(_help_label)


func _process(_delta: float) -> void:
	if not visible or _info_label == null:
		return
	_info_label.text = _build_info_text()
	# 行の中身で幅が変わる（ユニット数・HPの桁）。毎フレーム右端に寄せ直す。
	_place_top_right()


# 右上に寄せる。ウィンドウサイズが変わっても追従させる。
#
# ⚠ 右上は debug_overlay.gd（0キー）も使っている。両方開くと重なる。
# 戦闘中に資源を配る用事は少ないので、重なったらオーバーレイ側を 0 で閉じる。
func _place_top_right() -> void:
	if _root == null:
		return
	var view_width: float = get_viewport().get_visible_rect().size.x
	var panel_width: float = _root.size.x if _root.size.x > 0.0 else PANEL_FALLBACK_WIDTH
	_root.position = Vector2(max(8.0, view_width - panel_width - 8.0), 8.0)


func _build_info_text() -> String:
	if _controller == null:
		return "controller なし"
	var session: BattleSession = _controller.get_session()
	if session == null:
		return "session なし（初期化前）"

	var lines: Array[String] = []
	lines.append("state=%s  wave=%d/%d  speed=%.0fx" % [
		session.state, session.current_wave, session.total_waves, Engine.time_scale
	])
	lines.append("--------------------------------")
	lines.append("味方")
	for u in session.party_units:
		lines.append(_format_unit(u))
	lines.append("敵")
	for u in session.enemy_units:
		lines.append(_format_unit(u))
	return "\n".join(lines)


# 1ユニットにつき2行出す。
# 1行目 … 位置・HP・ターゲット・攻撃タイマー（右側は atkspd 適用済みの実効間隔）
# 2行目 … 10軸と、いま狙っている相手に通る非会心ダメージ
#         ⚠ 10軸は状態の補正込み（get_stat() が足す）。バフはここに出る
# 3行目 … いま付いている状態。⚠ 0件のユニットには出さない（全員に空行が出ると読めない）
#
# ダメージの式はここに書かない。BattleFormula.damage() をそのまま呼ぶ。
# 会心は抽選せず必ず false を渡すので、表示はフレームごとにぶれない。
func _format_unit(unit: BattleUnit) -> String:
	if unit == null:
		return "  (null)"
	var mark: String = " " if unit.is_alive() else "x"
	var target: String = _unit_label(_find_unit(unit.target_unit_id))
	var line1: String = "%s %-10s hp %4d/%-4d x %6.1f tgt %-10s t %.2f/%.2f" % [
		mark, _unit_label(unit), unit.hp, unit.max_hp, unit.x,
		target, unit.attack_timer, unit.attack_interval_sec
	]
	var line2: String = "    %-8s atk %3d mag %3d def %3d mdef %3d | as %3d%% ha %3d%% cr %3d%% cd %3d%% spd %3d | dmg %s" % [
		unit.attack_type,
		unit.get_stat(GameStateKeys.STAT_ATK), unit.get_stat(GameStateKeys.STAT_MAG),
		unit.get_stat(GameStateKeys.STAT_DEF), unit.get_stat(GameStateKeys.STAT_MDEF),
		unit.get_stat(GameStateKeys.STAT_ATKSPD), unit.get_stat(GameStateKeys.STAT_HASTE),
		unit.get_stat(GameStateKeys.STAT_CRIT_RATE), unit.get_stat(GameStateKeys.STAT_CRIT_DMG),
		unit.get_stat(GameStateKeys.STAT_SPD),
		_format_damage_to_target(unit)
	]
	var line3: String = _format_statuses(unit)
	if line3 == "":
		return line1 + "\n" + line2
	return line1 + "\n" + line2 + "\n" + line3


# そのユニットに付いている状態。0件なら空文字（行を出さない）。
#
# ⚠ 状態は画面に何も出ないので、ここが唯一の確認手段になる。
#   「黙って剥がれた」「二重に付いた」「消えない」はどれもエラーが出ない。
# ⚠ status_id をそのまま出す。翻訳キーを引かない（検証用。ja.csv を触らない）。
func _format_statuses(unit: BattleUnit) -> String:
	var registry: StatusRegistry = _get_registry()
	if registry == null:
		return ""
	var entries: Array = registry.query({
		"host": SkillSchema.HOST_UNIT,
		"host_unit_id": unit.unit_id,
	})
	if entries.is_empty():
		return ""

	var parts: Array[String] = []
	for entry: Dictionary in entries:
		var text: String = str(entry.get("status_id", ""))
		if str(entry.get("life", "")) == StatusRegistry.LIFE_SEC:
			var left: float = float(entry.get("duration_sec", 0.0)) - float(entry.get("elapsed", 0.0))
			text += " (%.1fs" % maxf(0.0, left)
			if str(entry.get("kind", "")) == StatusRegistry.KIND_DOT:
				text += "/%d発" % maxi(0, int(entry.get("fires_total", 0)) - int(entry.get("fires_done", 0)))
			text += ")"
		else:
			text += " (until:%s)" % str(entry.get("life", ""))
		parts.append(text)
	return "    状態: " + " ".join(parts)


# 状態の器。BattleController が持っていなければ null。
func _get_registry() -> StatusRegistry:
	if _controller == null or not _controller.has_method("get_status_registry"):
		return null
	return _controller.get_status_registry()


# ============================================================
# コンソール出力（[P]）
# ============================================================

# いま器に入っている状態を、押した瞬間に1回だけ出す。
#
# ⚠ 毎フレーム出さないこと。出力パネルが埋まると本物の異常が見えなくなる。
# ⚠ パネルの3行目（_format_statuses）と役割が違う。あちらは host: unit だけを
#   ユニットの行の下に出す。ここは器の中身を丸ごと出すので、host: point /
#   host: battle も出る（どちらも画面には一切出ない）。
# ⚠ 0件でも出すこと。「押したのに何も出ない」と「0件だった」を区別できなくなる。
func _print_statuses() -> void:
	var registry: StatusRegistry = _get_registry()
	if registry == null:
		print("[BattleDebug] 状態: registry が取れない（controller に get_status_registry が無い）")
		return

	var entries: Array = registry.snapshot()
	print("[BattleDebug] ---- 状態 %d件（speed %.0fx）----" % [entries.size(), Engine.time_scale])
	for entry: Dictionary in entries:
		print("  " + _format_entry_line(entry))
	_print_stat_diffs()
	print("[BattleDebug] ---- ここまで ----")


# 状態1件を1行にする。⚠ 器が持つ欄をそのまま出す。ここで計算し直さない。
func _format_entry_line(entry: Dictionary) -> String:
	var host: String = str(entry.get("host", ""))
	var text: String = "#%d %s %s host=%s" % [
		int(entry.get("instance_id", 0)),
		str(entry.get("status_id", "")),
		str(entry.get("kind", "")),
		host,
	]
	if host == SkillSchema.HOST_UNIT:
		text += "(%s)" % str(entry.get("host_unit_id", ""))
	elif host == SkillSchema.HOST_POINT:
		text += "(x=%.1f)" % float(entry.get("host_x", 0.0))

	text += " 付与=%s stack=%s" % [str(entry.get("source_unit_id", "")), str(entry.get("stack", ""))]

	if str(entry.get("life", "")) == StatusRegistry.LIFE_SEC:
		text += " 経過 %.2f/%.2f秒" % [
			float(entry.get("elapsed", 0.0)), float(entry.get("duration_sec", 0.0))
		]
	else:
		text += " until=%s 経過 %.2f秒" % [str(entry.get("life", "")), float(entry.get("elapsed", 0.0))]

	if str(entry.get("kind", "")) == StatusRegistry.KIND_BUFF:
		text += " | %s %+d" % [str(entry.get("stat", "")), int(entry.get("value", 0))]
	else:
		var total: int = int(entry.get("fires_total", 0))
		var total_text: String = "無制限" if total == StatusRegistry.FIRES_UNLIMITED else str(total)
		var damage_effect: Dictionary = entry.get("damage_effect", {})
		text += " | 周期 %.2f秒 発火 %d/%s mult %.2f %s" % [
			float(entry.get("interval_sec", 0.0)),
			int(entry.get("fires_done", 0)),
			total_text,
			float(damage_effect.get("multiplier", 0.0)),
			str(damage_effect.get("attack_type", "")),
		]
	return text


# 補正が乗っているユニットだけ、素の値と実効値の両方を出す。
#
# ⚠ これが無いと検証にならない。get_stat() は足したあとの値しか返さないので、
#   F3 パネルの数字だけでは「バフが乗ったのか、元からその値なのか」が分からない。
# ⚠ attack_interval_sec も出す。atkspd のバフは10軸の行ではなく1行目に効くため。
func _print_stat_diffs() -> void:
	if _controller == null:
		return
	var session: BattleSession = _controller.get_session()
	if session == null:
		return
	for u in session.party_units + session.enemy_units:
		if not (u is BattleUnit):
			continue
		var unit: BattleUnit = u as BattleUnit
		var parts: Array[String] = []
		for stat_key in GameManager.get_stat_keys():
			var base_value: int = unit.get_base_stat(str(stat_key))
			var effective: int = unit.get_stat(str(stat_key))
			if base_value != effective:
				parts.append("%s %d→%d" % [str(stat_key), base_value, effective])
		if parts.is_empty():
			continue
		print("  補正 %s(%s): %s | 攻撃間隔 %.3f秒" % [
			_unit_label(unit), unit.unit_id, " ".join(parts), unit.attack_interval_sec
		])


# 画面に出ている名前で表示する。unit_id（party_0 / enemy_1_0）だと
# どのキャラの行か読み替えが要るため。翻訳は ja.csv 側にあるものをそのまま使う。
#
# 同じ敵が複数並ぶので、unit_id の末尾の番号を "#0" として付ける。
# これが無いと「スライム」が3行並んで区別できない。
func _unit_label(unit: BattleUnit) -> String:
	if unit == null:
		return "-"
	var name_text: String = tr(unit.unit_name_key)
	var parts: PackedStringArray = unit.unit_id.split("_")
	if parts.size() > 0:
		return "%s#%s" % [name_text, parts[parts.size() - 1]]
	return name_text


# unit_id から BattleUnit を引く。見つからなければ null。
func _find_unit(unit_id: String) -> BattleUnit:
	if _controller == null or unit_id == "":
		return null
	var session: BattleSession = _controller.get_session()
	if session == null:
		return null
	for u in session.party_units + session.enemy_units:
		if u is BattleUnit and u.unit_id == unit_id:
			return u
	return null


# いま狙っている相手に通る非会心ダメージ。対象がいなければ "-"。
func _format_damage_to_target(unit: BattleUnit) -> String:
	var target: BattleUnit = _find_unit(unit.target_unit_id)
	if target == null:
		return "-"
	var t: String = unit.attack_type
	return str(BattleFormula.damage(
		unit.get_power(t),
		target.get_defense(t),
		unit.atk_multiplier,
		unit.get_stat(GameStateKeys.STAT_CRIT_DMG),
		false
	))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.keycode:
		KEY_F3:
			visible = not visible
		KEY_1:
			_set_time_scale(0)
		KEY_2:
			_set_time_scale(1)
		KEY_3:
			_set_time_scale(2)
		KEY_4:
			_set_time_scale(3)
		KEY_K:
			_call_controller("debug_kill_one_enemy")
		KEY_L:
			_call_controller("debug_kill_all_enemies")
		KEY_S:
			_call_controller("debug_reset_cooldowns")
		KEY_P:
			_print_statuses()
		KEY_J:
			_call_controller("debug_damage_party", [DEBUG_DAMAGE_POWER, BattleUnit.ATTACK_TYPE_PHYSICAL])
		KEY_M:
			_call_controller("debug_damage_party", [DEBUG_DAMAGE_POWER, BattleUnit.ATTACK_TYPE_MAGIC])
		KEY_V:
			_call_controller("debug_force_victory")
		KEY_B:
			_call_controller("debug_force_defeat")
		_:
			return
	get_viewport().set_input_as_handled()


func _set_time_scale(index: int) -> void:
	if index < 0 or index >= TIME_SCALES.size():
		return
	_scale_index = index
	Engine.time_scale = TIME_SCALES[index]
	print("[BattleDebug] time_scale = %.0fx" % Engine.time_scale)


# 引数の数がメソッドごとに違う（0個・2個）ので callv で渡す。
# 以前は「引数1個か0個か」を null で分岐していたが、2個を渡せなかった。
func _call_controller(method: String, args: Array = []) -> void:
	if _controller == null:
		return
	if not _controller.has_method(method):
		push_warning("[BattleDebug] controller に %s が無い" % method)
		return
	_controller.callv(method, args)
