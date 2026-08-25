extends CanvasLayer

# 検証用のデバッグオーバーレイ。全画面の右上に常駐し、ボタンで操作する。
#
# ⚠ リリース前に消すもの。消すときに触るのは次の2つだけ：
#   1. このファイル（res://tests/debug_overlay.gd）
#   2. scene_manager.gd の _ready() と _spawn_debug_overlay() と DEBUG_OVERLAY_SCRIPT
#
# .tscn を作らずコードで組み立てるのは battle_debug_panel.gd と同じ理由。
# 本番シーンのツリーに残らず、消すときにシーン側の参照も残らない。
#
# 【キーは表示・非表示の [0] だけ。操作は全部ボタン】
# 最初は [F4] 開閉 + 英字キーで操作する形にしたが、F4 が _unhandled_input まで
# 届かなかった（project.godot の Input Map に F4 は無く、プロジェクト側のコードも
# 握っていないが、実機で届かない。外側の何が握っているかは特定できていない。F2 は届いた）。
# 検証のたびにキーの当たり外れを調べるのは本題ではないので、操作は全部ボタンにした。
# ⚠ 操作系のキーをここに足さないこと。Input Map（project.godot）は人間の担当でもある。
#
# [0] を選んだのは BattleDebugPanel が 1〜4 を使っていて 0 だけ空いているため。
# 万一 [0] が届かなくても畳むボタンが残るので、パネルを出せなくなることはない。
#
# 【資源とアイテムは必ず GameManager の公開関数から配る】
# _state を直接書かないこと。特に装備は add_to_inventory() だけが個体（eq_N）を作る
# （CLAUDE.md 8番）。ここで inventory を直接書くと、装備が個体にならず静かに消える。
# 研究も unlock_research_node() を通す。前提と素材の判定をそのまま通したいため。
# ⚠ 例外は _complete_all_crafts() の1本だけ（製作キューの started_at を戻す）。
#   ⚠ 時刻を戻す公開関数が無く、書き換えるのが時刻だけで関所を迂回しないため。
#
# 【tr() を通さない】
# 開発者向けでリリースビルドには出ないため、ja.csv には登録しない
# （AGENTS.md「tr() を使わないもの」。BattleDebugPanel と同じ扱い）。
#
# 【バランス数値ではないので .tres にしない】
# ここの数字は「検証で困らない量」であって、ゲームバランスの調整対象ではない。

# 配る量。中途半端だと足りなくてもう一度押すことになるので多めにする。
const GOLD_AMOUNT: int = 100000
const GEMS_AMOUNT: int = 10000
const STAMINA_AMOUNT: int = 999
const MATERIAL_AMOUNT: int = 999
const CONSUMABLE_AMOUNT: int = 99
# 装備は1種につき1個。1個あれば着脱の確認はできる。
# 多く配ると倉庫が個体で埋まり、逆に目当ての1個を探せなくなる。
const EQUIPMENT_COUNT: int = 1
# 研究の解放を回す最大回数の下限。前提を辿るために複数回まわす必要があるが、
# 解放できないノード（素材不足）が残ると無限に回るため上限で必ず止める。
#
# ⚠ 実際に使う回数は「この値」と「ノード数」の大きいほう（段階10）。
#   ⚠ 20 固定のままボードを足すと、前提の連なりが 20 を超えた瞬間に
#     「F4 を押したのに全部解放されない」形で無音に壊れる。
#   ⚠ 1回のパスで最低1件は解放されるので、ノード数まで回せば必ず打ち止まる。
const RESEARCH_MAX_PASSES: int = 20
# 右上に寄せるときの想定幅。実サイズはレイアウト確定後にしか取れないため、
# 位置決めにはこの固定値を使う。多少ずれても検証には困らない。
const PANEL_WIDTH: float = 330.0
# パネルごと表示・非表示するキー。これ1つだけ。
const TOGGLE_VISIBLE_KEY: int = KEY_0

var _root: PanelContainer = null
var _info_label: Label = null
var _body: VBoxContainer = null
var _toggle_button: Button = null


func _ready() -> void:
	layer = 200  # BattleDebugPanel（100）より前に出す
	# ポーズ中（モーダル表示中）でもボタンを押せるようにする。子も継承する。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_info()
	print("[DebugOverlay] ready. panel_pos=%s viewport=%s" % [
		_root.position, get_viewport().get_visible_rect().size
	])


