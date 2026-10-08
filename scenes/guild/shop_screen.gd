# res://scenes/guild/shop_screen.gd
# ショップ画面（第1弾：日替わりのみ・固定ラインナップ）。指示書 EXEC_GUILD_SHOP.md §5-4 準拠。
# 研究画面と同じ作りにそろえている：1画面・スクロール・行をコードで生成・詳細画面なし。
# 戻るボタンは1つだけ（育成で2つ並んだ不具合を繰り返さない）。
#
# 週替わり・月替わりのタブは第1弾では作らない。GameManager 側は shop_type を受け取る形の
# ままなので、shop.json に "weekly" を足してタブを1つ増やせば拡張できる。

class_name ShopScreen
extends Control

# ⚠ 2026-09-26（回UI-3）：⚠ 戻る先はギルドから本部（拠点）へ（⚠ ギルドの画面は消した）。
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"

# 第1弾で表示するショップ種別。文字列リテラルを書かないこと。
const SHOP_TYPE: String = GameStateKeys.SHOP_TYPE_DAILY

# --- ノード参照 ---
@onready var gold_label: Label = $Margin/Layout/GoldLabel
@onready var refresh_label: Label = $Margin/Layout/RefreshLabel
@onready var slot_list: VBoxContainer = $Margin/Layout/Scroll/SlotList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
# ⚠ 題と戻るは `ScreenHeader` が持つ（2026-09-09）。⚠ ボタンを直接掴まない
#   （⚠ 掴むと、⚠ 部品の作りを変えるたびに画面ぜんぶを直すことになる）。
@onready var header: ScreenHeader = $Margin/Layout/Header

func _ready() -> void:
	# 1. 画面を開いた時点で日付を見る。
	#    起動しっぱなしで 4:00 をまたいだ場合、起動時のチェックだけでは在庫が戻らない。
	GameManager.refresh_shop_if_needed(SHOP_TYPE)

	# 2. ボタン接続
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.SHOP)

	# 3. GameManager のシグナル購読
	#    shop_changed: 購入回数・リフレッシュ
	#    resource_changed: 所持金の表示とボタンの活性
	GameManager.shop_changed.connect(_on_shop_changed)
	GameManager.resource_changed.connect(_on_resource_changed)

	# 4. 初期描画
	notice_label.text = ""
	_rebuild()

# --- 描画 ---

func _rebuild() -> void:
	_update_header()

	# remove_child してから queue_free する。queue_free + await process_frame にすると、
	# 1回の購入で resource_changed と shop_changed が続けて飛ぶため
	# 再描画が2本並走し、行が二重に並ぶ（await の間に2本目が削除を終えてしまう）。
	# remove_child はその場で効くので、この関数は await を持たない。
	for child: Node in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()

	var line_up: Array = GameManager.get_shop_lineup(SHOP_TYPE)
	if line_up.is_empty():
		# ⚠ 0件の置き場は `EmptyState` の1本（2026-09-09）。⚠ 文字1行だと
		#   ⚠ 「売り切れなのか、⚠ まだ並んでいないのか」が読み取れなかった。
		slot_list.add_child(EmptyState.create(
			"ui_guild_shop_empty", "", IconTextures.for_chest()
		))
		return

	for entry: Variant in line_up:
		if not (entry is Dictionary):
			continue
		_create_slot_row(entry as Dictionary)

func _update_header() -> void:
	var state: Dictionary = GameManager.get_state()
	gold_label.text = "%s %d" % [tr("ui_res_gold"), int(state.get(GameStateKeys.GOLD, 0))]
	# ⚠ 10-07（人間「⚠ まとめて」）：⚠ 所持金は右上の通貨と重なるので出さない。
	gold_label.visible = false

	# 「いつ在庫が戻ったか」を出す。出していないと、翌日に購入回数が戻ったことが
	# 画面から確認できない（在庫表示が動くだけで、原因が分からない）。
	var shop: Dictionary = state.get(GameStateKeys.DAILY_SHOP, {})
	# tr() の戻り値に % を掛けない。ja.csv にキーが無いとキー名がそのまま返り、
	# 書式指定子を含まない文字列に % を適用してエラーになる（AGENTS.md はキー名表示を許容している）。
	refresh_label.text = "%s %s" % [tr("ui_guild_shop_refreshed_at"), str(shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))]
	_update_next_refresh()


# ⚠ 次の更新までの残り（2026-10-07・回UI-便 I）。⚠ 更新日のうしろに足す。⚠ 30秒ごとに書き直す（⚠ 分までしか出さない）。
var _next_refresh_wait: float = 0.0
const NEXT_REFRESH_TICK_SEC: float = 30.0


