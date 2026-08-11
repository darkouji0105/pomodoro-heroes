# 【実行指示書】ギルド - ショップ（第1弾：日替わり・固定ラインナップ）

第3層。対応する第2層は`PLAN_GUILD_SHOP.md`（**実コードと突き合わせて改訂した版**）。

**このタスクは実装役を使わない。** `.gd`・`.tscn`・`.json`はすべて設計役が全文を書いた。育成・研究に続いて3回目。

| 誰 | 担当するファイル |
|---|---|
| **人間** | `ja.csv` / `guild_screen.gd`の2行差し替え / 受け取ったファイルの保存 |
| **設計役** | `game_manager.gd`（1051行 → 1323行）/ `master_data_loader.gd` / `shop_screen.gd` / `shop_screen.tscn` / `shop.json` |
| **実装役** | なし |

`shop_config.tres`の編集は**不要**。理由は§2-7。

---

## 1. このタスクで実現すること

**ゴールドの出口を1つ開ける。** ゴールドを払って`training_material` / `construction_material` / `stamina_potion`を買えるところまで。

```
戦闘で gold を得る → ショップで素材を買う → 育成・研究で使う
```

日替わりの在庫は**毎朝4時に戻る**（`GameDate`基準。ポモドーロ・ストリークと同じ区切り）。

**含まないもの：** 週替わり・月替わりのタブ、抽選によるラインナップ生成、装備アイテム、購入確認モーダル、購入演出。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. `PLAN`の「対応済み」は3つとも嘘だった

`PLAN_GUILD_SHOP.md`旧版§5は`get_shop_lineup` / `purchase_shop_item` / `refresh_shop_if_needed`を「反映済み」と書いていたが、実際は**後ろ2つが`print`して`false`を返すだけ**だった。`get_shop_lineup`だけは本実装だったが、ラインナップが空なので常に`[]`を返していた。

**育成・研究に続いて3回目のズレ。** PLANは改訂済みの版を使うこと。

### 2-2. 売るものが無い問題（装備は存在しない）

PLAN旧版は装備アイテムを前提に読めるが、**このプロジェクトに装備アイテムは1つも存在しない。** 育成のときと同じ状況。

第1弾は**素材2種＋スタミナポーション**を売る。装備は`get_effective_stats()`への加算・スロット・戦闘反映がまとめて要るため別タスク。

### 2-3. 素材とアイテムは保存先が違う

`training_material`は`materials`（`add_material()`）、`stamina_potion`は`inventory`（`add_to_inventory()`）に入る。**IDの綴りだけでは判別できない。**

`shop.json`の各スロットに`payout_type`（`"material"` / `"item"`）を持たせ、それで分岐する。推測で分岐させないこと。

### 2-4. `refresh_at`はタイムスタンプではなく「ゲーム内日付の文字列」にした

`DATA_SCHEMA.md` 4-2は`"timestamp"`と書いているが、**実装は`"2026-08-11"`形式の文字列**にした。

理由：判定が`GameDate.get_game_date_string()`との文字列比較1回で済み、4:00境界の計算を`GameDate`の外に漏らさずに済むため。タイムスタンプで持つと、比較のたびに「その時刻はどの"ゲーム内の日"か」を計算し直すことになり、基準がずれる余地ができる。

**`DATA_SCHEMA.md`側を実装に合わせて直す**（§9）。

### 2-5. `_copy_dict()`は浅いコピー

`_copy_dict(DAILY_SHOP)`で取り出しても、**中の`line_up`配列は`_state`と同じ実体を指す。** さらにその中の各スロットも同じ。`duplicate(true)`してから書き換える。§5-1のコードはそうなっている。

### 2-6. `MasterDataLoader`が返す数値は`float`

`cost.amount`・`stock_limit`・`count`は**必ず`int()`で包む。** 包み忘れるとセーブに`300.0`と書かれる。

`purchased_count`も、セーブから戻ると`float`になる。`_sync_shop_from_master()`で`int()`に戻している。

### 2-7. `ShopConfig`（`.tres`）は使わない