func _build_ui() -> void:
	_root = PanelContainer.new()
	_root.modulate = Color(1, 1, 1, 0.94)
	add_child(_root)
	# CanvasLayer は Control ではないため、子のアンカー（PRESET_TOP_RIGHT など）は効かない。
	# 右上に出したいので、ビューポートの幅から位置を計算する。
	# 左上は BattleDebugPanel（8, 8）が使っているので避ける。
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

	# --- 見出し行（常に出る。ここを畳むと右上の小さなボタン1つになる） ---
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)

	var title: Label = Label.new()
	title.text = "デバッグ  [0]で表示切替"
	title.add_theme_font_size_override("font_size", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_toggle_button = _make_button("▲ 畳む", _on_toggle_pressed)
	header.add_child(_toggle_button)

	# --- 本体（畳む対象） ---
	_body = VBoxContainer.new()
	box.add_child(_body)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	_body.add_child(_info_label)

	var separator: HSeparator = HSeparator.new()
	_body.add_child(separator)

	# ボタンの並び順は「使う頻度」ではなく「押す順番」にしてある。
	# 研究は素材を持っていないと解放できないので、素材より後ろに置く。
	_body.add_child(_make_button("ゴールド・ジェム・スタミナ", _grant_currencies))
	_body.add_child(_make_button("素材を全種類", _grant_all_materials))
	_body.add_child(_make_button("消費アイテムを全種類", _grant_all_consumables))
	_body.add_child(_make_button("装備を全種類 1個ずつ", _grant_all_equipment))
	_body.add_child(_make_button("装飾を全種類", _grant_all_parts))
	_body.add_child(_make_button("研究を全部解放（先に素材）", _unlock_all_research))
	_body.add_child(_make_button("画面を全部解放", _unlock_all_screens))
	_body.add_child(_make_button("製作をすぐ完了させる", _complete_all_crafts))
	_body.add_child(_make_button("セーブする", _save))


# AGENTS.md は表示テキストに PrimaryButton + label_key を使う決まりだが、
# ここは tr() を通さない開発者向けUIなので素の Button でよい（冒頭のコメント参照）。
#
# focus_mode を切っているのは、押したあとキーボードフォーカスがこのボタンに残り、
# ゲーム側のキー操作（ポモドーロの [P] など）が効かなくなるのを防ぐため。
func _make_button(text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(func() -> void:
		handler.call()
		_refresh_info()
	)
	return button


# [0] でパネルごと消す／出す。畳むボタン（_on_toggle_pressed）とは別物で、
# こちらは見出しごと消える。
#
# ⚠ 操作系のキーをここに足さないこと（冒頭のコメント）。
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != TOGGLE_VISIBLE_KEY:
		return

	visible = not visible
	if visible:
		_refresh_info()
	print("[DebugOverlay] visible -> %s" % visible)
	get_viewport().set_input_as_handled()


func _on_toggle_pressed() -> void:
	_body.visible = not _body.visible
	_toggle_button.text = "▲ 畳む" if _body.visible else "▼ 開く"
	# 畳むとパネルが小さくなる。位置は右上のままにしたいので置き直す。
	_place_top_right.call_deferred()


# 右上に寄せる。ウィンドウサイズが変わっても追従させる。
func _place_top_right() -> void:
	if _root == null:
		return
	var view_width: float = get_viewport().get_visible_rect().size.x
	# サイズが確定する前に呼ばれても破綻しないよう、実サイズではなく想定幅で引く。
	_root.position = Vector2(max(8.0, view_width - PANEL_WIDTH - 8.0), 8.0)


# 毎フレーム更新しない。get_state() が状態を丸ごと duplicate(true) するため、
# _process() から呼ぶと毎フレーム深いコピーが走る。ボタンを押した直後だけ引く。
func _refresh_info() -> void:
	if _info_label == null:
		return
	var state: Dictionary = GameManager.get_state()
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	var materials: Dictionary = state.get(GameStateKeys.MATERIALS, {})
	var inventory: Dictionary = state.get(GameStateKeys.INVENTORY, {})

	# get_research_tree() も duplicate(true) を返すため、1回だけ引いて使い回す。
	var tree: Dictionary = GameManager.get_research_tree()
	var unlocked_nodes: int = 0
	for node_id: String in tree:
		var node: Variant = tree[node_id]
		if node is Dictionary and bool((node as Dictionary).get(GameStateKeys.NODE_UNLOCKED, false)):
			unlocked_nodes += 1

	_info_label.text = "\n".join([
		"save_version=%d" % int(state.get(GameStateKeys.SAVE_VERSION, 0)),
		"G %d   ジェム %d   スタミナ %d/%d" % [
			int(state.get(GameStateKeys.GOLD, 0)),
			int(state.get(GameStateKeys.GEMS, 0)),
			int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0)),
			int(stamina.get(GameStateKeys.STAMINA_MAX, 0)),
		],
		"素材 %d種  アイテム %d種  装備の個体 %d個" % [
			materials.size(), inventory.size(), GameManager.get_owned_instances().size()
		],
		"研究の解放 %d / %d" % [unlocked_nodes, tree.size()],
		# ⚠ 「製作をすぐ完了させる」を押したことが、ログを見ずに分かるようにする。
		"製作 %d / %d本（完成 %d）" % [
			GameManager.get_crafting_queue().size(),
			GameManager.get_max_queue_slots(),
			_completed_craft_count(),
		],
	])


