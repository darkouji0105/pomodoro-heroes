# res://scenes/guild/forge_result_window.gd
# 鍛えた結果の窓（2026-10-18・回UI-1018-3・手本 `docs/pomodoro-heroes-ui-docs/2026-10-18/images/03_forge_result_ok.png` / `_ng.png`）。
#
# ⚠ 鍛冶場の上に暗幕と紙を重ねる：⚠ 判（成功 ／ 一部成功 ／ 失敗）／ 鍛える前 → いま（⚠ 値と増えた分）／ 名前・等級 ◯ → ◯
#   ／ 使った素材・鍛冶の腕の次まで ／ 遺物に入った点 ／ 「閉じる」「続けて鍛える（失敗は もう一度鍛える）」。⚠ 外を押しても閉じる。
# ⚠⚠ 09-28 の「結果の画面」（⚠ 紙いっぱいの鍛冶の記録）をやめた（⚠ web版の手本＝人間が作ったもの）。⚠ 判の演出（`FORGE_FX`）は残す。
# ⚠ 鍛冶場でしか使わないので scenes/guild/（AGENTS.md）。⚠ 状態は触らない（⚠ 押されたことを返すだけ）。

class_name ForgeResultWindow
extends Control

signal closed
signal again_pressed

const THEME_TYPE: StringName = &"Forge"
# ⚠ 鍛冶場が控えておく前の値（⚠ `forge_equipment_roll()` の戻り値に足す字）。
const RESULT_STATS_BEFORE: String = "stats_before"
const RESULT_STEPS: String = "steps"

var _instance_id: String = ""
var _result: Dictionary = {}


