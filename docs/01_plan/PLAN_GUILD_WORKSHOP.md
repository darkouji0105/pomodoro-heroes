# 【作戦計画書】ギルド - 作業場

第2層・作戦計画。**実コードと突き合わせて改訂した版**（旧版は実装前に書かれており、§4「対応済み」が事実と異なっていた。§4を参照）。

対応する第3層は`EXEC_GUILD_WORKSHOP.md`。

---

## 1. スコープ

### 含む

- レシピ一覧の表示（`recipes.json`から生成）
- 製作の開始（素材を消費してキューへ追加）
- 残り時間の表示（**毎秒更新**）
- 完成品の受け取り（インベントリ／素材へ反映）
- アイテムIDの台帳（`items.json`）の新設

### 含まない

- ポモドーロ進行と連動した製作短縮（`DATA_SCHEMA.md`で「詳細ロジックは未確定」のまま。時間経過のみで完成する最小構成を先に作る）
- 製作のキャンセル
- レシピの解放条件（第1弾は全レシピ解放済みで開始する）
- 装備アイテムそのもの（**次のタスク**。`items.json` / `recipes.json`に行を足すだけで作業場に乗る形にしておく）
- 確認モーダル・製作演出

---

## 2. このタスクの位置づけ

**素材とゴールドの出口はできた。残っているのは「時間を投資する」出口。**

```
戦闘で training_material / construction_material / gold を得る
  → 育成で training_material を使う      ✅ 済
  → 研究で construction_material を使う  ✅ 済
  → ショップで gold を使う               ✅ 済
  → 作業場で素材と「時間」を使う          ← ここ
```

ショップは**即座に手に入る**。作業場は**待つ**。この2つが並んで初めて「今すぐ欲しいか、安く手に入れたいか」の選択が生まれる。

---

## 3. 何を作れるようにするか（決定）

**A案（素材の変換）を採用する。** ただし出力の種類はコードに埋め込まず、**アイテムIDの交換として一般化する**（§4）。

### B案（スタミナポーションの製作）を却下した理由

`DATA_SCHEMA.md`のスタミナ設計は「スタミナ＝その日に遊べる時間であり、**働いた分だけ増える**」を土台にしている。作業場でポーションを作れると

```
戦闘 → 素材 → ポーション → 戦闘
```

が閉じたループになり、ポモドーロを回さなくても遊び続けられてしまう。ショップの`stamina_potion`（500G）は`stock_limit: 2`で1日の頭打ちがあるが、作業場は素材が続く限り回る。**この出口は塞いだままにする。**

### C案（装備を先に作る）を後回しにした理由

装備は`get_effective_stats()`への加算・スロット・戦闘反映がまとめて必要で、`equip_item()` / `unequip_item()`は現在も空実装（`game_manager.gd` 938-942行）。時間投資の仕組み（開始・待つ・受け取る）と装備システムを同じタスクに入れると、不具合の切り分けができなくなる。

**順番は「作業場 → 装備」のまま。** 装備が入ったとき、作業場側はJSONに行を足すだけで対応できる。

### 第1弾のレシピ

| recipe_id | 消費 | 産出 | 所要 |
|---|---|---|---|
| `convert_con_to_tra` | 建築素材 30 | 育成素材 20 | 30分 |
| `convert_tra_to_con` | 育成素材 30 | 建築素材 20 | 30分 |
| `bulk_con_to_tra` | 建築素材 100 | 育成素材 80 | 3時間 |
| `debug_instant` | 建築素材 1 | 育成素材 1 | **10秒**（検証用。リリース前に削除する） |

> **交換レートは必ず1未満にすること。** 旧`NEXT_STEPS.md`にあった「30個消費して20個産出」の逆、つまり「20個消費して30個産出」を双方向に置くと、往復させるだけで素材が無限に増える。**時間が唯一のコストなので、レートで得をさせてはいけない。**

大口ほどレートが良いのは、長い待ち時間を選ぶ動機を作るため。第1弾のレシピは**どちらも既存の素材**なので、翻訳キー（`ui_res_*`）の追加は不要。

---

## 4. データ設計

### 4-1. マスターを2枚に分ける

