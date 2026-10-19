class_name QuestRewardIcons
extends HFlowContainer

# 依頼の報酬の並び（2026-10-19・回SEE29-D・決定 `RUN-18`）。
#
# ⚠ 人間「⚠ 報酬もアイコンで、右下に個数を表す数字で表記ある程度ランダム」→「⚠ ５あ」（数に幅・紙には「10〜14」）。
# ⚠ 1つ＝暗い箱（`QuestRewardBox`）に絵・右下に数（⚠ 幅があれば「10〜14」）。⚠ 触れると名前と数の吹き出し。
# ⚠ 数の幅は `GameManager.get_stage_reward_spans()` の1本（⚠ 払う数の抽選と同じ式）。⚠ ここで計算しない。
# ⚠ 並び＝金 → 素材 → 品（⚠ マスターの順）。⚠ `limit` を超えたら最後に「ほか◯」。
# ⚠ 掲示板でしか使わない＝scenes/adventure/（AGENTS.md）。⚠ 大きさは Theme の `QuestBoard`。

const THEME_TYPE: StringName = &"QuestBoard"


# ⚠ `limit` が 0 なら全部。
static func create(stage_id: String, limit: int = 0) -> QuestRewardIcons:
	var row: QuestRewardIcons = QuestRewardIcons.new()
	row.name = "RewardIcons"
	row._stage_id = stage_id
	row._limit = limit
	return row


var _stage_id: String = ""
var _limit: int = 0


# ⚠ 1つの数の字（⚠ 幅が無ければ「12」・あれば「10〜14」）。⚠ 検査からも引く。
static func span_text(span: Vector2i) -> String:
	return str(span.x) if span.x == span.y else TranslationServer.translate("ui_quest_reward_span") % [span.x, span.y]


func _ready() -> void:
	theme_type_variation = &"QuestRewardRow"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spans: Dictionary = GameManager.get_stage_reward_spans(_stage_id)
	var entries: Array[Array] = []
	if spans.has(GameStateKeys.REWARD_GOLD):
		entries.append([GameStateKeys.REWARD_GOLD, IconTextures.for_resource(GameStateKeys.GOLD), TranslationServer.translate("ui_res_gold"), spans[GameStateKeys.REWARD_GOLD]])
	for group: String in [GameStateKeys.REWARD_MATERIALS, GameStateKeys.REWARD_INVENTORY]:
		var group_spans: Dictionary = spans.get(group, {}) as Dictionary
		for item_id: String in group_spans:
			entries.append([item_id, IconTextures.for_item(item_id), TranslationServer.translate(GameManager.item_name_key(item_id)), group_spans[item_id]])
	var shown: int = entries.size() if _limit <= 0 else mini(entries.size(), _limit)
	for i: int in range(shown):
		var entry: Array = entries[i]
		var cell: Control = _cell(str(entry[0]), entry[1] as Texture2D, str(entry[2]), entry[3] as Vector2i)
		add_child(cell)
		_fit(cell)
	if shown < entries.size():
		var more: Label = Label.new()
		more.name = "MoreLabel"
		more.theme_type_variation = &"CaptionLabel"
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.text = TranslationServer.translate("ui_quest_reward_more_count") % (entries.size() - shown)
		add_child(more)


func _cell(id: String, texture: Texture2D, name_text: String, span: Vector2i) -> Control:
	var side: float = float(get_theme_constant(&"reward_cell", THEME_TYPE))
	var holder: Control = Control.new()
	holder.name = "Reward_" + id
	holder.custom_minimum_size = Vector2(side, side)
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.tooltip_text = "%s　%s" % [name_text, span_text(span)]
	# ⚠ 箱は左上に決まった大きさ（⚠ 数の札が箱より長いときは枠だけ右へ広げる＝隣に重ねない・撮った絵で「20〜30」が重なった）。
	var box: PanelContainer = PanelContainer.new()
	box.theme_type_variation = &"QuestRewardBox"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2.ZERO
	box.size = Vector2(side, side)
	holder.add_child(box)
	if texture != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.self_modulate = get_theme_color(&"icon", &"BaseDesk")
		box.add_child(picture)
	var count: Label = Label.new()
	count.name = "CountLabel"
	count.theme_type_variation = &"QuestRewardCountLabel"
	count.text = span_text(span)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(count)
	return holder


# ⚠ 数の札は右下（⚠ 箱の下の縁から少し出す）。⚠ 札が箱より長ければ、枠をその幅にする。
#   ⚠ 木に入ってから測る（⚠ 入る前は Theme の字の大きさが効かず、札の幅を小さく測る）。
func _fit(holder: Control) -> void:
	var side: float = float(get_theme_constant(&"reward_cell", THEME_TYPE))
	var out: float = float(get_theme_constant(&"reward_count_out", THEME_TYPE))
	var count: Label = holder.get_node("CountLabel") as Label
	var count_size: Vector2 = count.get_combined_minimum_size()
	var width: float = maxf(side, count_size.x)
	holder.custom_minimum_size = Vector2(width, side + out)
	count.size = count_size
	count.position = Vector2(width - count_size.x, side - count_size.y + out)
