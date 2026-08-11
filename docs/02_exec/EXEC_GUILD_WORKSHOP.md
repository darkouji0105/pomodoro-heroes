# 【実行指示書】ギルド - 作業場（第1弾：レシピ4つ・キュー1本・キャンセルなし）

第3層。対応する第2層は`PLAN_GUILD_WORKSHOP.md`（**実コードと突き合わせて改訂した版**）。

**このタスクも実装役を使わない。** 育成・研究・ショップに続いて4回目。

| 誰 | 担当するファイル |
|---|---|
| **人間** | `ja.csv`への追記 / `game_manager.gd`への5箇所の差し替え / `guild_screen.gd`の1行差し替え / `balance.gd`と`workshop_config.tres`の確認 / 受け取ったファイルの保存 |
| **設計役** | `items.json` / `recipes.json` / `master_data_loader.gd`の追記分 / `workshop_screen.gd` / `workshop_screen.tscn` / `workshop_config.gd` / `game_manager.gd`の差し替え5箇所 |
| **実装役** | なし |

---

## 1. このタスクで実現すること

**時間を投資する出口を開ける。** 素材と待ち時間を払って別の素材を受け取れるところまで。

```
戦闘で素材を得る → 作業場に入れる → 待つ → 別の素材を受け取る
```

ショップ（ゴールド・即時）と作業場（素材＋時間）が並ぶことで、「今すぐ欲しいか、待てるか」の選択が生まれる。

**含まないもの：** 装備の製作、スタミナポーションの製作（`PLAN`§3で却下）、ポモドーロ連動、キャンセル、キューの複数本、レシピの解放条件、確認モーダル。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. `PLAN`旧版の「対応済み」は今回も嘘だった

旧`PLAN_GUILD_WORKSHOP.md`§4は3関数を「反映済み」と書いていたが、実際は`get_crafting_queue()`のみ本実装で、`start_craft()` / `collect_craft()`は`print`して`false`を返すだけだった（`game_manager.gd` 1142-1153行）。**育成・研究・ショップに続いて4回目。**

### 2-2. `GameDate`は使えない

ショップのリフレッシュは「ゲーム内の日付が変わったか」で`GameDate`の文字列比較1回だった。**作業場は経過時間の比較なので`GameDate`では判定できない。** `Time.get_unix_time_from_system()`を`int()`で包んで使う。

`GameDate`を混ぜないこと。4:00の区切りと製作の完了時刻は無関係。

### 2-3. `started_at`が`float`になる

セーブから戻すと`float`になる。時刻の比較なので`float`のままでも動いてしまうが、`save_slot_0.json`に`1.7628e+09`と書かれると読めなくなる。

**`_sync_recipes_from_master()`の中で`int()`に戻している**（`_normalize_crafting_queue()`）。この関数は`_ready()`と`load_state()`の両方から呼ぶ。片方だけにすると、ロードしたときだけ壊れる。

### 2-4. キューのエントリは`_copy_array()`だけでは足りない

`_copy_array(CRAFTING_QUEUE)`は浅いコピーで、**中の各Dictionaryは`_state`と同じ実体を指す。** 状態を書き換える箇所では`duplicate(true)`を使っている。ショップの`line_up`と同じ罠。

### 2-5. 走行中のキューは`duration_sec`だけを固定し、`outputs`は固定しない

キューに`duration_sec`をコピーして持たせているため、`recipes.json`の所要時間を変えても走行中の残り時間は飛ばない。

**一方、受け取る中身は受け取り時点の`recipes.json`から引く。** 製作中に`outputs`を書き換えると、受け取る物が変わる。これは意図した挙動（調整中にJSONを触るのが前提のため）。**気になる場合はキューを空にしてから編集する。**

### 2-6. 毎秒`_rebuild()`しない

`Tick`（1秒）で作り直すのは**残り時間ラベルの`text`だけ**。行ごと作り直すと、ボタンを押そうとした瞬間にノードが差し替わって押せなくなる。