# 完成していて受け取っていない製作の件数。
func _completed_craft_count() -> int:
	var count: int = 0
	for entry: Variant in GameManager.get_crafting_queue():
		if entry is Dictionary and str((entry as Dictionary).get(GameStateKeys.CRAFT_STATUS, "")) == GameStateKeys.CRAFT_STATUS_COMPLETED:
			count += 1
	return count


# --- 配る ---

func _grant_currencies() -> void:
	GameManager.add_gold(GOLD_AMOUNT)
	GameManager.add_gems(GEMS_AMOUNT)
	# add_stamina() は max を超えない。上限まで入れたいので多めに渡す。
	GameManager.add_stamina(STAMINA_AMOUNT)
	print("[DebugOverlay] 資源を配った")


func _grant_all_materials() -> void:
	# get_all_items() は duplicate(true) を返す。ループの中で呼ばないこと。
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	var count: int = 0
	for item_id: String in all_items:
		var definition: Dictionary = all_items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_STORAGE, "")) != GameManager.ITEM_STORAGE_MATERIAL:
			continue
		GameManager.add_material(item_id, MATERIAL_AMOUNT)
		count += 1
	print("[DebugOverlay] 素材 %d種を +%d" % [count, MATERIAL_AMOUNT])


func _grant_all_consumables() -> void:
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	var count: int = 0
	for item_id: String in all_items:
		var definition: Dictionary = all_items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_STORAGE, "")) != GameManager.ITEM_STORAGE_INVENTORY:
			continue
		var item_type: String = str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, ""))
		# 装備は「装備を全種類」の担当。ここで配ると個体が二重に増える。
		if item_type == GameStateKeys.ITEM_TYPE_EQUIPMENT:
			continue
		# 装飾は「装飾を全種類」の担当。除かないと36種が消費アイテム側から配られ、
		# 倉庫の持ち物タブが装飾で埋まる（EXEC_DECORATION.md §3-K）。
		if item_type == GameStateKeys.ITEM_TYPE_PART:
			continue
		GameManager.add_to_inventory(item_id, CONSUMABLE_AMOUNT, item_type)
		count += 1
	print("[DebugOverlay] 消費アイテム %d種を +%d" % [count, CONSUMABLE_AMOUNT])


# 装飾（宝石・護符・紋章）。装備と違って個体にならず、スタック品として入る。
#
# ⚠ 「新規セーブから枠の検証に到達する唯一の経路」がここ。装飾はステージ報酬
#   （stage_2 / stage_3）とショップにしか無く、素の状態では1つも持っていない。
# ⚠ 配る量は少なめ。36種 × 大量にすると倉庫の持ち物タブが装飾で埋まり、
#   目当ての1つを探せなくなる（装備を1個ずつにしているのと同じ理由）。
const PART_COUNT: int = 5

func _grant_all_parts() -> void:
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	var count: int = 0
	for item_id: String in all_items:
		var definition: Dictionary = all_items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_PART:
			continue
		GameManager.add_to_inventory(item_id, PART_COUNT, GameStateKeys.ITEM_TYPE_PART)
		count += 1
	print("[DebugOverlay] 装飾 %d種を +%d" % [count, PART_COUNT])