`shop_config.gd`は`daily_slot_count` / `weekly_slot_count` / `monthly_slot_count` / `item_pool`だけを持つスケルトンで、**これは抽選（未実装）のための器**。固定ラインナップの第1弾では1つも使わない。

商品ごとに違う値（ID・価格・在庫・個数）は`.tres`の単一値では表せないため、`research.json`と同じく**マスターデータ（`shop.json`）側に置く。** 数値管理ルール（`AGENTS.md`）の趣旨——コードを触らずに調整できる——は満たしている。

**`shop_config.gd`と`shop_config.tres`は1文字も触らない。**

### 2-8. 1回の購入でシグナルが2本飛ぶ

購入すると`resource_changed`（ゴールド）と`shop_changed`が続けて発火する。画面が両方を購読しているため、**再描画が2回走る。**

倉庫画面の`_rebuild_inventory()`のように`queue_free()` + `await process_frame`で書くと、**awaitの間に2本目が削除を終えてしまい、行が二重に並ぶ。** `shop_screen.gd`の`_rebuild()`は`remove_child()`してから`queue_free()`し、`await`を持たない形にしてある。**この形を崩さないこと。**

### 2-9. `stock_limit`が0のスロットは「無制限」ではなく「買えない」

`shop.json`で`stock_limit`を書き忘れたときに無限購入にならないようにするため。無制限を作りたければ大きな数を書く。

### 2-10. `state_keys.gd`は編集不要

`SHOP_REFRESH_AT` / `SHOP_LINE_UP` / `SHOP_SLOT_ID` / `SHOP_ITEM_ID` / `SHOP_COST` / `SHOP_STOCK_LIMIT` / `SHOP_PURCHASED_COUNT` / `COST_CURRENCY_TYPE` / `COST_AMOUNT` / `SHOP_TYPE_DAILY`がすべて揃っている。**このタスクでは1文字も触らない。**

`payout_type` / `count` / `item_type`は`shop.json`側だけのキーで状態には残らないため、`game_manager.gd`の定数にした（`RESEARCH_NODE_COST_*`と同じ扱い）。

### 2-11. 確認モーダルは入れていない

`Modal.confirm()`の待ち方が未確認のため、研究画面と同じく**確認なしで即実行**。ボタンは条件を満たさないと押せない。後から`_on_buy_pressed()`に足せる。**完了条件には含めない。**

---

## 3. 人間がやる作業

### 3-1. `ja.csv`に翻訳キーを追加

**追記の前に、既にあるキーでないか`grep`で確認すること**（`AGENTS.md`「2回書かない」）。**特に`ui_guild_shop_sold_out`は`AGENTS.md`の例に出ているため、既にある可能性が高い。**

| キー | 日本語（案） |
|---|---|
| `ui_guild_shop_buy` | 購入する |
| `ui_guild_shop_sold_out` | 売り切れ |
| `ui_guild_shop_stock` | 在庫 |
| `ui_guild_shop_refreshed_at` | 更新日 |
| `ui_guild_shop_purchased` | 購入しました |
| `ui_guild_shop_failed` | 購入できませんでした |
| `ui_guild_shop_empty` | ショップのデータが読み込めませんでした |

`ui_guild_shop`（タイトル）・`ui_common_back`・`ui_res_gold`は既存。

**次の3つが無いと商品名がキー名のまま並ぶ。必ず確認する。**

| キー | 日本語（案） | 備考 |
|---|---|---|
| `ui_res_training_material` | 訓練素材 | 育成画面で使用済みのはず |
| `ui_res_construction_material` | 建材 | 研究のときに確認済みのはず |
| `ui_res_stamina_potion` | スタミナポーション | **未確認。無い可能性が高い** |

書式指定子（`%d`など）は**どのキーにも入れない。** コード側で`"%s %d/%d"`のように組み立てている。CSVに`%`を書くと二重適用になる。

### 3-2. ファイルの保存

設計役から受け取ったものをそのまま置く。**中身を書き換えない。**

