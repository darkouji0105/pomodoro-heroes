# 【実行指示書】ギルド - 装備 第2弾（5部位・個体管理・鍛冶・宝箱からの入手）

**このファイルにコードは載せない。** 差し替えるコードはチャット上に出したものが正。ここが持つのは、決定事項・事故りやすい箇所・触ったファイル一覧・完了条件・実施結果だけ。

同じコードがチャットとEXECの2箇所にあると、修正が入ったときにどちらが正か分からなくなるため。

**実装役は使わない。設計役が`.gd`・`.tscn`・`.json`を全部書き、人間が当てた。**（育成・研究・ショップ・作業場・装備第1弾と同じ。6回目）

**このタスクを最後に、以降はClaude Codeへ移る。**

---

## 1. このタスクで実現したこと

**「防具を作る → 装備する → 鍛冶で等級を上げる → ステータスが増える」を1本通した。**

```
ショップ／作業場／宝箱で装備を手に入れる
  → equipment_instances に eq_N として1個ずつ入る
  → 5部位のどれかに装備する
  → 鍛冶で等級を上げる（素材だけ・待ち時間なし・失敗しない）
  → 育成画面と戦闘のダメージが増える
```

第1弾は武器スロット1つ・`atk`加算のみ・在庫と出し入れする形だった。**今回で装備が「個体」になり、同じ武器を2本持って2人に別々に着けられるようになった。**

**ルーンと宝石は入れていない。** 器（`parts`）だけ作って中身は空。

---

## 2. 事故りやすい箇所

### 2-1. 装備の入口は4箇所あり、`_grant_item()`を通るのは作業場だけ

着手前の調査でいちばん効いた発見。

```
open_chest()            → add_to_inventory()   ← 宝箱
purchase_shop_item()    → add_to_inventory()   ← ショップ
collect_craft()         → _grant_item()        ← 作業場
grant_stamina_potions() → add_to_inventory()
```

`_grant_item()`自身も内部で`add_to_inventory()`を呼ぶため、**唯一の関所は`add_to_inventory()`。** 個体の生成をここに1箇所だけ置いた。

**`_grant_item()`に置いていたら、宝箱とショップから出た装備が個体にならず消えていた。**

判定に`item_type`引数を使わず`items.json`で見ているのは、`open_chest()`が第3引数を渡さないため。

### 2-2. `NEXT_STEPS.md`と`PLAN`が食い違っていた

| | NEXT_STEPS §4 | PLAN 2-2 | 採用 |
|---|---|---|---|
| 個体の枠 | `"runes": []` | `"parts": [null, null]` | **PLAN** |
| 強化素材 | `forging_material` 1種 | `forging_material_1〜3` | **1種だが連番の名前** |

**`forging_material`という名前にしなかったのは、リリース後にIDを改名できないため。** あとから`_1`に変えると既存の所持数が消える。

### 2-3. `_default_state()`という関数は存在しない

実際の名前は`_empty_state_template()`。**ドキュメントと実コードのズレ6回目。**

### 2-4. 鍛冶は作業場のレシピの形に乗らない

`workshop_screen.gd`は`get_available_recipes()` → `start_craft(recipe_id)`の1本道で、**個体IDを渡す隙間が無い。** キューも1本しかなく、同じキューに入れると「剣を作っている間は鍛えられない」になる。

**装備画面に置いた。** 「どの個体か」を選ぶ行が既にそこにあるため。

### 2-5. 鍛冶は2本のシグナルを飛ばす

`forge_equipment()`は`add_material()`（`material_changed`）と`equipment_instances_changed`を続けて発火する。

**装備画面は`material_changed`を購読していない。** 両方購読すると再描画が並走して行が二重に並ぶ。所持素材のラベルは`_rebuild()`の中で読み直している。

### 2-6. 着脱ではシグナルが1本しか飛ばない

装備中の個体を在庫から出し入れしないため、着脱で変わるのは`character_growth`だけ。**第1弾で2本飛んでいたのが1本になった。**

### 2-7. `MasterDataLoader`が返す数値は`float`