行を作り直すのは`crafting_queue_changed` / `material_changed` / `inventory_changed`を受けたときだけ。**再描画に`await`を持たせない**（`remove_child()` → `queue_free()`）。受け取り時はシグナルが2本続けて飛ぶため、`await process_frame`だと行が二重に並ぶ。

### 2-7. 30分待たない

`recipes.json`に`debug_instant`（10秒・建築素材1個 → 育成素材1個）を入れてある。**完了・受け取りの確認は全部これで行う。** 30分レシピで待つ必要はどこにもない。

**`debug_instant`はリリース前に`recipes.json`から1ブロック消すだけで消える。** コード側には何も残らない。

### 2-8. `Balance.workshop`という名前が実在するか未確認

`balance.gd`を見ていないため、`WorkshopConfig`がどのプロパティ名で公開されているか分からない（`Balance.character` / `Balance.pomodoro` / `Balance.initial_state`は実在を確認済み）。

`get_max_queue_slots()`は`"workshop" in Balance`で存在を確かめてから読み、無ければ既定値`1`で動く。**プロパティ名が違っていても画面は動くが、`.tres`の値が効かない。** §7の確認項目1で確かめること。

---

## 3. 触るファイル一覧

| ファイル | パス | 種類 |
|---|---|---|
| `items.json` | `res://resources/balance/master/items.json` | **新規** |
| `recipes.json` | `res://resources/balance/master/recipes.json` | **新規** |
| `master_data_loader.gd` | `res://scripts/systems/master_data_loader.gd` | **末尾に追記**（`master_data_loader_append.gd`の中身をそのまま貼る） |
| `workshop_config.gd` | `res://resources/balance/workshop_config.gd` | **全文差し替え**（`@export`が1つ増える） |
| `workshop_screen.gd` | `res://scenes/guild/workshop_screen.gd` | **新規** |
| `workshop_screen.tscn` | `res://scenes/guild/workshop_screen.tscn` | **新規** |
| `game_manager.gd` | `res://autoload/game_manager.gd` | **5箇所の差し替え**（§4） |
| `guild_screen.gd` | `res://scenes/guild/guild_screen.gd` | **1行の差し替え**（§5） |
| `ja.csv` | `res://localization/ja.csv` | **10行追記**（`ja_csv_additions.csv`） |

> **`master_data_loader.gd`のパスは`res://scripts/systems/`。** `NEXT_STEPS.md`と`EXEC_GUILD_SHOP.md`は`autoload/`と書いているが誤り。§8で直す。

---

## 4. `game_manager.gd`への差し替え（5箇所）

**全文の差し替えではない。** 下記の「差し替え前」を検索し、一意に見つかることを確認してから「差し替え後」に置き換える。**一意に見つからなかった箇所があれば、そこで止めて報告すること**（残りを当てずっぽうで当てない）。

作業前に`game_manager.gd`をコピーしておく。5箇所すべてを当て終えるまでは起動しない（途中の状態では関数が足りず、パースエラーになる）。

### 4-1. シグナルの追加

**差し替え前**

```gdscript
signal shop_changed(shop_type: String)
```

**差し替え後**

```gdscript
signal shop_changed(shop_type: String)
# 製作キューの変化（開始・完了への切り替え・受け取り）。
# 素材・アイテムの増減は material_changed / inventory_changed 側で通知されるため、
# こちらはキューの中身の変化だけを担当する。
signal crafting_queue_changed()
```

### 4-2. 定数の追加

**差し替え前**

```gdscript
const PAYOUT_TYPE_MATERIAL: String = "material"
const PAYOUT_TYPE_ITEM: String = "item"
```

**差し替え後**

```gdscript
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

# Balance.workshop が読めなかったときの既定値。
const DEFAULT_MAX_QUEUE_SLOTS: int = 1
const DEFAULT_CRAFT_DURATION_SEC: int = 1800
```

### 4-3. `_ready()`にレシピの同期を足す

**差し替え前**

