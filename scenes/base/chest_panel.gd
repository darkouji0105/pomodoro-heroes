class_name ChestPanel
extends Control

# 拠点で宝箱を開ける一覧（2026-09-15・人間の指示「宝箱は、倉庫側ではなく拠点から直接開けるように」）。
#
# ⚠ 拠点の宝箱バッジで開く。⚠ 中身は倉庫の宝箱タブにあったものをそのまま移した
#   （⚠ 種類ごとに1行・「開ける」＝その種類の1個目・「すべて開ける」・結果の窓）。
#   ⚠ 1つずつ開けるのと、まとめて開けるのの両方を選べる（人間「両方選べるように」）。
# ⚠⚠ モーダルにしない。⚠ モーダルは同時に1枚しか出せず、⚠ 一覧をモーダルにすると
#   ⚠ 開けた結果の窓が一覧を閉じるまで出ない。⚠ 一覧は拠点の上に重ねる面、⚠ 結果はモーダル。
# ⚠ 拠点からしか開かないので scenes/base/（AGENTS.md「1画面だけならその画面のフォルダ」）。⚠ `.tscn` を持たない。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ 開けると pending_chests_changed が飛ぶ。

# 開封結果の窓のマス目の列数（⚠ 見た目の都合だけ。⚠ バランス数値ではない）。
const REWARD_GRID_COLUMNS: int = 6

var _list: VBoxContainer = null
var _open_all_button: UiButton = null


# 拠点の上に開く。⚠ 開いていればそれを返す（⚠ 2枚重ねない）。
static func open_on(host: Control) -> ChestPanel:
	for child: Node in host.get_children():
		if child is ChestPanel:
			return child
	var panel: ChestPanel = ChestPanel.new()
	panel.name = "ChestPanel"
	host.add_child(panel)
	return panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠ 後ろの拠点を押せないようにする（⚠ 開いている間は一覧だけを触る）。
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame: PanelContainer = PanelContainer.new()
	frame.name = "Frame"
	frame.theme_type_variation = &"SidePanel"
	center.add_child(frame)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.theme_type_variation = &"DialogMargin"
	frame.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.theme_type_variation = &"SectionStack"
	margin.add_child(layout)

	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.text = "ui_base_chest"
	layout.add_child(title_label)

	_list = VBoxContainer.new()
	_list.name = "ChestList"
	layout.add_child(_list)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	footer.theme_type_variation = &"ButtonRow"
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)

	var close_button: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_common_close")
	close_button.name = "CloseButton"
	close_button.pressed.connect(close)
	footer.add_child(close_button)

	# ⚠ この面の主要動作＝真鍮（⚠ 1面に1個まで）。
	_open_all_button = UiButton.create(UiButton.Variant.PRIMARY, "ui_warehouse_open_all")
	_open_all_button.name = "OpenAllButton"
	_open_all_button.pressed.connect(_on_open_all_pressed)
	footer.add_child(_open_all_button)

	GameManager.pending_chests_changed.connect(_on_pending_chests_changed)
	_rebuild_chest_list()


# 閉じる。⚠ remove_child してから queue_free（AGENTS.md）。
func close() -> void:
	var parent: Node = get_parent()
	if parent != null:
		parent.remove_child(self)
	queue_free()


# 種類ごとに1行。⚠ 並びは入手した順（⚠ `PENDING_CHESTS` の並びをそのまま使う）。
#
# ⚠ 「開ける」は **その種類の1個目**を開ける。⚠ どれを開けても中身は同じ
#   （⚠ 2026-09-18 から**中身は開けるときに振る**。⚠ 同じ種類なら区別が無いので、どれを開けても同じ）。
func _rebuild_chest_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var chests: Array = GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, [])
	# ⚠ {chest_id: [instance_id]}。⚠ 開けていないものだけ。
	var groups: Dictionary = {}
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var chest_id: String = str(chest_dict.get(GameStateKeys.CHEST_ID, ""))
		if not groups.has(chest_id):
			groups[chest_id] = []
		(groups[chest_id] as Array).append(str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, "")))

	_open_all_button.disabled = groups.is_empty()
	if groups.is_empty():
		_list.add_child(EmptyState.create(
			"ui_warehouse_no_chest", "ui_warehouse_no_chest_hint", IconTextures.for_chest()
		))
		return

	# ⚠ Dictionary は入れた順を覚えている。⚠ ＝ 入手した順に並ぶ。
	for chest_id: Variant in groups.keys():
		_create_chest_row(str(chest_id), groups[chest_id])


