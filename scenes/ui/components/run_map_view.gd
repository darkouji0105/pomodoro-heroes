class_name RunMapView
extends Control

# ランのマップの「層の並び・マスのボタン・つながりの線」（2026-09-19・人間の決定「全部推奨で」）。
#
# ⚠⚠ シナリオ（floor_map.gd）と難ダンジョン（dungeon_map.gd）の2画面で使う部品。
#   ⚠ 描き方は段階19-e〜20-g で難ダンジョンに入れたもの（⚠ 列を揃える・線を散らす）をそのまま移した。
# ⚠⚠ この部品は GameManager を1行も知らない。⚠ FLOOR_* ／ DUNGEON_* のキーも読まない。
#   ⚠ 画面側が「描く材料」（マス・線）に直して渡す（⚠ 器は別＝PLAN_HARD_DUNGEON.md §7）。
#   ⚠ 進めるか・見えているか・通路に何があるかの判定は、画面が GameManager に聞いた結果を渡す。
# ⚠ スクロールは持たない。⚠ 難ダンジョンは外側の ScrollContainer に入れる（⚠ シナリオは入れない＝
#   ⚠ scenario=layout で測れるまま）。
# ⚠ 再描画に await を持たせない。remove_child() してから queue_free()（AGENTS.md）。

## 進める先のマスを押した。
signal node_pressed(node_id: String)
## 並べ終わって線を引き直した（⚠ マスの位置が確定したあと）。⚠ スクロールを寄せる画面が受ける。
signal laid_out

# マス1つぶんのキー（set_map() に渡す）。⚠ 文字列リテラルを画面側と2箇所に書かないための定数。
const NODE_ID: String = "id"
const NODE_LAYER: String = "layer"
## ⚠ マスの文字。⚠ 翻訳済みで渡す（⚠ ▶ ✓ はこちらで付ける）。
const NODE_TEXT: String = "text"
const NODE_STATE: String = "state"
## ⚠ たいまつが届いていないか（⚠ 届いていなければ静かな札）。⚠ 判定は画面が GameManager に聞く。
const NODE_HIDDEN: String = "hidden"
## ⚠ ボスか（⚠ 札を一回り大きくする＝モック v2 §3）。
const NODE_BOSS: String = "boss"
## ⚠ マスの絵（`Texture2D`・無くてよい）。⚠ `round_nodes` のときだけ使う（⚠ 字の代わりに絵）。
const NODE_ICON: String = "icon"

# マスの状態（NODE_STATE の値）。
const STATE_CURRENT: String = "current"
const STATE_VISITED: String = "visited"
const STATE_REACHABLE: String = "reachable"
const STATE_FAR: String = "far"

# 線1本ぶんのキー（set_map() に渡す）。
const EDGE_FROM: String = "from"
const EDGE_TO: String = "to"
const EDGE_TONE: String = "tone"
## ⚠ 通路の真ん中に出す字。⚠ "" なら何も出さない。
const EDGE_LABEL: String = "label"

# 線の色の種類（EDGE_TONE の値）。⚠ 「良いか悪いか」だけを言う（⚠ 何が起きるかは字が言う）。
const TONE_PLAIN: String = "plain"
const TONE_HIDDEN: String = "hidden"
const TONE_TRAP: String = "trap"
const TONE_GAIN: String = "gain"

# マスの札（2026-09-19・モック v2「真鍮の札」）。⚠ 札そのものの色は Theme の variation（theme_builder.gd の MAP_NODE_LEVELS）。
#   ⚠ 前はここで modulate の4色を持っていた。⚠ 札になったので Theme へ移した。
const VARIATION_REACHABLE: StringName = &"MapNodeButton"
const VARIATION_CURRENT: StringName = &"MapNodeCurrent"
const VARIATION_VISITED: StringName = &"MapNodeVisited"
const VARIATION_FAR: StringName = &"MapNodeFar"
const VARIATION_HIDDEN: StringName = &"MapNodeHidden"

# ⚠⚠ 色は 2026-09-26（回UI-4 マップ）に Theme の `RunMapView` へ移した（⚠ 直書き14色＝`UI-1` 違反だった）。
# 札の四隅の鋲（モック v2）。⚠ 見えないマスには打たない（⚠ 明かりに入ると鋲が点く）。
#   ⚠ 札の上に描く小さな点なので Theme に対応する概念が無い（⚠ 線の色と同じ扱い）。
const PIN_RADIUS: float = 1.5
const PIN_INSET: float = 5.0

# ボスの札の大きさ（モック v2 §3「一回り大きく」）。⚠ 幅はふつうの札＋この値・高さは最小の高さ。
const BOSS_EXTRA_WIDTH: float = 22.0
const BOSS_MIN_HEIGHT: float = 46.0

