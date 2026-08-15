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
# 育成データの変化。レベル・ステータス・装備・スキルのいずれかが変わったときに発火する。
# 素材の増減は material_changed 側で通知されるため、こちらには含めない。
signal character_growth_changed(character_id: String)

# 装備の個体が増えた・等級が上がった・素材に戻したときに飛ぶ。
# 着脱では飛ばない（着脱で変わるのは character_growth だけ）。
signal equipment_instances_changed(instance_id: String)
# 研究ノードの解放。素材の増減は material_changed 側で通知されるため、こちらには含めない。
# 実効レベル上限・ステータス上昇は都度計算のため、解放の通知だけで全画面が追従できる。
signal research_node_unlocked(node_id: String)
# ショップのラインナップの変化（購入・リフレッシュの両方）。
# 所持金・素材・アイテムの増減は resource_changed / material_changed / inventory_changed 側で
# 通知されるため、こちらは purchased_count と refresh_at の変化だけを担当する。
signal shop_changed(shop_type: String)
# 製作キューの変化（開始・完了への切り替え・受け取り）。
# 素材・アイテムの増減は material_changed / inventory_changed 側で通知されるため、
# こちらはキューの中身の変化だけを担当する。
signal crafting_queue_changed()

# get_level_up_cost() が返す Dictionary のキー。
# 呼び出し側が文字列リテラルを書かなくて済むようにここで公開する。
const LEVEL_UP_COST_MATERIAL_ID: String = "material_id"
const LEVEL_UP_COST_AMOUNT: String = "amount"

# get_stat_boost_all() が「全ステータス対象」の加算をまとめるキー。
# 既存の get_stat_boost_all() が target_stat 未指定時に使う値と揃える必要がある。
const STAT_BOOST_ALL_KEY: String = "all"

# get_research_unlock_cost() が返す Dictionary のキー。
# get_level_up_cost() と同じ形にそろえてある。
const RESEARCH_COST_MATERIAL_ID: String = "material_id"
const RESEARCH_COST_AMOUNT: String = "amount"

# research.json 側のキー（状態ではなくマスターデータのため GameStateKeys には置かない）。
const RESEARCH_NODE_COST_MATERIAL_ID: String = "cost_material_id"
const RESEARCH_NODE_COST_AMOUNT: String = "cost_amount"

# shop.json 側だけにあるキー（状態には残らないため GameStateKeys には置かない）。
# slot_id / item_id / cost / stock_limit は状態と同じ形のため GameStateKeys 側を使う。
const SHOP_SLOT_PAYOUT_TYPE: String = "payout_type"
const SHOP_SLOT_PAYOUT_COUNT: String = "count"
const SHOP_SLOT_ITEM_TYPE: String = "item_type"

# payout_type に入る値。
# 素材（materials）とアイテム（inventory）は保存先が違うため、渡す関数を切り替える必要がある。
# 「素材IDならadd_material」と推測で分岐させない（IDの綴りだけでは判別できない）。
const PAYOUT_TYPE_MATERIAL: String = "material"
const PAYOUT_TYPE_ITEM: String = "item"

# recipes.json 側だけにあるキー（状態には残らないため GameStateKeys には置かない）。
# 画面側もこの定数を使う（文字列リテラルを2箇所に書かない）。
const RECIPE_ID: String = "recipe_id"
const RECIPE_DURATION_SEC: String = "duration_sec"
const RECIPE_INPUTS: String = "inputs"
const RECIPE_OUTPUTS: String = "outputs"
const RECIPE_IO_ITEM_ID: String = "item_id"
const RECIPE_IO_COUNT: String = "count"
const RECIPE_UNLOCKED_BY_DEFAULT: String = "unlocked_by_default"
const RECIPE_SORT_ORDER: String = "sort_order"

# items.json 側だけにあるキー。
# 「そのIDが materials に入るのか inventory に入るのか」はここでしか分からない。
# IDの綴りから推測して分岐させないこと（ショップの payout_type と同じ理由）。
const ITEM_MASTER_STORAGE: String = "storage"
const ITEM_MASTER_ITEM_TYPE: String = "item_type"
const ITEM_STORAGE_MATERIAL: String = "material"
const ITEM_STORAGE_INVENTORY: String = "inventory"

# items.json の装備エントリだけが持つキー。
# equipment.json を別に作らないのは、_item_storage() / _grant_item() が既に items.json を
# 引いているため。性能値だけ別ファイルにすると、同期の型がもう1枚要る。
const ITEM_MASTER_EQUIP_SLOT: String = "equip_slot"
const ITEM_MASTER_EQUIP_STATS: String = "equip_stats"

# --- 装備の個体（第2弾） ---

const INSTANCE_ID_PREFIX: String = "eq_"

# 等級の上限。第1弾は3で止める。
# 4〜10の必要素材量はバランスの計算道具ができてから決める（勘で置くと全部やり直しになる）。
const MAX_EQUIPMENT_GRADE: int = 3

# 等級1つにつき、基礎値の何割を「加算」するか。
# 乗算で重ねるとインフレするため加算にしている（PLAN_CHARACTER_GROWTH_LOOP.md 3-1）。
# 等級10でも 1 + 0.25*9 = 3.25倍で止まる。
const GRADE_STAT_RATIO: float = 0.25

# 枠（宝石・ルーンを刺すところ）。第1弾は器だけ作り、中身は空。
# parts は null 込みの長さ固定配列。位置が枠を表す（PLAN 2-2）。
const PART_SLOT_COUNT: int = 2
const PART_SLOT_GRADES: Array[int] = [5, 10]

# 鍛冶のコスト。等級 g へ上げるのに FORGE_COST_PER_GRADE * g。
const FORGE_MATERIAL_ID: String = GameStateKeys.ITEM_FORGING_MATERIAL_1
const FORGE_COST_PER_GRADE: int = 4
const FORGE_COST_MATERIAL_ID: String = "material_id"
const FORGE_COST_AMOUNT: String = "amount"

# 装備を素材に戻したときの基礎量。上げた等級ぶんは全額戻す。
const DISMANTLE_REFUND_BASE: int = 3

# get_equippable_instances() / get_owned_instances() が返す Dictionary のキー。
const INSTANCE_VIEW_ID: String = "instance_id"
const INSTANCE_VIEW_STATS: String = "stats"
const INSTANCE_VIEW_EQUIPPED_BY: String = "equipped_by"
const INSTANCE_VIEW_SORT_ORDER: String = "sort_order"

# Balance.workshop が読めなかったときの既定値。
const DEFAULT_MAX_QUEUE_SLOTS: int = 1
const DEFAULT_CRAFT_DURATION_SEC: int = 1800

func _ready() -> void:
	print("[GameManager] _ready() — initializing from Balance.initial_state")
	if Balance != null and Balance.initial_state != null:
		_init_from_config(Balance.initial_state)
	else:
		push_warning("[GameManager] Balance.initial_state is null — using empty defaults")
		_state = _empty_state_template()
	# 研究ツリーを research.json から流し込む。
	# _empty_state_template() の research_tree は {} のため、これが無いと画面に1つも出ない。
	_sync_research_tree_from_master()
	# ショップのラインナップを shop.json から流し込む。research_tree と同じ理由で、
	# _empty_state_template() の line_up は [] のため、これが無いと画面に1つも出ない。
	_sync_shops_from_master()
	# 流し込んだ「あと」に日付を見る。順序が逆だと、リセットした購入回数を
	# セーブ側の値で上書きしてしまう。
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピを recipes.json から流し込む。research_tree / line_up と同じ理由で、
	# _empty_state_template() の recipes_unlocked は {} のため、これが無いと画面に1つも出ない。
	_sync_recipes_from_master()
	# 起動した時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
	# materials も出す。initial_state に足した素材が届いているかを、
	# セーブファイルを開かずに確認できるようにするため。
	print("[GameManager] init complete. gold=%d stamina=%s materials=%s unlocked_screens=%s" % [
		int(_state.get(GameStateKeys.GOLD, 0)),
		_state.get(GameStateKeys.STAMINA, {}),
		_state.get(GameStateKeys.MATERIALS, {}),
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
		# ⚠ save_version の出どころは3箇所ある。上げるときは3つとも上げること。
		#   1. ここ（Balance.initial_state が無いときのフォールバック）
		#   2. save_manager.gd の CURRENT_SAVE_VERSION
		#   3. initial_state_config.tres の save_version（新規開始で実際に効くのはこれ）
		# SaveManager.CURRENT_SAVE_VERSION を参照しないこと。GameManager は Autoload 2番目、
		# SaveManager は3番目で、_ready() の時点でまだ初期化されていない。
		GameStateKeys.SAVE_VERSION: 2,
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
		GameStateKeys.EQUIPMENT_INSTANCES: {},
		GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID: 1,
		GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY: 0,
		GameStateKeys.REACHED_CHEST_THRESHOLDS: [],
		GameStateKeys.UNCLAIMED_CHESTS: [],
		GameStateKeys.LAST_PROTECTION_SELECTED_AT: "",
		GameStateKeys.SELECTED_PROTECTION_TYPE: "",
		GameStateKeys.POTION_FOCUS_REMAINDER: 0,
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
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	var max_stamina: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	
	current += amount
	if current > max_stamina:
		current = max_stamina
	
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d" % [amount, current])
	resource_changed.emit(GameStateKeys.STAMINA, current)

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
#
# 装備だけは inventory に入れず、1個につき個体（eq_N）を1つ作る。
# 装備の入口は宝箱（open_chest）・ショップ（purchase_shop_item）・作業場（collect_craft）の
# 3つあるが、どれも最後はこの関数を通るため、個体の生成をここに1箇所だけ置いている。
# 判定に item_type 引数を使わないのは、open_chest() が第3引数を渡さないため。
func add_to_inventory(item_id: String, count: int, item_type: String = GameStateKeys.ITEM_TYPE_UNKNOWN) -> void:
	if _is_equipment_item(item_id):
		var newly: bool = _mark_codex_discovered(item_id)
		var last_instance_id: String = ""
		for i: int in range(count):
			last_instance_id = _create_equipment_instance(item_id)
		print("[GameManager] add_to_inventory('%s', %d) -> equipment instances (last=%s newly_discovered=%s)" % [
			item_id, count, last_instance_id, newly
		])
		# 1回の受け取りで何個来ても、飛ばすシグナルは1本にする（再描画を並走させない）。
		equipment_instances_changed.emit(last_instance_id)
		return

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

	var newly_discovered: bool = _mark_codex_discovered(item_id)
	print("[GameManager] add_to_inventory('%s', %d, type='%s') -> count=%d newly_discovered=%s" % [
		item_id, count, str(entry[GameStateKeys.ITEM_TYPE]), int(entry[GameStateKeys.ITEM_COUNT]), newly_discovered])
	inventory_changed.emit(item_id)

# 図鑑の discovered を立てる。初出なら true。
# 装備は inventory を通らないため、切り出して両方から呼ぶ。
func _mark_codex_discovered(item_id: String) -> bool:
	var codex: Dictionary = _copy_dict(GameStateKeys.CODEX)
	if codex.has(item_id):
		return false
	codex[item_id] = {
		GameStateKeys.CODEX_DISCOVERED: true,
		GameStateKeys.CODEX_OBTAINED_AT: str(Time.get_unix_time_from_system()),
	}
	_state[GameStateKeys.CODEX] = codex
	return true

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

# --- ポモドーロ：しきい値と宝箱 ---

# その日の累計作業分を加算する。振り返りが確定したセットのみ呼ばれる想定。
func add_focus_minutes(minutes: int) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	
	var current: int = int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))
	var new_total: int = current + minutes
	_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = new_total
	print("[GameManager] add_focus_minutes(%d) -> total=%d" % [minutes, new_total])
	# ここでしきい値判定を自動で行わず、PomodoroController 側で明示的に跨ぎを制御できるように口を開けておく
	# (指示書 7-6 は PomodoroController 側で判定する手順になっている)

