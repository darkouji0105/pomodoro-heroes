# res://scenes/guild/guild_relic_screen.gd
# 拠点の遺物（2026-10-07・回HB-3・`EQ-8`・`EXEC_GUILD_RELIC.md`・人間「⚠ １　う　分解でたまる形に　２あ　３あ　４あ　５あ」）。
#
# ⚠ 左＝遺物6つ（段・次の段までの点数・いまと次の効き目）。⚠ 右＝祭壇（等級5以上・誰も着けていない装備）。
# ⚠ 捧げる＝分解（`GameManager.dismantle_equipment()` の1本）。⚠ 素材は分解と同じく戻り、その等級の遺物に点数が入る。
# ⚠ 10-07（見る回22回目・人間「⚠ 鍛冶場の中に遺物のカテゴリを」）：⚠ 鍛冶場のタブ（鍛える／作る／遺物）の3つめ。⚠ 部屋は鍛冶場。
#   ⚠ 「⚠ ささげるとポイントがたまるのもわかるように」：⚠ 遺物ごとの目盛り・捧げたら窓で知らせ・目盛りが伸びる。
#   ⚠ 「⚠ 遺物にはアイコンを」：⚠ 品の絵の部品（`ItemIcon`）・枠は育つ等級の色。
# ⚠ 寸法は Theme の `GuildRelic` 型。
# ⚠ 描き直しに await を持たせない（CLAUDE.md 5番＝`remove_child()` してから `queue_free()`）。

class_name GuildRelicScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"GuildRelic"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var main_stack: VBoxContainer = $Margin/Layout/Body/Main
@onready var relic_sheet: PaperSheet = $Margin/Layout/Body/Main/RelicSheet
@onready var altar_sheet: PaperSheet = $Margin/Layout/Body/AltarSheet

var _selected: String = ""
var _notice: String = ""
# ⚠ いま点数が入った遺物と、入る前の目盛り（⚠ 描き直したあとに目盛りを伸ばして見せる）。
var _gained_relic: String = ""
var _gained_from: int = 0
var _gained_points: int = 0


func _ready() -> void:
	header.back_pressed.connect(_on_back_pressed)
	header.set_subtitle_text(tr("ui_grelic_subtitle"))
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.FORGE)
	var tabs: PaperTabs = ForgeScreen.create_tabs(ForgeScreen.TAB_RELIC_ID)
	main_stack.add_child(tabs)
	main_stack.move_child(tabs, 0)
	altar_sheet.custom_minimum_size.x = float(get_theme_constant(&"altar_width", THEME_TYPE))
	GameManager.guild_relic_changed.connect(_on_relic_changed)
	GameManager.equipment_instances_changed.connect(_on_instances_changed)
	_rebuild()


func _rebuild() -> void:
	_fill(relic_sheet, _build_relics())
	_fill(altar_sheet, _build_altar())


func _fill(sheet: PaperSheet, body: Control) -> void:
	for child: Node in sheet.get_children():
		sheet.remove_child(child)
		child.queue_free()
	sheet.add_child(body)


# --- 左：遺物 ---------------------------------------------------------

func _build_relics() -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "RelicBody"
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_grelic_list_title"
	body.add_child(heading)
	# ⚠ 送れる形（⚠ 1回目の絵：6つ目が帯の裏に隠れ、⚠ その高さに引っ張られて右の「捧げる」も隠れた）。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var ids: Array[String] = MasterDataLoader.get_guild_relic_ids()
	for i: int in range(ids.size()):
		rows.add_child(_relic_row(ids[i], i == ids.size() - 1))
	return body