**アイテムIDが何者なのかを知っているのは`items.json`だけ**にする。レシピは「IDとその個数の交換」しか書かない。

#### `resources/balance/master/items.json`（新設）

```json
{
  "items": [
	{ "item_id": "training_material",     "storage": "material",  "item_type": "material",   "sort_order": 0 },
	{ "item_id": "construction_material", "storage": "material",  "item_type": "material",   "sort_order": 1 },
	{ "item_id": "stamina_potion",        "storage": "inventory", "item_type": "consumable", "sort_order": 10 }
  ]
}
```

- `storage`は状態のどのバケツに入るかだけを表す。現在の`_state`は`materials`（`{id: 数値}`）と`inventory`（`{id: {count, type, ...}}`）で構造が違うため、その差をここで吸収する
- `item_type`は`inventory`側に書き込む値。`state_keys.gd` 70-74行の`ITEM_TYPE_*`のいずれか

#### `resources/balance/master/recipes.json`（新設）

```json
{
  "recipes": [
	{
	  "recipe_id": "convert_con_to_tra",
	  "duration_sec": 1800,
	  "inputs":  [ { "item_id": "construction_material", "count": 30 } ],
	  "outputs": [ { "item_id": "training_material",     "count": 20 } ],
	  "unlocked_by_default": true,
	  "sort_order": 0
	}
  ]
}
```

- **`inputs` / `outputs`は最初から配列にする。** 単数で作ると「素材2種 → 装備1個」を書きたくなった時点でコードとセーブの両方を触ることになる
- `duration_sec`を省略したレシピは`WorkshopConfig.base_craft_duration_sec`を使う。既にある`@export`がここで初めて使われる
- `recipe_type`（`DATA_SCHEMA.md` 4-5の`equipment | furniture_goods`）は**キューに持たせるが、レシピ側では`outputs`から決まるため書かない**。§4-3参照

### 4-2. 状態（`DATA_SCHEMA.md` 4-5）

```json
{
  "recipes_unlocked": { "recipe_id": false },
  "crafting_queue": [
	{
	  "queue_id": "string",
	  "recipe_id": "string",
	  "recipe_type": "equipment | furniture_goods",
	  "started_at": 0,
	  "duration_sec": 0,
	  "status": "in_progress | completed",
	  "output_item_id": "string"
	}
  ]
}
```

キーは`state_keys.gd` 41-156行に一式ある。**追加・変更は不要。**

### 4-3. `DATA_SCHEMA.md`への変更（このタスクで併せて直す）

| 箇所 | 変更 |
|---|---|
| `status`の`collected` | **削除する。** 受け取ったエントリはキューから消す（§5-4）ため、`collected`が保存されている瞬間が存在しない |
| `started_at` | `"timestamp"`という記述を**`int`（Unix秒）**と明記する |
| 4-5に追記 | アイテムIDの台帳を`items.json`に置くこと、レシピの`inputs`/`outputs`が配列であること |

---

## 5. GameManagerへの反映（**現状は空実装。ここが本体**）

> **旧版§4は「反映済み」と書いていたが、事実と異なる。** 実際は`get_crafting_queue()`のみ本実装で、残る2つは`print`して`false`を返すだけ（`game_manager.gd` 1139-1153行）。育成・研究・ショップに続いて**4回目のズレ**。第3層では必ず`grep`で中身を見てから書くこと。

| 関数 | 現在 | このタスク後 |
|---|---|---|
| `get_crafting_queue()` | 本実装 | そのまま |
| `start_craft(recipe_id)` | **空** | 本実装 |
| `collect_craft(queue_id)` | **空** | 本実装 |
| `refresh_crafting_queue_if_needed()` | 無し | **新設** |
| `_get_item_count` / `_consume_item` / `_grant_item` | 無し | **新設（private）** |
| `_sync_recipes_from_master()` | 無し | **新設** |

### 5-1. アイテムIDを扱う3つのprivate関数

```
_get_item_count(item_id) -> int
_consume_item(item_id, count) -> void
_grant_item(item_id, count) -> void
```

`items.json`で`storage`を引き、`material`なら`add_material()` / `get_material_count()`、`inventory`なら`add_to_inventory()`へ回すだけ。