# 通路の線の色（段階19-e → 2026-09-19 にモック v2 の値へ）。
#   ⚠ 罠＝赤 ／ 得＝金 ／ 何も無い＝灰 ／ 中身が見えていない＝暗い灰（点線）。
# 通路の字の台（菱形）の枠。⚠ 罠＝赤茶 ／ 得＝金茶（モック `.edge-badge.bad / .good`）。
# ⚠ いま立っているマスから出ている線は太くする（⚠ 「次に選ぶのはここ」が読めること）。
const EDGE_WIDTH: float = 1.6
const EDGE_WIDTH_CURRENT: float = 2.2
# ⚠ 通った道（⚠ 人間の参考 HTML `stroke-width="3.2"`）。⚠ 09-26：今いるマスから出る道は 3.0 → 2.2（⚠ 点線で太いと通った道と紛れる）。
const EDGE_WIDTH_WALKED: float = 3.2

# 層の目盛り（2026-09-19・モック v2「左端に層の目盛り」）。⚠ 行の左に置く字の欄の幅。
#   ⚠ 右にも同じ幅の空きを置く（⚠ 置かないとマスの並びが画面の真ん中からずれる＝決定37）。
const LAYER_CAPTION_WIDTH: float = 64.0

# マスの並びの間隔（段階19-f）。⚠ 層のあいだが狭いと線がほとんど点になる。
# ⚠ バランスの数値ではなく見た目なので Config に出していない（⚠ 色と同じ扱い）。
const LAYER_SEPARATION: int = 44
# ⚠ スクロールの無い画面（シナリオ）の層の間隔（2026-09-19）。⚠ 44 のままだと
#   フロアのマップが 614 x 722 になり、⚠ 基準 720 を縦に 2px はみ出した（⚠ scenario=layout で実測）。
const LAYER_SEPARATION_NO_SCROLL: int = 32
const NODE_SEPARATION: int = 56

# マス1つの幅（段階20-g）。⚠ 列を揃えるのに要る。⚠ 空の列にも同じ幅のものを置く。
const NODE_WIDTH: float = 104.0

# 線の端をマスの辺に沿ってどれだけ散らすか（マスの幅に対する割合。段階20-g）。
const EDGE_ANCHOR_SPREAD: float = 0.55

# たいまつの明かり（2026-09-19・モック v2 §0 → 2026-09-20 に値を Theme へ）。
#   ① いまいるマスを中心にした金の光（⚠ ゆっくり揺れる）
#   ② たいまつが届かない層を覆う暗さ（⚠ 等級が上がると境目が上へ動く）
# ⚠⚠ 揺れ・大きさ・色は Theme の `RunMapView` が持つ（2026-09-20・人間の指示
#   「⚠ 光の揺れは調整できるようにしてほしい」）。⚠ ここに数字を書かない。
#   ⚠ 直すのは `tools/theme_builder.gd` の `MAP_LIGHT_*` → `scenario=theme` を回す。
# ⚠ 暗さのほうは絵ではなく「見える範囲の線引き」なので、⚠ 引き続きここが持つ。
const THEME_TYPE: StringName = &"RunMapView"
# ⚠ 暗さの境目から「濃い暗さ」までの長さ（⚠ 層のあいだ何個ぶんか）。
const FOG_RAMP_LAYERS: float = 1.6
# ⚠ 暗さを横にはみ出させる幅は**紙の余白ちょうど**（⚠ Theme の `sheet_pad`）。
#   ⚠ 2026-09-26（回UI-4 マップ）：⚠ 前は 80 固定で、⚠ 地図が紙になったら**紙の外へ**はみ出した。

## たいまつで何層先まで見えるか。⚠ -1 なら暗さを出さない（⚠ ボスを倒したあと＝部屋いっぱいに明るい）。
##   ⚠ set_map() の前に入れる。⚠ 値は画面が GameManager に聞いた結果。
var torch_reveal_layers: int = -1

# 線（下に描く）とマス（上に描く）。⚠ 同じ矩形に重ねる。
#   ⚠ 描く順：光 → 線 → 暗さ → マス（⚠ モック v2 の z の順）。
var _light_anchor: Control = null
var _light: TextureRect = null
var _edge_lines: DungeonEdgeLines = null
var _fog: Control = null
var _layer_list: VBoxContainer = null
# いまいるマスの層（⚠ 暗さの境目を決める）。
var _current_layer: int = 0

# {node_id: Button}。⚠ 描き直すたびに作り直す（⚠ queue_free() 済みの位置を読むと落ちる）。
var _node_buttons: Dictionary = {}
# 渡された線。⚠ 位置はレイアウトが済むまで分からないので、並べ替えのたびに引き直す。
var _edges: Array = []
# いま立っているマス（⚠ そこから出る線を太くする）。
var _current_id: String = ""
# {layer: 行の Control}。⚠ 霧（見えていない層）の高さを決めるのに使う。
# ⚠ 2026-09-20 まで区画の切れ目の高さにも使っていた（⚠ 切れ目は人間の指示で消した）。
var _rows: Dictionary = {}
# 通ったマス {node_id: true}（⚠ 通った道を赤くするため）。
var _walked: Dictionary = {}