# その日の累計作業分を取得する
func get_cumulative_focus_minutes() -> int:
	_refresh_daily_pomodoro_stats_if_needed()
	return int(_state.get(GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY, 0))

# しきい値に到達済みか（同じしきい値で二重に宝箱を発生させないため）
func has_reached_threshold(threshold_min: int) -> bool:
	var reached: Array = _state.get(GameStateKeys.REACHED_CHEST_THRESHOLDS, [])
	return int(threshold_min) in reached

# しきい値到達を記録し、受け取り待ちの宝箱を積む。
# この時点では add_pending_chest() を呼ばない（受け取りは拠点帰還時）。
func record_reached_threshold(threshold_min: int, chest_type: String) -> void:
	var reached: Array = _copy_array(GameStateKeys.REACHED_CHEST_THRESHOLDS)
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	
	if not (int(threshold_min) in reached):
		reached.append(int(threshold_min))
		unclaimed.append(chest_type)
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = reached
		_state[GameStateKeys.UNCLAIMED_CHESTS] = unclaimed
		print("[GameManager] recorded threshold: %d min -> %s" % [threshold_min, chest_type])

# 宝箱に入れる装備。export を足す前に保存した .tres でも落ちないよう null を潰す。
func _chest_equipment(content_config: ChestContentConfig) -> Dictionary:
	if content_config == null or content_config.equipment == null:
		return {}
	return content_config.equipment.duplicate(true)

# 受け取り待ちの宝箱の一覧を取得する
func get_unclaimed_chests() -> Array:
	return _state.get(GameStateKeys.UNCLAIMED_CHESTS, []).duplicate(true)

# 受け取り待ちの宝箱をすべて pending_chests へ移し、unclaimed_chests を空にする。
# 付与した件数を返す。
func claim_pending_chests() -> int:
	var unclaimed: Array = _copy_array(GameStateKeys.UNCLAIMED_CHESTS)
	if unclaimed.is_empty():
		return 0
	
	var count: int = 0
	for chest_type: String in unclaimed:
		var content_config: ChestContentConfig = null
		for c in Balance.pomodoro.chest_contents:
			if c.chest_type == chest_type:
				content_config = c
				break
		
		if content_config == null:
			push_warning("[GameManager] chest_type not found in config: " + chest_type)
			continue
			
		var chest_data: Dictionary = {
			GameStateKeys.CHEST_ID: str(Time.get_unix_time_from_system()) + "_" + str(randi()),
			GameStateKeys.CHEST_TYPE: chest_type,
			GameStateKeys.CHEST_SOURCE: GameStateKeys.CHEST_SOURCE_POMODORO,
			GameStateKeys.CHEST_OBTAINED_AT: str(Time.get_unix_time_from_system()),
			GameStateKeys.CHEST_OPENED: false,
			GameStateKeys.CHEST_REWARDS: {
				GameStateKeys.REWARD_GOLD: 0,
				GameStateKeys.REWARD_GEMS: 0,
				GameStateKeys.REWARD_STAMINA: 0,
				GameStateKeys.REWARD_MATERIALS: content_config.materials.duplicate(true),
				# 装備は rewards の inventory に入れる。open_chest() がこれを
				# add_to_inventory() に流し、そこで個体（eq_N）が作られる。
				# ChestContentConfig に書くだけで済み、開封側のコードは要らない。
				GameStateKeys.REWARD_INVENTORY: _chest_equipment(content_config)
			}
		}
		add_pending_chest(chest_data)
		count += 1
	
	_state[GameStateKeys.UNCLAIMED_CHESTS] = []
	print("[GameManager] claimed %d chests" % count)
	return count

# 加護の選択を記録する（選択時刻も記録し、翌日の再表示判定に使う）
func set_protection_type(protection_id: String) -> void:
	_refresh_daily_pomodoro_stats_if_needed()
	_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = protection_id
	_state[GameStateKeys.LAST_PROTECTION_SELECTED_AT] = str(Time.get_unix_time_from_system())
	print("[GameManager] set_protection_type('%s')" % protection_id)

# 今日すでに加護を選んでいるか（毎朝4:00基準）
func has_selected_protection_today() -> bool:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at == "":
		return false
	return GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system())

# 日付が変わっていれば当日データをリセットする。
func reset_daily_pomodoro_state_if_needed() -> void:
	_refresh_daily_pomodoro_stats_if_needed()

# 日付が変わっていたら累計作業分としきい値をリセットする内部関数
func _refresh_daily_pomodoro_stats_if_needed() -> void:
	var last_at: String = str(_state.get(GameStateKeys.LAST_PROTECTION_SELECTED_AT, ""))
	if last_at != "" and not GameDate.is_same_game_day(float(last_at), Time.get_unix_time_from_system()):
		print("[GameManager] new day detected - resetting daily pomodoro stats")
		_state[GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY] = 0
		_state[GameStateKeys.REACHED_CHEST_THRESHOLDS] = []
		_state[GameStateKeys.SELECTED_PROTECTION_TYPE] = ""
		# UNCLAIMED_CHESTS はリセットしない

func _check_chest_thresholds(_old_total: int, new_total: int) -> void:
	pass # PomodoroController 側で呼ぶため不要になったが互換性のために残すか、削除する

func add_cumulative_focus_minutes(minutes: int) -> void:
	add_focus_minutes(minutes)

func claim_unclaimed_chests() -> void:
	var _cnt = claim_pending_chests()

func is_protection_selected_today() -> bool:
	return has_selected_protection_today()

func get_cumulative_focus_minutes_today() -> int:
	return get_cumulative_focus_minutes()

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

# 商品を1つ購入する。
# 不明な shop_type・存在しない slot_id・売り切れ・残高不足のときは
# 何もせず false を返す。成功時は通貨を減らし、素材またはアイテムを増やして
# shop_changed を発火する。
#
# 判定の順番は unlock_research_node() と揃える：
#   存在 → 在庫 → 残高 → （ここから状態を変える）
# add_gold() / add_gems() は残高を確認しないため、減算する前に必ずここで確認する。
func purchase_shop_item(shop_type: String, slot_id: int) -> bool:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] purchase_shop_item: unknown shop_type: " + shop_type)
		return false

	var shop: Dictionary = _state.get(key, {})
	var line_up: Variant = shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if not (line_up is Array):
		push_warning("[GameManager] purchase_shop_item: line_up is not Array: " + shop_type)
		return false

	var index: int = _find_shop_slot_index(line_up as Array, slot_id)
	if index < 0:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (slot not found)" % [shop_type, slot_id])
		return false

	var slot: Dictionary = (line_up as Array)[index]

	# 在庫。stock_limit が 0 以下のスロットは「無制限」ではなく「買えない」として扱う。
	# 0 を無制限にすると、shop.json の書き忘れがそのまま無限購入になる。
	var stock_limit: int = int(slot.get(GameStateKeys.SHOP_STOCK_LIMIT, 0))
	var purchased_count: int = int(slot.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0))
	if stock_limit <= 0 or purchased_count >= stock_limit:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (sold out: %d/%d)" % [
			shop_type, slot_id, purchased_count, stock_limit
		])
		return false

	# 受け取るもの。状態を変える前に不正な定義を弾いておく
	# （通貨を減らしたあとで「渡せません」が起きないようにするため）。
	var item_id: String = str(slot.get(GameStateKeys.SHOP_ITEM_ID, ""))
	var payout_type: String = str(slot.get(SHOP_SLOT_PAYOUT_TYPE, PAYOUT_TYPE_ITEM))
	var payout_count: int = int(slot.get(SHOP_SLOT_PAYOUT_COUNT, 1))
	if item_id == "":
		push_warning("[GameManager] purchase_shop_item: item_id が未設定（shop.json）: slot %d" % slot_id)
		return false
	if payout_count <= 0:
		push_warning("[GameManager] purchase_shop_item: count が 0 以下（shop.json）: slot %d" % slot_id)
		return false
	if payout_type != PAYOUT_TYPE_MATERIAL and payout_type != PAYOUT_TYPE_ITEM:
		push_warning("[GameManager] purchase_shop_item: 未知の payout_type: " + payout_type)
		return false

	# 残高
	var cost: Dictionary = slot.get(GameStateKeys.SHOP_COST, {})
	var currency_type: String = str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, ""))
	var amount: int = int(cost.get(GameStateKeys.COST_AMOUNT, 0))
	if amount < 0:
		push_warning("[GameManager] purchase_shop_item: cost.amount が負（shop.json）: slot %d" % slot_id)
		return false
	var balance: int = _get_currency_balance(currency_type)
	if balance < 0:
		push_warning("[GameManager] purchase_shop_item: 未知の currency_type: " + currency_type)
		return false
	if balance < amount:
		print("[GameManager] purchase_shop_item('%s', %d) -> false (%s: %d < %d)" % [
			shop_type, slot_id, currency_type, balance, amount
		])
		return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# _copy_dict() は浅いコピーのため、line_up の配列と各スロットを
	# duplicate(true) してから書き換える。これを飛ばすと _state 内の実体を直接触る。
	var new_shop: Dictionary = _copy_dict(key)
	var new_line_up: Array = (line_up as Array).duplicate(true)
	var new_slot: Dictionary = new_line_up[index]
	new_slot[GameStateKeys.SHOP_PURCHASED_COUNT] = purchased_count + 1
	new_line_up[index] = new_slot
	new_shop[GameStateKeys.SHOP_LINE_UP] = new_line_up
	_state[key] = new_shop

	# 通貨の減算・受け取りはラインナップを更新したあとに行う。
	# resource_changed / material_changed を受けて再描画する画面が、
	# 購入済み回数が増えた状態を見られるようにするため。
	if amount > 0:
		_spend_currency(currency_type, amount)

	if payout_type == PAYOUT_TYPE_MATERIAL:
		add_material(item_id, payout_count)
	else:
		add_to_inventory(item_id, payout_count, str(slot.get(SHOP_SLOT_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)))

	print("[GameManager] purchase_shop_item('%s', %d) -> true (%s x%d for %s %d, stock %d/%d)" % [
		shop_type, slot_id, item_id, payout_count, currency_type, amount,
		purchased_count + 1, stock_limit
	])
	shop_changed.emit(shop_type)
	return true

