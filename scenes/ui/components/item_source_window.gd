class_name ItemSourceWindow
extends VBoxContainer

# 品の入手先の窓（2026-10-06・人間「⚠ 足りない素材など、素材の入手にすぐ行けるようにしたい
#   ⚠ 入手方法を提示する窓と、そこに行くボタンがある専用の窓を今のうちに共通のコンポーネントとして作る」・`NAV-19`）。
#
# ⚠ 使い方：`ItemSourceWindow.open(self, item_id, 要る数, 戻ったときに渡すデータ)` の1行。
# ⚠ 入手先は `GameManager.get_item_sources()` の1本（⚠ この部品は並べて行き先へ送るだけ＝判定を持たない）。
# ⚠ 行き先へは**寄り道**で行く（`NAV-18`）＝⚠ 行き先の「戻る」で、窓を開いた画面へ（⚠ `return_data` の姿で）戻る。
#   ⚠ ポモドーロだけは寄り道にしない（⚠ 終われば本部で受け取りを出す＝今までどおり）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

const CHEST_PATH: String = "res://scenes/base/chest_screen.tscn"
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
const SORTIE_PATH: String = "res://scenes/adventure/party_preset_screen.tscn"
const ADVENTURE_PATH: String = "res://scenes/adventure/adventure_select.tscn"
const POMODORO_PATH: String = "res://scenes/pomodoro/pomodoro.tscn"

# ⚠ 行き先ごとの「行く」の字（⚠ 何をしに行くかが分かるように）。
const GO_KEYS: Dictionary = {
	GameManager.ITEM_SOURCE_PENDING_CHEST: "ui_source_go_chest",
	GameManager.ITEM_SOURCE_SHOP: "ui_source_go_shop",
	GameManager.ITEM_SOURCE_STAGE: "ui_source_go_stage",
	GameManager.ITEM_SOURCE_DUNGEON: "ui_source_go_dungeon",
	GameManager.ITEM_SOURCE_POMODORO: "ui_source_go_pomodoro",
	GameManager.ITEM_SOURCE_USE_POTION: "ui_source_go_use_potion",
}

var _item_id: String = ""
var _need: int = 0
# ⚠ 目標にする数（2026-10-09・回AUTO-1）。⚠ -1 ＝まだ決めていない（⚠ 初めて描くときに決める）。
var _goal_target: int = -1
var _return_path: String = ""
var _return_data: Dictionary = {}


# ⚠ 足りなければ入手先の窓を出して true（2026-10-07・人間「⚠ プラスボタン押さなくても　例えば必要な素材を提示する画面などがあれば」）。
#   ⚠ 呼ぶ側は「押したら」これを先に聞き、true なら何もしない（⚠ ボタンは足りなくても押せる＝押すと何が足りないかとその入手先が出る）。
static func open_if_short(caller: Node, item_id: String, need: int, return_data: Dictionary = {}) -> bool:
	if item_id == "" or need <= 0 or GameManager.get_resource_amount(item_id) >= need:
		return false
	var _window: ModalDialog = open(caller, item_id, need, return_data)
	return true


# ⚠ アイコンを押しても窓（2026-10-07・人間「⚠ アイコンをクリックしても窓が出るように」）。
#   ⚠ 品・素材を見せているアイコンに1行で付ける。⚠ 指の形・触れると「入手先を見る」。⚠ 戻ったときの姿は画面が預けたもの。
#   ⚠ 一覧の行の中のアイコン（⚠ 押すと行を選ぶ）には付けない（⚠ 行の選び方が変わる）。
static func attach_to(control: Control, item_id: String, need: int = 0) -> void:
	if control == null or item_id == "":
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.tooltip_text = TranslationServer.translate("ui_source_open")
	control.gui_input.connect(_on_attached_input.bind(control, item_id, need))