# ⚠ `result`：`forge_equipment_roll()` の戻り値 ＋ 前の値（`RESULT_STATS_BEFORE`）＋ 何回鍛えたか（`RESULT_STEPS`・まとめて鍛えたとき）。
static func open(host: Control, instance_id: String, result: Dictionary) -> ForgeResultWindow:
	var window: ForgeResultWindow = ForgeResultWindow.new()
	window.name = "ForgeResultWindow"
	window._instance_id = instance_id
	window._result = result
	host.add_child(window)
	return window


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = get_theme_color(&"result_scrim", THEME_TYPE)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var sheet: PaperSheet = PaperSheet.new()
	sheet.name = "Sheet"
	sheet.custom_minimum_size.x = float(get_theme_constant(&"result_width", THEME_TYPE))
	center.add_child(sheet)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = &"SectionStack"
	sheet.add_child(body)
	_build(body)

	var hint: Label = Label.new()
	hint.name = "OutsideHint"
	hint.theme_type_variation = &"MutedLabel"
	hint.text = tr("ui_forge_result_outside")
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.position.y -= float(get_theme_constant(&"result_hint_lift", THEME_TYPE))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build(body: VBoxContainer) -> void:
	var instance: Dictionary = GameManager.get_equipment_instance(_instance_id)
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var success: bool = bool(_result.get(GameManager.FORGE_RESULT_SUCCESS, false))
	var grade_before: int = int(_result.get(GameManager.FORGE_RESULT_GRADE_BEFORE, 1))
	var grade_after: int = int(_result.get(GameManager.FORGE_RESULT_GRADE_AFTER, 1))
	var steps: int = int(_result.get(RESULT_STEPS, 1))

	# 判（⚠ 器に入れる＝⚠ `Container` は子の大きさを毎回戻すので、⚠ 押し付ける演出が効かない）。
	var seal_holder: Control = Control.new()
	seal_holder.name = "SealHolder"
	seal_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(seal_holder)
	var seal: Stamp = Stamp.new()
	seal.name = "ResultStamp"
	seal.label_key = "ui_forge_success" if success else "ui_forge_fail"
	seal_holder.add_child(seal)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ArrowRow"
	row.theme_type_variation = &"ForgeArrowRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	var before: Dictionary = _result.get(RESULT_STATS_BEFORE, {})
	var after: Dictionary = GameManager.get_instance_stats(_instance_id)
	var stat_key: String = BelongingsDetail.main_stat_of(after)
	var before_value: int = int(before.get(stat_key, 0))
	var after_value: int = int(after.get(stat_key, 0))
	row.add_child(_cell_with_caption(item_id, grade_before, tr("ui_forge_before"), _stat_line(stat_key, before_value, 0), &""))
	var arrow: Label = Label.new()
	arrow.theme_type_variation = &"LevelArrowLabel"
	arrow.text = tr("ui_forge_arrow")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	var now: VBoxContainer = _cell_with_caption(item_id, grade_after, tr("ui_forge_now"), _stat_line(stat_key, after_value, after_value - before_value),
		&"GainLabel" if success and after_value > before_value else &"")
	now.name = "NowColumn"
	row.add_child(now)

	var title: Label = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = &"SheetHeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr("ui_forge_result_title") % [tr(GameManager.item_name_key(item_id)), grade_before, grade_after]
	body.add_child(title)
	if not success:
		body.add_child(_caption("NotLowered", tr("ui_forge_result_not_lowered")))
	elif steps > 1:
		body.add_child(_caption("Steps", tr("ui_forge_result_steps") % steps))
	var used: Array[String] = []
	used.append(tr("ui_forge_result_used") % [tr("ui_res_" + str(_result.get(GameManager.FORGE_RESULT_MATERIAL_ID, ""))), int(_result.get(GameManager.FORGE_RESULT_AMOUNT, 0))])
	if bool(_result.get(GameManager.FORGE_RESULT_USED_TOKEN, false)):
		used.append(tr("ui_forge_result_used_token"))
	var to_next: int = GameManager.get_forge_exp_to_next()
	used.append(tr("ui_forge_level_next") % to_next if to_next > 0 else tr("ui_forge_level_max"))
	body.add_child(_caption("UsedLine", "　".join(used)))
	# ⚠ 遺物に点が入った（⚠ 10-09・`EQ-8`＝鍛えるたびに・成功でも失敗でも）。
	var relic_id: String = str(_result.get(GameManager.FORGE_RESULT_RELIC_ID, ""))
	if relic_id != "":
		var relic: Label = _caption("RelicGainText", tr("ui_grelic_offer_preview_short") % [
			tr(str(MasterDataLoader.get_guild_relic(relic_id).get("name_key", ""))), int(_result.get(GameManager.FORGE_RESULT_RELIC_POINTS, 0))])
		relic.theme_type_variation = &"AccentLabel"
		body.add_child(relic)
	# ⚠ 遺物に捧げられる等級に届いた（⚠ 手本「等級5になった。遺物に捧げられる」）。
	var offer_from: int = GameManager.get_guild_relic_grade_min()
	if success and grade_before < offer_from and grade_after >= offer_from:
		var offer: Label = _caption("OfferReached", tr("ui_forge_result_offer_reached") % grade_after)
		offer.theme_type_variation = &"AccentLabel"
		body.add_child(offer)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.theme_type_variation = &"ButtonRow"
	body.add_child(buttons)
	var close_button: Button = UiButton.create_paper_choice("ui_common_close")
	close_button.name = "CloseButton"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	buttons.add_child(close_button)
	# ⚠ 「続けて鍛える」（⚠ 09-28 人間「⚠ 続けて鍛えるで元の画面に戻らないで」＝その場でもう一度）。⚠ 最大か素材が足りなければ押せない。
	var again: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_forge_continue" if success else "ui_forge_retry")
	again.name = "ContinueButton"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_stretch_ratio = 1.6
	again.disabled = not GameManager.can_forge(_instance_id)
	again.pressed.connect(_on_again_pressed)
	buttons.add_child(again)
	seal.ready.connect(_play_seal.bind(seal_holder, seal, now, success))