# ゲーム内の日付が変わっていれば購入回数を戻す。
#
# 第1弾はラインナップが固定のため、リフレッシュ＝「purchased_count を 0 に戻す」だけ。
# 抽選を入れる場合も、この関数の中でラインナップを組み直せば呼び出し側は変わらない。
#
# 日付の判定は必ず GameDate を経由する。ここで Time を直接使うと、
# ポモドーロの加護選択・ストリークと 4:00 の基準がずれる。
func refresh_shop_if_needed(shop_type: String) -> void:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] refresh_shop_if_needed: unknown shop_type: " + shop_type)
		return

	# 週替わり・月替わりは第1弾では未実装（週・月の区切りが未確定のため）。
	# 誤って日単位でリセットしないよう、ここで明示的に何もせず返す。
	if shop_type != GameStateKeys.SHOP_TYPE_DAILY:
		print("[GameManager] refresh_shop_if_needed('%s') -> skip (第1弾は daily のみ)" % shop_type)
		return

	var shop: Dictionary = _state.get(key, {})
	var last_refreshed: String = str(shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))
	var today: String = GameDate.get_game_date_string()
	if last_refreshed == today:
		print("[GameManager] refresh_shop_if_needed('%s') -> no refresh (%s)" % [shop_type, today])
		return

	var new_shop: Dictionary = _copy_dict(key)
	var line_up: Variant = new_shop.get(GameStateKeys.SHOP_LINE_UP, [])
	var new_line_up: Array = []
	if line_up is Array:
		new_line_up = (line_up as Array).duplicate(true)
	for i: int in range(new_line_up.size()):
		if not (new_line_up[i] is Dictionary):
			continue
		var slot: Dictionary = new_line_up[i]
		slot[GameStateKeys.SHOP_PURCHASED_COUNT] = 0
		new_line_up[i] = slot
	new_shop[GameStateKeys.SHOP_LINE_UP] = new_line_up
	new_shop[GameStateKeys.SHOP_REFRESH_AT] = today
	_state[key] = new_shop

	print("[GameManager] refresh_shop_if_needed('%s') -> refreshed (%s -> %s, %d slots)" % [
		shop_type, last_refreshed, today, new_line_up.size()
	])
	shop_changed.emit(shop_type)

# --- ショップ：内部ヘルパー ---

# line_up の中から slot_id が一致する要素の位置を返す。見つからなければ -1。
# 配列の添字と slot_id は一致するとは限らない（shop.json で歯抜けの番号を振れるため）。
func _find_shop_slot_index(line_up: Array, slot_id: int) -> int:
	for i: int in range(line_up.size()):
		if not (line_up[i] is Dictionary):
			continue
		if int((line_up[i] as Dictionary).get(GameStateKeys.SHOP_SLOT_ID, -1)) == slot_id:
			return i
	return -1

# 通貨の所持数。未知の currency_type では -1 を返す（0 と区別するため）。
func _get_currency_balance(currency_type: String) -> int:
	match currency_type:
		GameStateKeys.GOLD:
			return int(_state.get(GameStateKeys.GOLD, 0))
		GameStateKeys.GEMS:
			return int(_state.get(GameStateKeys.GEMS, 0))
	return -1

# 残高の確認は呼び出し側で済ませてあること。この関数は確認しない。
func _spend_currency(currency_type: String, amount: int) -> void:
	match currency_type:
		GameStateKeys.GOLD:
			add_gold(-amount)
		GameStateKeys.GEMS:
			add_gems(-amount)

# shop.json の定義を各ショップの line_up へ流し込む。
#
# purchased_count だけは既存の値を残し、それ以外（item_id / cost / stock_limit /
# payout_type / count / item_type）は毎回マスターデータで上書きする。
# これで shop.json の価格を変えると、既存セーブにも次の起動で反映される。
# 研究の _sync_research_tree_from_master() と同じ型（AGENTS.md「マスターデータと状態を同期する型」）。
#
# refresh_at には触らない。ここで消すと、起動するたびに購入回数が戻る。
#
# shop.json から消えた slot_id はラインナップからも消える。
# slot_id を振り直すと購入回数が別の商品に付け替わるため、番号は使い回さないこと。
func _sync_shops_from_master() -> void:
	for shop_type: String in MasterDataLoader.get_all_shop_types():
		_sync_shop_from_master(shop_type)

func _sync_shop_from_master(shop_type: String) -> void:
	var key: String = _shop_key(shop_type)
	if key == "":
		push_warning("[GameManager] _sync_shop_from_master: shop.json に未知の shop_type: " + shop_type)
		return

	var slots: Array = MasterDataLoader.get_shop_slots(shop_type)
	if slots.is_empty():
		push_warning("[GameManager] _sync_shop_from_master: shop.json の '%s' が空か読み込めない" % shop_type)
		return

	# 既存の購入回数を slot_id で引けるようにしておく
	var current_shop: Dictionary = _state.get(key, {})
	var current_counts: Dictionary = {}
	var current_line_up: Variant = current_shop.get(GameStateKeys.SHOP_LINE_UP, [])
	if current_line_up is Array:
		for entry: Variant in (current_line_up as Array):
			if not (entry is Dictionary):
				continue
			var existing: Dictionary = entry
			var existing_slot_id: int = int(existing.get(GameStateKeys.SHOP_SLOT_ID, -1))
			current_counts[existing_slot_id] = int(existing.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0))

	var synced: Array = []
	for entry: Variant in slots:
		if not (entry is Dictionary):
			continue
		var definition: Dictionary = entry
		var slot_id: int = int(definition.get(GameStateKeys.SHOP_SLOT_ID, -1))
		if slot_id < 0:
			push_warning("[GameManager] _sync_shop_from_master: slot_id が無いスロットを飛ばした")
			continue

		# MasterDataLoader は JSON をそのまま返すため数値は float で来る。int() 必須。
		# 包み忘れるとセーブに 100.0 と書かれる。
		var stock_limit: int = int(definition.get(GameStateKeys.SHOP_STOCK_LIMIT, 0))
		var purchased_count: int = int(current_counts.get(slot_id, 0))
		# stock_limit を下げたとき、購入回数が上限を超えたまま残らないようにする
		if purchased_count > stock_limit:
			purchased_count = stock_limit

		var cost_definition: Dictionary = definition.get(GameStateKeys.SHOP_COST, {})
		synced.append({
			GameStateKeys.SHOP_SLOT_ID: slot_id,
			GameStateKeys.SHOP_ITEM_ID: str(definition.get(GameStateKeys.SHOP_ITEM_ID, "")),
			GameStateKeys.SHOP_COST: {
				GameStateKeys.COST_CURRENCY_TYPE: str(cost_definition.get(GameStateKeys.COST_CURRENCY_TYPE, GameStateKeys.GOLD)),
				GameStateKeys.COST_AMOUNT: int(cost_definition.get(GameStateKeys.COST_AMOUNT, 0)),
			},
			GameStateKeys.SHOP_STOCK_LIMIT: stock_limit,
			GameStateKeys.SHOP_PURCHASED_COUNT: purchased_count,
			SHOP_SLOT_PAYOUT_TYPE: str(definition.get(SHOP_SLOT_PAYOUT_TYPE, PAYOUT_TYPE_ITEM)),
			SHOP_SLOT_PAYOUT_COUNT: int(definition.get(SHOP_SLOT_PAYOUT_COUNT, 1)),
			SHOP_SLOT_ITEM_TYPE: str(definition.get(SHOP_SLOT_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)),
		})

	var new_shop: Dictionary = _copy_dict(key)
	new_shop[GameStateKeys.SHOP_LINE_UP] = synced
	if not new_shop.has(GameStateKeys.SHOP_REFRESH_AT):
		new_shop[GameStateKeys.SHOP_REFRESH_AT] = ""
	_state[key] = new_shop

	print("[GameManager] _sync_shop_from_master('%s') -> %d slots (refresh_at='%s')" % [
		shop_type, synced.size(), str(new_shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))
	])

# --- 育成 ---

# 育成データを返す。エントリが無ければ characters.json から既定値（レベル1）を組み立てて返す。
#
# 既定値は _state に書き込まない。理由：
#  - レベル1のキャラはセーブデータに現れず、キャラクターを追加しても移行処理が要らない
#  - 「読んだだけで状態が変わる」getter を作らない
func get_character_growth(character_id: String) -> Dictionary:
	var growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	var entry: Dictionary = growth.get(character_id, {})
	if entry.is_empty():
		return _default_growth_for(character_id)
	return entry.duplicate(true)

# 保存されている素の値に、研究と装備のボーナスを合成した最終値を返す。
# 表示と戦闘の両方がこちらを使う。
#
# stats そのものに研究・装備の効果を混ぜないのは、研究ノードの効果値や装備の性能値を
# 変えたときに、既存セーブの stats が実態とずれるのを避けるため。
# 状態が持つのは「どのレベルか」「どの item_id を装備しているか」だけ。
func get_effective_stats(character_id: String) -> Dictionary:
	var growth: Dictionary = get_character_growth(character_id)
	var raw: Dictionary = growth.get(GameStateKeys.GROWTH_STATS, {})
	var boosts: Dictionary = get_stat_boost_all()
	var boost_all: int = int(boosts.get(STAT_BOOST_ALL_KEY, 0))
	var equip: Dictionary = get_equipment_bonus(character_id)

	var result: Dictionary = {}
	var percent_keys: Array[String] = _percent_stat_keys()
	for stat_key: String in _stat_keys():
		# 研究の「全ステータス+N」は実数軸だけに乗せる。
		# ％軸に乗せると1ノードで会心率とCD短縮が同時に上がる（_percent_stat_keys()）。
		var all_bonus: int = 0 if stat_key in percent_keys else boost_all
		result[stat_key] = (
			int(raw.get(stat_key, 0))
			+ int(boosts.get(stat_key, 0))
			+ all_bonus
			+ int(equip.get(stat_key, 0))
		)
	return result

# 現在のレベルから1つ上げるのに必要な素材を返す。
# 戻り値: {material_id: String, amount: int}
func get_level_up_cost(character_id: String) -> Dictionary:
	var empty: Dictionary = {LEVEL_UP_COST_MATERIAL_ID: "", LEVEL_UP_COST_AMOUNT: 0}
	if Balance == null or Balance.character == null:
		push_warning("[GameManager] get_level_up_cost: Balance.character is null")
		return empty

	var config: CharacterConfig = Balance.character
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var base: float = float(config.base_level_up_cost)
	var growth: float = config.cost_growth_per_level
	var fallback: float = base + growth * float(level - 1)

	var amount: int = GrowthFormula.evaluate_int(
		config.level_up_cost_formula,
		{"base": base, "growth": growth, "level": float(level)},
		fallback
	)
	if amount < 0:
		amount = 0

	return {
		LEVEL_UP_COST_MATERIAL_ID: config.level_up_material_id,
		LEVEL_UP_COST_AMOUNT: amount,
	}