## ⚠⚠ マスを**アイコンだけの丸**にするか（2026-09-26・人間の参考画像「地図らしく」）。
##   ⚠ 字（`NODE_TEXT`）は触れると出る札へ回す。⚠ 通ったマスは赤いチェック、今いるマスは点線の輪。
##   ⚠ 列の幅（`NODE_WIDTH`）は変えない（⚠ 丸を列の真ん中に置く＝線の並びが崩れない）。
var round_nodes: bool = false

## ⚠ 地図の下に自分で紙を敷くか。⚠ 外に `TornPaperPanel` を敷く画面は false（⚠ 紙が2枚重なる）。
var draw_sheet: bool = true:
	set(value):
		draw_sheet = value
		queue_redraw()

## 紙を上下にもはみ出させるか。⚠ スクロールの無い画面（シナリオ）は false
##   （⚠ 2026-09-26：⚠ 上下 24px が**フッターの HP に重なった**）。⚠ 左右はいつもはみ出す。
var sheet_bleed_vertical: bool = true:
	set(value):
		sheet_bleed_vertical = value
		queue_redraw()
		if _fog != null:
			_fog.queue_redraw()


## 層のあいだの間隔。⚠ LAYER_SEPARATION か LAYER_SEPARATION_NO_SCROLL を入れる（⚠ 値を画面に書かない）。
var layer_separation: int = LAYER_SEPARATION:
	set(value):
		layer_separation = value
		if _layer_list != null:
			_layer_list.add_theme_constant_override("separation", layer_separation)


func _init() -> void:
	# ⚠⚠ 2026-09-26（回UI-4 マップ・手本 DungeonMap）：⚠ 地図は**羊皮紙の上に墨で描く**。
	#   ⚠ 紙のテーマを持つ（⚠ 目盛りと線の菱形の字が墨になる）。⚠ 紙そのものは `_draw()` が敷く。
	theme = PaperSheet.PAPER_THEME
	# ⚠⚠ 光は「中心の器」の中に入れる（2026-09-20）。⚠ 器はいまいるマスへ置き直され、
	#   ⚠ 揺れ（明るさ・大きさ・左右）は器の中だけで起きる。⚠ こうしないと置き直しと揺れが取り合う。
	#   ⚠ 大きさ・色は Theme から引くので、⚠ 中身を作るのは木に入ってから（`_ready()`）。
	_light_anchor = Control.new()
	_light_anchor.name = "TorchLight"
	_light_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_anchor.visible = false
	add_child(_light_anchor)

	_light = TextureRect.new()
	_light.name = "Flame"
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light_anchor.add_child(_light)

	_edge_lines = DungeonEdgeLines.new()
	_edge_lines.name = "EdgeLines"
	_edge_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_edge_lines)

	_fog = Control.new()
	_fog.name = "TorchFog"
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.draw.connect(_draw_fog)
	add_child(_fog)

	_layer_list = VBoxContainer.new()
	_layer_list.name = "LayerList"
	_layer_list.theme_type_variation = &"SectionStack"
	_layer_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_layer_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠ 層のあいだの間隔（段階19-f）。⚠ マスのあいだの間隔と同じ場所に並べる。
	_layer_list.add_theme_constant_override("separation", layer_separation)
	add_child(_layer_list)
	# ⚠⚠ 線はマスの位置が確定してからでないと引けない。⚠ 並べ替えが終わるたびに引き直す。
	#   ⚠ await を使わない（AGENTS.md）。⚠ ウィンドウを広げても追従する。
	_layer_list.sort_children.connect(_request_redraw)


