# res://scenes/guild/workshop_screen.gd
# 作業場画面（第1弾：レシピ4つ・キュー1本・キャンセルなし）。指示書 EXEC_GUILD_WORKSHOP.md §5-4 準拠。
# ショップ画面と同じ作りにそろえている：1画面・スクロール・行をコードで生成・詳細画面なし。
# 戻るボタンは1つだけ（育成で2つ並んだ不具合を繰り返さない）。
#
# この画面だけにある要素が1つある：残り時間の毎秒更新。
# Tick（Timer・1秒）で【ラベルの text だけ】を差し替える。行の作り直しはしない。
# 毎秒 _rebuild() すると、ボタンを押そうとした瞬間にノードが作り直されて押せなくなる。

class_name WorkshopScreen
extends Control

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"

# --- ノード参照 ---
@onready var material_label: Label = $Margin/Layout/MaterialLabel
@onready var queue_list: VBoxContainer = $Margin/Layout/Scroll/Content/QueueList
@onready var recipe_list: VBoxContainer = $Margin/Layout/Scroll/Content/RecipeList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton
@onready var tick: Timer = $Tick

# queue_id -> 残り時間ラベル。Tick はこの Dictionary だけを見て text を書き換える。
# _rebuild() のたびに作り直す（古いノードを掴んだままにしない）。
var _remaining_labels: Dictionary = {}

func _ready() -> void:
	# 1. 画面を開いた時点で完了判定を回す。
	#    アプリを閉じている間に完成した製作は、ここで in_progress -> completed になる。
	GameManager.refresh_crafting_queue_if_needed()

	# 2. ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	tick.timeout.connect(_on_tick)

	# 3. GameManager のシグナル購読
	#    crafting_queue_changed: 開始・完了への切り替え・受け取り
	#    material_changed / inventory_changed: 素材が変わると「作れるかどうか」が変わる
	GameManager.crafting_queue_changed.connect(_on_crafting_queue_changed)
	GameManager.material_changed.connect(_on_material_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)

	# 4. 初期描画
	notice_label.text = ""
	_rebuild()

# --- 描画 ---

func _rebuild() -> void:
	_update_header()

	# remove_child してから queue_free する。queue_free + await process_frame にすると、
	# 1回の受け取りで crafting_queue_changed と material_changed が続けて飛ぶため
	# 再描画が2本並走し、行が二重に並ぶ（await の間に2本目が削除を終えてしまう）。
	# remove_child はその場で効くので、この関数は await を持たない。
	_clear(queue_list)
	_clear(recipe_list)
	_remaining_labels.clear()

	var queue: Array = GameManager.get_crafting_queue()
	if queue.is_empty():
		var empty_queue: Label = Label.new()
		empty_queue.name = "EmptyQueueLabel"
		empty_queue.text = tr("ui_guild_workshop_queue_empty")
		queue_list.add_child(empty_queue)
	else:
		for entry: Variant in queue:
			if entry is Dictionary:
				_create_queue_row(entry as Dictionary)

	var recipes: Array = GameManager.get_available_recipes()
	if recipes.is_empty():
		var empty_recipes: Label = Label.new()
		empty_recipes.name = "EmptyRecipeLabel"
		empty_recipes.text = tr("ui_guild_workshop_recipe_empty")
		recipe_list.add_child(empty_recipes)
	else:
		for entry: Variant in recipes:
			if entry is Dictionary:
				_create_recipe_row(entry as Dictionary)