| ファイル | 置き場所 | 種別 |
|---|---|---|
| `game_manager.gd` | `res://autoload/game_manager.gd` | **全文差し替え** |
| `master_data_loader.gd` | `res://scripts/systems/master_data_loader.gd` | **全文差し替え**（末尾追記済みの版） |
| `shop.json` | `res://resources/balance/master/shop.json` | 新規 |
| `shop_screen.tscn` | `res://scenes/guild/shop_screen.tscn` | 新規 |
| `shop_screen.gd` | `res://scenes/guild/shop_screen.gd` | 新規 |

`master_data_loader.gd`は`res://scripts/systems/`にある（`RefCounted`の静的クラスでAutoloadではない）。**このEXECは当初`autoload/`と書いていた。作業場のタスクで訂正済み。**

### 3-3. `guild_screen.gd`の遷移先差し替え（**最後に**）

定数を1つ追加：
```gdscript
const SHOP_PATH: String = "res://scenes/guild/shop_screen.tscn"
```

`GUILD_SCENES`の1行を差し替え：
```gdscript
	"shop": PLACEHOLDER_PATH,
```
↓
```gdscript
	"shop": SHOP_PATH,
```

`_go_to_sub()`は`path == PLACEHOLDER_PATH`のときだけ`change_scene_with_data`を使う分岐なので、**ショップは`else`側（`change_scene`）を通る。修正不要。**

**この差し替えは`shop_screen.tscn`を保存してから行う。** 先にやると遷移先が無くエラーになる。

---

## 4. 決めた数値

### 4-1. 日替わりラインナップ（5スロット・固定）

| slot_id | 商品 | 個数 | 価格 | 在庫 |
|---|---|---|---|---|
| 0 | `training_material` | 10 | gold 300 | 3 |
| 1 | `construction_material` | 10 | gold 300 | 3 |
| 2 | `stamina_potion` | 1 | gold 500 | 2 |
| 3 | `training_material` | 30 | gold 800 | 1 |
| 4 | `construction_material` | 30 | gold 800 | 1 |

1日あたりの上限は**gold 4,600**。まとめ買い（slot 3・4）は単価が1割ほど安い。

**通貨は`gold`のみ。** コードは`gems`にも対応しているが、第1弾のラインナップでは使わない（`gems`の入手経路が実質無いため）。

### 4-2. 価格は仮。ステージ報酬を見て調整すること

**`stages.json`の`gold`の量を確認していない。** 1周で得られるゴールドが分からないまま置いた数字なので、**「1日ぶんを買い切るのに何周必要か」を実際に測ってから直す。**

目安：`training_material`はステージ3で1周6個。ショップのslot 0は10個＝1.7周ぶんを300ゴールドで買えることになる。**1周で300ゴールド前後入るなら釣り合う。** 大きくずれていたら`shop.json`の`amount`だけ直せばよい（再起動で既存セーブにも反映される。§8-2）。

### 4-3. なぜ素材を売るのか

ゴールドの出口として一番短いのが素材。`training_material`は育成、`construction_material`は研究に**既に出口が繋がっている**ため、買った瞬間に使い道がある。

消耗品（`stamina_potion`）を混ぜたのは、`add_to_inventory()`側の経路も1本通しておくため。**装備が入ったとき、`payout_type: "item"`のスロットを足すだけで売れる。**

---

## 5. 設計役が書いたもの

### 5-1. `game_manager.gd`（1051行 → 1323行・全文差し替え）

**原本をコピーして該当箇所だけ差し替えた。既存の関数は1つも変質していない。** 元のファイルから消えたのは、空実装だった`purchase_shop_item()`と`refresh_shop_if_needed()`の中身4行だけ。

