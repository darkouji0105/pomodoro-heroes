extends Node

# GameManager: 全画面のSingle Source of Truth。
# 拠点共通データ＋育成・図鑑・ショップ・研究ツリー・製作キュー等の永続データを保持・更新する。
# 他のAutoloadやシーンは直接データを書き換えず、必ず下記関数を経由すること。

var _state: Dictionary = {}

# resource_type には GameStateKeys の定数（GOLD / GEMS / STAMINA）を渡す。
# 文字列リテラルを直接渡さないこと（typoしても実行時まで気づけないため）。
signal resource_changed(resource_type: String, new_value: Variant)
# 素材は種類ごとに表示先が分かれるため、辞書全体ではなく
# 「どの素材がいくつになったか」を個別に通知する専用シグナルを分けている。
signal material_changed(material_id: String, new_amount: int)
signal screen_unlocked(screen_id: String)
signal inventory_changed(item_id: String)
signal pending_chests_changed(pending_count: int)

func _ready() -> void:
	print("[GameManager] _ready() — initializing from Balance.initial_state")
	if Balance != null and Balance.initial_state != null:
		_init_from_config(Balance.initial_state)
	else:
		push_warning("[GameManager] Balance.initial_state is null — using empty defaults")
		_state = _empty_state_template()
	print("[GameManager] init complete. gold=%d stamina=%s unlocked_screens=%s" % [
		int(_state.get(GameStateKeys.GOLD, 0)),
		_state.get(GameStateKeys.STAMINA, {}),
		_state.get(GameStateKeys.UNLOCKED_SCREENS, {}),
	])

# --- 初期化 ---

func _init_from_config(config: InitialStateConfig) -> void:
	_state = _empty_state_template()
	
	var unlocked: Dictionary = {}
	for screen_id: String in config.initially_unlocked_screens:
		unlocked[screen_id] = true
	
	_state[GameStateKeys.GOLD] = config.starting_gold
	_state[GameStateKeys.GEMS] = config.starting_gems
	_state[GameStateKeys.STAMINA] = {
		GameStateKeys.STAMINA_CURRENT: config.starting_stamina_current,
		GameStateKeys.STAMINA_MAX: config.starting_stamina_max
	}
	_state[GameStateKeys.MATERIALS] = config.starting_materials.duplicate(true)
	_state[GameStateKeys.SCENARIO_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.STORY][GameStateKeys.STORY_CURRENT_CHAPTER] = config.starting_scenario_chapter
	_state[GameStateKeys.SAVE_VERSION] = config.save_version
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked

func _init_empty() -> void:
	_state = _empty_state_template()

func _empty_state_template() -> Dictionary:
	return {
		GameStateKeys.GOLD: 0,
		GameStateKeys.GEMS: 0,
		GameStateKeys.STAMINA: {GameStateKeys.STAMINA_CURRENT: 0, GameStateKeys.STAMINA_MAX: 0},
		GameStateKeys.MATERIALS: {},
		GameStateKeys.INVENTORY: {},
		GameStateKeys.PENDING_CHESTS: [],
		GameStateKeys.UNLOCKED_SCREENS: {},
		GameStateKeys.SCENARIO_CHAPTER: 1,
		GameStateKeys.BOSS_UNLOCKED: false,
		GameStateKeys.PITY_COUNTERS: {},
		GameStateKeys.TOTAL_POMODORO_COMPLETED: 0,
		GameStateKeys.LAST_POMODORO_END_AT: "",
		GameStateKeys.SAVE_VERSION: 1,
		GameStateKeys.LAST_SAVED_AT: "",
		GameStateKeys.STORY: {GameStateKeys.STORY_CURRENT_CHAPTER: 1, GameStateKeys.STORY_STAGES: {}},
		GameStateKeys.TRAINING_MODE_UNLOCKED: false,
		GameStateKeys.CODEX: {},
		GameStateKeys.DAILY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.WEEKLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.MONTHLY_SHOP: {GameStateKeys.SHOP_REFRESH_AT: "", GameStateKeys.SHOP_LINE_UP: []},
		GameStateKeys.CHARACTER_GROWTH: {},
		GameStateKeys.RESEARCH_TREE: {},
		GameStateKeys.RECIPES_UNLOCKED: {},
		GameStateKeys.CRAFTING_QUEUE: [],
	}