func _relic_row(relic_id: String, last: bool) -> LedgerRow:
	var relic: Dictionary = MasterDataLoader.get_guild_relic(relic_id)
	var level: int = GameManager.get_guild_relic_level(relic_id)
	var max_level: int = GameManager.get_guild_relic_max_level(relic_id)
	var progress: Dictionary = GameManager.get_guild_relic_progress(relic_id)
	var row: LedgerRow = LedgerRow.new()
	row.name = "Relic_" + relic_id
	row.compact = true
	row.show_rule = not last
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer: HBoxContainer = HBoxContainer.new()
	row.add_child(outer)
	# ⚠ アイコン（⚠ 枠の色＝育つ等級）。
	var icon: ItemIcon = ItemIcon.create(relic_id, int(relic.get(MasterDataLoader.GUILD_RELIC_GRADE, 0)))
	icon.name = "RelicIcon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	outer.add_child(icon)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(lines)
	var top: HBoxContainer = HBoxContainer.new()
	lines.add_child(top)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr(str(relic.get("name_key", relic_id)))
	top.add_child(name_label)
	var grade_label: Label = Label.new()
	grade_label.theme_type_variation = &"CaptionLabel"
	grade_label.text = tr("ui_grelic_grows_by") % int(relic.get(MasterDataLoader.GUILD_RELIC_GRADE, 0))
	grade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grade_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(grade_label)
	var level_label: Label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = tr("ui_grelic_level") % [level, max_level]
	top.add_child(level_label)
	var bottom: HBoxContainer = HBoxContainer.new()
	lines.add_child(bottom)
	var effect: Label = Label.new()
	effect.name = "EffectLabel"
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var now_text: String = effect_text(relic_id, GameManager.get_guild_relic_value(relic_id))
	if level >= max_level:
		effect.text = now_text
	else:
		effect.text = tr("ui_grelic_effect_next") % [now_text, effect_text(relic_id, GameManager.get_guild_relic_value(relic_id, level + 1))]
	bottom.add_child(effect)
	var points: Label = Label.new()
	points.name = "PointsLabel"
	points.theme_type_variation = &"CaptionLabel"
	var need: int = int(progress.get(GameManager.GUILD_RELIC_PROGRESS_NEED, 0))
	var have: int = int(progress.get(GameManager.GUILD_RELIC_PROGRESS_HAVE, 0))
	points.text = tr("ui_grelic_max") if need <= 0 else tr("ui_grelic_points") % [have, need]
	bottom.add_child(points)
	# ⚠ 点数の目盛り（⚠ 次の段まで）。⚠ 最大なら満ちたまま。
	var gauge: ProgressBar = ProgressBar.new()
	gauge.name = "PointsGauge"
	gauge.show_percentage = false
	gauge.theme_type_variation = &"LevelBar"   # ⚠ 育成のレベルの進みと同じ細い帯（溝＋真鍮）
	gauge.custom_minimum_size.y = float(get_theme_constant(&"height", &"LevelBar"))
	gauge.max_value = float(maxi(need, 1))
	gauge.value = float(need) if need <= 0 else float(have)
	if need <= 0:
		gauge.max_value = 1.0
		gauge.value = 1.0
	lines.add_child(gauge)
	# ⚠ いま点数が入った遺物は、⚠ 入る前の目盛りから伸ばす（⚠ 段が上がったときは0から）。
	if relic_id == _gained_relic:
		var target: float = gauge.value
		gauge.value = minf(float(_gained_from), target) if _gained_from <= have else 0.0
		var tween: Tween = gauge.create_tween()
		tween.tween_property(gauge, "value", target, 0.6 / GameSettings.effect_speed())
		var gained: Label = Label.new()
		gained.name = "GainedLabel"
		gained.theme_type_variation = &"GainLabel"
		gained.text = tr("ui_grelic_gained") % _gained_points
		top.add_child(gained)
		top.move_child(gained, level_label.get_index())
	return row


# 「攻撃 +6」「受ける回復 +10%」。⚠ 0 なら「なし」。
static func effect_text(relic_id: String, value: int) -> String:
	if value <= 0:
		return TranslationServer.translate("ui_grelic_effect_none")
	var relic: Dictionary = MasterDataLoader.get_guild_relic(relic_id)
	var axis: String = str(relic.get(MasterDataLoader.GUILD_RELIC_AXIS, ""))
	if axis == MasterDataLoader.GUILD_RELIC_AXIS_STAT:
		var names: Array[String] = []
		for stat_key: Variant in (relic.get(MasterDataLoader.GUILD_RELIC_STATS, []) as Array):
			names.append(TranslationServer.translate("ui_training_stat_" + str(stat_key)))
		return "%s +%d" % ["・".join(names), value]
	return TranslationServer.translate("ui_grelic_effect_" + axis) % value


# --- 右：祭壇 ---------------------------------------------------------

func _build_altar() -> VBoxContainer:
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "AltarBody"
	var heading: SheetHeading = SheetHeading.new()
	heading.title_key = "ui_grelic_altar_title"
	body.add_child(heading)
	var caption: Label = Label.new()
	caption.theme_type_variation = &"CaptionLabel"
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.text = tr("ui_grelic_altar_hint")
	body.add_child(caption)
	var views: Array = GameManager.get_offerable_instances()
	if not _has_view(views, _selected):
		_selected = ""
	if views.is_empty():
		body.add_child(EmptyState.create("ui_grelic_altar_empty", "ui_grelic_altar_empty_hint"))
	else:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(scroll)
		var rows: VBoxContainer = VBoxContainer.new()
		rows.name = "Rows"
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		for raw: Variant in views:
			rows.add_child(_offer_row(raw as Dictionary))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL if views.is_empty() else Control.SIZE_FILL
	body.add_child(spacer)
	var preview: Label = Label.new()
	preview.name = "OfferPreview"
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.text = _preview_text()
	body.add_child(preview)
	var notice: Label = Label.new()
	notice.name = "NoticeLabel"
	notice.theme_type_variation = &"CaptionLabel"
	notice.text = _notice
	body.add_child(notice)
	var offer: UiButton = UiButton.create(UiButton.Variant.PRIMARY, "ui_grelic_offer")
	offer.name = "OfferButton"
	offer.disabled = _selected == ""
	offer.pressed.connect(_on_offer_pressed)
	body.add_child(offer)
	return body


