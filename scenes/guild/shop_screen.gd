# res://scenes/guild/shop_screen.gd
# ショップ画面（第1弾：日替わりのみ・固定ラインナップ）。指示書 EXEC_GUILD_SHOP.md §5-4 準拠。
# 研究画面と同じ作りにそろえている：1画面・スクロール・行をコードで生成・詳細画面なし。
# 戻るボタンは1つだけ（育成で2つ並んだ不具合を繰り返さない）。
#
# 週替わり・月替わりのタブは第1弾では作らない。GameManager 側は shop_type を受け取る形の
# ままなので、shop.json に "weekly" を足してタブを1つ増やせば拡張できる。

class_name ShopScreen
extends Control

const GUILD_PATH: String = "res://scenes/guild/guild_screen.tscn"

# 第1弾で表示するショップ種別。文字列リテラルを書かないこと。
const SHOP_TYPE: String = GameStateKeys.SHOP_TYPE_DAILY

# --- ノード参照 ---
@onready var gold_label: Label = $Margin/Layout/GoldLabel
@onready var refresh_label: Label = $Margin/Layout/RefreshLabel
@onready var slot_list: VBoxContainer = $Margin/Layout/Scroll/SlotList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

func _ready() -> void:
	# 1. 画面を開いた時点で日付を見る。
	#    起動しっぱなしで 4:00 をまたいだ場合、起動時のチェックだけでは在庫が戻らない。
	GameManager.refresh_shop_if_needed(SHOP_TYPE)

	# 2. ボタン接続
	back_button.pressed.connect(_on_back_pressed)

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
		var empty_label: Label = Label.new()
		empty_label.name = "EmptyLabel"
		empty_label.text = tr("ui_guild_shop_empty")
		slot_list.add_child(empty_label)
		return

	for entry: Variant in line_up:
		if not (entry is Dictionary):
			continue
		_create_slot_row(entry as Dictionary)

func _update_header() -> void:
	var state: Dictionary = GameManager.get_state()
	gold_label.text = "%s %d" % [tr("ui_res_gold"), int(state.get(GameStateKeys.GOLD, 0))]

	# 「いつ在庫が戻ったか」を出す。出していないと、翌日に購入回数が戻ったことが
	# 画面から確認できない（在庫表示が動くだけで、原因が分からない）。
	var shop: Dictionary = state.get(GameStateKeys.DAILY_SHOP, {})
	# tr() の戻り値に % を掛けない。ja.csv にキーが無いとキー名がそのまま返り、
	# 書式指定子を含まない文字列に % を適用してエラーになる（AGENTS.md はキー名表示を許容している）。
	refresh_label.text = "%s %s" % [tr("ui_guild_shop_refreshed_at"), str(shop.get(GameStateKeys.SHOP_REFRESH_AT, ""))]

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

	var buy_button: Button = Button.new()
	buy_button.name = "BuyButton"
	var sold_out: bool = purchased_count >= stock_limit or stock_limit <= 0
	var affordable: bool = _get_balance(currency_type) >= amount
	if sold_out:
		buy_button.text = tr("ui_guild_shop_sold_out")
	else:
		buy_button.text = tr("ui_guild_shop_buy")
	# 購入できない理由は表示側でも弾く。GameManager 側も同じ判定を持っているため、
	# ここが抜けても状態は壊れない（二重に守る）。
	buy_button.disabled = sold_out or not affordable
	buy_button.pressed.connect(_on_buy_pressed.bind(slot_id))
	row.add_child(buy_button)

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
func _on_buy_pressed(slot_id: int) -> void:
	var success: bool = GameManager.purchase_shop_item(SHOP_TYPE, slot_id)
	if success:
		notice_label.text = tr("ui_guild_shop_purchased")
	else:
		# ここに来るのは、ボタンの活性判定と GameManager の判定がずれたときだけ。
		notice_label.text = tr("ui_guild_shop_failed")
	# 再描画は shop_changed / resource_changed 側で行う（成功時）。
	# 失敗時は状態が変わらずシグナルも飛ばないため、ここでは何もしない。

func _on_back_pressed() -> void:
	SceneManager.change_scene(GUILD_PATH)

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