# マスと線を差し替える。
#
# nodes: [{id, layer, text, state, hidden, boss}] ／ edges: [{from, to, tone, label}]
# layer_captions: {layer: 目盛りの字}（⚠ 翻訳済み。⚠ 無い層は空）
# ⚠ edges は画面が並べた順に引く（⚠ 重なり順が起動ごとに変わらないよう、画面側で綴り順に）。
# ⚠ 2026-09-20：区画の切れ目（`seam_after` / `seam_caption`）は人間の指示で消した。
func set_map(nodes: Array, edges: Array, layer_captions: Dictionary = {}) -> void:
	for child in _layer_list.get_children():
		_layer_list.remove_child(child)
		child.queue_free()
	_node_buttons.clear()
	_rows.clear()
	_edges = edges
	_current_id = ""
	_current_layer = 0

	# ⚠ 綴り順に並べてから層に仕分ける。
	var by_id: Dictionary = {}
	for entry: Variant in nodes:
		if entry is Dictionary:
			by_id[str((entry as Dictionary).get(NODE_ID, ""))] = entry
	# ⚠ 通ったマス（⚠ 通った・今いる）。⚠ 両端がここにある道は「通った道」＝赤い線（⚠ 参考画像）。
	_walked.clear()
	for raw_id: Variant in by_id:
		var walked_state: String = str((by_id[raw_id] as Dictionary).get(NODE_STATE, ""))
		if walked_state == STATE_VISITED or walked_state == STATE_CURRENT:
			_walked[str(raw_id)] = true
	var node_ids: Array = by_id.keys()
	node_ids.sort()
	var by_layer: Dictionary = {}
	for node_id: Variant in node_ids:
		var node: Dictionary = by_id[node_id]
		var layer: int = int(node.get(NODE_LAYER, 1))
		if not by_layer.has(layer):
			by_layer[layer] = []
		(by_layer[layer] as Array).append(str(node_id))
		if str(node.get(NODE_STATE, "")) == STATE_CURRENT:
			_current_id = str(node_id)
			_current_layer = layer

	var layers: Array = by_layer.keys()
	layers.sort()
	layers.reverse()  # 深い層（ボス）を上に。

	# ⚠⚠ 列を固定する（段階20-g・人間の指摘「左から右に行く道がやたら生成される」）。
	#   ⚠ 全部の層を「一番マスの多い層」の列に揃えると、⚠ 線は真下か隣にしか行かない。
	var columns: int = 1
	for layer: Variant in layers:
		columns = maxi(columns, (by_layer[layer] as Array).size())

	for layer: Variant in layers:
		# ⚠ 1層＝［目盛りの字｜マスの並び｜同じ幅の空き］（2026-09-19・モック v2）。
		var line: HBoxContainer = HBoxContainer.new()
		line.name = "Layer_%d" % int(layer)
		var caption: Label = Label.new()
		caption.name = "Caption"
		caption.theme_type_variation = &"CaptionLabel"
		caption.custom_minimum_size = Vector2(LAYER_CAPTION_WIDTH, 0.0)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_vertical = Control.SIZE_FILL
		caption.text = str(layer_captions.get(int(layer), ""))
		line.add_child(caption)
		var row: GridContainer = GridContainer.new()
		row.name = "Nodes"
		row.columns = columns
		row.add_theme_constant_override("h_separation", NODE_SEPARATION)
		var row_ids: Array = by_layer[layer]
		# ⚠ マスを列へ割り当てる。⚠ 均等に散らして中央寄せ
		#   （⚠ 両端に寄せると、⚠ 2マスの層が左端と右端に開いて斜めが復活する）。
		var column_of: Dictionary = {}
		var used_column: int = -1
		for i: int in range(row_ids.size()):
			var wanted: int = int(round(
				(float(i) + 0.5) * float(columns) / float(row_ids.size()) - 0.5
			))
			# ⚠ 同じ列に2つ来ないよう、⚠ 必ず前より右へ（⚠ 丸めで重なることがある）。
			used_column = clampi(maxi(wanted, used_column + 1), 0, columns - 1)
			column_of[used_column] = str(row_ids[i])

		for c: int in range(columns):
			if not column_of.has(c):
				# ⚠ 空の列にも同じ幅のものを置く。⚠ 置かないと列が詰まって揃わない。
				var spacer: Control = Control.new()
				spacer.name = "Gap_%d" % c
				spacer.custom_minimum_size = Vector2(NODE_WIDTH, 0.0)
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(spacer)
				continue
			var node_id: String = str(column_of[c])
			var node_button: Button = _make_node_button(node_id, by_id[node_id])
			_node_buttons[node_id] = node_button
			if round_nodes:
				# ⚠ 丸は列の幅より細いので、⚠ 列の幅の器の真ん中に置く（⚠ 列を揃えたまま）。
				var holder: CenterContainer = CenterContainer.new()
				holder.name = "Cell_" + node_id
				holder.custom_minimum_size = Vector2(NODE_WIDTH, 0.0)
				holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_child(node_button)
				row.add_child(holder)
			else:
				row.add_child(node_button)
		line.add_child(row)
		# ⚠⚠ 行の中の並べ替えは外側より後に来ることがある（⚠ 行を1段入れ子にしたため）。
		#   ⚠ 中の並べ替えでも引き直す（⚠ まとめて1回にする＝_request_redraw）。
		line.sort_children.connect(_request_redraw)
		row.sort_children.connect(_request_redraw)
		var pad: Control = Control.new()
		pad.name = "Pad"
		pad.custom_minimum_size = Vector2(LAYER_CAPTION_WIDTH, 0.0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(pad)
		_layer_list.add_child(line)
		_rows[int(layer)] = line

	# ⚠ Control は子の最小サイズを自動では拾わない。⚠ 外側（ScrollContainer / VBox）へ渡す。
	custom_minimum_size = _layer_list.get_combined_minimum_size()
	_redraw_edges()


# マスの札。⚠ 進める先だけ押せる（⚠ 判定は画面が GameManager に聞いた結果）。
#
# ⚠ `UiButton` ではなく素の `Button`（⚠ UiButton は variant から variation を上書きするので、
#   ⚠ 札の variation を当てられない）。⚠ ボタンの5階層は増やしていない。
func _make_node_button(node_id: String, node: Dictionary) -> Button:
	var button: Button = Button.new()
	button.name = "Node_" + node_id
	button.text = str(node.get(NODE_TEXT, ""))
	var state: String = str(node.get(NODE_STATE, STATE_FAR))
	var hidden: bool = bool(node.get(NODE_HIDDEN, false))
	var pin_color: Color = get_theme_color(&"pin_far", THEME_TYPE)
	match state:
		STATE_CURRENT:
			button.text = "▶ " + button.text
			button.theme_type_variation = VARIATION_CURRENT
			pin_color = get_theme_color(&"pin_current", THEME_TYPE)
		STATE_VISITED:
			button.text = "✓ " + button.text
			button.theme_type_variation = VARIATION_VISITED
			pin_color = get_theme_color(&"pin_visited", THEME_TYPE)
		STATE_REACHABLE:
			button.theme_type_variation = VARIATION_REACHABLE
			pin_color = get_theme_color(&"pin_reachable", THEME_TYPE)
		_:
			button.theme_type_variation = VARIATION_HIDDEN if hidden else VARIATION_FAR
	if round_nodes:
		# ⚠ たいまつが届かないマスは**縁と字だけ薄く**（⚠ `MapNodeHidden`）。⚠ 地は不透明のまま
		#   ⚠ （⚠ 丸ごと半透明にしたら後ろを通る道が透けて「く」の字に見えた・09-26 の絵）。
		_make_round(button, node, state, hidden)
	else:
		_make_plate(button, node, hidden, pin_color)
	var reachable: bool = state == STATE_REACHABLE
	button.disabled = not reachable
	if reachable:
		button.pressed.connect(func() -> void: node_pressed.emit(node_id))
	return button


# ⚠⚠ アイコンだけの丸（2026-09-26・`round_nodes`）。⚠ 字は触れると出る札へ（⚠ ▶ ✓ も付けない＝印で描く）。
#   ⚠ 見えないマスは「?」だけ。⚠ 大きさは Theme（`node_size` / `node_size_boss`）。
func _make_round(button: Button, node: Dictionary, state: String, hidden: bool) -> void:
	button.tooltip_text = str(node.get(NODE_TEXT, ""))
	var icon: Texture2D = null if hidden else node.get(NODE_ICON, null) as Texture2D
	if icon != null:
		button.text = ""
		button.icon = icon
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = "?" if hidden else str(node.get(NODE_TEXT, ""))
	var side: float = float(get_theme_constant(
		&"node_size_boss" if bool(node.get(NODE_BOSS, false)) else &"node_size", THEME_TYPE
	))
	button.custom_minimum_size = Vector2(side, side)
	if state == STATE_VISITED or state == STATE_CURRENT:
		var mark: NodeMark = NodeMark.new()
		mark.name = "Mark"
		mark.ring = state == STATE_CURRENT
		mark.color = get_theme_color(&"mark", THEME_TYPE)
		mark.width = float(get_theme_constant(&"mark_width", THEME_TYPE))
		button.add_child(mark)


# 字の札（⚠ `round_nodes` でないとき＝前からの形）。
func _make_plate(button: Button, node: Dictionary, hidden: bool, pin_color: Color) -> void:
	# ⚠ 幅を揃える。⚠ 揃えないと文字の長さで列がずれる（⚠ 「戦闘」と「レリック」）。
	button.custom_minimum_size = Vector2(NODE_WIDTH, 0.0)
	if bool(node.get(NODE_BOSS, false)):
		button.custom_minimum_size = Vector2(NODE_WIDTH + BOSS_EXTRA_WIDTH, BOSS_MIN_HEIGHT)
	# ⚠ 見えないマスには鋲を打たない（⚠ 進める先でも、⚠ 見えていなければ静か）。
	if not hidden:
		_add_pins(button, pin_color)


# 札の四隅の鋲。⚠ 押下を食べない（⚠ IGNORE）。⚠ 札の大きさが変わっても隅に付く（⚠ 全面に張る）。
#
# ⚠⚠ 無名関数で描かない（2026-09-20）。⚠ `draw` に自分自身を捕まえた無名関数をつないでいたため、
#   ⚠ 札が消えたあとに「Lambda capture at index 0 was freed」が赤で出た（⚠ scenario=layout で6件）。
#   ⚠ 内側のクラスにして、⚠ 捕まえるものを持たせない。
func _add_pins(button: Button, color: Color) -> void:
	var pins: NodePins = NodePins.new()
	pins.name = "Pins"
	pins.pin_color = color
	button.add_child(pins)


# 丸いマスの印（2026-09-26）。⚠ 通った＝右上に赤いチェック ／ ⚠ 今いる＝外側に点線の輪。
#   ⚠ `NodePins` と同じく内側のクラス（⚠ 無名関数で描かない＝「Lambda capture ... was freed」を踏まない）。
class NodeMark extends Control:
	var ring: bool = false
	var color: Color = Color.WHITE
	var width: float = 2.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		if ring:
			# ⚠ 点線の輪（⚠ 12 片）。⚠ 丸より一回り外。
			var radius: float = size.x * 0.5 + width * 3.0
			var pieces: int = 12
			for i: int in range(pieces):
				var from: float = TAU * float(i) / float(pieces)
				draw_arc(center, radius, from, from + TAU / float(pieces) * 0.55, 6, color, width)
			return
		# ⚠ チェック（✓）。⚠ 丸の右上に大きめに重ねる（⚠ 参考画像）。
		var s: float = size.x
		draw_polyline(PackedVector2Array([
			Vector2(s * 0.30, s * 0.52), Vector2(s * 0.48, s * 0.70), Vector2(s * 0.95, s * 0.12),
		]), color, width * 1.5)


# 札の四隅の鋲を描くだけの器。⚠ 値（大きさ・位置）は外側の const。
class NodePins extends Control:
	var pin_color: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		for p: Vector2 in [
			Vector2(PIN_INSET, PIN_INSET), Vector2(size.x - PIN_INSET, PIN_INSET),
			Vector2(PIN_INSET, size.y - PIN_INSET), Vector2(size.x - PIN_INSET, size.y - PIN_INSET),
		]:
			draw_circle(p, PIN_RADIUS, pin_color)


# そのマスのボタン。⚠ 無ければ null。⚠ スクロールを寄せる画面が位置を読む。
func get_node_button(node_id: String) -> Control:
	var button: Variant = _node_buttons.get(node_id, null)
	if button is Control and is_instance_valid(button):
		return button as Control
	return null


# 線の引き直しを頼む。⚠ 1フレームの中で何度頼まれても1回だけ引く（⚠ 行ごとに合図が来るため）。
#   ⚠ await を使わない（AGENTS.md）。⚠ call_deferred で次の空き時間に回す。
var _redraw_queued: bool = false


func _request_redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_flush_redraw.call_deferred()


func _flush_redraw() -> void:
	_redraw_queued = false
	if is_inside_tree():
		_redraw_edges()


# 線を引く（段階19-e）。⚠ 呼ぶのは set_map() の最後と sort_children の2箇所だけ。
func _redraw_edges() -> void:
	if _edge_lines == null:
		return
	# ⚠⚠ 入ってくる本数を先に数える（段階20-g）。⚠ 合流するマスで線を横にずらすため
	#   （⚠ 人間の指摘「線が重ならないようにしたい　合流はあってもいい」）。
	var incoming_total: Dictionary = {}
	var outgoing_total: Dictionary = {}
	for entry: Variant in _edges:
		var edge: Dictionary = entry
		var to_key: String = str(edge.get(EDGE_TO, ""))
		var from_key: String = str(edge.get(EDGE_FROM, ""))
		incoming_total[to_key] = int(incoming_total.get(to_key, 0)) + 1
		outgoing_total[from_key] = int(outgoing_total.get(from_key, 0)) + 1
	var incoming_used: Dictionary = {}
	var outgoing_used: Dictionary = {}

	var lines: Array = []
	for entry: Variant in _edges:
		var edge: Dictionary = entry
		var from_id: String = str(edge.get(EDGE_FROM, ""))
		var to_id: String = str(edge.get(EDGE_TO, ""))
		# ⚠ 出る側の番号は、⚠ 描かない線（相手のマスが無い）も数える（⚠ 前の数え方と同じ）。
		var out_slot: int = int(outgoing_used.get(from_id, 0))
		outgoing_used[from_id] = out_slot + 1
		var from_button: Control = get_node_button(from_id)
		var to_button: Control = get_node_button(to_id)
		if from_button == null or to_button == null:
			continue
		var in_slot: int = int(incoming_used.get(to_id, 0))
		incoming_used[to_id] = in_slot + 1
		lines.append({
			# ⚠ 深い層が上なので、⚠ from は上辺・to は下辺でつなぐと線が交差しない。
			DungeonEdgeLines.LINE_FROM: _edge_anchor(
				from_button, true, out_slot, int(outgoing_total.get(from_id, 1))
			),
			DungeonEdgeLines.LINE_TO: _edge_anchor(
				to_button, false, in_slot, int(incoming_total.get(to_id, 1))
			),
			DungeonEdgeLines.LINE_COLOR: _edge_color(from_id, to_id, str(edge.get(EDGE_TONE, TONE_PLAIN))),
			# ⚠ 通った道だけ実線（⚠ 人間「⚠ 道は点線に　⚠ すでに行った場所を赤いラインに」）。
			DungeonEdgeLines.LINE_DASHED: not (_walked.has(from_id) and _walked.has(to_id)),
			DungeonEdgeLines.LINE_STYLE: _tone_style(str(edge.get(EDGE_TONE, TONE_PLAIN))),
			DungeonEdgeLines.LINE_BADGE_BORDER: _tone_badge(str(edge.get(EDGE_TONE, TONE_PLAIN))),
			DungeonEdgeLines.LINE_WIDTH: (
				EDGE_WIDTH_WALKED if (_walked.has(from_id) and _walked.has(to_id))
				else EDGE_WIDTH_CURRENT if from_id == _current_id
				else EDGE_WIDTH
			),
			DungeonEdgeLines.LINE_LABEL: str(edge.get(EDGE_LABEL, "")),
		})
	_edge_lines.set_lines(lines)
	_place_light()
	laid_out.emit()


# ⚠ 地図の下に紙を敷く（⚠ 地図の矩形より `sheet_pad` だけ広く）。⚠ 面は `PaperPanel` と同じ（⚠ 影つき）。
func _draw() -> void:
	if not draw_sheet:
		return
	var pad: float = float(get_theme_constant(&"sheet_pad", THEME_TYPE))
	var pad_v: float = pad if sheet_bleed_vertical else 0.0
	draw_style_box(
		get_theme_stylebox(&"panel", &"PaperPanel"),
		Rect2(Vector2.ZERO, size).grow_individual(pad, pad_v, pad, pad_v)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _ready() -> void:
	# ⚠ 光の大きさ・色・揺れ方は Theme（`RunMapView`）から引く（2026-09-20）。
	var size_px: float = float(_light_number(&"light_size_px"))
	_light.texture = _make_light_texture(
		get_theme_color(&"light", THEME_TYPE),
		float(_light_number(&"light_center_pct")) * 0.01,
		float(_light_number(&"light_mid_pct")) * 0.01,
		int(size_px)
	)
	_light.size = Vector2(size_px, size_px)
	_light.position = -Vector2(size_px, size_px) * 0.5
	_light.pivot_offset = Vector2(size_px, size_px) * 0.5

	# ⚠ 揺れ（⚠ 明るさ・大きさ・位置を少しずつずらす）。⚠ 周期を3つに割って、⚠ 点滅に見えないようにする。
	#   ⚠ 周期 0 なら揺らさない（⚠ Theme で止められる）。
	var period: float = float(_light_number(&"light_period_ms")) * 0.001
	if period <= 0.0:
		return
	var base_x: float = -size_px * 0.5
	var sway: float = float(_light_number(&"light_sway_px"))
	var alpha_min: float = float(_light_number(&"light_alpha_min_pct")) * 0.01
	var alpha_max: float = float(_light_number(&"light_alpha_max_pct")) * 0.01
	var scale_min: float = float(_light_number(&"light_scale_min_pct")) * 0.01
	var scale_max: float = float(_light_number(&"light_scale_max_pct")) * 0.01
	var tween: Tween = create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_light, "modulate:a", alpha_min, period * 0.34)
	tween.parallel().tween_property(_light, "scale", Vector2(scale_min, scale_min), period * 0.34)
	tween.parallel().tween_property(_light, "position:x", base_x - sway, period * 0.34)
	tween.tween_property(_light, "modulate:a", alpha_max, period * 0.22)
	tween.parallel().tween_property(_light, "scale", Vector2(scale_max, scale_max), period * 0.22)
	tween.parallel().tween_property(_light, "position:x", base_x + sway, period * 0.22)
	tween.tween_property(_light, "modulate:a", 1.0, period * 0.44)
	tween.parallel().tween_property(_light, "scale", Vector2.ONE, period * 0.44)
	tween.parallel().tween_property(_light, "position:x", base_x, period * 0.44)


# Theme の数（⚠ 無ければ 0）。⚠ 引く口はここ1本（⚠ 呼ぶ側に型名を書かせない）。
func _light_number(key: StringName) -> int:
	return get_theme_constant(key, THEME_TYPE)


# 光の絵（中心から外へ薄くなる円）。⚠ 画像ファイルを足さずにコードで作る。
static func _make_light_texture(color: Color, center: float, mid: float, size_px: int) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(color, center), Color(color, mid), Color(color, 0.0), Color(color, 0.0),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size_px
	texture.height = size_px
	return texture


# 光をいまいるマスの真ん中へ。⚠ マスの位置が確定してから（⚠ 線と同じく _redraw_edges の中）。
func _place_light() -> void:
	var button: Control = get_node_button(_current_id)
	_light_anchor.visible = button != null
	if button != null:
		_light_anchor.position = button.get_global_rect().get_center() - get_global_rect().position
	_fog.queue_redraw()


# 暗さの境目の高さ（⚠ 見えている一番上の層と、その1つ上の層のあいだ）。⚠ 無ければ -1。
func get_fog_edge_y() -> float:
	if torch_reveal_layers < 0 or _current_layer <= 0:
		return -1.0
	var last_seen: int = _current_layer + torch_reveal_layers
	var seen: Variant = _rows.get(last_seen, null)
	var beyond: Variant = _rows.get(last_seen + 1, null)
	if not (seen is Control) or not (beyond is Control):
		return -1.0
	if not is_instance_valid(seen) or not is_instance_valid(beyond):
		return -1.0
	var origin: float = get_global_rect().position.y
	return ((beyond as Control).get_global_rect().end.y + (seen as Control).get_global_rect().position.y) * 0.5 - origin


# 1層ぶんの高さ（行の中心どうしの距離）。⚠ 行が1つしか無ければ層の間隔だけ。
func _layer_step() -> float:
	var ys: Array[float] = []
	for raw: Variant in _rows.values():
		if raw is Control and is_instance_valid(raw):
			ys.append((raw as Control).get_global_rect().get_center().y)
	if ys.size() < 2:
		return float(layer_separation)
	ys.sort()
	return absf(ys[1] - ys[0])


# 暗さ。⚠ 境目より下は素通し、⚠ 上へ行くほど濃い（モック `.fog` の linear-gradient）。
func _draw_fog() -> void:
	var edge: float = get_fog_edge_y()
	if edge < 0.0:
		return
	# ⚠ 1層ぶんの高さは実際の行から取る（⚠ マスの高さを数字で持たない）。
	var step: float = _layer_step()
	var pad: float = float(get_theme_constant(&"sheet_pad", THEME_TYPE))
	var top_y: float = -pad if sheet_bleed_vertical else 0.0
	var ramp_top: float = maxf(top_y, edge - step * FOG_RAMP_LAYERS)
	var x0: float = -pad
	var x1: float = _fog.size.x + pad
	var fog: Color = get_theme_color(&"fog", THEME_TYPE)
	var clear: Color = Color(fog, 0.0)
	var mid: Color = Color(fog, float(get_theme_constant(&"fog_edge_pct", THEME_TYPE)) * 0.01)
	var top: Color = Color(fog, float(get_theme_constant(&"fog_top_pct", THEME_TYPE)) * 0.01)
	_fog.draw_polygon(
		PackedVector2Array([Vector2(x0, ramp_top), Vector2(x1, ramp_top), Vector2(x1, edge), Vector2(x0, edge)]),
		PackedColorArray([mid, mid, clear, clear])
	)
	# ⚠ 上は紙の縁まで（⚠ 0 で止めると紙の上端に霧のかからない帯が残った）。
	if ramp_top > top_y:
		_fog.draw_polygon(
			PackedVector2Array([Vector2(x0, top_y), Vector2(x1, top_y), Vector2(x1, ramp_top), Vector2(x0, ramp_top)]),
			PackedColorArray([top, top, mid, mid])
		)


# マスのボタンのつなぎ目。⚠ top なら上辺、⚠ でなければ下辺。
#
# ⚠ 座標は線の部品の中の位置。⚠ 線とマスは同じ矩形に重ねてあるので、⚠ そのまま使える。
# ⚠⚠ 何本も出る／入るときは、⚠ マスの辺に沿って少しずらす（段階20-g）。
func _edge_anchor(button: Control, top: bool, slot: int = 0, slot_count: int = 1) -> Vector2:
	var rect: Rect2 = button.get_global_rect()
	var origin: Vector2 = _edge_lines.get_global_rect().position
	# ⚠⚠ 丸いマスは**中心から出て中心に入る**（⚠ 人間の参考 HTML：同じマスの道は全部同じ点から）。
	#   ⚠ 線はマスの後ろに描かれるので、⚠ 丸の縁から出ているように見える。
	if round_nodes:
		return rect.get_center() - origin
	var span: float = rect.size.x * EDGE_ANCHOR_SPREAD
	var offset: float = 0.0
	if slot_count > 1:
		offset = (float(slot) / float(slot_count - 1) - 0.5) * span
	var center_x: float = rect.position.x + rect.size.x * 0.5 + offset
	var y: float = rect.position.y if top else rect.position.y + rect.size.y
	return Vector2(center_x, y) - origin


# 線の描き方。⚠ 罠＝折れ線 ／ 見えない＝点線 ／ ほか＝手描きの曲線（モック v2）。
func _tone_style(tone: String) -> String:
	# ⚠ 丸いマスの地図は罠の道も同じ曲線（⚠ 参考は全部同じ形。⚠ 罠は色で分かる）。
	if round_nodes:
		return DungeonEdgeLines.STYLE_CURVE
	match tone:
		TONE_TRAP:
			return DungeonEdgeLines.STYLE_ZIGZAG
		TONE_HIDDEN:
			return DungeonEdgeLines.STYLE_DASHED
	return DungeonEdgeLines.STYLE_CURVE


func _tone_badge(tone: String) -> Color:
	match tone:
		TONE_TRAP:
			return get_theme_color(&"badge_trap", THEME_TYPE)
		TONE_GAIN:
			return get_theme_color(&"badge_gain", THEME_TYPE)
	return get_theme_color(&"badge_plain", THEME_TYPE)


# 道の色。⚠ 通った＝赤 ／ ⚠ ほかは種類の色に「点線の濃さ」を掛ける ／ ⚠ たいまつが届かない道はさらに薄く（半透明）。
#   ⚠ 人間「⚠ 見える範囲だけ、くっきりと　⚠ そうでない場合は半透明に」。
func _edge_color(from_id: String, to_id: String, tone: String) -> Color:
	if _walked.has(from_id) and _walked.has(to_id):
		return get_theme_color(&"edge_walked", THEME_TYPE)
	var color: Color = _tone_color(tone)
	var alpha_pct: int = get_theme_constant(
		&"far_alpha_pct" if tone == TONE_HIDDEN else &"edge_alpha_pct", THEME_TYPE
	)
	color.a *= float(alpha_pct) * 0.01
	return color


func _tone_color(tone: String) -> Color:
	match tone:
		TONE_TRAP:
			return get_theme_color(&"edge_trap", THEME_TYPE)
		TONE_GAIN:
			return get_theme_color(&"edge_gain", THEME_TYPE)
		TONE_HIDDEN:
			return get_theme_color(&"edge_hidden", THEME_TYPE)
	return get_theme_color(&"edge_plain", THEME_TYPE)