等級の係数も装備の性能値も`int()`で包む。包み忘れると`get_effective_stats()`が`atk: 55.0`を返し、セーブにも`.0`が書かれる。

### 2-8. 倉庫の`_rebuild_*()`が`await process_frame`を持っていた

装備を素材に戻すと2本のシグナルが飛ぶため、そのままだと行が二重に並ぶ。**`remove_child()` → `queue_free()`に直した**（3つの`_rebuild_*()`すべて）。

---

## 3. 決定事項

| 論点 | 決定 |
|---|---|
| **個体の持ち物** | **`item_id` / `grade` / `parts` の3つだけ。** 性能値はコピーしない。`equip_stats` × 等級係数で毎回計算する |
| **個体の生成場所** | **`add_to_inventory()` の中。** 入口が4箇所あるため、唯一の関所に置く |
| **`inventory`との関係** | **混ぜない。** 装備は`equipment_instances`にだけ入る。`add_to_inventory()`・`_consume_item()`・図鑑が`{item_id: {count}}`に依存しているため |
| **装備中の個体** | **`equipment_instances`に残す。** 在庫から出し入れせず「どこかのスロットに入っているか」で絞る |
| **部位** | **5部位**（頭 / 上半身 / 下半身 / 武器 / アクセサリー）。内部キーは`armor`のまま（`EQUIP_TORSO`に改名しない） |
| **等級の上限** | **3。** 4〜10のコストはバランスの計算道具ができてから決める |
| **等級の係数** | **加算。** 基礎値 × `GRADE_STAT_RATIO`(0.25) × (等級-1)。乗算にするとインフレする |
| **鍛冶の置き場所** | **装備画面。** 作業場はレシピの形で個体IDを渡せない |
| **鍛冶の待ち時間** | **無し。** 素材だけで即座に上がる。入れるならキューがもう1本要る。あとで個体に`grade_up_at`を足す形で乗せられる |
| **鍛冶の失敗** | **しない。** 素材と判定を通れば必ず上がる |
| **強化素材** | **`forging_material_1` の1種。** 名前は最初から連番。`_2` / `_3` を足すときに`items.json`・`ja.csv`・`stages.json`だけで済む |
| **重複の変換** | **手動**（倉庫の「素材にする」）。自動にすると「同じ装備を2人に着ける」が確認できなくなる。装備中は不可 |
| **変換の戻り量** | 基礎3 ＋ 等級を上げるのに払った全額 |
| **枠（宝石・ルーン）** | **器だけ。** `parts: [null, null]` を作り、等級5・10で開く計算（`get_open_part_slot_count()`）だけ入れた。中身は次のタスク以降 |
| **既存セーブの装備** | **捨てる。** 第1弾は`equipment.weapon`に`item_id`の文字列が入っていた。`_normalize_equipment_from_save()`が個体IDでない値を`null`に戻し`push_warning`を出す。**移行処理は書かない** |
| **宝箱からの入手** | `ChestContentConfig`に`@export var equipment`を1つ足し、`claim_pending_chests()`が`rewards.inventory`に流す。**開封側（`open_chest()`）は触っていない** |

---

## 4. 触ったファイル一覧

| ファイル | 変更 |
|---|---|
| `autoload/game_manager.gd` | 大幅（シグナル1本追加・定数・`add_to_inventory()`・`_default_growth_for()`・装備ブロック全面・`load_state()`・`claim_pending_chests()`） |
| `scripts/utils/state_keys.gd` | 末尾追記のみ |
| `scenes/guild/equipment_screen.gd` / `.tscn` | 全面書き直し |
| `scenes/guild/warehouse_screen.gd` | 装備の個体表示・「素材にする」・`await`除去 |
| `chest_content_config.gd` | `@export var equipment` を1行追加 |
| `resources/balance/master/items.json` | 16エントリ（装備12種＋素材3＋消費1） |
| `resources/balance/master/recipes.json` | 15エントリ（装備のレシピ8本追加） |
| `resources/balance/master/stages.json` | `forging_material_1` のドロップを3ステージに |
| `resources/balance/master/shop.json` | 検証用0Gスロット・鍛冶素材 |
| `localization/ja.csv` | 21行追記 |
| `pomodoro_config.tres` 生成スクリプト | 宝箱の中身に装備と鍛冶素材 |