# レベルを1つ上げる。上限到達・素材不足のときは何もせず false を返す。
# 成功時は素材を消費し、stats を再計算して character_growth_changed を発火する。
func level_up_character(character_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		push_warning("[GameManager] level_up_character: unknown character_id: " + character_id)
		return false

	var level: int = int(growth.get(GameStateKeys.GROWTH_LEVEL, 1))
	var cap: int = get_effective_level_cap(character_id)
	if level >= cap:
		print("[GameManager] level_up_character('%s') -> false (level %d >= cap %d)" % [character_id, level, cap])
		return false

	var cost: Dictionary = get_level_up_cost(character_id)
	var material_id: String = str(cost.get(LEVEL_UP_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(LEVEL_UP_COST_AMOUNT, 0))
	if material_id == "":
		push_warning("[GameManager] level_up_character: level_up_material_id が未設定（character_config.tres）")
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	var owned: int = get_material_count(material_id)
	if owned < amount:
		print("[GameManager] level_up_character('%s') -> false (material %s: %d < %d)" % [
			character_id, material_id, owned, amount
		])
		return false

	if amount > 0:
		add_material(material_id, -amount)

	var new_level: int = level + 1
	# growth は get_character_growth() が返した複製なので、直接書き換えてよい。
	growth[GameStateKeys.GROWTH_LEVEL] = new_level
	growth[GameStateKeys.GROWTH_STATS] = _recalc_stats(character_id, new_level)

	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	all_growth[character_id] = growth
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth

	print("[GameManager] level_up_character('%s') -> true (level=%d stats=%s)" % [
		character_id, new_level, growth[GameStateKeys.GROWTH_STATS]
	])
	character_growth_changed.emit(character_id)
	return true

# --- 育成：内部ヘルパー ---

# stats のキー10本（GAME_DESIGN.md 8-1）。並びは 8-1 の表と同じ順。
# 順序を固定したいので配列で持つ。
#
# ここに足すと追従するもの：
#   get_effective_stats() / get_instance_stats() / get_equipment_bonus()
#   _default_growth_for() / _recalc_stats() / load_state() の int() 正規化
#
# 戦闘も追従する（EXEC_STATS_10_AXES_FORMULA.md）：
#   BattleUnit.create() が get_stat_keys() を回して 10軸を取り込む。
#   ただし式（どの軸をどう使うか）は BattleFormula と BattleUnit.get_power() /
#   get_defense() にあるので、新しい軸を「効かせる」にはそちらも直すこと。
func _stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_HP,
		GameStateKeys.STAT_ATK,
		GameStateKeys.STAT_MAG,
		GameStateKeys.STAT_DEF,
		GameStateKeys.STAT_MDEF,
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
		GameStateKeys.STAT_SPD,
	]

# 画面がステータスをこの順で並べるために公開する（get_equip_slots() と同じ形）。
# 画面側に軸の配列を複製させないこと。以前 equipment_screen.gd に
# _stat_labels() という2本目の4軸配列があり、片方だけ直す事故の元になっていた。
func get_stat_keys() -> Array[String]:
	return _stat_keys()

# ％で持つ軸（GAME_DESIGN.md 8-1）。実数軸と同じ stats 辞書に入るが、扱いが2箇所だけ違う。
#
#  1. 研究の「全ステータス+N」（stat_boost_all の target_stat = "all"）の対象にしない
#  2. 画面に "%" を付けて出す
#
# 1 を守らないと、研究ノード1つで crit_rate と haste が同時に上がる。
# ％系は装備と装飾だけで動かす前提（PLAN_STATS_AND_FORMULAS.md 4章）なので、
# 研究で上がると装飾を刺す理由が消える。
#
# なお target_stat で名指しされた加算（boosts.get(stat_key)）は％軸にも効かせる。
# 「会心率を上げる研究ノード」を将来置けるようにするため。
func _percent_stat_keys() -> Array[String]:
	return [
		GameStateKeys.STAT_ATKSPD,
		GameStateKeys.STAT_HASTE,
		GameStateKeys.STAT_CRIT_RATE,
		GameStateKeys.STAT_CRIT_DMG,
	]

# 画面が "%" を付けるかどうかの判定に使う。
func is_percent_stat(stat_key: String) -> bool:
	return stat_key in _percent_stat_keys()

# characters.json からレベル1の既定値を組み立てる。存在しないIDなら空を返す。
#
# MasterDataLoader は JSON をそのまま返すため、数値は float で来る。
# int() で包まないと、セーブに "hp": 120.0 と書かれる。
func _default_growth_for(character_id: String) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		stats[stat_key] = int(char_data.get(stat_key, 0))

	return {
		GameStateKeys.GROWTH_LEVEL: 1,
		GameStateKeys.GROWTH_STATS: stats,
		# skills の中身（slots）はスキル選択の実装時に入れる。
		# 今そこに "slots" と書くと state_keys.gd に無いキーを文字列で書くことになるため空にしておく。
		GameStateKeys.GROWTH_SKILLS: {},
		GameStateKeys.GROWTH_EQUIPMENT: {
			GameStateKeys.EQUIP_HEAD: null,
			GameStateKeys.EQUIP_ARMOR: null,
			GameStateKeys.EQUIP_LEGS: null,
			GameStateKeys.EQUIP_WEAPON: null,
			GameStateKeys.EQUIP_ACCESSORY: null,
		},
	}

# 指定レベルにおける stats を、stat_growth_formula で計算し直す。
# 差分を足し込むのではなく毎回レベルから計算するため、式を変えても既存データが追従する。
func _recalc_stats(character_id: String, level: int) -> Dictionary:
	var char_data: Dictionary = MasterDataLoader.get_character(character_id)
	if char_data.is_empty():
		return {}

	var growth_table: Dictionary = char_data.get("growth_per_level", {})
	var formula: String = ""
	if Balance != null and Balance.character != null:
		formula = Balance.character.stat_growth_formula

	var stats: Dictionary = {}
	for stat_key: String in _stat_keys():
		var base: float = float(char_data.get(stat_key, 0))
		# growth_per_level を持たないキャラは 0 として扱う（伸びないだけで、エラーにしない）。
		var growth: float = float(growth_table.get(stat_key, 0))
		var fallback: float = base + growth * float(level - 1)
		stats[stat_key] = GrowthFormula.evaluate_int(
			formula,
			{"base": base, "growth": growth, "level": float(level)},
			fallback
		)
	return stats

# --- 装備：スロット ---

# 装備できるスロット名。順序を固定したいので配列で持つ（_stat_keys() と同じ形）。
# 画面もこの順で並ぶ：頭・上半身・下半身・武器・アクセサリー。
# armor は「上半身」の内部キー。改名しない（既存セーブのキーが変わるため）。
func _equip_slots() -> Array[String]:
	return [
		GameStateKeys.EQUIP_HEAD,
		GameStateKeys.EQUIP_ARMOR,
		GameStateKeys.EQUIP_LEGS,
		GameStateKeys.EQUIP_WEAPON,
		GameStateKeys.EQUIP_ACCESSORY,
	]

# 画面が「頭・上半身・…」の順でスロットを並べるために公開する。
func get_equip_slots() -> Array[String]:
	return _equip_slots()

# --- 装備：個体 ---

# item_id が装備品かどうか。items.json だけで判定する。
func _is_equipment_item(item_id: String) -> bool:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return false
	return str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) == GameStateKeys.ITEM_TYPE_EQUIPMENT

# 個体1つ分。存在しなければ空。
func get_equipment_instance(instance_id: String) -> Dictionary:
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	var entry: Variant = instances.get(instance_id, null)
	if not (entry is Dictionary):
		return {}
	return (entry as Dictionary).duplicate(true)

# 個体を1つ作る。戻り値は新しい instance_id。
# 呼ぶのは add_to_inventory() だけ（シグナルもそちらが1本だけ飛ばす）。
func _create_equipment_instance(item_id: String) -> String:
	var next_id: int = int(_state.get(GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID, 1))
	var instance_id: String = INSTANCE_ID_PREFIX + str(next_id)

	# parts は null 込みの長さ固定配列。位置が枠を表す。
	# 「刺さっているものだけ入れる」形にすると、どちらの枠か分からなくなる。
	var parts: Array = []
	for i: int in range(PART_SLOT_COUNT):
		parts.append(null)

	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances[instance_id] = {
		GameStateKeys.INSTANCE_ITEM_ID: item_id,
		GameStateKeys.INSTANCE_GRADE: 1,
		GameStateKeys.INSTANCE_PARTS: parts,
	}
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances
	_state[GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID] = next_id + 1

	print("[GameManager] _create_equipment_instance('%s') -> %s" % [item_id, instance_id])
	return instance_id

# 個体1つ分を _state へ書き戻す（_write_growth() と同じ形）。
func _write_instance(instance_id: String, instance: Dictionary) -> void:
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances[instance_id] = instance
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

# その個体を装備しているキャラのID。どこにも装備していなければ ""。
# 在庫から出し入れせず「どこかのスロットに入っているか」で絞る（PLAN 2-2）。
func _equipped_owner(instance_id: String) -> String:
	if instance_id == "":
		return ""
	var all_growth: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	for character_id: String in all_growth:
		if not (all_growth[character_id] is Dictionary):
			continue
		var equipment: Variant = (all_growth[character_id] as Dictionary).get(GameStateKeys.GROWTH_EQUIPMENT, {})
		if not (equipment is Dictionary):
			continue
		for slot: String in _equip_slots():
			var value: Variant = (equipment as Dictionary).get(slot, null)
			if value != null and str(value) == instance_id:
				return character_id
	return ""

# 等級から、開いている枠の数を計算する。状態には持たない（PLAN 2-2）。
# 第1弾は上限が3なので常に0。器だけ先に作っている。
func get_open_part_slot_count(grade: int) -> int:
	var count: int = 0
	for required_grade: int in PART_SLOT_GRADES:
		if grade >= required_grade:
			count += 1
	return count

# --- 装備：性能 ---

# 個体1つ分のステータス加算。{hp, atk, def, spd} を必ず4つ返す。
#
# 性能値は状態に持たない。equip_stats × 等級係数で毎回計算する。
# こうすると items.json を調整したときに既存の個体へも次の起動で反映される。
#
# 等級1が素の値。1つ上がるごとに基礎値の GRADE_STAT_RATIO 倍を加算する（乗算にしない）。
# MasterDataLoader は JSON をそのまま返すため、必ず int() で包む。
func get_instance_stats(instance_id: String) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in _stat_keys():
		result[stat_key] = 0

	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return result

	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		# items.json から消えたIDを装備したまま。装備は外れないが加算されない。
		# リリース後にアイテムIDを改名しないこと（レシピIDと同じ制約）。
		push_warning("[GameManager] get_instance_stats: items.json に無いID: " + item_id)
		return result

	var equip_stats: Variant = definition.get(ITEM_MASTER_EQUIP_STATS, {})
	if not (equip_stats is Dictionary):
		return result

	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	for stat_key: String in _stat_keys():
		var base: int = int((equip_stats as Dictionary).get(stat_key, 0))
		result[stat_key] = base + int(floor(float(base) * GRADE_STAT_RATIO * float(grade - 1)))
	return result

# 装備している個体のステータス加算の合計。{hp, atk, def, spd} を必ず4つ返す。
func get_equipment_bonus(character_id: String) -> Dictionary:
	var result: Dictionary = {}
	for stat_key: String in _stat_keys():
		result[stat_key] = 0

	for slot: String in _equip_slots():
		var instance_id: String = get_equipped_instance_id(character_id, slot)
		if instance_id == "":
			continue
		var stats: Dictionary = get_instance_stats(instance_id)
		for stat_key: String in _stat_keys():
			result[stat_key] = int(result[stat_key]) + int(stats.get(stat_key, 0))
	return result

# --- 装備：一覧 ---

# 指定スロットに装備している個体ID。何も装備していなければ ""。
func get_equipped_instance_id(character_id: String, slot: String) -> String:
	var growth: Dictionary = get_character_growth(character_id)
	var equipment: Dictionary = growth.get(GameStateKeys.GROWTH_EQUIPMENT, {})
	var value: Variant = equipment.get(slot, null)
	if value == null:
		return ""
	return str(value)