# 装備は add_to_inventory() を通す。ここが個体（eq_N）を作る唯一の入口。
func _grant_all_equipment() -> void:
	var all_items: Dictionary = MasterDataLoader.get_all_items()
	var count: int = 0
	for item_id: String in all_items:
		var definition: Dictionary = all_items[item_id]
		if str(definition.get(GameManager.ITEM_MASTER_ITEM_TYPE, "")) != GameStateKeys.ITEM_TYPE_EQUIPMENT:
			continue
		GameManager.add_to_inventory(item_id, EQUIPMENT_COUNT, GameStateKeys.ITEM_TYPE_EQUIPMENT)
		count += 1
	print("[DebugOverlay] 装備 %d種を %d個ずつ（個体を生成）" % [count, EQUIPMENT_COUNT])


# 段階解放（GAME_DESIGN.md 9-5）を全部飛ばす。
#
# ⚠ これが無いと、新規セーブから装備画面へ行くのに stage_1 を倒す必要がある。
#   検証のたびに戦うのは現実的でない（EXEC_SCREEN_UNLOCK.md §0-1 の9）。
# ⚠ workshop も開けるが、.tscn 側で visible = false なので画面には出ない。
# ⚠ リリース前に消す（宿題）。
func _unlock_all_screens() -> void:
	var count: int = 0
	for screen_id: String in GameManager.get_all_screen_ids():
		if GameManager.is_screen_unlocked(screen_id):
			continue
		GameManager.unlock_screen(screen_id)
		count += 1
	print("[DebugOverlay] 画面を %d 件 解放（全 %d 件）" % [
		count, GameManager.get_all_screen_ids().size()
	])


# 前提を辿るため、解放できなくなるまで繰り返す。
# unlock_research_node() は前提と素材を判定するので、素材が足りなければ解放されない。
# 先に「素材を全種類」を押しておくこと。
func _unlock_all_research() -> void:
	var total: int = 0
	var passes: int = maxi(RESEARCH_MAX_PASSES, MasterDataLoader.get_all_research_nodes().size())
	for pass_index: int in range(passes):
		var unlocked_this_pass: int = 0
		for node_id: String in MasterDataLoader.get_all_research_nodes():
			if GameManager.unlock_research_node(node_id):
				unlocked_this_pass += 1
		total += unlocked_this_pass
		if unlocked_this_pass == 0:
			break
	print("[DebugOverlay] 研究を %d件 解放した（解放できないものは素材不足か前提未達）" % total)


# 製作中のものを全部「完成」にする（⚠ 受け取りはしない。⚠ 押すのは人間）。
#
# ⚠ 作業場の一番短いレシピでも30分あり、⚠ 画面の確認がそこで止まる。
#   ⚠ それまでは「端末の時計を進めて開き直す」しか手が無かった。
#
# ⚠ この関数だけ _state を直接書く（冒頭の「_state を直接書かないこと」の唯一の例外）。
#   ⚠ 書き換えるのは started_at だけで、⚠ 資源もアイテムも個体も作らないため
#     add_to_inventory() などの関所を迂回しない。⚠ 時刻を戻す公開関数は無い。
#   ⚠ debug_boot.gd の _rewind_craft_queue() と同じ形。
# ⚠ 完了への切り替えと再描画は refresh_crafting_queue_if_needed() に任せる
#   （⚠ crafting_queue_changed をここで発火しない。二重発火になる）。
func _complete_all_crafts() -> void:
	var queue: Array = GameManager._state.get(GameStateKeys.CRAFTING_QUEUE, [])
	var rewound: int = 0
	for i: int in range(queue.size()):
		if not (queue[i] is Dictionary):
			continue
		var entry: Dictionary = queue[i]
		if str(entry.get(GameStateKeys.CRAFT_STATUS, "")) != GameStateKeys.CRAFT_STATUS_IN_PROGRESS:
			continue
		entry[GameStateKeys.CRAFT_STARTED_AT] = int(entry.get(GameStateKeys.CRAFT_STARTED_AT, 0)) - int(entry.get(GameStateKeys.CRAFT_DURATION_SEC, 0)) - 1
		queue[i] = entry
		rewound += 1
	GameManager._state[GameStateKeys.CRAFTING_QUEUE] = queue
	GameManager.refresh_crafting_queue_if_needed()
	print("[DebugOverlay] 製作 %d件 を完成にした（受け取りは「受け取る」を押す）" % rewound)


func _save() -> void:
	var ok: bool = SaveManager.save_game()
	print("[DebugOverlay] save_game() -> %s" % ok)