| 対象 | 内容 |
|---|---|
| `shop_changed(shop_type)` | **シグナル追加** |
| `SHOP_SLOT_PAYOUT_TYPE` / `SHOP_SLOT_PAYOUT_COUNT` / `SHOP_SLOT_ITEM_TYPE` | 定数追加。`shop.json`側のキー |
| `PAYOUT_TYPE_MATERIAL` / `PAYOUT_TYPE_ITEM` | 定数追加。`payout_type`に入る値 |
| `_ready()` | `_sync_shops_from_master()` → `refresh_shop_if_needed(daily)`の順で呼ぶ |
| `purchase_shop_item()` | **本実装** |
| `refresh_shop_if_needed()` | **本実装** |
| `_find_shop_slot_index()` | 新規（private） |
| `_get_currency_balance()` / `_spend_currency()` | 新規（private） |
| `_sync_shops_from_master()` / `_sync_shop_from_master()` | 新規（private） |
| `load_state()` | `_state`反映の直後に同期→リフレッシュを呼ぶ |
| `get_shop_lineup()` / `_shop_key()` | **変更なし**（元から本実装） |

**`purchase_shop_item()`の判定順**

```
1. shop_type が既知か                    → 不明なら false
2. slot_id が line_up に存在するか        → 無ければ false
3. 在庫が残っているか                     → 売り切れなら false
4. 定義が妥当か（item_id・count・payout_type） → 不正なら false
5. 残高が足りているか                     → 足りなければ false
--- ここから状態を変える。以降に失敗する分岐を作らない ---
6. purchased_count を +1 して _state へ代入し直す
7. 通貨を減らす（add_gold / add_gems）
8. 素材またはアイテムを増やす
9. shop_changed.emit(shop_type)
```

**4を5より先に行う。** `shop.json`の書き間違いで通貨だけ減って何も貰えない、が起きないようにするため。

**6を7より先に行う。** `add_gold()`が`resource_changed`を発火し、それを受けた画面が再描画する。順序が逆だと購入前の在庫で1度描き直される。

**`add_gold()`は残高を確認しない。** 負数を渡せばマイナスまで減る。5の確認は省略できない。

**`refresh_shop_if_needed()`の仕様**

- `GameDate.get_game_date_string()`と`refresh_at`を文字列で比較する
- 違っていれば全スロットの`purchased_count`を0に戻し、`refresh_at`を今日にする
- **`daily`以外は何もせず返す。** 週・月の区切りが未確定のため、誤って日単位でリセットしないよう明示的に弾いている
- 呼ばれるのは3箇所：`_ready()` / `load_state()` / **ショップ画面を開いたとき**

> 画面を開いたときにも見るのは、**起動しっぱなしで4:00をまたぐ**場合があるため。起動時のチェックだけだと在庫が戻らない。

**`_sync_shop_from_master()`の仕様**

- `shop.json`の全スロットを`line_up`へ流し込む
- **`purchased_count`だけは既存の値を残す**（`stock_limit`を下げたときは上限で切り詰める）
- `item_id` / `cost` / `stock_limit` / `payout_type` / `count` / `item_type`は毎回マスターデータで上書き
- **`refresh_at`には触らない**（ここで消すと起動のたびに在庫が戻る）

研究の`_sync_research_tree_from_master()`と同じ型（`AGENTS.md`「マスターデータと状態を同期する型」）。

> **`shop.json`から消えた`slot_id`はラインナップからも消える。** `slot_id`を振り直すと購入回数が別の商品に付け替わる。**番号は使い回さないこと。**

### 5-2. `master_data_loader.gd`（179行 → 225行・末尾追記のみ）

`get_research_node()`と同じ形にそろえた。**既存の関数・定数・`static var`には一切触っていない。**

- `PATH_SHOP` / `_cache_shop` / `_shop_loaded`
- `get_shop_slots(shop_type)` — 1種別ぶんのスロット定義を返す
- `get_all_shop_types()` — `shop.json`にある種別を全て返す。`GameManager`の同期処理が使う
- `_ensure_shop_loaded()` — 遅延ロード。`_ensure_loaded()`には組み込まない

**他の5ファイルと違い、`shop.json`は値が`Array`。** `get_shop_slots()`は`Array`かどうかを確認してから返している。

### 5-3. `shop.json`（新規）

§4-1の5スロット。`purchased_count`は**書かない**（状態側だけが持つ）。

### 5-4. `shop_screen.tscn` / `shop_screen.gd`（新規）