# --- 内部ヘルパー ---

# _state 内のネストしたDictionary/Arrayを取り出す。
# GDScriptのDictionary・Arrayは参照渡しのため、.get() で取り出したものを直接書き換えると
# _state へ代入し直す前に内部状態が変わってしまう。
# 必ず複製を返し、呼び出し側が明示的に _state へ代入し直す形にする
# （「変更前の値と比較する」処理を後から足しても壊れないようにするため）。
func _copy_dict(key: String) -> Dictionary:
	var value: Variant = _state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate()
	return {}

func _copy_array(key: String) -> Array:
	var value: Variant = _state.get(key, [])
	if value is Array:
		return (value as Array).duplicate()
	return []

# --- 基本リソース ---

func get_state() -> Dictionary:
	# 内部Dictionaryそのものではなく、duplicate(true)した読み取り専用スナップショットを返す。
	# 呼び出し側からの直接書き換えを防ぐため（AGENTS.md「状態アクセスのルール」準拠）。
	return _state.duplicate(true)

func add_gold(amount: int) -> void:
	_state[GameStateKeys.GOLD] = int(_state.get(GameStateKeys.GOLD, 0)) + amount
	print("[GameManager] add_gold(%d) -> %d" % [amount, _state[GameStateKeys.GOLD]])
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])

func add_gems(amount: int) -> void:
	_state[GameStateKeys.GEMS] = int(_state.get(GameStateKeys.GEMS, 0)) + amount
	print("[GameManager] add_gems(%d) -> %d" % [amount, _state[GameStateKeys.GEMS]])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])

func add_stamina(amount: int) -> void:
	# NOTE: max を超えたぶんを切り捨てるかどうかは未確定。
	# 現状は切り捨てず加算する。仕様が決まったら PLAN_POMODORO_CORE_LOOP.md と合わせて修正すること。
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	stamina[GameStateKeys.STAMINA_CURRENT] = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)) + amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d" % [amount, int(stamina[GameStateKeys.STAMINA_CURRENT])])
	resource_changed.emit(GameStateKeys.STAMINA, stamina[GameStateKeys.STAMINA_CURRENT])

func spend_stamina(amount: int) -> bool:
	# 足りなければ何もせずfalseを返す
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	if current < amount:
		print("[GameManager] spend_stamina(%d) -> false (have %d)" % [amount, current])
		return false
	stamina[GameStateKeys.STAMINA_CURRENT] = current - amount
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] spend_stamina(%d) -> true (current=%d)" % [amount, int(stamina[GameStateKeys.STAMINA_CURRENT])])
	resource_changed.emit(GameStateKeys.STAMINA, stamina[GameStateKeys.STAMINA_CURRENT])
	return true

func add_material(material_id: String, amount: int) -> void:
	var materials: Dictionary = _copy_dict(GameStateKeys.MATERIALS)
	var new_amount: int = int(materials.get(material_id, 0)) + amount
	materials[material_id] = new_amount
	_state[GameStateKeys.MATERIALS] = materials
	print("[GameManager] add_material('%s', %d) -> %d" % [material_id, amount, new_amount])
	# 辞書全体ではなく「どの素材がいくつになったか」を通知する。
	# 拠点画面は素材の種類ごとにラベルを持つため、種類が特定できないと差分更新できない。
	material_changed.emit(material_id, new_amount)

func get_material_count(material_id: String) -> int:
	var materials: Dictionary = _state.get(GameStateKeys.MATERIALS, {})
	return int(materials.get(material_id, 0))

