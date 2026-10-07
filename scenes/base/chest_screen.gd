# res://scenes/base/chest_screen.gd
# 届いた宝箱（本部の宝物庫）。
#
# ⚠⚠ 2026-09-27（回UI-組 宝箱・手本 Chest・決定 `BS-21`）：⚠ 拠点の上に重ねていた一覧（`ChestPanel`）を**1枚の画面にした**。
#   ⚠ 人間「⚠ 1あ」＝画面にする（⚠ 入口は拠点の宝箱バッジ・「戻る」で拠点）。
#   ⚠ 人間「⚠ 2あ」＝開けた中身は右の台に札で並べる。⚠ **確かめの窓（受け取る）はやめた**。
#   ⚠ 人間「⚠ 3あ」＝札は箱から浮かび上がる（⚠ 手本 `rise`）。
# ⚠ 左＝紙の「棚の帳面」（⚠ 種類ごとに1行・選ぶ）／ 右＝暗い台（⚠ 開けた宝箱の名前・札・箱・「次を開ける」）。
# ⚠ 開ける仕組みは変えていない（⚠ `open_chest()` が中身を振って配る・2026-09-18）。⚠ ここは見せるだけ。
# ⚠ 帳面の名前は墨（⚠ レアリティの灰や白は紙の上で読めない）。⚠ 色は行の絵の枠（`ItemIcon`）と、⚠ 台の上の名前に出す。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 開けると pending_chests_changed が飛ぶ。
# ⚠ 拠点からしか開かないので scenes/base/（AGENTS.md「1画面だけならその画面のフォルダ」）。

class_name ChestScreen
extends Control

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const THEME_TYPE: StringName = &"ChestScreen"
# ⚠ items.json の item_type に無い札の種類（⚠ 翻訳キー `ui_chest_kind_<種類>` と色 `band_<種類>` の字）。
const KIND_CURRENCY: String = "currency"
const KIND_CHEST: String = "chest"
const KIND_OTHER: String = "other"
# ⚠ 札に持たせる印（⚠ 描くときと検査が読む）。
const META_KIND: StringName = &"chest_kind"
const META_ITEM_ID: StringName = &"chest_item_id"
const META_NEW: StringName = &"chest_new"

@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var ledger: PaperSheet = $Margin/Layout/Body/Ledger
@onready var ledger_body: VBoxContainer = $Margin/Layout/Body/Ledger/LedgerBody
@onready var stage_body: VBoxContainer = $Margin/Layout/Body/Stage/StageBody

# ⚠ 左で選んでいる種類（chest_id）。⚠ 「次を開ける」はこの種類の1個目を開ける。
var _selected_kind: String = ""

var _remain_label: Label = null
var _list: VBoxContainer = null
var _open_all_button: UiButton = null
var _opened_name: Label = null
var _cards: HFlowContainer = null
var _box: ChestBox = null
var _note: Label = null
var _next_button: UiButton = null
# ⚠ 高レアの演出の最中か ／ 台を押して残りを飛ばすか ／ 流した演出の数（⚠ 検査が読む）。
var _fx_busy: bool = false
var _fx_skip: bool = false
var fx_played: int = 0


func _ready() -> void:
	SceneManager.consume_transfer_data()
	header.back_pressed.connect(_on_back_pressed)
	header.set_subtitle_text(tr("ui_chest_subtitle"))
	ledger.custom_minimum_size.x = float(get_theme_constant(&"ledger_width", THEME_TYPE))
	_build_ledger()
	_build_stage()
	GameManager.pending_chests_changed.connect(_on_pending_chests_changed)
	_rebuild_ledger()


# --- 左：棚の帳面 ------------------------------------------------------

func _build_ledger() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.text = tr("ui_chest_ledger")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_remain_label = Label.new()
	_remain_label.name = "RemainLabel"
	_remain_label.theme_type_variation = &"CaptionLabel"
	_remain_label.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_remain_label)
	ledger_body.add_child(head)
	ledger_body.add_child(HSeparator.new())

	# ⚠ 種類が多いと紙からはみ出す（⚠ 検査では27種類）＝⚠ 一覧だけ縦に流す。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ledger_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "ChestList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_open_all_button = UiButton.create(UiButton.Variant.SECONDARY, "ui_chest_open_all")
	_open_all_button.name = "OpenAllButton"
	_open_all_button.pressed.connect(_on_open_all_pressed)
	ledger_body.add_child(_open_all_button)