func _offer_row(view: Dictionary) -> LedgerRow:
	var instance_id: String = str(view.get(GameManager.INSTANCE_VIEW_ID, ""))
	var item_id: String = str(view.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var grade: int = int(view.get(GameStateKeys.INSTANCE_GRADE, 1))
	var row: LedgerRow = LedgerRow.new()
	row.name = "Offer_" + instance_id
	row.compact = true
	row.selected = instance_id == _selected
	row.pressed.connect(_on_offer_row_pressed.bind(instance_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	line.add_child(ItemIcon.create(item_id, grade))
	var name_label: Label = Label.new()
	name_label.text = tr(GameManager.item_name_key(item_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	var relic_label: Label = Label.new()
	relic_label.theme_type_variation = &"CaptionLabel"
	relic_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	relic_label.text = tr(str(MasterDataLoader.get_guild_relic(GameManager.get_guild_relic_of_grade(grade)).get("name_key", "")))
	line.add_child(relic_label)
	return row


func _has_view(views: Array, instance_id: String) -> bool:
	for raw: Variant in views:
		if str((raw as Dictionary).get(GameManager.INSTANCE_VIEW_ID, "")) == instance_id:
			return true
	return false


# 「力の遺物 +1 点 ／ 戻る素材 25 個」。
func _preview_text() -> String:
	if _selected == "":
		return tr("ui_grelic_pick_hint")
	var offer: Dictionary = GameManager.get_offer_preview(_selected)
	if offer.is_empty():
		return ""
	var relic_name: String = tr(str(MasterDataLoader.get_guild_relic(str(offer[GameManager.OFFER_RELIC_ID])).get("name_key", "")))
	return tr("ui_grelic_offer_preview") % [relic_name, int(offer[GameManager.OFFER_POINTS]), GameManager.get_dismantle_refund_total(_selected)]


# --- 操作 -------------------------------------------------------------

func _on_offer_row_pressed(instance_id: String) -> void:
	_selected = instance_id
	_notice = ""
	_gained_relic = ""
	_rebuild()


func _on_offer_pressed() -> void:
	if _selected == "":
		return
	var instance_id: String = _selected
	var item_id: String = str(GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var ok: bool = await Modal.confirm(self, "ui_grelic_offer_confirm", [tr(GameManager.item_name_key(item_id))], false, {
		Modal.OPTION_TITLE: tr("ui_grelic_offer"),
	})
	if not ok:
		return
	var offer: Dictionary = GameManager.get_offer_preview(instance_id)
	var relic_id: String = str(offer.get(GameManager.OFFER_RELIC_ID, ""))
	var from: int = int(GameManager.get_guild_relic_progress(relic_id).get(GameManager.GUILD_RELIC_PROGRESS_HAVE, 0))
	if GameManager.dismantle_equipment(instance_id):
		_selected = ""
		_gained_relic = relic_id
		_gained_from = from
		_gained_points = int(offer.get(GameManager.OFFER_POINTS, 0))
		_notice = tr("ui_grelic_offered") % [
			tr(str(MasterDataLoader.get_guild_relic(relic_id).get("name_key", ""))),
			_gained_points,
		]
		_rebuild()
		notify_offered(self, offer)
		return
	_notice = tr("ui_grelic_offer_failed")
	_rebuild()


# ⚠ 捧げたあとの知らせ（⚠ 鍛冶場の「鍛える」からも呼ぶ＝同じ文）。
#   「力の遺物に 1 点入った（Lv 2・次まで 1 / 3 点）」。
static func notify_offered(caller: Node, offer: Dictionary) -> void:
	var relic_id: String = str(offer.get(GameManager.OFFER_RELIC_ID, ""))
	if relic_id == "":
		return
	var relic_name: String = TranslationServer.translate(str(MasterDataLoader.get_guild_relic(relic_id).get("name_key", "")))
	var progress: Dictionary = GameManager.get_guild_relic_progress(relic_id)
	var need: int = int(progress.get(GameManager.GUILD_RELIC_PROGRESS_NEED, 0))
	var options: Dictionary = {Modal.OPTION_TITLE: TranslationServer.translate("ui_grelic_offer")}
	if need <= 0:
		Modal.notify(caller, "ui_grelic_offered_max", [relic_name, int(offer.get(GameManager.OFFER_POINTS, 0)), GameManager.get_guild_relic_level(relic_id)], false, options)
	else:
		Modal.notify(caller, "ui_grelic_offered_notify", [relic_name, int(offer.get(GameManager.OFFER_POINTS, 0)), GameManager.get_guild_relic_level(relic_id),
			int(progress.get(GameManager.GUILD_RELIC_PROGRESS_HAVE, 0)), need], false, options)


func _on_relic_changed(_relic_id: String) -> void:
	_rebuild()


func _on_instances_changed(_instance_id: String) -> void:
	_rebuild()


func _on_back_pressed() -> void:
	SceneManager.go_back_or(BASE_PATH)