```gdscript
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# materials も出す。initial_state に足した素材が届いているかを、
```

**差し替え後**

```gdscript
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピを recipes.json から流し込む。research_tree / line_up と同じ理由で、
	# _empty_state_template() の recipes_unlocked は {} のため、これが無いと画面に1つも出ない。
	_sync_recipes_from_master()
	# 起動した時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
	# materials も出す。initial_state に足した素材が届いているかを、
```

> `refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)`は`load_state()`にも同じ行がある。**次の行のコメントまで含めて検索すること。**

### 4-4. 作業場の本体（ここが本番）

**差し替え前**（`# --- 作業場 ---`から`# --- セーブ・ロード ---`の直前まで。17行）

```gdscript
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
```

**差し替え後**

```gdscript
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
	# 実際に配るものは受け取り時に recipes.json から引き直す（EXEC §2-5）。
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
# 日付ではなく経過時間で判定するため、GameDate は使わない（EXEC §2-2）。
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
```

### 4-5. `load_state()`にレシピの同期を足す

**差し替え前**

```gdscript
	_sync_shops_from_master()
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	print("[GameManager] load_state success. version=%d" % int(_state[GameStateKeys.SAVE_VERSION]))
```

**差し替え後**

```gdscript
	_sync_shops_from_master()
	refresh_shop_if_needed(GameStateKeys.SHOP_TYPE_DAILY)
	# レシピも同様。解放状態と crafting_queue だけが残る。
	# JSON復元で float になった started_at / duration_sec も、ここで int() に戻る。
	_sync_recipes_from_master()
	# ロードした時点で、閉じている間に完成した製作を completed にしておく。
	refresh_crafting_queue_if_needed()
	print("[GameManager] load_state success. version=%d" % int(_state[GameStateKeys.SAVE_VERSION]))
```

> `load_state()`の末尾にある「主要なシグナルを発火」の並びに`crafting_queue_changed`は足さない。`refresh_crafting_queue_if_needed()`が必要なときだけ発火する。ロード直後は画面が生成される前なので、どちらでも表示は変わらない。

---

## 5. `guild_screen.gd`への差し替え（1行）

**差し替え前**

```gdscript
	"workshop": PLACEHOLDER_PATH,
```

**差し替え後**

```gdscript
	"workshop": WORKSHOP_PATH,
```

あわせて定数を1行足す。**差し替え前**

```gdscript
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
```

**差し替え後**

```gdscript
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
const WORKSHOP_PATH: String = "res://scenes/guild/workshop_screen.tscn"
```

`PLACEHOLDER_PATH`の定数自体は消さない（他のサブ画面が使う可能性を残す）。

---

## 6. `ja.csv`への追記

`ja_csv_additions.csv`の10行を`res://localization/ja.csv`の末尾に貼る。

- **UTF-8（BOMなし）で保存する。** BOM付きだと1行目のキーが壊れる
- 追記したら FileSystem パネルで`ja.csv`を右クリック → 再インポート（またはGodot再起動）
- `ui_guild_workshop` / `ui_common_back` / `ui_res_training_material` / `ui_res_construction_material`は**既にあるはず**。無ければ足す

**レシピ名の翻訳キーは作っていない。** 行のテキストは`inputs` / `outputs`から組み立てている（`建築素材 ×30 → 育成素材 ×20`）。**レシピを増やしても`ja.csv`を触らなくてよい**のはこのため。

---

## 7. 完了条件

### 7-1. ログ（起動時とボタン操作で出力を見る）