func _caption(node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.theme_type_variation = &"CaptionLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	return label


# 「攻撃 +14 （+3）」。
func _stat_line(stat_key: String, value: int, delta: int) -> String:
	if stat_key == "":
		return ""
	var text: String = "%s %s" % [tr("ui_training_stat_" + stat_key), BelongingsDetail.stat_text(stat_key, value)]
	if delta > 0:
		text += "  (%s)" % BelongingsDetail.stat_text(stat_key, delta)
	return text


func _cell_with_caption(item_id: String, grade: int, caption: String, value: String, variation: StringName) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var cell: ItemCell = ItemCell.create({
		GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_INSTANCE,
		GameManager.SLOT_ENTRY_ITEM_ID: item_id,
		GameManager.SLOT_ENTRY_INSTANCE_ID: _instance_id,
		GameManager.SLOT_ENTRY_GRADE: grade,
	}, get_theme_constant(&"result_icon", THEME_TYPE))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(cell)
	column.add_child(_caption("Caption", caption))
	var value_label: Label = Label.new()
	value_label.name = "ValueLabel"
	value_label.theme_type_variation = variation if variation != &"" else &"DossierLevelLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.text = value
	column.add_child(value_label)
	return column


# 判の演出（⚠ 大きく現れて押し付けられる ／ ⚠ 失敗は左右に震える ／ ⚠ 成功は新しい絵がふくらむ）。⚠ 値は Theme の `Forge`（`FORGE_FX`）。
func _play_seal(holder: Control, seal: Stamp, now: Control, success: bool) -> void:
	var final_scale: float = float(get_theme_constant(&"fx_seal_scale_pct", THEME_TYPE)) / 100.0
	seal.size = seal.custom_minimum_size
	holder.custom_minimum_size = seal.custom_minimum_size * final_scale
	seal.position = (holder.custom_minimum_size - seal.size) * 0.5
	seal.pivot_offset = seal.size * 0.5
	var delay: float = float(get_theme_constant(&"fx_delay_ms", THEME_TYPE)) / 1000.0
	var slam: float = float(get_theme_constant(&"fx_slam_ms", THEME_TYPE)) / 1000.0
	seal.scale = Vector2.ONE * float(get_theme_constant(&"fx_slam_scale_pct", THEME_TYPE)) / 100.0
	seal.modulate.a = 0.0
	var tween: Tween = seal.create_tween().set_speed_scale(GameSettings.effect_speed())
	tween.tween_interval(delay)
	tween.tween_property(seal, "modulate:a", 1.0, slam)
	tween.parallel().tween_property(seal, "scale", Vector2.ONE * final_scale, slam).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var after: float = float(get_theme_constant(&"fx_after_ms", THEME_TYPE)) / 1000.0
	var icon_tween: Tween = now.create_tween().set_speed_scale(GameSettings.effect_speed())
	icon_tween.tween_interval(delay + slam)
	icon_tween.tween_callback(func() -> void: now.pivot_offset = now.size * 0.5)
	if success:
		var pulse: float = float(get_theme_constant(&"fx_pulse_pct", THEME_TYPE)) / 100.0
		icon_tween.tween_property(now, "scale", Vector2.ONE * pulse, after * 0.5)
		icon_tween.parallel().tween_property(now, "modulate", get_theme_color(&"fx_glow", THEME_TYPE), after * 0.5)
		icon_tween.tween_property(now, "scale", Vector2.ONE, after * 0.5)
		icon_tween.parallel().tween_property(now, "modulate", Color.WHITE, after * 0.5)
	else:
		var shake: float = float(get_theme_constant(&"fx_shake_px", THEME_TYPE))
		var steps: int = get_theme_constant(&"fx_shake_steps", THEME_TYPE)
		var base_x: float = seal.position.x
		for i: int in range(steps):
			var offset: float = shake * (1.0 - float(i) / float(steps)) * (1.0 if i % 2 == 0 else -1.0)
			tween.tween_property(seal, "position:x", base_x + offset, after / float(steps))
		tween.tween_property(seal, "position:x", base_x, after / float(steps))
		icon_tween.tween_property(now, "modulate", get_theme_color(&"fx_dim", THEME_TYPE), after)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		close()


func close() -> void:
	closed.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


func _on_again_pressed() -> void:
	again_pressed.emit()
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