func _clear(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _update_header() -> void:
	# 所持素材。作業場は「何を持っているか」を見ながらレシピを選ぶ画面なので、
	# ショップの所持金ラベルに相当するものとして出す。
	var state: Dictionary = GameManager.get_state()
	var materials: Dictionary = state.get(GameStateKeys.MATERIALS, {})
	var parts: Array[String] = []
	for material_id: String in materials:
		parts.append("%s %d" % [tr("ui_res_" + material_id), int(materials[material_id])])
	material_label.text = "  ".join(parts)

# --- 製作中の行 ---

func _create_queue_row(entry: Dictionary) -> void:
	var queue_id: String = str(entry.get(GameStateKeys.CRAFT_QUEUE_ID, ""))
	var status: String = str(entry.get(GameStateKeys.CRAFT_STATUS, ""))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "QueueRow_" + queue_id

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _recipe_text(str(entry.get(GameStateKeys.CRAFT_RECIPE_ID, "")))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	# 残り時間。Tick が書き換えるのはこのラベルだけ。
	var remaining_label: Label = Label.new()
	remaining_label.name = "RemainingLabel"
	remaining_label.text = _remaining_text(entry)
	row.add_child(remaining_label)
	_remaining_labels[queue_id] = remaining_label

	var collect_button: Button = Button.new()
	collect_button.name = "CollectButton"
	collect_button.text = tr("ui_guild_workshop_collect")
	# 完了前は押せない。GameManager 側も同じ判定を持っているため、ここが抜けても状態は壊れない。
	collect_button.disabled = status != GameStateKeys.CRAFT_STATUS_COMPLETED
	collect_button.pressed.connect(_on_collect_pressed.bind(queue_id))
	row.add_child(collect_button)

	queue_list.add_child(row)

# --- レシピの行 ---

func _create_recipe_row(recipe: Dictionary) -> void:
	var recipe_id: String = str(recipe.get(GameManager.RECIPE_ID, ""))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RecipeRow_" + recipe_id

	# レシピ名は翻訳キーを持たせない。inputs / outputs から組み立てる。
	# こうしておくと、recipes.json にレシピを足しても ja.csv を触らなくて済む。
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = _recipe_text(recipe_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var duration_label: Label = Label.new()
	duration_label.name = "DurationLabel"
	duration_label.text = _format_duration(int(recipe.get(GameManager.RECIPE_DURATION_SEC, 0)))
	row.add_child(duration_label)

	var start_button: Button = Button.new()
	start_button.name = "StartButton"
	start_button.text = tr("ui_guild_workshop_start")
	start_button.disabled = _queue_is_full() or not _can_afford(recipe)
	start_button.pressed.connect(_on_start_pressed.bind(recipe_id))
	row.add_child(start_button)

	recipe_list.add_child(row)

# --- 表示の組み立て ---

# 「建築素材 ×30 → 育成素材 ×20」の形にする。
# recipes.json から引き直すため、キュー側の行にも同じ関数を使える。
func _recipe_text(recipe_id: String) -> String:
	var recipe: Dictionary = MasterDataLoader.get_recipe(recipe_id)
	if recipe.is_empty():
		return recipe_id
	var inputs: String = _io_text(recipe.get(GameManager.RECIPE_INPUTS, []))
	return "%s → %s" % [inputs, _result_text(recipe)]


# 右辺（出るもの）。⚠ draw を持つレシピは中身を1件も出さない。
#
# ⚠ 「種類も等級も両方ランダム」が仕様（GAME_DESIGN 9-3）。抽選表を並べると
#   36行になり、行が縦に伸びて ScrollContainer の外へ出る（EXEC_WORKSHOP_REVIVE.md 決め11）。
func _result_text(recipe: Dictionary) -> String:
	var draw_def: Variant = recipe.get(GameManager.RECIPE_DRAW, null)
	var has_draw: bool = draw_def is Dictionary and not (draw_def as Dictionary).is_empty()
	var outputs: String = _io_text(recipe.get(GameManager.RECIPE_OUTPUTS, []))
	if not has_draw:
		return outputs
	if outputs == "":
		return tr("ui_guild_workshop_draw")
	return "%s + %s" % [outputs, tr("ui_guild_workshop_draw")]

func _io_text(list: Variant) -> String:
	if not (list is Array):
		return ""
	var parts: Array[String] = []
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		var item_id: String = str(item.get(GameManager.RECIPE_IO_ITEM_ID, ""))
		parts.append("%s ×%d" % [tr("ui_res_" + item_id), int(item.get(GameManager.RECIPE_IO_COUNT, 0))])
	return " + ".join(parts)

func _remaining_text(entry: Dictionary) -> String:
	if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) == GameStateKeys.CRAFT_STATUS_COMPLETED:
		return tr("ui_guild_workshop_done")
	var started_at: int = int(entry.get(GameStateKeys.CRAFT_STARTED_AT, 0))
	var duration_sec: int = int(entry.get(GameStateKeys.CRAFT_DURATION_SEC, 0))
	var remaining: int = started_at + duration_sec - int(Time.get_unix_time_from_system())
	if remaining < 0:
		remaining = 0
	return _format_duration(remaining)

# 秒を H:MM:SS / M:SS にする。tr() を使わない（数字だけのため）。
func _format_duration(total_sec: int) -> String:
	if total_sec < 0:
		total_sec = 0
	var hours: int = total_sec / 3600
	var minutes: int = (total_sec % 3600) / 60
	var seconds: int = total_sec % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%d:%02d" % [minutes, seconds]

# --- ボタンの活性判定（GameManager と二重に持つ） ---

func _queue_is_full() -> bool:
	return GameManager.get_crafting_queue().size() >= GameManager.get_max_queue_slots()

func _can_afford(recipe: Dictionary) -> bool:
	var inputs: Variant = recipe.get(GameManager.RECIPE_INPUTS, [])
	if not (inputs is Array):
		return false
	for entry: Variant in (inputs as Array):
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		var item_id: String = str(item.get(GameManager.RECIPE_IO_ITEM_ID, ""))
		var need: int = int(item.get(GameManager.RECIPE_IO_COUNT, 0))
		if GameManager.get_item_count(item_id) < need:
			return false
	return true

# --- 操作 ---

# 確認モーダルは入れていない。Modal.confirm() の待ち方が未確認のため
# （研究・ショップと同じ判断）。キャンセルが無いので、押し間違いは素材が減る形で残る。
func _on_start_pressed(recipe_id: String) -> void:
	if GameManager.start_craft(recipe_id):
		notice_label.text = tr("ui_guild_workshop_started")
	else:
		# ここに来るのは、ボタンの活性判定と GameManager の判定がずれたときだけ。
		notice_label.text = tr("ui_guild_workshop_failed")
	# 再描画は crafting_queue_changed 側で行う（成功時）。

func _on_collect_pressed(queue_id: String) -> void:
	if GameManager.collect_craft(queue_id):
		notice_label.text = tr("ui_guild_workshop_collected")
	else:
		notice_label.text = tr("ui_guild_workshop_failed")

func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)

# --- 毎秒の更新 ---

func _on_tick() -> void:
	# 完了判定はここでも回す。画面を開いたまま待っているときに completed へ切り替える。
	# 切り替わった場合は crafting_queue_changed が飛び、_rebuild() が走る。
	GameManager.refresh_crafting_queue_if_needed()

	# ラベルの text だけを差し替える。行は作り直さない。
	for entry: Variant in GameManager.get_crafting_queue():
		if not (entry is Dictionary):
			continue
		var queue_entry: Dictionary = entry
		var queue_id: String = str(queue_entry.get(GameStateKeys.CRAFT_QUEUE_ID, ""))
		if not _remaining_labels.has(queue_id):
			continue
		var label: Variant = _remaining_labels[queue_id]
		# _rebuild() の直後は古いノードが解放済みのことがある。
		if not is_instance_valid(label):
			continue
		(label as Label).text = _remaining_text(queue_entry)

# --- シグナルハンドラ ---

func _on_crafting_queue_changed() -> void:
	_rebuild()

func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	# 素材が変わると「作れるかどうか」が変わる。行ごと作り直す。
	_rebuild()

func _on_inventory_changed(_item_id: String) -> void:
	_rebuild()