# 未開封を種類ごとに束ねる。⚠ {chest_id: [instance_id]}。⚠ 並びは入手した順（⚠ Dictionary は入れた順を保つ）。
func _groups() -> Dictionary:
	var groups: Dictionary = {}
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var chest_id: String = str(chest_dict.get(GameStateKeys.CHEST_ID, ""))
		if not groups.has(chest_id):
			groups[chest_id] = []
		(groups[chest_id] as Array).append(str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, "")))
	return groups


# ⚠ その種類の1個目の出どころ（⚠ 戦闘・フロア・難ダンジョン・集中の加護）。⚠ 知らない出どころは出さない。
func _source_text(chest_id: String) -> String:
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if not (chest is Dictionary):
			continue
		if str((chest as Dictionary).get(GameStateKeys.CHEST_ID, "")) != chest_id:
			continue
		var key: String = "ui_chest_source_" + str((chest as Dictionary).get(GameStateKeys.CHEST_SOURCE, ""))
		var text: String = tr(key)
		return "" if text == key else text
	return ""


func _rebuild_ledger() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var groups: Dictionary = _groups()
	var total: int = GameManager.get_pending_chest_count()
	_remain_label.text = tr("ui_chest_remain") % total
	if not groups.has(_selected_kind):
		_selected_kind = str(groups.keys()[0]) if not groups.is_empty() else ""
	# ⚠ 演出の最中は押せない（⚠ 開けると pending_chests_changed でここが走る）。
	_open_all_button.disabled = groups.is_empty() or _fx_busy
	_next_button.disabled = groups.is_empty() or _fx_busy
	_next_button.text = tr("ui_chest_next") % total
	if groups.is_empty():
		_list.add_child(EmptyState.create(
			"ui_warehouse_no_chest", "ui_warehouse_no_chest_hint", IconTextures.for_chest()
		))
		return
	for chest_id: Variant in groups.keys():
		_list.add_child(_make_row(str(chest_id), (groups[chest_id] as Array).size()))


# 1行 ＝ 絵（⚠ 枠がレアリティの色）／ 名前 と 出どころ ／ ×個数。⚠ 押すとその種類を選ぶ。
func _make_row(chest_id: String, count: int) -> LedgerRow:
	var row: LedgerRow = LedgerRow.new()
	row.name = "ChestRow_" + chest_id
	row.selected = chest_id == _selected_kind
	row.pressed.connect(_on_row_pressed.bind(chest_id))
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var glyph: ItemIcon = ItemIcon.create(chest_id)
	glyph.name = "ChestGlyph"
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(glyph)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(column)
	var name_label: Label = Label.new()
	name_label.name = "ChestNameLabel"
	name_label.text = tr(GameManager.item_name_key(chest_id))
	column.add_child(name_label)
	var source: String = _source_text(chest_id)
	if source != "":
		var source_label: Label = Label.new()
		source_label.name = "SourceLabel"
		source_label.theme_type_variation = &"CaptionLabel"
		source_label.text = source
		column.add_child(source_label)
	# ⚠ 数値だけなので tr() を通さない（AGENTS.md）。
	var count_label: Label = Label.new()
	count_label.name = "ChestCountLabel"
	count_label.theme_type_variation = &"SheetHeadingLabel"
	count_label.text = "×%d" % count
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(count_label)
	return row


func _on_row_pressed(chest_id: String) -> void:
	_selected_kind = chest_id
	_rebuild_ledger()


# --- 右：台（開けた宝箱の名前・札・箱・次を開ける） ---------------------------