# item_type を省略した場合は "" （種別不明）として登録する。
# 勝手に "equipment" 等を推測すると、消費アイテムまで装備扱いになるため。
# 種別が分かる呼び出し元（ショップ・作業場・宝箱など）は必ず明示的に渡すこと。
func add_to_inventory(item_id: String, count: int, item_type: String = GameStateKeys.ITEM_TYPE_UNKNOWN) -> void:
	# 初出のitem_idであれば、図鑑（codex）のdiscoveredも自動でtrueにする
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = {}
	if inventory.has(item_id) and inventory[item_id] is Dictionary:
		entry = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_COUNT] = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) + count
	if item_type != GameStateKeys.ITEM_TYPE_UNKNOWN:
		entry[GameStateKeys.ITEM_TYPE] = item_type
	elif not entry.has(GameStateKeys.ITEM_TYPE):
		entry[GameStateKeys.ITEM_TYPE] = GameStateKeys.ITEM_TYPE_UNKNOWN
	if not entry.has(GameStateKeys.ITEM_SLOT_POSITION):
		entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: 0, GameStateKeys.POS_Y: 0}
	if not entry.has(GameStateKeys.ITEM_PROPERTIES):
		entry[GameStateKeys.ITEM_PROPERTIES] = {}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory

	var codex: Dictionary = _copy_dict(GameStateKeys.CODEX)
	var newly_discovered: bool = not codex.has(item_id)
	if newly_discovered:
		codex[item_id] = {GameStateKeys.CODEX_DISCOVERED: true, GameStateKeys.CODEX_OBTAINED_AT: str(Time.get_unix_time_from_system())}
		_state[GameStateKeys.CODEX] = codex
	print("[GameManager] add_to_inventory('%s', %d, type='%s') -> count=%d newly_discovered=%s" % [
		item_id, count, str(entry[GameStateKeys.ITEM_TYPE]), int(entry[GameStateKeys.ITEM_COUNT]), newly_discovered])
	inventory_changed.emit(item_id)

# --- 画面アンロック ---

func unlock_screen(screen_id: String) -> void:
	var unlocked: Dictionary = _copy_dict(GameStateKeys.UNLOCKED_SCREENS)
	unlocked[screen_id] = true
	_state[GameStateKeys.UNLOCKED_SCREENS] = unlocked
	print("[GameManager] unlock_screen('%s')" % screen_id)
	screen_unlocked.emit(screen_id)

func is_screen_unlocked(screen_id: String) -> bool:
	var unlocked: Dictionary = _state.get(GameStateKeys.UNLOCKED_SCREENS, {})
	return bool(unlocked.get(screen_id, false))

# --- 宝箱 ---

func add_pending_chest(chest_data: Dictionary) -> void:
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	chests.append(chest_data.duplicate(true))
	_state[GameStateKeys.PENDING_CHESTS] = chests
	print("[GameManager] add_pending_chest() -> pending_count=%d" % get_pending_chest_count())
	pending_chests_changed.emit(get_pending_chest_count())

func open_chest(chest_id: String) -> bool:
	# 存在しなければ何もせずfalse。存在すればopened=trueにしてrewardsを反映
	var chests: Array = _copy_array(GameStateKeys.PENDING_CHESTS)
	for i: int in range(chests.size()):
		if not (chests[i] is Dictionary):
			continue
		var chest: Dictionary = (chests[i] as Dictionary).duplicate(true)
		if str(chest.get(GameStateKeys.CHEST_ID, "")) != chest_id:
			continue
		if bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			print("[GameManager] open_chest('%s') -> false (already opened)" % chest_id)
			return false
		chest[GameStateKeys.CHEST_OPENED] = true
		chests[i] = chest
		_state[GameStateKeys.PENDING_CHESTS] = chests
		# rewards を反映（既存の add_* 関数を使い回し、重複実装を避ける）
		var rewards: Dictionary = chest.get(GameStateKeys.CHEST_REWARDS, {})
		if rewards.has(GameStateKeys.REWARD_GOLD):
			add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
		if rewards.has(GameStateKeys.REWARD_GEMS):
			add_gems(int(rewards[GameStateKeys.REWARD_GEMS]))
		if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
			var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
			for mat_id: String in mats:
				add_material(mat_id, int(mats[mat_id]))
		if rewards.has(GameStateKeys.REWARD_INVENTORY) and rewards[GameStateKeys.REWARD_INVENTORY] is Dictionary:
			var items: Dictionary = rewards[GameStateKeys.REWARD_INVENTORY]
			for item_id: String in items:
				add_to_inventory(item_id, int(items[item_id]))
		print("[GameManager] open_chest('%s') -> true" % chest_id)
		pending_chests_changed.emit(get_pending_chest_count())
		return true
	print("[GameManager] open_chest('%s') -> false (not found)" % chest_id)
	return false