# 1行 ＝ 絵 ／ 名前 ／ ×個数 ／ 開ける。
#
# ⚠ 表示名は chests.json の name_key（⚠ 接頭辞を組み立てない）。
func _create_chest_row(chest_id: String, instance_ids: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ChestRow_" + chest_id

	row.add_child(_make_chest_glyph("ChestGlyph", chest_id))

	var name_label: Label = Label.new()
	var chest_def: Dictionary = MasterDataLoader.get_chest(chest_id)
	name_label.text = tr(str(chest_def.get(GameManager.CHEST_NAME_KEY, "")))
	name_label.name = "ChestNameLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint_by_rarity(name_label, chest_id)
	row.add_child(name_label)

	# ⚠ 数値だけなので tr() を通さない（AGENTS.md）。
	var count_label: Label = Label.new()
	count_label.name = "ChestCountLabel"
	count_label.text = "×%d" % instance_ids.size()
	row.add_child(count_label)

	var open_button: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_warehouse_open")
	open_button.name = "OpenButton"
	# ⚠ その種類の1個目を開ける。⚠ 開けると再描画が走って番号は引き直される。
	open_button.pressed.connect(_on_open_chest_pressed.bind(str(instance_ids[0])))
	row.add_child(open_button)

	_list.add_child(row)


# 宝箱の絵。⚠ 線画（SVG）が在ればそちら、⚠ 無ければ絵文字。
#   ⚠ 大きさは `Balance.icon` の絵文字と同じ段（⚠ ここに px を書かない）。
# ⚠ 2026-09-18：⚠ レアリティの色を着せる（人間「宝箱のアイコンが見れるように　文字の色も」）。
#   ⚠ `size_scale` は開封結果の窓で大きく出すときだけ（⚠ 一覧は 1）。
func _make_chest_glyph(node_name: String, chest_id: String = "", size_scale: int = 1) -> Control:
	var texture: Texture2D = IconTextures.for_chest()
	var size_px: float = float(maxi(1, Balance.icon.glyph_font_size)) if Balance.icon != null else 20.0
	size_px *= float(maxi(1, size_scale))
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.name = node_name
		rect.texture = texture
		rect.custom_minimum_size = Vector2(size_px, size_px)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_tint_by_rarity(rect, chest_id)
		return rect
	var glyph: Label = Label.new()
	glyph.name = node_name
	glyph.text = Glyphs.NODE_CHEST
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return glyph


# レアリティの色を着せる（2026-09-18）。⚠ 色はフロアで宝箱を拾ったときの演出と同じ
#   （`Balance.icon` の10色ランプ・`GameManager.CHEST_RARITY_TIERS`）。⚠ ここに色を書かない。
# ⚠ レアリティが無い宝箱（ポモドーロの宝箱など）は何もしない（⚠ 既定の色のまま）。
func _tint_by_rarity(target: CanvasItem, chest_id: String) -> void:
	var rarity: String = GameManager.get_chest_rarity(chest_id)
	if rarity == "" or Balance.icon == null:
		return
	target.modulate = Balance.icon.color_of_grade(
		Balance.icon.grade_of_tier(int(GameManager.CHEST_RARITY_TIERS.get(rarity, 1)), false)
	)


# --- 開封 ---

func _on_open_chest_pressed(instance_id: String) -> void:
	# ⚠ 名前と種類は開ける前に読む。⚠⚠ 中身は**開けたあと**に読む（2026-09-18）。
	#   ⚠ 中身は `open_chest()` の中で振られ、⚠ 開けた記録（`CHEST_REWARDS`）に残る。
	var chest_title: String = _chest_name(instance_id)
	var chest_id: String = _chest_id_of(instance_id)
	if not _chest_exists(instance_id):
		push_warning("[ChestPanel] chest not found: " + instance_id)
		return
	if not GameManager.open_chest(instance_id):
		push_warning("[ChestPanel] open_chest failed: " + instance_id)
		return
	var rewards: Dictionary = _read_chest_rewards(instance_id)
	# ⚠ 増えた演出はここで呼ばない（⚠ `ResourceGainEffect` が資源の変化を見て自分で流す）。
	_show_reward_window(rewards, chest_title, chest_id)


func _on_open_all_pressed() -> void:
	var chests: Array = GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, [])
	var opened_count: int = 0
	var combined: Dictionary = _empty_rewards()
	for chest: Variant in chests:
		if not (chest is Dictionary):
			continue
		var chest_dict: Dictionary = chest
		if bool(chest_dict.get(GameStateKeys.CHEST_OPENED, false)):
			continue
		var instance_id: String = str(chest_dict.get(GameStateKeys.CHEST_INSTANCE_ID, ""))
		# ⚠ 中身は開けたあとに読む（⚠ `open_chest()` が振って記録に残す・2026-09-18）。
		if GameManager.open_chest(instance_id):
			_merge_rewards(combined, _read_chest_rewards(instance_id))
			opened_count += 1
	if opened_count > 0:
		# ⚠ まとめて1つの窓（⚠ 5個開けて窓が5つ並ぶと閉じるだけで疲れる）。
		_show_reward_window(combined, tr("ui_warehouse_open_all"))