**`start_craft()` / `collect_craft()`はアイテムの種類を一切知らない。** `inputs`をループして`_consume_item()`、`outputs`をループして`_grant_item()`で終わる。これにより、レシピの追加・変更は**JSONの編集だけ**で完結する。

> ショップの`purchase_shop_item()`にある`payout_type`分岐も本来この3関数に寄せられるが、**今回は触らない**。動いているものを巻き込まない。

### 5-2. `start_craft(recipe_id)`

**状態を変える前に、判定を全部通す。** 順番を守ること。

1. レシピが`recipes.json`に存在するか
2. `recipes_unlocked`が`true`か
3. キューに空きがあるか（`WorkshopConfig.max_queue_slots`）
4. **`outputs`が妥当か**（空でない、IDが`items.json`にある、`count > 0`）
5. `inputs`を全部払えるか（`_get_item_count()`で確認）

**4を5より先に見る。** 素材だけ減って何も貰えない事故を防ぐため。すべて通ってから`inputs`を消費し、キューへ追加する。

- 素材の消費は**開始時**。キャンセルが無いので払い戻し処理が要らない
- `queue_id`は`"%d_%s" % [Unix秒, recipe_id]`。キューが1本なので衝突しない
- `duration_sec`は**開始時点の値をキューへコピーする**。マスターを変更しても走行中のキューの残り時間が飛ばないようにするため（`CRAFT_DURATION_SEC`がキュー側にあるのはこのため）

### 5-3. `refresh_crafting_queue_if_needed()`

**`refresh_shop_if_needed()`と同じ形にする。** 現在時刻と`started_at + duration_sec`を比較し、`in_progress`のまま完了しているエントリを`completed`へ書き換える。変化があったときだけ`crafting_queue_changed`を発火する。

- 呼ぶのは**画面を開いたとき**と**毎秒のtick**と**`collect_craft()`の先頭**
- 時刻は`Time.get_unix_time_from_system()`を`int()`で包んだもの。**`GameDate`は1日の区切り専用であり、経過時間の判定には使えない**
- `started_at`は`load_state()`で必ず`int()`に戻す。セーブに`1.7628e+09`と書かれると読めなくなる

**オフライン中も進む。** `started_at`との比較なので当然そうなる。仕様として受け入れる。

### 5-4. `collect_craft(queue_id)`

1. `refresh_crafting_queue_if_needed()`
2. `queue_id`が存在するか
3. `status`が`completed`か（`in_progress`なら`false`）
4. `outputs`をループして`_grant_item()`
5. **エントリをキューから削除する**

`collected`のまま残すとセーブが肥大し、1スロットが埋まったままになる。履歴は持たない（§4-3）。

### 5-5. `_sync_recipes_from_master()`

研究・ショップで2回書いた`_sync_*_from_master()`と同じ考え方。起動時とロード時に`recipes.json`の内容を状態へ反映する。

- **状態側だけが持つのは`recipes_unlocked`の真偽値と`crafting_queue`のみ。** それ以外はマスターが正
- `recipes.json`から消えたレシピIDは`recipes_unlocked`からも消す
- **`inputs` / `outputs`に`items.json`に無いIDが混ざっていたら、そのレシピを丸ごと捨ててログに出す。** 実行時に気づくと「素材だけ減って何も貰えない」が起きる
- 走行中のキューの`duration_sec`は**上書きしない**（§5-2）

### 5-6. `WorkshopConfig`への追加

`resources/balance/workshop_config.gd`は現在`base_craft_duration_sec`のみの骨組み。

```gdscript
@export var max_queue_slots: int = 1
```

を追加する。**同時進行数をハードコードしない**（旧版§6の指示）。第1弾の値は`1`。

---

## 6. UI（`scenes/guild/workshop_screen.gd` / `.tscn`）

**ショップ画面と同じ作りにする。** 1画面・スクロール・行をコードで生成・詳細画面なし。**戻るボタンは1つだけ**（育成で2つ並んだ件を繰り返さない）。