| # | 見るもの |
|---|---|
| 1 | 起動時に`[MasterDataLoader] loaded 3 entries from res://resources/balance/master/items.json`が出る |
| 2 | 起動時に`loaded 4 entries from ...recipes.json`が出る |
| 3 | 起動時に`_sync_recipes_from_master() -> 4 recipes (unlocked=4, skipped=0)`が出る。**`skipped`が0でなければJSONの綴りが違う** |
| 4 | **`get_max_queue_slots: Balance.workshop が読めない`が出ていないこと。** 出た場合は§2-8。`balance.gd`のプロパティ名を確認する |
| 5 | 素材が足りない状態で「作る」を押すと`start_craft(...) -> false (construction_material: 0 < 30)`の形で理由が出る |
| 6 | 10秒後に`refresh_crafting_queue_if_needed: '..._debug_instant' -> completed`が出る |
| 7 | 受け取ると`collect_craft(...) -> true (training_material x1, queue=0)`が出る |

### 7-2. ファイル（`save_slot_0.json`を開いて見る）

| # | 見るもの |
|---|---|
| 1 | `recipes_unlocked`に4つのIDが`true`で入っている |
| 2 | 製作中にセーブすると`crafting_queue`に1件ある |
| 3 | その`started_at`が`1762800000`の形（**`1.7628e+09`や`.0`付きでない**） |
| 4 | `duration_sec`が`10`（**`10.0`でない**） |
| 5 | 受け取ったあとにセーブすると`crafting_queue`が`[]`になっている |
| 6 | セーブ → 起動し直し → ロードで、製作中のキューが残っている（残り時間が進んでいる） |

### 7-3. 画面（実機で触る）

| # | 見るもの |
|---|---|
| 1 | ギルド画面の「作業場」でプレースホルダではなく作業場が開く |
| 2 | レシピが4行、`建築素材 ×30 → 育成素材 ×20`の形で出る |
| 3 | 所要時間が`30:00` / `3:00:00` / `0:10`の形で出る |
| 4 | 素材が足りないレシピの「作る」が押せない |
| 5 | `debug_instant`で「作る」を押すと素材が1減り、製作中に1行増える |
| 6 | **残り時間が毎秒減る**（`0:10` → `0:09` → …） |
| 7 | キューが埋まっている間、すべてのレシピの「作る」が押せない |
| 8 | 0になると表示が「完成」に変わり、「受け取る」が押せるようになる |
| 9 | 「受け取る」で素材が増え、製作中の行が消え、**行が二重に並ばない** |
| 10 | 倉庫画面で受け取った素材が増えている |
| 11 | 戻るボタンが1つだけで、ギルド画面に戻る |
| 12 | アプリを終了 → 10秒以上待つ → 起動 → 作業場を開くと「完成」になっている |

**「30分待つ」項目は無い。** すべて`debug_instant`（10秒）で確認できる。

---

## 8. 実施結果

**完了。ログ7項目・ファイル6項目・画面12項目のすべてが一発で通った。** 差し戻しゼロ。

`game_manager.gd`は5箇所の差し替えではなく**全文差し替え**で適用した（1323行 → 1721行）。差し替え5箇所はスクリプトで機械的に当て、各アンカーが1件だけ一致することを確認済み。

### やり残し

- [ ] **`recipes.json`から`debug_instant`（10秒レシピ）を消す。** 検証用。**リリース前に必ず消す**（ブロックを1つ削るだけ。コード側には何も残らない）

### このタスクで直したドキュメント

- [x] `DATA_SCHEMA.md` 4-5：`status`から`collected`を削除、`started_at`を`int`（Unix秒）と明記、`items.json`と`recipes.json`の形を追記
- [x] `NEXT_STEPS.md`：作業場から装備へ全面的に書き換え
- [x] `EXEC_GUILD_SHOP.md` 134行：`autoload/master_data_loader.gd` → `scripts/systems/master_data_loader.gd`
- [x] `PROJECT_STATUS.md`：現在地・実装済み表・次のタスク・決定済み表・未決定表・宿題・更新履歴

---

## 9. 止まる条件

- `game_manager.gd`の差し替え5箇所のうち、**検索して一意に見つからないものが1つでもあれば、そこで止めて報告する。** 残りを推測で当てない
- 起動時にパースエラーが出たら、`game_manager.gd`をコピーした原本に戻してからやり直す
- 1つの症状に対して試す方法は2つまで