# 開封結果の窓。⚠ 報酬はもう配り終わっている（⚠ `open_chest()` の中で入っている）。
#   ⚠ この窓は「何が入ったか」を見せるだけ。⚠ 閉じても何も失われない。
# ⚠ ゴールド・ジェム・スタミナはマスにならないので文字で出す。
#
# ⚠ `chest_id` を渡すと、⚠ 窓の頭に**宝箱の絵と名前をレアリティの色で**出す
#   （2026-09-18・人間「宝箱を開けるとき宝箱のアイコンが見れるように　文字の色も」）。
#   ⚠ 「すべて開ける」は種類が混ざるので渡さない（⚠ 頭の行は出ない）。
func _show_reward_window(rewards: Dictionary, title: String, chest_id: String = "") -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "RewardWindow"

	if chest_id != "":
		var head: HBoxContainer = HBoxContainer.new()
		head.name = "ChestHead"
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_child(_make_chest_glyph("ChestHeadGlyph", chest_id, 2))
		var head_label: Label = Label.new()
		head_label.name = "ChestHeadName"
		head_label.text = title
		head_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tint_by_rarity(head_label, chest_id)
		head.add_child(head_label)
		box.add_child(head)

	var entries: Array = RewardEntries.slot_entries(rewards)
	if not entries.is_empty():
		var grid: ItemGrid = ItemGrid.new()
		grid.name = "RewardGrid"
		grid.columns = mini(entries.size(), REWARD_GRID_COLUMNS)
		box.add_child(grid)
		grid.rebuild(entries, entries.size())

	var currency: String = RewardEntries.currency_text(rewards)
	if currency != "":
		var label: Label = Label.new()
		label.name = "RewardCurrency"
		label.text = currency
		box.add_child(label)

	Modal.notify(self, "", [], false, {
		Modal.OPTION_TITLE: title,
		Modal.OPTION_CONTENT: box,
		Modal.OPTION_CLOSE_LABEL: "ui_warehouse_receive",
	})


# ⚠ 報酬のマスと通貨の文字は `RewardEntries`（2026-09-17）。⚠ 戦闘の結果窓と同じ口。


# 宝箱の表示名。⚠ chests.json の name_key（⚠ 綴りを組み立てない）。
func _chest_name(instance_id: String) -> String:
	var chest_id: String = _chest_id_of(instance_id)
	if chest_id == "":
		return tr("ui_warehouse_opened")
	var chest_def: Dictionary = MasterDataLoader.get_chest(chest_id)
	return tr(str(chest_def.get(GameManager.CHEST_NAME_KEY, "")))


# その1個の種類（chest_id）。⚠ 無ければ ""。
func _chest_id_of(instance_id: String) -> String:
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if not (chest is Dictionary):
			continue
		if str((chest as Dictionary).get(GameStateKeys.CHEST_INSTANCE_ID, "")) != instance_id:
			continue
		return str((chest as Dictionary).get(GameStateKeys.CHEST_ID, ""))
	return ""


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


func _chest_exists(instance_id: String) -> bool:
	for chest: Variant in GameManager.get_state().get(GameStateKeys.PENDING_CHESTS, []):
		if chest is Dictionary and str((chest as Dictionary).get(GameStateKeys.CHEST_INSTANCE_ID, "")) == instance_id:
			return true
	return false


func _on_pending_chests_changed(_pending_count: int) -> void:
	_rebuild_chest_list()