**触っていないもの：** `transfer_keys.gd`（`CHARACTER_ID`は追加済みだった）、`training_screen.gd`（装備ボタンは接続済みだった）、`workshop_screen.gd`、`save_manager.gd`（`get_state()`を丸ごと保存しているため往復は自動）、`battle_controller.gd`。

---

## 5. 完了条件

**項目番号と文言をそのまま転記して検証すること。** 要約したり作り直したりしない。

### 5-0. コード（`grep`だけで済む）

1. 旧API（`equip_item` / `unequip_item` / `get_equipped_item_id` / `get_equippable_items`）が0件
2. 新API（`equip_instance` / `unequip_instance` / `forge_equipment` / `dismantle_equipment` / `_normalize_equipment_from_save`）がすべて実装されている
3. `_normalize_equipment_from_save()` が `load_state()` から呼ばれている
4. `state_keys.gd` に `EQUIPMENT_INSTANCES` / `EQUIP_HEAD` / `ITEM_FORGING_MATERIAL_1` がある
5. **`_create_equipment_instance` の呼び出し元が1箇所だけ**（2箇所以上あると個体が二重に作られる）
6. `battle_controller.gd` で `get_effective_stats` が1件以上
7. **`battle_controller.gd` で `GROWTH_STATS` が0件**（生の`stats`を直接読んでいないこと。第1弾で踏んだ罠）
8. 4スペースインデントの行が0件

### 5-1. ログ（Godotの出力パネルを見る）

1. 起動時に `[MasterDataLoader] loaded 16 entries from res://resources/balance/master/items.json`
2. 起動時に `[MasterDataLoader] loaded 15 entries from res://resources/balance/master/recipes.json`
3. 既存セーブを読むと `[GameManager] load_state: 個体でない装備を捨てた（...）` が出る（**正常**）
4. 装備を手に入れると `[GameManager] _create_equipment_instance('armor_leather_cap') -> eq_1`
5. 鍛えると `[GameManager] forge_equipment('eq_1') -> true (grade 1 -> 2 cost=8 stats={...} slots=0)`
6. `stats` の値に `.0` が付いていない
7. 素材に戻すと `[GameManager] dismantle_equipment('eq_1') -> true (... refund=forging_material_1 x3)`
8. 装備中のものを素材にしようとすると `false (equipped by char_swordsman)`

### 5-2. ファイル（`user://saves/save_slot_0.json`をテキストエディタで開く）

1. `equipment_instances` に `eq_1` 等が入っている
2. 個体が持つのは `item_id` / `grade` / `parts` の3つだけ（**性能値がコピーされていない**）
3. `parts` が `[null, null]` になっている
4. `next_equipment_instance_id` が個体の数だけ進んでいる
5. `character_growth.<id>.equipment` が**5キー**（head / armor / legs / weapon / accessory）
6. そこに入っているのが `"eq_3"` のような**個体ID**（`item_id`ではない）
7. `inventory` に装備が**1つも入っていない**
8. 数値に `.0` が付いていない

### 5-3. 画面（実機で触る）

1. ショップに0Gのスロットが出ている（革の帽子・革の胴着・革のブーツ・力の指輪・鍛冶の欠片×50）
2. 倉庫の持ち物タブで、装備が**1個ずつ別の行**で出る（個数表示ではない）
3. 装備画面に**5部位**が並び、「選ぶ」で下の一覧が切り替わる
4. **同じ武器を2つ買い、剣士と弓兵に別々に着けられる**
5. 着けた個体が一覧から消え、外すと戻る
6. **行が二重に並ばない**（着脱と鍛冶を5回ずつ繰り返して確認する）
7. 「鍛える(8)」で等級2になり、ステータスが増える。等級3で「最大」になる
8. 倉庫の「素材にする」で鍛冶の欠片が戻る。**装備中のものは押せない**
9. 育成画面の詳細で、`atk`等が装備込みの値になっている
10. **ステージ1で、装備前よりダメージが大きい**
11. F3のデバッグパネルで、装備込みの値になっている
12. 宝箱を開けると装備が出る（**`.tres`を生成し直してから**）
13. 再起動しても装備と等級が保たれている