# 持っている装備の個体を全部返す。倉庫が一覧を描くために使う。
# 戻り値: [{instance_id, item_id, grade, parts, stats, equipped_by, sort_order}]
# sort_order の昇順 → 等級の降順。
func get_owned_instances() -> Array:
	var result: Array = []
	var instances: Dictionary = _state.get(GameStateKeys.EQUIPMENT_INSTANCES, {})
	for instance_id: String in instances:
		var instance: Dictionary = get_equipment_instance(instance_id)
		if instance.is_empty():
			continue
		var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
		var definition: Dictionary = MasterDataLoader.get_item(item_id)
		result.append({
			INSTANCE_VIEW_ID: instance_id,
			GameStateKeys.INSTANCE_ITEM_ID: item_id,
			GameStateKeys.INSTANCE_GRADE: int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)),
			GameStateKeys.INSTANCE_PARTS: instance.get(GameStateKeys.INSTANCE_PARTS, []),
			INSTANCE_VIEW_STATS: get_instance_stats(instance_id),
			INSTANCE_VIEW_EQUIPPED_BY: _equipped_owner(instance_id),
			INSTANCE_VIEW_SORT_ORDER: int(definition.get(RECIPE_SORT_ORDER, 0)),
		})
	_sort_instance_view(result)
	return result

# 指定スロットに着けられる、どこにも装備していない個体。装備画面の一覧はこれを使う。
func get_equippable_instances(slot: String) -> Array:
	var result: Array = []
	for entry: Variant in get_owned_instances():
		if not (entry is Dictionary):
			continue
		var view: Dictionary = entry
		if str(view.get(INSTANCE_VIEW_EQUIPPED_BY, "")) != "":
			continue
		var definition: Dictionary = MasterDataLoader.get_item(str(view.get(GameStateKeys.INSTANCE_ITEM_ID, "")))
		if definition.is_empty():
			continue
		if str(definition.get(ITEM_MASTER_EQUIP_SLOT, "")) != slot:
			continue
		result.append(view)
	return result

func _sort_instance_view(list: Array) -> void:
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sort_a: int = int(a.get(INSTANCE_VIEW_SORT_ORDER, 0))
		var sort_b: int = int(b.get(INSTANCE_VIEW_SORT_ORDER, 0))
		if sort_a != sort_b:
			return sort_a < sort_b
		return int(a.get(GameStateKeys.INSTANCE_GRADE, 1)) > int(b.get(GameStateKeys.INSTANCE_GRADE, 1)))

# --- 装備：着脱 ---