```
ShopScreen (Control)              ← script: shop_screen.gd
├── Background (ColorRect)
└── Margin (MarginContainer)       上下左右 24
	└── Layout (VBoxContainer)
		├── TitleLabel (Label)      text = "ui_guild_shop"
		├── GoldLabel (Label)       所持ゴールド
		├── RefreshLabel (Label)    在庫が戻った日付
		├── Scroll (ScrollContainer)
		│   └── SlotList (VBoxContainer)   商品行をコードで生成
		├── NoticeLabel (Label)     購入結果
		└── BackButton (PrimaryButton)     label_key = "ui_common_back"
```

研究画面と同じ作り。1画面・スクロール・行をコードで生成・詳細画面なし。**戻るボタンは1つだけ。**

商品行：`名前 ×個数` / `gold 300` / `在庫 3/3` / 購入ボタン。

**`RefreshLabel`を置いたのが要点。** 在庫が戻ったことが画面から確認できないと、翌日に数字が変わった理由が分からない（研究画面の`CapLabel`と同じ理由）。

購入ボタンは**売り切れ・残高不足のとき`disabled`**。同じ判定を`GameManager`側も持っているため二重に守っている。

---

## 6. 作業の順番

1. 人間：§3-1（`ja.csv`）
2. 人間：§3-2（ファイルの保存）
3. 人間：§7（起動ログ）を確認
4. 人間：§3-3（`guild_screen.gd`の差し替え）
5. 人間：§8を実機で確認
6. 人間：§8-2（ファイル）を確認

**1を飛ばすと画面に翻訳キーがそのまま並ぶ。** 動作はするので後から足してもよい。

---

## 7. 完了条件：ログで確認する

**画面を操作すれば分かることはここに書かない。** §8にだけ書く。

- [ ] L-1. 起動ログに`[GameManager] _sync_shop_from_master('daily') -> 5 slots`が出る
- [ ] L-2. 続けて`[GameManager] refresh_shop_if_needed('daily') -> refreshed ( -> 2026-XX-XX, 5 slots)`が出る（初回のみ。2回目以降の起動は`no refresh`）

**`0 slots`または警告が出たときの切り分け（2手まで）**

| | 見るところ |
|---|---|
| 1 | `shop.json`が`res://resources/balance/master/`に置かれているか。パスの綴り |
| 2 | 出力に`[MasterDataLoader] load() returned null`か`FileAccess.open failed`が出ていないか |

3つ目に進まず報告すること。

---

## 8. 完了条件：画面で確認する

**ここがこのタスクの本体。**

- [ ] S-1. ギルド画面の「ショップ」ボタンからショップ画面へ遷移する
- [ ] S-2. 商品が5つ、縦に並んで表示される
- [ ] S-3. 各行に商品名・個数・価格・在庫が出ている
- [ ] S-4. 上部に所持ゴールドと更新日が出ている
- [ ] S-5. 所持ゴールドが足りない商品は購入ボタンが押せない
- [ ] S-6. 買える商品を押すと、**画面を出入りせずに**所持ゴールドが減る
- [ ] S-7. 同時にその行の在庫が1つ減る（例：`3/3` → `2/3`）
- [ ] S-8. **行が二重に並ばない**（§2-8）
- [ ] S-9. 在庫を使い切ると、その行のボタンが「売り切れ」になり押せなくなる
- [ ] S-10. 一覧が長くなってもスクロールできる
- [ ] S-11. 戻るボタンでギルド画面へ戻る。**戻るボタンが2つ並んでいない**
- [ ] S-12. 倉庫画面の持ち物に`stamina_potion`が増えている（slot 2を買った場合）
- [ ] S-13. 拠点画面の素材表示が、買った数だけ増えている
- [ ] S-14. **育成画面でレベルを上げられる**（買った`training_material`が実際に使える）
- [ ] S-15. セーブして再起動しても、その日の購入回数が保持されている（在庫が戻っていない）

**S-14がこのタスクの本題。** ゴールドが素材に変わり、素材が育成に流れることはここでしか確認できない。

---

## 8-2. 完了条件：ファイルで確認する

### 価格を変えると既存セーブに反映されるか