func _build_stage() -> void:
	# ⚠ 演出の最中に台を押すと残りを飛ばす。⚠ 光の筋が台の外へ出ないよう台で描画を切る。
	var stage: Control = stage_body.get_parent() as Control
	stage.gui_input.connect(_on_stage_gui_input)
	stage.clip_contents = true
	_opened_name = Label.new()
	_opened_name.name = "OpenedName"
	_opened_name.theme_type_variation = &"SheetHeadingLabel"
	_opened_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_body.add_child(_opened_name)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_body.add_child(scroll)
	_cards = HFlowContainer.new()
	_cards.name = "Cards"
	_cards.theme_type_variation = &"ChestCards"
	_cards.alignment = FlowContainer.ALIGNMENT_CENTER
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)

	_box = ChestBox.new()
	_box.name = "Box"
	stage_body.add_child(_box)
	stage_body.add_child(HSeparator.new())

	var foot: HBoxContainer = HBoxContainer.new()
	foot.name = "Foot"
	stage_body.add_child(foot)
	_note = Label.new()
	_note.name = "NoteLabel"
	_note.theme_type_variation = &"MutedLabel"
	_note.text = tr("ui_chest_pick_hint")
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_note)
	# ⚠ この画面の主要動作＝真鍮（⚠ 1画面に1個まで）。
	_next_button = UiButton.create(UiButton.Variant.PRIMARY)
	_next_button.name = "NextButton"
	_next_button.pressed.connect(_on_next_pressed)
	foot.add_child(_next_button)


# --- 開ける ------------------------------------------------------------

# 次を開ける＝選んでいる種類の1個目（⚠ 無ければ帳面の一番上の種類＝`_rebuild_ledger()` が選び直す）。
func _on_next_pressed() -> void:
	var groups: Dictionary = _groups()
	if not groups.has(_selected_kind):
		return
	if _fx_busy:
		return
	var instance_id: String = str((groups[_selected_kind] as Array)[0])
	var chest_id: String = _selected_kind
	# ⚠ 開ける前の図鑑を控える（⚠ 開けたあとに初めて載った品＝しおり紐）。
	var known: Dictionary = _codex_snapshot()
	if not GameManager.open_chest(instance_id):
		push_warning("[ChestScreen] open_chest failed: " + instance_id)
		return
	# ⚠⚠ 中身は**開けたあと**に読む（⚠ `open_chest()` の中で振られ、開けた記録に残る・2026-09-18）。
	var rewards: Dictionary = _read_chest_rewards(instance_id)
	# ⚠ 高い等級の品が出たら演出を見せてから札を並べる（⚠ 人間「⚠ 4あ」・09-28「⚠ 出るアイテムの等級で」）。
	if not await _play_fx([[chest_id, rewards]]):
		return
	_show_rewards(rewards, tr(GameManager.item_name_key(chest_id)), chest_id, known)


func _on_open_all_pressed() -> void:
	if _fx_busy:
		return
	var known: Dictionary = _codex_snapshot()
	var opened_boxes: Array = []
	var opened_count: int = 0
	var combined: Dictionary = _empty_rewards()
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var instance_id: String = str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
		var chest_id: String = str(chest_dict.get(GameStateKeys.CHEST_ID, ""))
		if GameManager.open_chest(instance_id):
			var rewards: Dictionary = _read_chest_rewards(instance_id)
			_merge_rewards(combined, rewards)
			opened_boxes.append([chest_id, rewards])
			opened_count += 1
	# ⚠ まとめて開けるときは**高い等級の品が出た箱ぜんぶ**に演出（⚠ 人間「⚠ まとめて開けるときは全部演出を」）。⚠ 台を押すと残りを飛ばす。
	if not await _play_fx(opened_boxes):
		return
	if opened_count > 0:
		# ⚠ まとめて1回ぶんの札（⚠ 種類が混ざるので名前に色は付けない）。
		_show_rewards(combined, tr("ui_chest_opened_all") % opened_count, "", known)


# --- 高い等級の品の演出（2026-09-27 の見る回・人間「⚠ 4あ」／ 09-28「⚠ 出るアイテムの等級で」「⚠ 1い」） ------