func get_pending_chest_count() -> int:
	# opened == false の件数
	var chests: Array = _state.get(GameStateKeys.PENDING_CHESTS, [])
	var count: int = 0
	for chest: Dictionary in chests:
		if not bool(chest.get(GameStateKeys.CHEST_OPENED, false)):
			count += 1
	return count

# --- ポモドーロ報酬 ---

func apply_pomodoro_rewards(reward_data: Dictionary) -> void:
	# gold/stamina/materialsの反映、total_pomodoro_completedの加算、
	# last_pomodoro_end_atの更新、SignalBus.pomodoro_session_completedの発火までを一括で行う
	print("[GameManager] apply_pomodoro_rewards(%s)" % reward_data)
	if reward_data.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(reward_data[GameStateKeys.REWARD_GOLD]))
	if reward_data.has(GameStateKeys.REWARD_STAMINA):
		add_stamina(int(reward_data[GameStateKeys.REWARD_STAMINA]))
	if reward_data.has(GameStateKeys.REWARD_MATERIALS) and reward_data[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = reward_data[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# total_pomodoro_completed +1
	_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(_state.get(GameStateKeys.TOTAL_POMODORO_COMPLETED, 0)) + 1
	# last_pomodoro_end_at 更新
	_state[GameStateKeys.LAST_POMODORO_END_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] total_pomodoro_completed -> %d" % _state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	# 発火元をGameManagerに一本化（呼び出し元のポモドーロ画面側では発火させない・二重発火防止）
	SignalBus.pomodoro_session_completed.emit(reward_data)

# --- 戦闘報酬 ---

func apply_battle_rewards(result_data: Dictionary) -> void:
	# gold/materialsの反映、SignalBus.battle_finishedの発火までを一括で行う
	# ※ expは扱わない（レベル上げは専用素材消費型。DATA_SCHEMA.md 4-3準拠）
	print("[GameManager] apply_battle_rewards(%s)" % result_data)
	var rewards: Dictionary = result_data.get(GameStateKeys.BATTLE_REWARDS, {})
	if rewards.has(GameStateKeys.REWARD_GOLD):
		add_gold(int(rewards[GameStateKeys.REWARD_GOLD]))
	if rewards.has(GameStateKeys.REWARD_MATERIALS) and rewards[GameStateKeys.REWARD_MATERIALS] is Dictionary:
		var mats: Dictionary = rewards[GameStateKeys.REWARD_MATERIALS]
		for mat_id: String in mats:
			add_material(mat_id, int(mats[mat_id]))
	# 発火元をGameManagerに一本化（呼び出し元の戦闘画面側では発火させない・二重発火防止）
	SignalBus.battle_finished.emit(result_data)

# --- 倉庫：図鑑・インベントリ整理 ---

func get_codex_entry(item_id: String) -> Dictionary:
	var codex: Dictionary = _state.get(GameStateKeys.CODEX, {})
	var entry: Dictionary = codex.get(item_id, {})
	return entry.duplicate(true)

func update_inventory_slot_position(item_id: String, position: Vector2i) -> void:
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	if not inventory.has(item_id):
		print("[GameManager] update_inventory_slot_position('%s') -> item not in inventory" % item_id)
		return
	var entry: Dictionary = (inventory[item_id] as Dictionary).duplicate(true)
	entry[GameStateKeys.ITEM_SLOT_POSITION] = {GameStateKeys.POS_X: position.x, GameStateKeys.POS_Y: position.y}
	inventory[item_id] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	print("[GameManager] update_inventory_slot_position('%s', %s)" % [item_id, position])
	inventory_changed.emit(item_id)

# --- ショップ ---

func _shop_key(shop_type: String) -> String:
	match shop_type:
		GameStateKeys.SHOP_TYPE_DAILY:
			return GameStateKeys.DAILY_SHOP
		GameStateKeys.SHOP_TYPE_WEEKLY:
			return GameStateKeys.WEEKLY_SHOP
		GameStateKeys.SHOP_TYPE_MONTHLY:
			return GameStateKeys.MONTHLY_SHOP
	return ""

func get_shop_lineup(shop_type: String) -> Array:
	var key: String = _shop_key(shop_type)
	if key == "":
		print("[GameManager] get_shop_lineup('%s') -> unknown shop_type" % shop_type)
		return []
	var shop: Dictionary = _state.get(key, {})
	var line_up: Variant = shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if line_up is Array:
		return (line_up as Array).duplicate(true)
	return []

func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
	# 残高不足・売り切れなら何もせずfalse（空実装：ラインナップが空のため常にfalse）
	print("[GameManager] purchase_shop_item('%s', %d) -> false (dummy: lineup empty)" % [shop_type, slot_id])
	return false

func refresh_shop_if_needed(shop_type: String) -> void:
	print("[GameManager] refresh_shop_if_needed('%s') (dummy)" % shop_type)

# --- 育成 ---

func get_character_growth(character_id: String) -> Dictionary:
	var growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var entry: Dictionary = growth.get(character_id, {})
	return entry.duplicate(true)

func level_up_character(character_id: String) -> bool:
	# 素材不足なら何もせずfalse（空実装）
	print("[GameManager] level_up_character('%s') -> false (dummy: insufficient materials)" % character_id)
	return false

func equip_item(character_id: String, slot: String, item_id: String) -> void:
	print("[GameManager] equip_item('%s', '%s', '%s') (dummy)" % [character_id, slot, item_id])

func unequip_item(character_id: String, slot: String) -> void:
	print("[GameManager] unequip_item('%s', '%s') (dummy)" % [character_id, slot])

func select_skill(character_id: String, slot_id: int, skill_id: String) -> void:
	print("[GameManager] select_skill('%s', %d, '%s') (dummy)" % [character_id, slot_id, skill_id])

# --- 研究 ---

func get_research_tree() -> Dictionary:
	return _state.get(GameStateKeys.RESEARCH_TREE, {}).duplicate(true)

func unlock_research_node(node_id: String) -> bool:
	# 前提未解放・素材不足なら何もせずfalse（空実装）
	print("[GameManager] unlock_research_node('%s') -> false (dummy: prerequisites not met)" % node_id)
	return false

func get_effective_level_cap(_character_id: String) -> int:
	# 保存された値ではなく、research_treeを都度走査して計算する
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var cap: int = 0
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_LEVEL_CAP_UNLOCK:
			cap += int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return cap

func get_stat_boost_all() -> Dictionary:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	# 返り値の形は { "hp": 10, "atk": 5, ... }。target_stat未指定のノードは "all" に集約する。
	# TODO: 実際にどのステータスへどう加算するかは PLAN_GUILD_RESEARCH.md 側で未確定。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var boosts: Dictionary = {}
	for node_id: String in tree:
		var node: Dictionary = tree[node_id]
		if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)) and str(node.get(GameStateKeys.NODE_EFFECT_TYPE, "")) == GameStateKeys.EFFECT_STAT_BOOST_ALL:
			var stat: String = str(node.get(GameStateKeys.NODE_TARGET_STAT, "all"))
			boosts[stat] = int(boosts.get(stat, 0)) + int(node.get(GameStateKeys.NODE_EFFECT_VALUE, 0))
	return boosts