| 区画 | 内容 |
|---|---|
| 製作中 | キューのエントリ。**残り時間**と、完了していれば「受け取る」ボタン |
| レシピ一覧 | `recipes_unlocked`が`true`のもの。消費・産出・所要時間・「作る」ボタン |

### これまでのどの画面にも無かった要素

**毎秒の更新が要る。** 育成・研究・ショップは一度描いたら動かない画面だった。

- `Timer`（1秒・`autostart`）を使う。`_process`は使わない
- **tickでは残り時間ラベルの`text`を差し替えるだけ。行の再生成はしない**
- 行を作り直すのは`crafting_queue_changed` / `material_changed` / `inventory_changed`を受けたときだけ
- 再描画に`await`を持たせない。`remove_child()`してから`queue_free()`する（`AGENTS.md`「再描画は await を持たせない」）。受け取り時は複数のシグナルが連続で飛ぶため、`await process_frame`だと行が二重に並ぶ

---

## 7. 実装の分担

**育成・研究・ショップの3回とも、実装役に投げず設計役が`.gd`・`.tscn`・`.json`を全部書いた。事故ゼロ。** 作業場も同じ判断でよい。

`game_manager.gd`（**現在1323行**）に手を入れるため、**設計役が全文を書く。** 原本をコピーして該当箇所だけ差し替える方式なら、既存関数が変質しない。

`MasterDataLoader`は`get_research_node()` / `get_shop_slots()`と同じ形で**末尾に追記するだけ**。パスは`res://scripts/systems/master_data_loader.gd`（**旧版と`EXEC_GUILD_SHOP.md`は`autoload/`と書いていたが誤り**）。

---

## 8. 検証の段取り

### 待ち時間の問題

`duration_sec`が30分だと、完了確認に30分かかる。**EXECの完了条件に「30分待つ」と書かない。確実に飛ばされる。**

- `recipes.json`の`debug_instant`（10秒）で確認する
- または`save_slot_0.json`の`started_at`を過去に書き換える（ショップの`refresh_at`と同じ手）

### 完了条件は「どこを見るか」で3つに分ける

担当者で分けない（実装役を使わないタスクが4回続いており、その分け方は機能しない）。

| 種類 | 見るもの |
|---|---|
| **ログ** | 起動時のレシピ同期件数、`start_craft()` / `collect_craft()`の失敗理由、未知IDで捨てたレシピ |
| **ファイル** | `save_slot_0.json`の`crafting_queue`（`started_at`が`int`か、受け取り後に消えているか） |
| **画面** | レシピ表示・開始・残り時間の更新・受け取り・遷移 |

**同じことを2箇所に書かない。** UIから到達できない項目（完了前の受け取り、存在しない`queue_id`）は人間の確認項目にしない。

**検証手順は、その出力が実在することを確かめてから書く。** 育成では「ログで確認する」と書いたのに、該当する`print`が無かった。

---

## 9. 完了条件

- [ ] `items.json` / `recipes.json`が読み込まれ、起動時に`recipes_unlocked`へ同期される
- [ ] 未知のアイテムIDを含むレシピが起動時に除外され、ログに出る
- [ ] 解放済みレシピのみ製作を開始できる
- [ ] 素材不足・キュー満杯のとき、状態を一切変えずに`false`が返る
- [ ] 開始時に`inputs`が消費され、`crafting_queue`に1件追加される
- [ ] 残り時間が画面上で毎秒減る
- [ ] 時間経過で`in_progress` → `completed`へ切り替わる（アプリを閉じていた間の経過も反映される）
- [ ] 受け取りで`outputs`がインベントリ／素材へ反映され、エントリがキューから消える
- [ ] 受け取り後に行が二重に並ばない
- [ ] `save_slot_0.json`の`started_at` / `duration_sec`が`int`で保存されている

---

## 10. 未確定（このタスクでは決めない）

- ポモドーロ進行と連動した製作短縮の詳細ロジック
- レシピの解放条件（宝箱の中身にレシピを入れる案が`DATA_SCHEMA.md`にある。器だけ用意し、第1弾は全解放）
- キューの複数スロット化と、その解放方法（研究ツリー経由が自然か）
- 製作のキャンセルと素材の払い戻し
- 交換レートの実測調整（ステージ1周で入る素材量を測ってから）