# 中身のいちばん高い色の等級（1〜10・⚠ 札の絵の枠と同じ引き方＝`ItemIcon.grade_of()`）。⚠ お金だけの箱は 0。
func top_grade_of(rewards: Dictionary) -> int:
	var top: int = 0
	for entry: Variant in RewardEntries.slot_entries(rewards):
		var item_id: String = str((entry as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		top = maxi(top, int(ItemIcon.grade_of(item_id, 0).get(ItemIcon.RESULT_GRADE, 0)))
	return top


# 演出を出す等級か（⚠ Theme の `fx_grade`＝5 以上）。
func is_fx_grade(grade: int) -> bool:
	return grade >= get_theme_constant(&"fx_grade", THEME_TYPE)


# 開けた箱（[chest_id, 中身]）の並びのうち、⚠ 高い等級の品が出た箱に1つずつ演出を流す。⚠ 台を押すと残りを飛ばす。
# ⚠ 強い演出は `fx_strong_grade`（8）以上。⚠ 色はその品の等級の色。
# ⚠ 戻りが false なら画面が消えた（⚠ 呼ぶ側は何もしない）。
# ⚠ 演出の間はボタンを押せない（⚠ 2回目の開封が割り込まない）。
func _play_fx(boxes: Array) -> bool:
	var targets: Array = []
	for raw: Variant in boxes:
		var grade: int = top_grade_of((raw as Array)[1])
		if is_fx_grade(grade):
			targets.append([str((raw as Array)[0]), grade])
	if targets.is_empty():
		return true
	_fx_busy = true
	_fx_skip = false
	_next_button.disabled = true
	_open_all_button.disabled = true
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_note.text = tr("ui_chest_fx_skip_hint")
	for target: Variant in targets:
		if _fx_skip:
			break
		var chest_id: String = str((target as Array)[0])
		var grade: int = int((target as Array)[1])
		_opened_name.text = tr(GameManager.item_name_key(chest_id))
		_opened_name.modulate = Balance.icon.color_of_grade(grade) if Balance.icon != null else Color.WHITE
		var strong: bool = grade >= get_theme_constant(&"fx_strong_grade", THEME_TYPE)
		var tween: Tween = _box.play_fx(_opened_name.modulate, strong)
		fx_played += 1
		await tween.finished
		if not is_inside_tree():
			return false
	_fx_busy = false
	_box.stop_fx()
	_box.opened = true
	_rebuild_ledger()
	return true


# ⚠ 演出の最中に台を押したら残りを飛ばす。
func _on_stage_gui_input(event: InputEvent) -> void:
	if not _fx_busy:
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_fx_skip = true
		_box.stop_fx()


# 図鑑に載っている品（item_id -> true）。⚠ 複製（`get_state()`）から読む。
func _codex_snapshot() -> Dictionary:
	var known: Dictionary = {}
	var codex: Variant = GameManager.get_state().get(GameStateKeys.CODEX, {})
	if codex is Dictionary:
		for item_id: Variant in (codex as Dictionary):
			known[str(item_id)] = true
	return known


# 初めて手に入れた品か＝⚠ 開ける前の図鑑に無く、⚠ いまは載っている。
# ⚠ 素材は図鑑に載らない（⚠ `_mark_codex_discovered()` は持ち物と装備だけ）＝⚠ 素材に紐は付かない（⚠ 手本も装飾だけ）。
func _is_new(item_id: String, known: Dictionary) -> bool:
	return not known.has(item_id) and not GameManager.get_codex_entry(item_id).is_empty()


# 開けた中身を台に並べる。⚠ 報酬はもう配り終わっている（⚠ `open_chest()` の中で入っている）＝見せるだけ。
# ⚠ `chest_id` を渡すと名前をレアリティの色で出す（2026-09-18・人間「宝箱を開けるとき…文字の色も」）。
# ⚠ `known` は開ける前の図鑑（⚠ しおり紐の判定）。
func _show_rewards(rewards: Dictionary, title: String, chest_id: String, known: Dictionary) -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_opened_name.text = title
	_opened_name.modulate = Color.WHITE
	if chest_id != "":
		_tint_by_rarity(_opened_name, chest_id)
	_box.opened = true
	_note.text = tr("ui_chest_received")

	var index: int = 0
	# ⚠ 初めて手に入れた品を先に並べる（⚠ まとめて開けると札が多く、⚠ 紐の付いた品が下の行に埋もれる）。
	var entries: Array = RewardEntries.slot_entries(rewards)
	var fresh: Array = entries.filter(func(e: Variant) -> bool:
		return _is_new(str((e as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, "")), known))
	var rest: Array = entries.filter(func(e: Variant) -> bool:
		return not _is_new(str((e as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, "")), known))
	for entry: Variant in fresh + rest:
		var item_id: String = str((entry as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
		var count: int = int((entry as Dictionary).get(GameManager.SLOT_ENTRY_COUNT, 0))
		var card: TiltedSheet = _add_card(index, _kind_of(item_id, rewards), ItemIcon.create(item_id), tr(GameManager.item_name_key(item_id)), count)
		card.set_meta(META_ITEM_ID, item_id)
		card.set_meta(META_NEW, _is_new(item_id, known))
		card.sheet.queue_redraw()
		index += 1
	var amounts: Dictionary = RewardEntries.currency_amounts(rewards)
	for key: String in amounts:
		var icon: TextureRect = TextureRect.new()
		icon.texture = IconTextures.for_resource(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * float(get_theme_constant(&"currency_icon", THEME_TYPE))
		icon.self_modulate = get_theme_color(&"box_line", THEME_TYPE)
		var _card: TiltedSheet = _add_card(index, KIND_CURRENCY, icon, tr("ui_res_" + key), int(amounts[key]))
		index += 1


# 札1枚：上の色の帯（種類）／ 種類 ／ 絵 ／ 名前 ／ ×個数 ／ 初めてならしおり紐。
# ⚠ 箱から浮かび上がる（⚠ 人間「⚠ 3あ」・手本 `rise`）。⚠ 帯と紐は紙の描画に重ねて引く（⚠ 紐の有無は札の meta）。
func _add_card(index: int, kind: String, icon: Control, title: String, count: int) -> TiltedSheet:
	var card: TiltedSheet = TiltedSheet.create(index)
	card.name = "Card_%d" % index
	card.set_meta(META_KIND, kind)
	card.sheet.custom_minimum_size.x = float(get_theme_constant(&"card_width", THEME_TYPE))
	# ⚠ 手本の札に角飾りは無い（⚠ 上の色の帯と重なる）。
	card.sheet.show_corners = false
	card.sheet.draw.connect(_draw_card_marks.bind(card))
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.sheet.add_child(column)
	var kind_label: Label = Label.new()
	kind_label.theme_type_variation = &"CaptionLabel"
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kind_key: String = "ui_chest_kind_" + kind
	kind_label.text = "" if tr(kind_key) == kind_key else tr(kind_key)
	column.add_child(kind_label)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = title
	column.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "×%d" % count
	column.add_child(count_label)
	_cards.add_child(card)
	_rise(card, index)
	return card


# 札の上の色の帯（⚠ 種類ごとの色）と、⚠ 初めて手に入れた品のしおり紐（⚠ 右上・下が切れ込んだ赤い紐）。
func _draw_card_marks(card: TiltedSheet) -> void:
	var sheet: PaperSheet = card.sheet
	var kind: String = str(card.get_meta(META_KIND, KIND_OTHER))
	var color_name: StringName = StringName("band_" + kind)
	if not sheet.has_theme_color(color_name, THEME_TYPE):
		color_name = StringName("band_" + KIND_OTHER)
	var band: float = float(get_theme_constant(&"band", THEME_TYPE))
	sheet.draw_rect(Rect2(Vector2.ZERO, Vector2(sheet.size.x, band)), get_theme_color(color_name, THEME_TYPE))
	if not bool(card.get_meta(META_NEW, false)):
		return
	var w: float = float(get_theme_constant(&"ribbon_w", THEME_TYPE))
	var h: float = float(get_theme_constant(&"ribbon_h", THEME_TYPE))
	var x: float = sheet.size.x - float(get_theme_constant(&"ribbon_inset", THEME_TYPE)) - w
	# ⚠ 手本 `clip-path: polygon(0 0, 100% 0, 100% 100%, 50% 76%, 0 100%)`。
	sheet.draw_colored_polygon(PackedVector2Array([
		Vector2(x, 0.0), Vector2(x + w, 0.0), Vector2(x + w, h), Vector2(x + w * 0.5, h * 0.76), Vector2(x, h),
	]), get_theme_color(&"ribbon", THEME_TYPE))


# ⚠ 下から上がりながら現れる。⚠ Tween は札に結びつける（⚠ 札が消えれば一緒に止まる）。
func _rise(card: TiltedSheet, index: int) -> void:
	var duration: float = float(get_theme_constant(&"rise_ms", THEME_TYPE)) / 1000.0
	# ⚠ 遅れは段数に上限（⚠ まとめて開けると札が数十枚＝最後の札が数秒遅れて出る）。
	var step: int = mini(index, get_theme_constant(&"rise_max_steps", THEME_TYPE))
	var delay: float = float(get_theme_constant(&"rise_step_ms", THEME_TYPE)) * step / 1000.0
	var rise: float = float(get_theme_constant(&"rise_px", THEME_TYPE))
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween().set_speed_scale(GameSettings.effect_speed())
	tween.tween_interval(delay)
	tween.tween_property(card, "modulate:a", 1.0, duration)
	tween.parallel().tween_property(card.sheet, "position:y", 0.0, duration).from(rise) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# 札の種類（素材・装備・装飾…）。⚠ 素材は報酬の materials 側、⚠ ほかは items.json の item_type。
# ⚠ 札の一番上の小さな字（`ui_chest_kind_<種類>`）と、⚠ 上の色の帯（Theme の `band_<種類>`）の両方に使う。
func _kind_of(item_id: String, rewards: Dictionary) -> String:
	var materials: Variant = rewards.get(GameStateKeys.REWARD_MATERIALS, {})
	if materials is Dictionary and (materials as Dictionary).has(item_id):
		return GameStateKeys.ITEM_TYPE_MATERIAL
	if GameManager.is_chest_item(item_id):
		return KIND_CHEST
	var item_type: String = str(MasterDataLoader.get_item(item_id).get("item_type", ""))
	return item_type if item_type != "" else KIND_OTHER


# レアリティの色（2026-09-18）。⚠ 色は `Balance.icon` の10色ランプ（⚠ ここに色を書かない）。
# ⚠ レアリティが無い宝箱（集中の宝箱など）は何もしない。
func _tint_by_rarity(target: CanvasItem, chest_id: String) -> void:
	var rarity: String = GameManager.get_chest_rarity(chest_id)
	if rarity == "" or Balance.icon == null:
		return
	target.modulate = Balance.icon.color_of_grade(
		Balance.icon.grade_of_tier(int(GameManager.CHEST_RARITY_TIERS.get(rarity, 1)), false)
	)


func _empty_rewards() -> Dictionary:
	return {
		GameStateKeys.REWARD_GOLD: 0,
		GameStateKeys.REWARD_GEMS: 0,
		GameStateKeys.REWARD_STAMINA: 0,
		GameStateKeys.REWARD_MATERIALS: {},
		GameStateKeys.REWARD_INVENTORY: {},
	}


func _merge_rewards(combined: Dictionary, add: Dictionary) -> void:
	for key: String in [GameStateKeys.REWARD_GOLD, GameStateKeys.REWARD_GEMS, GameStateKeys.REWARD_STAMINA]:
		combined[key] = int(combined.get(key, 0)) + int(add.get(key, 0))
	for key: String in [GameStateKeys.REWARD_MATERIALS, GameStateKeys.REWARD_INVENTORY]:
		var current: Dictionary = combined.get(key, {})
		var adding: Variant = add.get(key, {})
		if adding is Dictionary:
			for item_id: String in (adding as Dictionary):
				current[item_id] = int(current.get(item_id, 0)) + int((adding as Dictionary)[item_id])
		combined[key] = current


func _read_chest_rewards(instance_id: String) -> Dictionary:
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, "")) == instance_id:
			var rewards_val: Variant = chest_dict.get(GameStateKeys.CHEST_REWARDS, {})
			return rewards_val if rewards_val is Dictionary else {}
	return {}


func _on_pending_chests_changed(_pending_count: int) -> void:
	_rebuild_ledger()


func _on_back_pressed() -> void:
	# ⚠ 10-06（`NAV-19`）：⚠ 入手先の窓から寄り道で来たなら、窓を開いた画面へ。
	SceneManager.go_back_or(BASE_PATH)