**4と10が本体。** 4が通らなければ個体管理が、10が通らなければ戦闘への反映が効いていない。

### 5-4. 将来コードを変えたときに見る項目（人間の確認項目ではない）

UIから到達できないため、実機では試せない。

- 存在しない`character_id` / `instance_id`を渡すと`false`を返し、状態が変わらない
- `item_type`が`equipment`でないIDの個体を装備しようとすると`false`
- `equip_slot`が`armor`の個体を`weapon`スロットに渡すと`false`
- 他のキャラが装備中の個体を渡すと`false`
- `items.json`から消えたIDの個体を装備したままロードすると、`push_warning`が出て加算が0になる（装備は外れない）
- 等級が上限の個体に`forge_equipment()`を呼ぶと`false`、素材が減らない

---

## 6. 止まる条件

- 1つの症状に対して**2手まで**。3手目に進まず報告する
- **1ファイルへの書き込みが2回失敗したら中止する**（方法を変えても回数に数える）
- 切り分けのために本番コードを書き換えない
- 原因を「環境の問題」と結論づけない。観測した事実だけ報告する

---

## 7. 実施結果

**5-0（コード8項目）・5-1（ログ8項目）・5-2（ファイル8項目）・5-3（画面13項目）、すべて通った。**

### 通らなかった項目

なし。**6回連続で事故ゼロ。**

**装備の第1弾で踏んだ「差し替えが当たっていない」は今回起きなかった。** 設計役が全文を書き、当てたあとに`grep`で確認する手順を最初から組み込んだため。

### やり残し

- 検証用のもの（`recipes.json`の`debug_instant`、`shop.json`の0Gスロット`slot_id` 6〜8・10〜14、`items.json`の`weapon_debug_blade`と`shop.json`の`slot_id` 5）を消していない。**次のタスクの最初にやる**
- 等級4〜10のコストが未定。上限は3のまま
- 枠（`parts`）は器だけ。宝石・ルーンは中身が無い
- 防具3部位の等級5・10の効果は「専用の枠を作る」と決めただけで、刺さるものが無い
- ショップの装備ラインナップが検証用の0Gスロットのみ

### このタスクで直したドキュメント

- **`NEXT_STEPS.md`（旧版）§4** … 個体の枠を`"runes": []`と書いていたが、`PLAN_CHARACTER_GROWTH_LOOP.md` 2-2 の`"parts": [null, null]`が正。台帳が2つあって食い違っていた
- **同 §3** … `_default_state()`と書いていたが、実際の関数名は`_empty_state_template()`
- **同 §6-1** … 強化素材を`forging_material`1種と書いていたが、PLAN 1章は3段階。**1種で始めるが名前は`forging_material_1`**として折衷した
- **同 §5** … 「鍛冶を作業場に足すなら`workshop_screen.gd`を見てから決める」→ **見た結果、乗らないと判明**
- **`HANDOVER_TO_CLAUDE_CODE.md` 3章** … `get_effective_stats`と`GROWTH_STATS`を1つの`grep`にまとめて書いていたため、「`GROWTH_STATS`が0件」を異常として報告させてしまった。**0件が正解**。2つの`grep`に分けた

---

## 8. このタスクのあとに増える宿題

- **検証用のものを全部消す。** 次のタスクの最初にやる。残っているとバランスの測定値が全部狂う
- **等級4〜10のコスト表。** バランスの計算道具ができてから
- **`GRADE_STAT_RATIO`と`FORGE_COST_PER_GRADE`を`.tres`へ出すか判断する。** いまは`game_manager.gd`の定数
- 宝石とルーン（`parts`に刺さるもの）
- 防具の等級5・10で開く枠に、実際に刺さるものを作る
- ショップの装備ラインナップ
- 鍛冶に待ち時間を入れるか（入れるなら個体に`grade_up_at`）
- 装備の着脱・鍛冶・素材化に確認モーダル（`Modal.confirm`の待ち方を確認してから）
- 倉庫の空表示が全タブ「受け取れる宝箱はありません」になっている