static func _on_attached_input(event: InputEvent, control: Control, item_id: String, need: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	control.accept_event()
	var _window: ModalDialog = open(control, item_id, need)


# ⚠ 窓を出す。⚠ 戻り先は呼んだ画面（`current_scene`）。
static func open(caller: Node, item_id: String, need: int = 0, return_data: Dictionary = {}) -> ModalDialog:
	# ⚠ 渡されなければ、画面が預けた「戻ってきたときの姿」（`SceneManager.current_return_data()`）。
	if return_data.is_empty():
		return_data = SceneManager.current_return_data()
	var content: ItemSourceWindow = create(item_id, need, caller.get_tree().current_scene.scene_file_path, return_data)
	return Modal.notify(caller, "", [], false, {
		Modal.OPTION_TITLE: TranslationServer.translate("ui_source_title"),
		Modal.OPTION_CONTENT: content,
		Modal.OPTION_PAPER: true,
		Modal.OPTION_WIDTH: Modal.WIDTH_MEDIUM,
		Modal.OPTION_CLOSE_OUTSIDE: true,
	})


static func create(item_id: String, need: int, return_path: String, return_data: Dictionary) -> ItemSourceWindow:
	var window: ItemSourceWindow = ItemSourceWindow.new()
	window.name = "ItemSourceWindow"
	window._item_id = item_id
	window._need = need
	window._return_path = return_path
	window._return_data = return_data.duplicate(true)
	return window


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rebuild()


# ⚠ その場で使ったとき（スタミナポーション）に数を描き直す。⚠ remove_child() してから queue_free()（CLAUDE.md 5番）。
func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_build_head()
	_build_goal_row()
	add_child(HSeparator.new())
	var sources: Array[Dictionary] = GameManager.get_item_sources(_item_id)
	if sources.is_empty():
		add_child(EmptyState.create("ui_source_none", "ui_source_none_hint"))
		return
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "SourceList"
	list.theme_type_variation = &"TightList"
	add_child(list)
	for i: int in range(sources.size()):
		list.add_child(_make_row(i, sources[i]))


# 頭：絵 ／ 名前 ／ 持っている数（⚠ 要る数を渡されたら「n ／ 要る m」・足りなければ赤）。
func _build_head() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	# ⚠ 通貨・スタミナは品のマスではなく資源の絵（⚠ チップと同じ絵と色）。
	if _item_id in ResourceBar.CURRENCY_IDS:
		var icon: TextureRect = TextureRect.new()
		icon.name = "ResourceIcon"
		icon.texture = IconTextures.for_resource(_item_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var side: float = float(get_theme_constant(&"icon", &"CurrencyChip")) * 2.0
		icon.custom_minimum_size = Vector2(side, side)
		icon.modulate = ResourceBar.icon_color_for(_item_id, self)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(icon)
	else:
		head.add_child(ItemIcon.create(_item_id))
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.theme_type_variation = &"SheetHeadingLabel"
	name_label.text = tr(GameManager.item_name_key(_item_id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_label)
	var owned: int = GameManager.get_resource_amount(_item_id)
	var count_label: Label = Label.new()
	count_label.name = "OwnedLabel"
	count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _need > 0:
		count_label.text = tr("ui_source_owned_need") % [owned, _need]
		count_label.theme_type_variation = &"" if owned >= _need else &"ErrorLabel"
	else:
		count_label.text = tr("ui_source_owned") % owned
	head.add_child(count_label)
	add_child(head)


# 目標の行（2026-10-09・回AUTO-1・人間「⚠ その個数とか指定した後一時的にクエストにする」）：
#   ⚠ 「目標 [−] n [＋] ［目標にする］」。⚠ n は「持っている数がいくつに届けばよいか」。
#   ⚠ 初めの数＝要る数（⚠ 渡されなければ持っている数 ＋ 1）。⚠ いまの目標がこの品だけならその数。
#   ⚠ スタミナは目標にしない（⚠ 時間で戻るもの）。
func _build_goal_row() -> void:
	if _item_id == GameStateKeys.STAMINA:
		return
	var owned: int = GameManager.get_resource_amount(_item_id)
	var current: Dictionary = GameManager.get_goal().get(GameStateKeys.GOAL_LINES, {})
	var is_current: bool = current.size() == 1 and current.has(_item_id)
	if _goal_target < 0:
		_goal_target = int(current[_item_id]) if is_current else maxi(_need, owned + 1)
	_goal_target = maxi(_goal_target, owned + 1)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "GoalRow"
	var caption: Label = Label.new()
	caption.name = "GoalCaption"
	caption.theme_type_variation = &"CaptionLabel"
	caption.text = tr("ui_goal_current" if is_current else "ui_goal_title")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var minus: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_goal_minus")
	minus.name = "GoalMinus"
	minus.disabled = _goal_target <= owned + 1
	minus.pressed.connect(_on_goal_step.bind(-1))
	row.add_child(minus)
	var count: Label = Label.new()
	count.name = "GoalCount"
	count.text = str(_goal_target)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.custom_minimum_size.x = float(get_theme_constant(&"stepper_width", &"Goal"))
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(count)
	var plus: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_goal_plus")
	plus.name = "GoalPlus"
	plus.pressed.connect(_on_goal_step.bind(1))
	row.add_child(plus)
	var set_key: String = "ui_goal_set"
	if is_current:
		set_key = "ui_goal_change"
	elif GameManager.has_goal():
		set_key = "ui_goal_replace"
	var set_button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, set_key)
	set_button.name = "GoalSetButton"
	set_button.disabled = is_current and int(current[_item_id]) == _goal_target
	set_button.pressed.connect(_on_goal_set_pressed)
	row.add_child(set_button)
	add_child(row)


func _on_goal_step(step: int) -> void:
	_goal_target += step
	_rebuild()


func _on_goal_set_pressed() -> void:
	if GameManager.set_goal({_item_id: _goal_target}, GameStateKeys.GOAL_ORIGIN_ITEM, _item_id, _goal_target):
		_rebuild()


# 1行：何で（小さい字）・どこで（名前）・行く。⚠ まだ行けないところは押せず、理由を添える。
func _make_row(index: int, source: Dictionary) -> LedgerRow:
	var kind: String = str(source.get(GameManager.ITEM_SOURCE_KIND, ""))
	var ref: String = str(source.get(GameManager.ITEM_SOURCE_REF, ""))
	var open: bool = bool(source.get(GameManager.ITEM_SOURCE_OPEN, false))
	var row: LedgerRow = LedgerRow.new()
	row.name = "Source_%d" % index
	row.compact = true
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: HBoxContainer = HBoxContainer.new()
	row.add_child(line)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	var kind_label: Label = Label.new()
	kind_label.name = "KindLabel"
	kind_label.theme_type_variation = &"CaptionLabel"
	kind_label.text = tr("ui_source_kind_" + kind)
	column.add_child(kind_label)
	var where: Label = Label.new()
	where.name = "WhereLabel"
	where.text = _where_text(kind, ref, int(source.get(GameManager.ITEM_SOURCE_COUNT, 0)))
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(where)
	if not open:
		var locked: Label = Label.new()
		locked.name = "LockedLabel"
		locked.theme_type_variation = &"CaptionLabel"
		locked.text = tr("ui_source_locked")
		column.add_child(locked)
	var go: UiButton = UiButton.create(UiButton.Variant.SECONDARY, str(GO_KEYS.get(kind, "ui_source_go")))
	go.name = "GoButton"
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = not open
	go.pressed.connect(_on_go_pressed.bind(kind, ref))
	line.add_child(go)
	return row


func _where_text(kind: String, ref: String, count: int) -> String:
	match kind:
		GameManager.ITEM_SOURCE_PENDING_CHEST:
			return tr("ui_source_where_chest") % [tr(str(MasterDataLoader.get_chest(ref).get(GameManager.CHEST_NAME_KEY, ref))), count]
		GameManager.ITEM_SOURCE_SHOP:
			return tr("ui_source_where_shop_" + ref)
		GameManager.ITEM_SOURCE_STAGE:
			var order: Array = MasterDataLoader.get_stage_order(GameStateKeys.STAGE_TYPE_STORY)
			return "%s　%s" % [tr("ui_quest_episode") % (order.find(ref) + 1), tr(str(MasterDataLoader.get_stage(ref).get("name_key", ref)))]
		GameManager.ITEM_SOURCE_DUNGEON:
			return tr(str(MasterDataLoader.get_dungeon(ref).get("name_key", ref)))
		GameManager.ITEM_SOURCE_POMODORO:
			return tr("ui_source_where_pomodoro_potion" if _item_id in [GameStateKeys.STAMINA, GameStateKeys.ITEM_STAMINA_POTION] else "ui_source_where_pomodoro")
		GameManager.ITEM_SOURCE_USE_POTION:
			return tr("ui_source_where_use_potion") % [count, int(Balance.pomodoro.stamina_potion_recovery)]
	return ref


# ⚠ 窓は画面と一緒に消える（⚠ 遷移で `Modal` が片付ける）。
func _on_go_pressed(kind: String, ref: String) -> void:
	match kind:
		GameManager.ITEM_SOURCE_PENDING_CHEST:
			SceneManager.open_detour(CHEST_PATH, {}, _return_path, _return_data)
		GameManager.ITEM_SOURCE_SHOP:
			SceneManager.open_detour(SHOP_PATH, {}, _return_path, _return_data)
		GameManager.ITEM_SOURCE_STAGE:
			SceneManager.open_detour(SORTIE_PATH, {
				TransferKeys.SORTIE_STAGE_ID: ref, TransferKeys.RETURN_PATH: ADVENTURE_PATH,
			}, _return_path, _return_data)
		GameManager.ITEM_SOURCE_DUNGEON:
			SceneManager.open_detour(ADVENTURE_PATH, {TransferKeys.QUEST_TAB: TransferKeys.QUEST_TAB_HARD}, _return_path, _return_data)
		GameManager.ITEM_SOURCE_POMODORO:
			SceneManager.change_scene(POMODORO_PATH)
		GameManager.ITEM_SOURCE_USE_POTION:
			# ⚠ その場で使う（⚠ 画面を移らない）。⚠ 使えたら数を描き直す。
			if GameManager.use_stamina_potion():
				_rebuild()