# 装備する。成功したら true。
#
# 判定の順番は start_craft() / purchase_shop_item() と揃える。
# 状態を変える前に全部の判定を終える：
#   キャラ存在 → スロット妥当 → 個体が存在 → items.json に存在 → 装備品である
#   → スロット一致 → 他のキャラが装備していない
#
# 在庫を触らないため、飛ぶシグナルは character_growth_changed の1本だけ。
# 前に着けていた個体は equipment_instances に残ったまま「どこにも装備していない」に戻る。
func equip_instance(character_id: String, slot: String, instance_id: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		print("[GameManager] equip_instance('%s') -> false (unknown character)" % character_id)
		return false

	if not _equip_slots().has(slot):
		print("[GameManager] equip_instance('%s') -> false (unknown slot: %s)" % [character_id, slot])
		return false

	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] equip_instance('%s') -> false (unknown instance: %s)" % [character_id, instance_id])
		return false

	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		print("[GameManager] equip_instance('%s') -> false (item not in items.json: %s)" % [character_id, item_id])
		return false

	if str(definition.get(ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_EQUIPMENT:
		print("[GameManager] equip_instance('%s') -> false (not equipment: %s)" % [character_id, item_id])
		return false

	var item_slot: String = str(definition.get(ITEM_MASTER_EQUIP_SLOT, ""))
	if item_slot != slot:
		print("[GameManager] equip_instance('%s') -> false (slot mismatch: item=%s requested=%s)" % [
			character_id, item_slot, slot
		])
		return false

	var owner: String = _equipped_owner(instance_id)
	if owner != "" and owner != character_id:
		print("[GameManager] equip_instance('%s') -> false (equipped by %s)" % [character_id, owner])
		return false

	# --- ここから状態を変える ---

	var previous: String = get_equipped_instance_id(character_id, slot)
	var equipment: Dictionary = (growth.get(GameStateKeys.GROWTH_EQUIPMENT, {}) as Dictionary).duplicate(true)
	equipment[slot] = instance_id
	growth[GameStateKeys.GROWTH_EQUIPMENT] = equipment
	_write_growth(character_id, growth)

	print("[GameManager] equip_instance('%s', '%s', '%s') -> true (item=%s previous=%s bonus=%s)" % [
		character_id, slot, instance_id, item_id, previous, get_equipment_bonus(character_id)
	])
	character_growth_changed.emit(character_id)
	return true

# 外す。何も装備していなければ false。個体は equipment_instances に残る。
func unequip_instance(character_id: String, slot: String) -> bool:
	var growth: Dictionary = get_character_growth(character_id)
	if growth.is_empty():
		print("[GameManager] unequip_instance('%s') -> false (unknown character)" % character_id)
		return false

	if not _equip_slots().has(slot):
		print("[GameManager] unequip_instance('%s') -> false (unknown slot: %s)" % [character_id, slot])
		return false

	var current: String = get_equipped_instance_id(character_id, slot)
	if current == "":
		print("[GameManager] unequip_instance('%s', '%s') -> false (nothing equipped)" % [character_id, slot])
		return false

	# --- ここから状態を変える ---

	var equipment: Dictionary = (growth.get(GameStateKeys.GROWTH_EQUIPMENT, {}) as Dictionary).duplicate(true)
	equipment[slot] = null
	growth[GameStateKeys.GROWTH_EQUIPMENT] = equipment
	_write_growth(character_id, growth)

	print("[GameManager] unequip_instance('%s', '%s') -> true (removed=%s bonus=%s)" % [
		character_id, slot, current, get_equipment_bonus(character_id)
	])
	character_growth_changed.emit(character_id)
	return true

# --- 装備：鍛冶 ---

# 等級を1つ上げるのに必要な素材。{material_id, amount}。上限に達していれば amount = 0。
func get_forge_cost(instance_id: String) -> Dictionary:
	var empty: Dictionary = {FORGE_COST_MATERIAL_ID: FORGE_MATERIAL_ID, FORGE_COST_AMOUNT: 0}
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return empty
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	if grade >= MAX_EQUIPMENT_GRADE:
		return empty
	return {
		FORGE_COST_MATERIAL_ID: FORGE_MATERIAL_ID,
		FORGE_COST_AMOUNT: FORGE_COST_PER_GRADE * (grade + 1),
	}

func can_forge(instance_id: String) -> bool:
	var cost: Dictionary = get_forge_cost(instance_id)
	var amount: int = int(cost.get(FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return false
	return get_material_count(str(cost.get(FORGE_COST_MATERIAL_ID, ""))) >= amount

# 等級を1つ上げる。失敗しない（素材と判定を通れば必ず上がる）。
#
# 待ち時間は持たせていない。時間を入れるならキューがもう1本要り、作業場の Tick を
# 装備画面にもう1つ作ることになるため、あとで個体に grade_up_at を足す形にする。
#
# add_material() が material_changed を飛ばすが、装備画面はそれを購読しない
# （equipment_instances_changed だけを見て再描画する。2本飛ぶと行が二重に並ぶ）。
func forge_equipment(instance_id: String) -> bool:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] forge_equipment('%s') -> false (unknown instance)" % instance_id)
		return false

	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	if grade >= MAX_EQUIPMENT_GRADE:
		print("[GameManager] forge_equipment('%s') -> false (grade %d >= max %d)" % [
			instance_id, grade, MAX_EQUIPMENT_GRADE
		])
		return false

	var cost: Dictionary = get_forge_cost(instance_id)
	var material_id: String = str(cost.get(FORGE_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(FORGE_COST_AMOUNT, 0))
	var owned: int = get_material_count(material_id)
	if owned < amount:
		print("[GameManager] forge_equipment('%s') -> false (material %s: %d < %d)" % [
			instance_id, material_id, owned, amount
		])
		return false

	# --- ここから状態を変える ---

	if amount > 0:
		add_material(material_id, -amount)

	var new_grade: int = grade + 1
	instance[GameStateKeys.INSTANCE_GRADE] = new_grade
	_write_instance(instance_id, instance)

	print("[GameManager] forge_equipment('%s') -> true (grade %d -> %d cost=%d stats=%s slots=%d)" % [
		instance_id, grade, new_grade, amount, get_instance_stats(instance_id),
		get_open_part_slot_count(new_grade)
	])
	equipment_instances_changed.emit(instance_id)
	return true

# 素材に戻したときの戻り量。基礎ぶん＋等級を上げるのに払った全額。
func get_dismantle_refund(instance_id: String) -> int:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		return 0
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	var refund: int = DISMANTLE_REFUND_BASE
	for g: int in range(2, grade + 1):
		refund += FORGE_COST_PER_GRADE * g
	return refund

# 重複した装備を鍛冶の素材に戻す。装備中のものは戻せない。
#
# 自動変換にしていないのは、「同じ装備を2本持って2人に着ける」がこのタスクの目玉のため。
# 2本目を勝手に溶かすと、個体管理が効いているかを確認できなくなる。
func dismantle_equipment(instance_id: String) -> bool:
	var instance: Dictionary = get_equipment_instance(instance_id)
	if instance.is_empty():
		print("[GameManager] dismantle_equipment('%s') -> false (unknown instance)" % instance_id)
		return false

	var owner: String = _equipped_owner(instance_id)
	if owner != "":
		print("[GameManager] dismantle_equipment('%s') -> false (equipped by %s)" % [instance_id, owner])
		return false

	# --- ここから状態を変える ---

	var refund: int = get_dismantle_refund(instance_id)
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	instances.erase(instance_id)
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

	if refund > 0:
		add_material(FORGE_MATERIAL_ID, refund)

	print("[GameManager] dismantle_equipment('%s') -> true (item=%s grade=%d refund=%s x%d)" % [
		instance_id, str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, "")),
		int(instance.get(GameStateKeys.INSTANCE_GRADE, 1)), FORGE_MATERIAL_ID, refund
	])
	equipment_instances_changed.emit(instance_id)
	return true

# 1キャラ分の育成データを _state へ書き戻す。
# level_up_character() が直接書いていた3行と同じ処理。装備でも同じ形が要るため関数にした。
# Dictionary は参照渡しのため、_copy_dict() で複製してから差し替える。
func _write_growth(character_id: String, growth: Dictionary) -> void:
	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	all_growth[character_id] = growth
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth


func select_skill(character_id: String, slot_id: int, skill_id: String) -> void:
	print("[GameManager] select_skill('%s', %d, '%s') (dummy)" % [character_id, slot_id, skill_id])

# --- 研究 ---

func get_research_tree() -> Dictionary:
	return _state.get(GameStateKeys.RESEARCH_TREE, {}).duplicate(true)

# 解放に必要な素材を返す。戻り値: {material_id: String, amount: int}
# コストは research.json 側に持つ（ノードごとに違うため .tres の単一値では表せない）。
func get_research_unlock_cost(node_id: String) -> Dictionary:
	var empty: Dictionary = {RESEARCH_COST_MATERIAL_ID: "", RESEARCH_COST_AMOUNT: 0}
	var definition: Dictionary = MasterDataLoader.get_research_node(node_id)
	if definition.is_empty():
		return empty
	# MasterDataLoader は JSON をそのまま返すため cost_amount は float で来る。int() 必須。
	return {
		RESEARCH_COST_MATERIAL_ID: str(definition.get(RESEARCH_NODE_COST_MATERIAL_ID, "")),
		RESEARCH_COST_AMOUNT: int(definition.get(RESEARCH_NODE_COST_AMOUNT, 0)),
	}

# 前提条件を満たしているか（素材は見ない）。
# 画面が「前提未解放」と「素材不足」を区別して表示するために分けてある。
func can_unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		return false
	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		return false
	return _prerequisites_met(node)

# 研究ノードを解放する。存在しない・解放済み・前提未達・素材不足のときは
# 何もせず false を返す。成功時は素材を消費して research_node_unlocked を発火する。
func unlock_research_node(node_id: String) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	if not tree.has(node_id) or not (tree[node_id] is Dictionary):
		push_warning("[GameManager] unlock_research_node: unknown node_id: " + node_id)
		return false

	var node: Dictionary = tree[node_id]
	if bool(node.get(GameStateKeys.NODE_UNLOCKED, false)):
		print("[GameManager] unlock_research_node('%s') -> false (already unlocked)" % node_id)
		return false

	# 前提の判定を素材の判定より先に行う。順序を入れ替えると、
	# 前提未解放のノードで「素材不足」と表示されて画面の説明と食い違う。
	if not _prerequisites_met(node):
		print("[GameManager] unlock_research_node('%s') -> false (prerequisites not met: %s)" % [
			node_id, node.get(GameStateKeys.NODE_PREREQUISITES, [])
		])
		return false

	var cost: Dictionary = get_research_unlock_cost(node_id)
	var material_id: String = str(cost.get(RESEARCH_COST_MATERIAL_ID, ""))
	var amount: int = int(cost.get(RESEARCH_COST_AMOUNT, 0))
	if amount > 0 and material_id == "":
		push_warning("[GameManager] unlock_research_node: cost_material_id が未設定（research.json）: " + node_id)
		return false

	# add_material() は残高を確認しないため、減算する前に必ずここで確認する。
	if amount > 0:
		var owned: int = get_material_count(material_id)
		if owned < amount:
			print("[GameManager] unlock_research_node('%s') -> false (material %s: %d < %d)" % [
				node_id, material_id, owned, amount
			])
			return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# _copy_dict() は浅いコピーのため、ノードのDictionaryをもう一段複製してから書き換える。
	# これを飛ばすと _state 内の実体を直接書き換えることになる。
	var new_tree: Dictionary = _copy_dict(GameStateKeys.RESEARCH_TREE)
	var new_node: Dictionary = (new_tree[node_id] as Dictionary).duplicate(true)
	new_node[GameStateKeys.NODE_UNLOCKED] = true
	new_tree[node_id] = new_node
	_state[GameStateKeys.RESEARCH_TREE] = new_tree

	# 素材の減算はツリーを更新したあとに行う。
	# material_changed を受けて再描画する画面が、解放済みの状態を見られるようにするため。
	if amount > 0:
		add_material(material_id, -amount)

	print("[GameManager] unlock_research_node('%s') -> true (cost %s x%d, effect %s +%d)" % [
		node_id, material_id, amount,
		str(new_node.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
		int(new_node.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
	])
	research_node_unlocked.emit(node_id)
	return true

# --- 研究：内部ヘルパー ---

# prerequisites に並ぶノードが全て unlocked か。空配列なら true。
func _prerequisites_met(node: Dictionary) -> bool:
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var prerequisites: Variant = node.get(GameStateKeys.NODE_PREREQUISITES, [])
	if not (prerequisites is Array):
		return true
	for prerequisite_id: Variant in (prerequisites as Array):
		var required: Variant = tree.get(str(prerequisite_id), null)
		if not (required is Dictionary):
			# research.json に存在しないIDが前提に書かれている。
			# 解放できてしまうより、解放できないほうが安全。
			push_warning("[GameManager] _prerequisites_met: unknown prerequisite: " + str(prerequisite_id))
			return false
		if not bool((required as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			return false
	return true

# research.json の定義を research_tree へ流し込む。
#
# unlocked だけは既存の値を残し、それ以外（effect_type / effect_value /
# target_stat / prerequisites）は毎回マスターデータで上書きする。
# これにより research.json の効果値を調整すると、既存セーブにも次の起動で反映される。
# （initial_state_config.tres がセーブ済みだと反映されない罠を、研究では踏まない形にする）
#
# research.json から消えたノードは research_tree からも消える。
# ノードIDを改名するとその解放状態は失われるため、リリース後は改名しないこと。
func _sync_research_tree_from_master() -> void:
	var master: Dictionary = MasterDataLoader.get_all_research_nodes()
	if master.is_empty():
		push_warning("[GameManager] _sync_research_tree_from_master: research.json が空か読み込めない")
		return

	var current: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var synced: Dictionary = {}
	for node_id: String in master:
		if not (master[node_id] is Dictionary):
			continue
		var definition: Dictionary = master[node_id]

		var was_unlocked: bool = false
		if current.has(node_id) and current[node_id] is Dictionary:
			was_unlocked = bool((current[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false))

		# JSON の配列要素は Variant で来るため str() で包み直す。
		var prerequisites: Array = []
		var raw_prerequisites: Variant = definition.get(GameStateKeys.NODE_PREREQUISITES, [])
		if raw_prerequisites is Array:
			for prerequisite_id: Variant in (raw_prerequisites as Array):
				prerequisites.append(str(prerequisite_id))

		# effect_value は必ず int() で包む。包み忘れるとセーブに 5.0 と書かれ、
		# get_effective_level_cap() の戻り値が 15.0 になる。
		synced[node_id] = {
			GameStateKeys.NODE_UNLOCKED: was_unlocked,
			GameStateKeys.NODE_EFFECT_TYPE: str(definition.get(GameStateKeys.NODE_EFFECT_TYPE, "")),
			GameStateKeys.NODE_EFFECT_VALUE: int(definition.get(GameStateKeys.NODE_EFFECT_VALUE, 0)),
			GameStateKeys.NODE_TARGET_STAT: str(definition.get(GameStateKeys.NODE_TARGET_STAT, STAT_BOOST_ALL_KEY)),
			GameStateKeys.NODE_PREREQUISITES: prerequisites,
		}

	_state[GameStateKeys.RESEARCH_TREE] = synced

	var unlocked_count: int = 0
	for node_id: String in synced:
		if bool((synced[node_id] as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			unlocked_count += 1
	print("[GameManager] _sync_research_tree_from_master() -> %d nodes (unlocked=%d)" % [synced.size(), unlocked_count])

func get_effective_level_cap(_character_id: String) -> int:
	# 保存された値ではなく、research_treeを都度走査して計算する。
	#
	# 研究ツリーは未実装で常に空のため、走査結果だけだと 0 が返り、
	# レベル1のキャラが即座に上限扱いになって育成画面が操作不能になる。
	# base_level_cap を下駄として先に置く（EXEC_GUILD_TRAINING §5-3）。
	# 研究が入っても、解放ノードの effect_value が加算されるだけで呼び出し側は変わらない。
	var tree: Dictionary = _state.get(GameStateKeys.RESEARCH_TREE, {})
	var cap: int = 0
	if Balance != null and Balance.character != null:
		cap = int(Balance.character.base_level_cap)
	else:
		push_warning("[GameManager] get_effective_level_cap: Balance.character is null — base_level_cap を 0 として扱う")
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

# 製作キューのスナップショットを返す。
func get_crafting_queue() -> Array:
	return _state.get(GameStateKeys.CRAFTING_QUEUE, []).duplicate(true)

# 同時に進行できる製作の本数。Balance から読めなければ既定値。
#
# balance.gd に workshop プロパティが実在するかは未確認のため、"in" で存在を確かめてから読む。
# 名前が違っていた場合はここで push_warning が出る（画面は既定値1で動く）。
func get_max_queue_slots() -> int:
	if Balance != null and "workshop" in Balance and Balance.workshop != null:
		var slots: int = int(Balance.workshop.max_queue_slots)
		if slots > 0:
			return slots
	push_warning("[GameManager] get_max_queue_slots: Balance.workshop が読めない — %d を使う" % DEFAULT_MAX_QUEUE_SLOTS)
	return DEFAULT_MAX_QUEUE_SLOTS

# 解放済みで、かつ定義が妥当なレシピの一覧を返す（画面がレシピ一覧を描くために使う）。
# sort_order の昇順。
func get_available_recipes() -> Array:
	var unlocked: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	var result: Array = []
	for recipe_id: String in MasterDataLoader.get_all_recipes():
		if not bool(unlocked.get(recipe_id, false)):
			continue
		var definition: Dictionary = _normalized_recipe(recipe_id)
		if definition.is_empty():
			continue
		result.append(definition)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get(RECIPE_SORT_ORDER, 0)) < int(b.get(RECIPE_SORT_ORDER, 0)))
	return result

# アイテムの所持数。items.json に無いIDでは -1 を返す（0 と区別するため）。
# materials と inventory のどちらに入っているかは items.json の storage で決まる。
func get_item_count(item_id: String) -> int:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		return get_material_count(item_id)
	if storage == ITEM_STORAGE_INVENTORY:
		var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
		if not inventory.has(item_id):
			return 0
		var entry: Variant = inventory[item_id]
		if not (entry is Dictionary):
			return 0
		return int((entry as Dictionary).get(GameStateKeys.ITEM_COUNT, 0))
	return -1

# 製作を開始する。
#
# 判定の順番は purchase_shop_item() と揃える：
#   レシピ存在 → 解放済み → キューの空き → 定義の妥当性 → 素材 → （ここから状態を変える）
# 定義の妥当性を素材より先に見る。素材だけ減って何も貰えない、を起こさないため。
func start_craft(recipe_id: String) -> bool:
	if MasterDataLoader.get_recipe(recipe_id).is_empty():
		print("[GameManager] start_craft('%s') -> false (recipe not found)" % recipe_id)
		return false

	var unlocked: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	if not bool(unlocked.get(recipe_id, false)):
		print("[GameManager] start_craft('%s') -> false (recipe not unlocked)" % recipe_id)
		return false

	var queue: Array = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	var max_slots: int = get_max_queue_slots()
	if queue.size() >= max_slots:
		print("[GameManager] start_craft('%s') -> false (queue full: %d/%d)" % [recipe_id, queue.size(), max_slots])
		return false

	# 定義の妥当性。ここで弾かれるのは items.json に無いIDや count<=0 を書いたとき。
	var definition: Dictionary = _normalized_recipe(recipe_id)
	if definition.is_empty():
		print("[GameManager] start_craft('%s') -> false (invalid recipe definition)" % recipe_id)
		return false

	var inputs: Array = definition.get(RECIPE_INPUTS, [])
	for entry: Variant in inputs:
		var input: Dictionary = entry
		var item_id: String = str(input.get(RECIPE_IO_ITEM_ID, ""))
		var need: int = int(input.get(RECIPE_IO_COUNT, 0))
		var have: int = get_item_count(item_id)
		if have < need:
			print("[GameManager] start_craft('%s') -> false (%s: %d < %d)" % [recipe_id, item_id, have, need])
			return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	for entry: Variant in inputs:
		var input: Dictionary = entry
		_consume_item(str(input.get(RECIPE_IO_ITEM_ID, "")), int(input.get(RECIPE_IO_COUNT, 0)))

	var started_at: int = int(Time.get_unix_time_from_system())
	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, DEFAULT_CRAFT_DURATION_SEC))
	# outputs の先頭は表示・スキーマ互換のために持たせるだけ。
	# 実際に配るものは受け取り時に recipes.json から引き直す（EXEC_GUILD_WORKSHOP.md §2-5）。
	var first_output: Dictionary = (definition.get(RECIPE_OUTPUTS, []) as Array)[0]
	var output_item_id: String = str(first_output.get(RECIPE_IO_ITEM_ID, ""))

	var new_queue: Array = _copy_array(GameStateKeys.CRAFTING_QUEUE)
	new_queue.append({
		GameStateKeys.CRAFT_QUEUE_ID: "%d_%s" % [started_at, recipe_id],
		GameStateKeys.CRAFT_RECIPE_ID: recipe_id,
		GameStateKeys.CRAFT_RECIPE_TYPE: str(MasterDataLoader.get_item(output_item_id).get(ITEM_MASTER_ITEM_TYPE, "")),
		GameStateKeys.CRAFT_STARTED_AT: started_at,
		# 開始時点の所要時間をコピーして持つ。recipes.json を変えても走行中の残り時間が飛ばない。
		GameStateKeys.CRAFT_DURATION_SEC: duration_sec,
		GameStateKeys.CRAFT_STATUS: GameStateKeys.CRAFT_STATUS_IN_PROGRESS,
		GameStateKeys.CRAFT_OUTPUT_ITEM_ID: output_item_id,
	})
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue

	print("[GameManager] start_craft('%s') -> true (duration=%ds, queue=%d/%d)" % [
		recipe_id, duration_sec, new_queue.size(), max_slots
	])
	crafting_queue_changed.emit()
	return true

# 完成した製作物を受け取る。完了前・存在しない queue_id なら何もせず false。
func collect_craft(queue_id: String) -> bool:
	# 受け取る前に完了判定を回す。画面を経由せずに呼ばれても正しく判定できるようにするため。
	refresh_crafting_queue_if_needed()

	var queue: Array = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	var index: int = _find_craft_index(queue, queue_id)
	if index < 0:
		print("[GameManager] collect_craft('%s') -> false (not found)" % queue_id)
		return false

	var entry: Dictionary = queue[index]
	if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) != GameStateKeys.CRAFT_STATUS_COMPLETED:
		print("[GameManager] collect_craft('%s') -> false (not completed)" % queue_id)
		return false

	var recipe_id: String = str(entry.get(GameStateKeys.CRAFT_RECIPE_ID, ""))
	var definition: Dictionary = _normalized_recipe(recipe_id)
	if definition.is_empty():
		# _sync_recipes_from_master() が消し損ねた場合の保険。
		push_warning("[GameManager] collect_craft: レシピ定義が無効: " + recipe_id)
		return false

	# --- ここから状態を変える。以降に失敗する分岐を作らないこと ---
	# キューから先に消してから配る。inventory_changed を受けて再描画する画面が、
	# 受け取り済みのキューを見られるようにするため（purchase_shop_item と同じ順番）。
	var new_queue: Array = _copy_array(GameStateKeys.CRAFTING_QUEUE)
	new_queue.remove_at(index)
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue

	var granted: Array[String] = []
	for output: Variant in (definition.get(RECIPE_OUTPUTS, []) as Array):
		var item: Dictionary = output
		var item_id: String = str(item.get(RECIPE_IO_ITEM_ID, ""))
		var count: int = int(item.get(RECIPE_IO_COUNT, 0))
		_grant_item(item_id, count)
		granted.append("%s x%d" % [item_id, count])

	print("[GameManager] collect_craft('%s') -> true (%s, queue=%d)" % [
		queue_id, ", ".join(granted), new_queue.size()
	])
	crafting_queue_changed.emit()
	return true

# 完了時刻を過ぎている in_progress のエントリを completed に切り替える。
#
# 日付ではなく経過時間で判定するため、GameDate は使わない。
# 変化があったときだけ crafting_queue_changed を発火する。毎秒呼ばれるため、
# ここで無条件に emit すると画面が毎秒作り直される。
func refresh_crafting_queue_if_needed() -> void:
	var queue: Variant = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	if not (queue is Array) or (queue as Array).is_empty():
		return

	var now: int = int(Time.get_unix_time_from_system())
	var new_queue: Array = (queue as Array).duplicate(true)
	var changed: bool = false
	for i: int in range(new_queue.size()):
		if not (new_queue[i] is Dictionary):
			continue
		var entry: Dictionary = new_queue[i]
		if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) != GameStateKeys.CRAFT_STATUS_IN_PROGRESS:
			continue
		var finish_at: int = int(entry.get(GameStateKeys.CRAFT_STARTED_AT, 0)) + int(entry.get(GameStateKeys.CRAFT_DURATION_SEC, 0))
		if now < finish_at:
			continue
		entry[GameStateKeys.CRAFT_STATUS] = GameStateKeys.CRAFT_STATUS_COMPLETED
		new_queue[i] = entry
		changed = true
		print("[GameManager] refresh_crafting_queue_if_needed: '%s' -> completed" % str(entry.get(GameStateKeys.CRAFT_QUEUE_ID, "")))

	if not changed:
		return
	_state[GameStateKeys.CRAFTING_QUEUE] = new_queue
	crafting_queue_changed.emit()

# --- 作業場：内部ヘルパー ---

# queue_id が一致する要素の位置を返す。見つからなければ -1。
func _find_craft_index(queue: Array, queue_id: String) -> int:
	for i: int in range(queue.size()):
		if not (queue[i] is Dictionary):
			continue
		if str((queue[i] as Dictionary).get(GameStateKeys.CRAFT_QUEUE_ID, "")) == queue_id:
			return i
	return -1

# items.json の storage を返す。未登録・未知の値なら ""。
func _item_storage(item_id: String) -> String:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	if definition.is_empty():
		return ""
	var storage: String = str(definition.get(ITEM_MASTER_STORAGE, ""))
	if storage != ITEM_STORAGE_MATERIAL and storage != ITEM_STORAGE_INVENTORY:
		return ""
	return storage

# 残高の確認は呼び出し側で済ませてあること。この関数は確認しない
# （_spend_currency() と同じ約束）。
func _consume_item(item_id: String, count: int) -> void:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		add_material(item_id, -count)
		return
	if storage == ITEM_STORAGE_INVENTORY:
		_remove_from_inventory(item_id, count)
		return
	push_warning("[GameManager] _consume_item: items.json に無いID: " + item_id)

func _grant_item(item_id: String, count: int) -> void:
	var storage: String = _item_storage(item_id)
	if storage == ITEM_STORAGE_MATERIAL:
		add_material(item_id, count)
		return
	if storage == ITEM_STORAGE_INVENTORY:
		add_to_inventory(item_id, count, str(MasterDataLoader.get_item(item_id).get(ITEM_MASTER_ITEM_TYPE, GameStateKeys.ITEM_TYPE_UNKNOWN)))
		return
	push_warning("[GameManager] _grant_item: items.json に無いID: " + item_id)

# inventory から減らす。0 になったエントリは消す（use_stamina_potion() と同じ扱い）。
func _remove_from_inventory(item_id: String, count: int) -> void:
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	if not inventory.has(item_id) or not (inventory[item_id] is Dictionary):
		push_warning("[GameManager] _remove_from_inventory: 所持していない: " + item_id)
		return
	var entry: Dictionary = (inventory[item_id] as Dictionary).duplicate(true)
	var remaining: int = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) - count
	if remaining > 0:
		entry[GameStateKeys.ITEM_COUNT] = remaining
		inventory[item_id] = entry
	else:
		inventory.erase(item_id)
	_state[GameStateKeys.INVENTORY] = inventory
	print("[GameManager] _remove_from_inventory('%s', %d) -> %d" % [item_id, count, maxi(remaining, 0)])
	inventory_changed.emit(item_id)

# recipes.json のレシピを検証して正規化した Dictionary を返す。妥当でなければ空。
#
# ここで弾くもの：inputs/outputs が空、items.json に無いID、count <= 0。
# MasterDataLoader が返す数値は float のため int() で包む。包み忘れると
# セーブに 1800.0 と書かれる。
func _normalized_recipe(recipe_id: String) -> Dictionary:
	var definition: Dictionary = MasterDataLoader.get_recipe(recipe_id)
	if definition.is_empty():
		return {}

	var inputs: Array = _normalized_io(definition.get(RECIPE_INPUTS, []), recipe_id, RECIPE_INPUTS)
	var outputs: Array = _normalized_io(definition.get(RECIPE_OUTPUTS, []), recipe_id, RECIPE_OUTPUTS)
	if inputs.is_empty() or outputs.is_empty():
		return {}

	var duration_sec: int = int(definition.get(RECIPE_DURATION_SEC, 0))
	if duration_sec <= 0:
		duration_sec = _default_craft_duration_sec()

	return {
		RECIPE_ID: recipe_id,
		RECIPE_DURATION_SEC: duration_sec,
		RECIPE_INPUTS: inputs,
		RECIPE_OUTPUTS: outputs,
		RECIPE_SORT_ORDER: int(definition.get(RECIPE_SORT_ORDER, 0)),
	}

func _normalized_io(list: Variant, recipe_id: String, label: String) -> Array:
	if not (list is Array) or (list as Array).is_empty():
		push_warning("[GameManager] recipes.json: '%s' の %s が空" % [recipe_id, label])
		return []
	var result: Array = []
	for entry: Variant in (list as Array):
		if not (entry is Dictionary):
			push_warning("[GameManager] recipes.json: '%s' の %s に Dictionary でない要素" % [recipe_id, label])
			return []
		var item: Dictionary = entry
		var item_id: String = str(item.get(RECIPE_IO_ITEM_ID, ""))
		var count: int = int(item.get(RECIPE_IO_COUNT, 0))
		if _item_storage(item_id) == "":
			push_warning("[GameManager] recipes.json: '%s' の %s に items.json へ無いID: '%s'" % [recipe_id, label, item_id])
			return []
		if count <= 0:
			push_warning("[GameManager] recipes.json: '%s' の %s の count が 0 以下: '%s'" % [recipe_id, label, item_id])
			return []
		result.append({RECIPE_IO_ITEM_ID: item_id, RECIPE_IO_COUNT: count})
	return result

func _default_craft_duration_sec() -> int:
	if Balance != null and "workshop" in Balance and Balance.workshop != null:
		var value: int = int(Balance.workshop.base_craft_duration_sec)
		if value > 0:
			return value
	return DEFAULT_CRAFT_DURATION_SEC

# recipes.json の定義を recipes_unlocked へ流し込む。
#
# 状態側だけが持つのは「解放済みかどうか」と crafting_queue のみ。
# 消費・産出・所要時間は毎回マスターデータが正（_sync_shop_from_master() と同じ型）。
#
# recipes.json から消えたレシピIDは recipes_unlocked からもキューからも消える。
# レシピIDを改名すると走行中の製作が消えるため、リリース後に改名しないこと。
func _sync_recipes_from_master() -> void:
	var master: Dictionary = MasterDataLoader.get_all_recipes()
	if master.is_empty():
		push_warning("[GameManager] _sync_recipes_from_master: recipes.json が空か読み込めない")
		return

	var current: Dictionary = _state.get(GameStateKeys.RECIPES_UNLOCKED, {})
	var synced: Dictionary = {}
	var skipped: int = 0
	for recipe_id: String in master:
		# 定義が壊れているレシピはここで落とす。実行時に気づくと
		# 「素材だけ減って何も貰えない」が起きる。
		if _normalized_recipe(recipe_id).is_empty():
			skipped += 1
			continue
		if current.has(recipe_id):
			synced[recipe_id] = bool(current[recipe_id])
		else:
			var definition: Dictionary = master[recipe_id]
			synced[recipe_id] = bool(definition.get(RECIPE_UNLOCKED_BY_DEFAULT, false))
	_state[GameStateKeys.RECIPES_UNLOCKED] = synced

	_normalize_crafting_queue(synced)

	var unlocked_count: int = 0
	for recipe_id: String in synced:
		if bool(synced[recipe_id]):
			unlocked_count += 1
	print("[GameManager] _sync_recipes_from_master() -> %d recipes (unlocked=%d, skipped=%d)" % [
		synced.size(), unlocked_count, skipped
	])

# キューの数値を int に戻し、消えたレシピのエントリを捨てる。
#
# JSON から復元すると started_at / duration_sec が float になる。時刻の比較は
# float でも動いてしまうが、セーブに 1.7628e+09 と書かれると読めなくなる。
func _normalize_crafting_queue(valid_recipes: Dictionary) -> void:
	var queue: Variant = _state.get(GameStateKeys.CRAFTING_QUEUE, [])
	if not (queue is Array):
		_state[GameStateKeys.CRAFTING_QUEUE] = []
		return

	var normalized: Array = []
	for entry: Variant in (queue as Array):
		if not (entry is Dictionary):
			continue
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var recipe_id: String = str(item.get(GameStateKeys.CRAFT_RECIPE_ID, ""))
		if not valid_recipes.has(recipe_id):
			push_warning("[GameManager] _normalize_crafting_queue: レシピが無いキューを捨てた: " + recipe_id)
			continue
		item[GameStateKeys.CRAFT_STARTED_AT] = int(item.get(GameStateKeys.CRAFT_STARTED_AT, 0))
		item[GameStateKeys.CRAFT_DURATION_SEC] = int(item.get(GameStateKeys.CRAFT_DURATION_SEC, 0))
		var status: String = str(item.get(GameStateKeys.CRAFT_STATUS, ""))
		if status != GameStateKeys.CRAFT_STATUS_IN_PROGRESS and status != GameStateKeys.CRAFT_STATUS_COMPLETED:
			item[GameStateKeys.CRAFT_STATUS] = GameStateKeys.CRAFT_STATUS_IN_PROGRESS
		normalized.append(item)
	_state[GameStateKeys.CRAFTING_QUEUE] = normalized

# --- セーブ・ロード ---

# セーブデータから状態を復元する。
# SaveManagerからのみ呼ばれることを想定。
# セーブから戻した装備を正規化する。load_state() からのみ呼ぶ。
#
# 1. grade を int に戻す（JSON復元で 3.0 になる）
# 2. parts を長さ PART_SLOT_COUNT に揃える。足りなければ null で埋める。
#    枠を減らす変更をしたときも配列から消さない（あふれた部品を黙って消さないため）
# 3. character_growth.equipment を5部位に揃え、個体でない値を捨てる
#
# 第1弾は equipment に item_id の文字列（"weapon_iron_sword" 等）が直接入っていた。
# 移行処理は書かず捨てると決めた（まだ自分しか遊んでいないため）。
func _normalize_equipment_from_save() -> void:
	var instances: Dictionary = _copy_dict(GameStateKeys.EQUIPMENT_INSTANCES)
	var max_id: int = 0
	for instance_id: String in instances:
		if not (instances[instance_id] is Dictionary):
			continue
		var instance: Dictionary = (instances[instance_id] as Dictionary).duplicate(true)
		instance[GameStateKeys.INSTANCE_GRADE] = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))

		var raw_parts: Variant = instance.get(GameStateKeys.INSTANCE_PARTS, [])
		var parts: Array = (raw_parts as Array).duplicate() if raw_parts is Array else []
		while parts.size() < PART_SLOT_COUNT:
			parts.append(null)
		instance[GameStateKeys.INSTANCE_PARTS] = parts

		instances[instance_id] = instance

		# 採番が巻き戻らないよう、既存のIDから最大値を拾っておく。
		if instance_id.begins_with(INSTANCE_ID_PREFIX):
			max_id = maxi(max_id, int(instance_id.substr(INSTANCE_ID_PREFIX.length())))
	_state[GameStateKeys.EQUIPMENT_INSTANCES] = instances

	var next_id: int = int(_state.get(GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID, 1))
	_state[GameStateKeys.NEXT_EQUIPMENT_INSTANCE_ID] = maxi(next_id, max_id + 1)

	var all_growth: Dictionary = _copy_dict(GameStateKeys.CHARACTER_GROWTH)
	for character_id: String in all_growth:
		if not (all_growth[character_id] is Dictionary):
			continue
		var entry: Dictionary = (all_growth[character_id] as Dictionary).duplicate(true)
		var saved: Variant = entry.get(GameStateKeys.GROWTH_EQUIPMENT, {})
		var equipment: Dictionary = {}
		for slot: String in _equip_slots():
			var value: Variant = (saved as Dictionary).get(slot, null) if saved is Dictionary else null
			if value == null:
				equipment[slot] = null
				continue
			var equipped_id: String = str(value)
			if instances.has(equipped_id):
				equipment[slot] = equipped_id
			else:
				push_warning("[GameManager] load_state: 個体でない装備を捨てた（%s の %s = %s）" % [
					character_id, slot, equipped_id
				])
				equipment[slot] = null
		entry[GameStateKeys.GROWTH_EQUIPMENT] = equipment
		all_growth[character_id] = entry
	_state[GameStateKeys.CHARACTER_GROWTH] = all_growth


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
	# 育成データ。JSONから戻すと level も stats も float になるため int に戻す。
	# これを飛ばすと、セーブ→ロード後に hp が 128.0 と表示され、レベル比較もずれる。
	if new_state.has(GameStateKeys.CHARACTER_GROWTH) and new_state[GameStateKeys.CHARACTER_GROWTH] is Dictionary:
		var growth_all: Dictionary = new_state[GameStateKeys.CHARACTER_GROWTH]
		for character_id: String in growth_all:
			if not (growth_all[character_id] is Dictionary):
				continue
			var entry: Dictionary = growth_all[character_id]
			if entry.has(GameStateKeys.GROWTH_LEVEL):
				entry[GameStateKeys.GROWTH_LEVEL] = int(entry[GameStateKeys.GROWTH_LEVEL])
			if entry.has(GameStateKeys.GROWTH_STATS) and entry[GameStateKeys.GROWTH_STATS] is Dictionary:
				var entry_stats: Dictionary = entry[GameStateKeys.GROWTH_STATS]
				for stat_key: String in _stat_keys():
					if entry_stats.has(stat_key):
						entry_stats[stat_key] = int(entry_stats[stat_key])
	
	# 状態反映（外部参照を断つため duplicate）
	_state = new_state.duplicate(true)
	# 装備の個体を正規化する。JSONから戻すと grade が float になる。
	# 第1弾の装備（equipment に item_id の文字列が入っている）はここで捨てる。
	_normalize_equipment_from_save()
	# セーブから戻した research_tree を research.json と同期する。
	# unlocked は残り、効果値・前提条件はマスターデータで上書きされる。
	# JSON復元で float になった effect_value も、ここで int() に戻る。
	_sync_research_tree_from_master()
	# ショップも同様。価格・在庫は shop.json で上書きし、purchased_count だけ残る。
	# JSON復元で float になった purchased_count も、ここで int() に戻る。
	_sync_shops_from_master()
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピも同様。解放状態と crafting_queue だけが残る。
	# JSON復元で float になった started_at / duration_sec も、ここで int() に戻る。
	_sync_recipes_from_master()
	# ロードした時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
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