1. `shop.json`のslot 0の`amount`を`300` → `400`に書き換えて保存する
2. **Godotエディタごと再起動する**（`.json`の再インポートを効かせるため）
3. ショップ画面を開く

- [ ] M-1. slot 0の価格が`400`になっている
- [ ] M-2. その日の購入回数が**保持されている**（在庫が`3/3`に戻っていない）
- [ ] M-3. `300`に戻して再起動すると、元に戻る

**M-1とM-2は両方通って初めて意味がある。** 片方だけでは同期の半分しか確認できていない。

**M-1で変わらないとき**は、エディタを再起動していないか`.json`が再インポートされていない。FileSystemパネルで`shop.json`を右クリック →「再インポート」。ここまでで止めて報告すること。

### 在庫が翌日に戻るか（1日待たずに確認する）

1. 何か買ってからセーブし、ゲームを終了する
2. `save_slot_0.json`をテキストエディタで開く
3. `daily_shop`の`refresh_at`を`"2020-01-01"`に書き換えて保存する
4. ゲームを起動してロードする

- [ ] F-1. `save_slot_0.json`に`daily_shop`があり、`line_up`に5件、`refresh_at`に**今日の日付**が入っている（3の書き換え前に確認）
- [ ] F-2. `cost`の`amount`と`stock_limit`が`300`のように書かれている。**`300.0`になっていない**
- [ ] F-3. ロード後、ショップ画面の在庫が全て満タンに戻っている
- [ ] F-4. 同時に`RefreshLabel`の日付が今日に変わっている

**F-2が`300.0`だったら`int()`の包み忘れ。** 報告すること。

---

## 8-3. UIから到達できない項目（人間は確認しない）

**以下は画面から実行できない。** 将来コードを変えたときに見る保険であって、今回の確認項目ではない。

| 経路 | 期待する挙動 |
|---|---|
| 売り切れのスロットを再度`purchase_shop_item()` | `false`。ログに`sold out`。ゴールドが減らない |
| 存在しない`slot_id`を渡す | `false`。ログに`slot not found`。クラッシュしない |
| `shop_type`に`"weekly"`を渡す | ラインナップが空なので`false`。`refresh_shop_if_needed()`は`skip` |
| `stock_limit`が`0`のスロット | 買えない（無制限にはならない）。§2-9 |
| `cost.amount`が`float`のまま保存される | 起きない。`_sync_shop_from_master()`が`int()`で包む |

**ボタンは条件を満たさないと押せないため、上の1つ目と2つ目は画面から起こせない。**

---

## 9. 併せて直すもの

| ファイル | 内容 |
|---|---|
| `PLAN_GUILD_SHOP.md` | **改訂済み**。§5「対応済み」の訂正、スコープを`daily`固定に縮小、`refresh_at`の型変更を反映 |
| `DATA_SCHEMA.md` 4-2 | `refresh_at`を`"timestamp"`から**ゲーム内日付の文字列**へ。`line_up`の要素に`payout_type` / `count` / `item_type`を追記 |
| `AGENTS.md`「GameManagerのシグナル」 | `shop_changed`を追記 |
| `NEXT_STEPS.md` | 次のタスク（作業場）の内容に書き換える |
| `PROJECT_STATUS.md` | ショップの項を「完了」へ。「ゴールドの出口が無い」の記述を消す |

---

## 10. このタスクで残した宿題

- **週替わり・月替わりショップ。** 週・月の区切りが未確定。`GameDate`に`get_game_week_string()`のような関数を足してから
- **抽選によるラインナップ生成。** `ShopConfig`の`item_pool` / `daily_slot_count`はそのために置いてある。`refresh_shop_if_needed()`の中でラインナップを組み直せば、呼び出し側は変わらない
- **`Modal.confirm`による購入確認**（§2-11）
- **価格の調整**（§4-2）。ステージ報酬のゴールドを測ってから
- **装備を売る。** `payout_type: "item"`のスロットを足すだけで売れる状態にはなっている。装備そのものが別タスク
- `MasterDataLoader`に`get_all_characters()`を足す（`NEXT_STEPS.md`の宿題。`get_all_shop_types()`と同じ形）