func _update_next_refresh() -> void:
	var left: int = GameDate.seconds_until_next_day()
	var base_text: String = refresh_label.text.split("　")[0]
	refresh_label.text = "%s　%s" % [base_text, tr("ui_guild_shop_next_refresh") % [left / 3600, (left % 3600) / 60]]


func _process(delta: float) -> void:
	_next_refresh_wait += delta
	if _next_refresh_wait < NEXT_REFRESH_TICK_SEC:
		return
	_next_refresh_wait = 0.0
	# ⚠ 区切りをまたいだら品揃えを引き直す（⚠ 開いたまま 4:00 を越えたとき）。
	GameManager.refresh_shop_if_needed(SHOP_TYPE)
	_update_next_refresh()

func _on_row_input(event: InputEvent, ribbon_slot: Control, slot_id: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_row_seen(ribbon_slot, slot_id)


# ⚠ その品を見た（⚠ 紐を外し、施設の帯の紐も引き直す）。
func _on_row_seen(row: Control, slot_id: int) -> void:
	GameManager.mark_shop_slot_seen(slot_id)
	if is_instance_valid(row):
		RibbonMark.detach(row)
	var facility: Node = get_node_or_null("FacilityBar")
	if facility is BaseFacilityBar:
		(facility as BaseFacilityBar).refresh_attention()


func _create_slot_row(slot: Dictionary) -> void:
	var slot_id: int = int(slot.get(GameStateKeys.SHOP_SLOT_ID, -1))
	var item_id: String = str(slot.get(GameStateKeys.SHOP_ITEM_ID, ""))
	var count: int = int(slot.get(GameManager.SHOP_SLOT_PAYOUT_COUNT, 1))
	var stock_limit: int = int(slot.get(GameStateKeys.SHOP_STOCK_LIMIT, 0))
	var purchased_count: int = int(slot.get(GameStateKeys.SHOP_PURCHASED_COUNT, 0))

	var cost: Dictionary = slot.get(GameStateKeys.SHOP_COST, {})
	var currency_type: String = str(cost.get(GameStateKeys.COST_CURRENCY_TYPE, GameStateKeys.GOLD))
	var amount: int = int(cost.get(GameStateKeys.COST_AMOUNT, 0))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ShopRow_%d" % slot_id
	# ⚠ 10-07（人間「⚠ そのページの紐が全部一気に消えてしまう　一個ずつ消えていくように確認したら」）：⚠ まだ見ていない品の行に紐。⚠ カーソルを乗せるか買ったら、その行だけ消える。
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	# ⚠ 10-07（見る回22回目・人間「⚠ ショップのしおりが分からない」→「⚠ 品物にしおりが出てこない」）：
	#   ⚠ 前は行の右端に描いていた＝⚠ 子の「購入する」ボタンが上に描かれて紐が隠れていた。⚠ 品の絵の前に紐だけの枠を置く。
	var ribbon_slot: Control = Control.new()
	ribbon_slot.name = "RibbonSlot"
	ribbon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon_slot.custom_minimum_size.x = float(ribbon_slot.get_theme_constant(&"ribbon_w", RibbonMark.THEME_TYPE))
	ribbon_slot.set_meta(RibbonMark.META_INSET, 0.0)
	row.add_child(ribbon_slot)
	# ⚠ 10-07（見る回23回目・人間「⚠ ショップのひもに気づくが、クリックして確認しないと、消えないように」）：⚠ カーソルを乗せただけでは消さない。⚠ 行を押すか買ったら消える。
	if not GameManager.is_shop_slot_seen(slot_id):
		RibbonMark.attach(ribbon_slot)
		row.gui_input.connect(_on_row_input.bind(ribbon_slot, slot_id))

	# 仮アセットのアイコン。⚠ daily の13枠は全部 items.json の実在のIDを売る。
	var item_icon: ItemIcon = ItemIcon.create(item_id)
	item_icon.name = "ItemIcon"
	# ⚠ 10-07：⚠ アイコンを押しても入手先の窓（⚠ ほかにどこで手に入るか）。
	ItemSourceWindow.attach_to(item_icon, item_id)
	# ⚠ 10-09（見る回24回目・人間「⚠ 紐を押すのではなく、アイテムクリックで消す」）：⚠ 品の絵を押しても「見た」。
	#   ⚠ 絵は押下を食べる（⚠ 入手先の窓）＝行まで届かず、⚠ 前は紐が消えなかった。
	if not GameManager.is_shop_slot_seen(slot_id):
		item_icon.gui_input.connect(_on_row_input.bind(ribbon_slot, slot_id))
	row.add_child(item_icon)

	# 商品名 ×個数。素材名は "ui_res_" + item_id で引く（AGENTS.md 翻訳キーの運用）
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s ×%d" % [tr("ui_res_" + item_id), count]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var cost_label: Label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "%s %d" % [tr("ui_res_" + currency_type), amount]
	row.add_child(cost_label)

	var stock_label: Label = Label.new()
	stock_label.name = "StockLabel"
	stock_label.text = "%s %d/%d" % [tr("ui_guild_shop_stock"), stock_limit - purchased_count, stock_limit]
	row.add_child(stock_label)

	var buy_button: UiButton = UiButton.create()
	buy_button.name = "BuyButton"
	var sold_out: bool = purchased_count >= stock_limit or stock_limit <= 0
	var affordable: bool = _get_balance(currency_type) >= amount
	if sold_out:
		buy_button.text = tr("ui_guild_shop_sold_out")
	else:
		buy_button.text = tr("ui_guild_shop_buy")
	# 購入できない理由は表示側でも弾く。GameManager 側も同じ判定を持っているため、
	# ここが抜けても状態は壊れない（二重に守る）。
	# ⚠ 10-07（人間「⚠ プラスボタン押さなくても　例えば必要な素材を提示する画面などがあれば」・`NAV-19`）：⚠ お金が足りなくても押せる＝押すと入手先の窓。⚠ 押せないのは売り切れだけ。
	buy_button.disabled = sold_out
	# ⚠ 10-07（人間「⚠ 足りないボタンは不足とは出さないで数字の色で」）：⚠ 値段の数字を赤に。
	if not sold_out and not affordable:
		cost_label.theme_type_variation = &"ErrorLabel"
	buy_button.pressed.connect(_on_buy_pressed.bind(slot_id, currency_type, amount))
	row.add_child(buy_button)
	# ⚠ 10-07（人間「⚠ C」＝まとめて）：⚠ 残りが2つ以上で、2つ以上買えるなら「まとめて買う(n)」（⚠ n＝残りと払える数の小さいほう）。
	var bulk: int = mini(stock_limit - purchased_count, _get_balance(currency_type) / maxi(1, amount))
	if not sold_out and bulk >= 2:
		var bulk_button: UiButton = UiButton.create()
		bulk_button.name = "BulkBuyButton"
		bulk_button.text = tr("ui_guild_shop_buy_bulk") % bulk
		bulk_button.pressed.connect(_on_bulk_buy_pressed.bind(slot_id, bulk))
		row.add_child(bulk_button)

	slot_list.add_child(row)

func _get_balance(currency_type: String) -> int:
	var state: Dictionary = GameManager.get_state()
	match currency_type:
		GameStateKeys.GOLD:
			return int(state.get(GameStateKeys.GOLD, 0))
		GameStateKeys.GEMS:
			return int(state.get(GameStateKeys.GEMS, 0))
	return 0

# --- 操作 ---

# 確認モーダルは入れていない。Modal.confirm() の待ち方が未確認のため
# （研究画面と同じ判断。EXEC_GUILD_SHOP.md §2-6）。
# ボタンは条件を満たさないと押せないため、誤操作は「押せる状態のものを押す」ときだけ起きる。
func _on_buy_pressed(slot_id: int, currency_type: String = "", amount: int = 0) -> void:
	GameManager.mark_shop_slot_seen(slot_id)
	if ItemSourceWindow.open_if_short(self, currency_type, amount, {}):
		return
	var success: bool = GameManager.purchase_shop_item(SHOP_TYPE, slot_id)
	if success:
		notice_label.text = tr("ui_guild_shop_purchased")
	else:
		# ここに来るのは、ボタンの活性判定と GameManager の判定がずれたときだけ。
		notice_label.text = tr("ui_guild_shop_failed")
	# 再描画は shop_changed / resource_changed 側で行う（成功時）。
	# 失敗時は状態が変わらずシグナルも飛ばないため、ここでは何もしない。

# ⚠ 1つずつ本番の口（`purchase_shop_item()`）で買う。⚠ 途中で買えなくなったら止まる。
func _on_bulk_buy_pressed(slot_id: int, count: int) -> void:
	var bought: int = 0
	for _i: int in range(count):
		if not GameManager.purchase_shop_item(SHOP_TYPE, slot_id):
			break
		bought += 1
	notice_label.text = tr("ui_guild_shop_purchased_bulk") % bought if bought > 0 else tr("ui_guild_shop_failed")


func _on_back_pressed() -> void:
	# ⚠ 10-06（`NAV-18`）：⚠ 掲示板から寄り道で来たなら掲示板へ。
	SceneManager.go_back_or(BASE_PATH)

# --- シグナルハンドラ ---

func _on_shop_changed(shop_type: String) -> void:
	if shop_type != SHOP_TYPE:
		return
	_rebuild()

func _on_resource_changed(resource_type: String, _new_value: Variant) -> void:
	# 所持金が変わると「買えるかどうか」が変わる。行ごと作り直す。
	if resource_type != GameStateKeys.GOLD and resource_type != GameStateKeys.GEMS:
		return
	_rebuild()