func grant_stamina_potions(focus_minutes: int) -> int:
	var unit_per_min: int = int(Balance.pomodoro.potion_focus_minutes_per_unit)
	if unit_per_min <= 0:
		push_warning("[GameManager] invalid potion rate")
		return 0
	var remainder: int = int(_state.get(GameStateKeys.POTION_FOCUS_REMAINDER, 0))
	var total_min: int = focus_minutes + remainder
	var count: int = total_min / unit_per_min
	_state[GameStateKeys.POTION_FOCUS_REMAINDER] = total_min % unit_per_min
	if count > 0:
		add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, count, GameStateKeys.ITEM_TYPE_CONSUMABLE)
	return count

func get_stamina_potion_count() -> int:
	var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
	if not inventory.has(GameStateKeys.ITEM_STAMINA_POTION):
		return 0
	var entry: Dictionary = inventory[GameStateKeys.ITEM_STAMINA_POTION]
	return int(entry.get(GameStateKeys.ITEM_COUNT, 0))

func use_stamina_potion() -> bool:
	var count: int = get_stamina_potion_count()
	if count <= 0:
		return false
	var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
	var entry: Dictionary = (inventory[GameStateKeys.ITEM_STAMINA_POTION] as Dictionary).duplicate(true)
	if count == 1:
		inventory.erase(GameStateKeys.ITEM_STAMINA_POTION)
	else:
		entry[GameStateKeys.ITEM_COUNT] = count - 1
		inventory[GameStateKeys.ITEM_STAMINA_POTION] = entry
	_state[GameStateKeys.INVENTORY] = inventory
	inventory_changed.emit(GameStateKeys.ITEM_STAMINA_POTION)
	_add_stamina_uncapped(int(Balance.pomodoro.stamina_potion_recovery))
	return true