# --- 作業場 ---

func get_crafting_queue() -> Array:
	return _state.get(GameStateKeys.CRAFTING_QUEUE, []).duplicate(true)

func start_craft(recipe_id: String) -> bool:
	# レシピ未解放・素材不足なら何もせずfalse（空実装）
	print("[GameManager] start_craft('%s') -> false (dummy: recipe not unlocked)" % recipe_id)
	return false

func collect_craft(queue_id: String) -> bool:
	# 完了前なら何もせずfalse。完了後は成功しinventoryへ反映（空実装：常にfalse）
	print("[GameManager] collect_craft('%s') -> false (dummy: not completed)" % queue_id)
	return false

# --- セーブ・ロード ---

# セーブデータから状態を復元する。
# SaveManagerからのみ呼ばれることを想定。
func load_state(data: Dictionary) -> bool:
	if data == null or not (data is Dictionary):
		return false
	
	if not data.has(GameStateKeys.SAVE_VERSION):
		push_warning("[GameManager] load_state: missing save_version")
		return false
	
	# テンプレで初期化してから上書き（将来のキー追加対策）
	var new_state: Dictionary = _empty_state_template()
	for key: String in data:
		if new_state.has(key):
			new_state[key] = data[key]
	
	# 数値の int() キャスト（JSON復元時は float になるため）
	# §6-2 の決定事項に従い、対象を限定する。
	if new_state.has(GameStateKeys.GOLD):
		new_state[GameStateKeys.GOLD] = int(new_state[GameStateKeys.GOLD])
	if new_state.has(GameStateKeys.GEMS):
		new_state[GameStateKeys.GEMS] = int(new_state[GameStateKeys.GEMS])
	if new_state.has(GameStateKeys.STAMINA) and new_state[GameStateKeys.STAMINA] is Dictionary:
		var stamina: Dictionary = new_state[GameStateKeys.STAMINA]
		if stamina.has(GameStateKeys.STAMINA_CURRENT):
			stamina[GameStateKeys.STAMINA_CURRENT] = int(stamina[GameStateKeys.STAMINA_CURRENT])
		if stamina.has(GameStateKeys.STAMINA_MAX):
			stamina[GameStateKeys.STAMINA_MAX] = int(stamina[GameStateKeys.STAMINA_MAX])
	if new_state.has(GameStateKeys.TOTAL_POMODORO_COMPLETED):
		new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED] = int(new_state[GameStateKeys.TOTAL_POMODORO_COMPLETED])
	if new_state.has(GameStateKeys.SCENARIO_CHAPTER):
		new_state[GameStateKeys.SCENARIO_CHAPTER] = int(new_state[GameStateKeys.SCENARIO_CHAPTER])
	if new_state.has(GameStateKeys.SAVE_VERSION):
		new_state[GameStateKeys.SAVE_VERSION] = int(new_state[GameStateKeys.SAVE_VERSION])
	if new_state.has(GameStateKeys.MATERIALS) and new_state[GameStateKeys.MATERIALS] is Dictionary:
		var mats: Dictionary = new_state[GameStateKeys.MATERIALS]
		for mat_id: String in mats:
			mats[mat_id] = int(mats[mat_id])
	
	# 状態反映（外部参照を断つため duplicate）
	_state = new_state.duplicate(true)
	print("[GameManager] load_state success. version=%d" % int(_state[GameStateKeys.SAVE_VERSION]))
	
	# 主要なシグナルを発火（再描画用）
	resource_changed.emit(GameStateKeys.GOLD, _state[GameStateKeys.GOLD])
	resource_changed.emit(GameStateKeys.GEMS, _state[GameStateKeys.GEMS])
	var stamina_dict: Dictionary = _state[GameStateKeys.STAMINA]
	resource_changed.emit(GameStateKeys.STAMINA, int(stamina_dict.get(GameStateKeys.STAMINA_CURRENT, 0)))
	
	var materials: Dictionary = _state[GameStateKeys.MATERIALS]
	for mat_id: String in materials:
		material_changed.emit(mat_id, int(materials[mat_id]))
	
	pending_chests_changed.emit(get_pending_chest_count())
	
	return true

# 保存直前に呼ばれ、last_saved_atを更新する
func mark_saved() -> void:
	_state[GameStateKeys.LAST_SAVED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] mark_saved -> last_saved_at=%s" % _state[GameStateKeys.LAST_SAVED_AT])