# --- ストーリーステージ ---

# 戦闘勝利時にステージのクリア状態を記録する。
# stars は判定基準が未確定のため、当面は常に 0 が渡される。
# 既存の stars より小さい値で上書きしないよう maxi で比較する。
func mark_stage_cleared(stage_id: String, stars: int = 0) -> void:
	var story: Dictionary = _copy_dict(GameStateKeys.STORY)
	var stages: Dictionary = (story.get(GameStateKeys.STORY_STAGES, {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (stages.get(stage_id, {}) as Dictionary).duplicate(true)
	entry[GameStateKeys.STAGE_CLEARED] = true
	entry[GameStateKeys.STAGE_STARS] = maxi(int(entry.get(GameStateKeys.STAGE_STARS, 0)), stars)
	stages[stage_id] = entry
	story[GameStateKeys.STORY_STAGES] = stages
	_state[GameStateKeys.STORY] = story
	print("[GameManager] mark_stage_cleared('%s', %d)" % [stage_id, stars])

func is_stage_cleared(stage_id: String) -> bool:
	var story: Dictionary = _state.get(GameStateKeys.STORY, {})
	var stages: Dictionary = story.get(GameStateKeys.STORY_STAGES, {})
	var entry: Dictionary = stages.get(stage_id, {})
	return bool(entry.get(GameStateKeys.STAGE_CLEARED, false))


# --- 上限を超えられるスタミナ加算 ---

# max で切り捨てずにスタミナを増やす。
#
# 通常の add_stamina() は max で切り捨てる。上限の意味は
# 「放っておいても max までしか溜まらない」ことであり、
# 自然回復・宝箱・ポモドーロ報酬はすべてそちらを通す。
#
# 上限を超えてよいのは「プレイヤーが能動的に使ったぶん」だけ。
# 現状はスタミナポーションと、戦闘敗北時の返却の2つ。
func _add_stamina_uncapped(amount: int) -> int:
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)) + amount
	stamina[GameStateKeys.STAMINA_CURRENT] = current
	_state[GameStateKeys.STAMINA] = stamina
	resource_changed.emit(GameStateKeys.STAMINA, current)
	return current

# 戦闘に敗北したときのスタミナ返却。
# ポーションで上限を超えている状態から払った場合、add_stamina() では
# max で切り捨てられて戻らないため、上限を超えられる経路を使う。
func refund_stamina(amount: int) -> void:
	if amount <= 0:
		return
	var current: int = _add_stamina_uncapped(amount)
	print("[GameManager] refund_stamina(%d) -> current=%d" % [amount, current])
