# 【実行指示書】ギルド - 装備（第1弾：武器スロット1つ・`atk`加算のみ・作業場で作れる）

**このファイルにコードは載せない。** 差し替えるコードはチャット上に出したものが正。ここが持つのは、決定事項・事故りやすい箇所・触るファイル一覧・完了条件だけ。

同じコードがチャットとEXECの2箇所にあると、修正が入ったときにどちらが正か分からなくなるため。

**実装役は使わない。設計役が`.gd`・`.tscn`・`.json`を全部書き、人間が当てる。**（育成・研究・ショップ・作業場と同じ。5回目）

---

## 1. このタスクで実現すること

**「作業場で武器を作る → 装備する → 戦闘のダメージが増える」を1本通す。**

```
建築素材20 を作業場に入れて30分待つ
  → 木の剣（atk +3）が倉庫に入る
  → 装備画面で剣士に装備する
  → 育成画面の atk が +3 された値になる
  → 戦闘のダメージ数値が増える
```

これで、ショップ・作業場・宝箱の3つが抱えていた「渡す物が無い」が解消する。

**種類・スロット・ステータスを増やすのはこのあと。** 第1弾は武器スロット1つ、装備3種（＋検証用1種）、`atk`加算のみ。

---

## 2. 事故りやすい箇所（先に読むこと）

### 2-1. 戦闘は`get_effective_stats()`を呼んでいなかった

`NEXT_STEPS.md`は「戦闘側で`get_effective_stats()`を呼んでいる箇所」と書いていたが、**実際には呼んでいない。** `battle_controller.gd`の`_init_party_units()`が`get_character_growth()`の生の`stats`を直接読んでいた。

**PLANの記述が事実と違ったのは5回目。**（育成・研究・ショップ・作業場・装備）

この差し替えをしないと、装備を実装しても戦闘のダメージは1ミリも変わらない。

### 2-2. 研究の全ステータス+3が、初めて戦闘に効く

2-1の差し替えの副作用。研究ノード`stat_boost_all`は育成画面には出ていたが、戦闘には乗っていなかった。**既存セーブで敵が急に柔らかくなる。意図した変更として受け入れる**（人間の判断済み）。

バランス調整のときに、この分を織り込んで測ること。

### 2-3. 装備の性能値は状態に持たない

状態が持つのは`character_growth.equipment.weapon`に入る`item_id`だけ。性能値は`get_equipment_bonus()`が毎回`items.json`から引き直す。

こうすると`equip_stats`を調整したときに既存セーブへも次の起動で反映される（育成の`stats`・研究の`effect_value`と同じ扱い）。

**代償：`items.json`からIDが消えると、装備していたものの加算が消える。リリース後にアイテムIDを改名しないこと。**（レシピIDと同じ制約）

### 2-4. `MasterDataLoader`が返す数値は`float`

`equip_stats`の値も必ず`int()`で包む。包み忘れると`get_effective_stats()`が`atk: 55.0`を返し、戦闘の計算と表示に`.0`が乗る。

### 2-5. 1回の着脱で2本のシグナルが飛ぶ

`equip_item()`は`inventory_changed`（在庫が減る）と`character_growth_changed`（装備が変わる）を続けて発火する。外すときも同じ。

**装備画面の再描画に`await`を持たせない。** `remove_child()`してから`queue_free()`する（`AGENTS.md`「再描画は await を持たせない」）。ショップで行が10行並んだのと同じ事故になる。

### 2-6. 状態を変える前に全部の判定を終える

`equip_item()`の判定順：キャラ存在 → スロット妥当 → `items.json`に存在 → `item_type == equipment` → `equip_slot`が一致 → 所持。

**装備品でないアイテム（スタミナポーション等）を装備できてしまわないこと。** UIからは到達できないが、判定が抜けていると次に画面を変えたときに通ってしまう。

### 2-7. `load_state()`は触らない

装備は状態にマスターデータの複製を持たない（`item_id`だけ）ため、`_sync_*_from_master()`にあたるものが要らない。**研究・ショップ・レシピと違う点。** 同期処理を足そうとしないこと。

### 2-8. 30分待たない

`recipes.json`の`debug_instant`（10秒）が残っているので、作業場の動作確認はそれで済む。装備そのものの確認は`shop.json`の`weapon_debug_blade`（100G・`atk +50`）を買えば即できる。

---

## 3. 決定事項

| 論点 | 決定 |
|---|---|
| **性能データの置き場所** | **`items.json`の各エントリに`equip_slot`と`equip_stats`を持たせる。** `equipment.json`は作らない（`_item_storage()`と`_grant_item()`が既に`items.json`を引いており、性能だけ別ファイルにすると同期の型がもう1枚要る）。`.tres`は却下（装備ごとに違う値は単一値で表せない。`ShopConfig`と同じ結論） |
| **スロット** | **第1弾は`weapon`だけ。** 状態側は`armor` / `accessory`も`null`で作られているが画面に出さない。`_equip_slots()`は最初から3つ返す |
| **ステータス** | **コードは4ステータス対応、データは`atk`だけ書く。** `get_effective_stats()`は既に`_stat_keys()`をループしているため、4対応にしてもコード量が変わらない |
| **`atk_multiplier`** | **触らない。** 加算のみ。`battle_controller.gd`で`1.0`固定のまま。加算と乗算を両方入れない |
| **装備画面の置き場所** | **独立画面**（`scenes/guild/equipment_screen.tscn`）。育成画面は既に一覧／詳細の切り替えを抱えており、行生成のリストを足すと1ファイルで2画面分の状態を持つことになる |
| **画面遷移** | 育成の詳細 → `EquipButton` → 装備画面（`TransferKeys.CHARACTER_ID`で対象を渡す）→ 戻る → 育成画面。**戻るボタンは1つだけ** |
| **在庫との整合** | **装備したら在庫から1つ減り、外したら戻る。** 装備中のものは倉庫にも一覧にも出ない。同じ装備を2人に着けたければ2つ作る |
| **持ち替え** | 既に着けているものがあれば、先に在庫へ戻してから新しいものを消費する。同じIDを着け直した場合は差し引きゼロ |
| **入手経路** | 作業場（`craft_wooden_sword` 30分／`craft_iron_sword` 3時間）とショップ（検証用のみ）。**コード側の変更は不要**。宝箱への投入は第2弾 |
| **検証用の装備** | `weapon_debug_blade`（`atk +50`・ショップで100G）。**`debug_instant`と同じくリリース前に消す**（宿題へ） |

---

## 4. 触るファイル一覧

| ファイル | 変更 | 誰が |
|---|---|---|
| `scripts/utils/transfer_keys.gd` | `CHARACTER_ID`を1行追記 | 人間 |
| `scripts/utils/state_keys.gd` | **触らない**（`ITEM_TYPE_EQUIPMENT` / `EQUIP_WEAPON`は既にある） | — |
| `autoload/game_manager.gd` | 差し替え3箇所（定数追加・`get_effective_stats()`・`equip_item()`まわり一式） | 設計役が書き、人間が当てる |
| `scenes/adventure/battle_controller.gd` | 差し替え1箇所（`_init_party_units()`の6行） | 人間 |
| `scenes/guild/training_screen.gd` | 差し替え3箇所（定数・接続・ハンドラ追加） | 人間が当てる |
| `scenes/guild/equipment_screen.gd` | 新規 | 設計役 |
| `scenes/guild/equipment_screen.tscn` | 新規 | 設計役 |
| `resources/balance/master/items.json` | 装備3種＋検証用1種を追加 | 人間が当てる |
| `resources/balance/master/recipes.json` | レシピ2本を追加 | 人間が当てる |
| `resources/balance/master/shop.json` | 1スロット追加（検証用） | 人間が当てる |
| `localization/ja.csv` | 15行追記 | **人間のみ** |

---

## 5. 完了条件

**項目番号と文言をそのまま転記して検証すること。** 要約したり作り直したりしない。

### 5-1. ログ（Godotの出力パネルを見る）

画面に出ない内部の値だけをここに書いている。画面を操作すれば分かることは5-3にしか書いていない。

1. 起動時に `[MasterDataLoader] loaded 7 entries from res://resources/balance/master/items.json` が出る（装備3種＋検証用1種を足したため4→7）
2. 起動時に `[MasterDataLoader] loaded 6 entries from res://resources/balance/master/recipes.json` が出る（レシピ2本を足したため4→6）
3. 装備したとき `[GameManager] equip_item('char_swordsman', 'weapon', 'weapon_wooden_sword') -> true (previous= bonus={...})` が出て、`bonus`の`atk`が`items.json`の`equip_stats`と一致する
4. `bonus`の値に`.0`が付いていない（`atk: 3`であって`atk: 3.0`でない）
5. 装備したとき `[GameManager] _remove_from_inventory('weapon_wooden_sword', 1) -> 0` が続けて出る
6. 外したとき `[GameManager] unequip_item(...) -> true (returned=weapon_wooden_sword bonus={...})` が出て、`bonus`が全部`0`になる
7. 外したとき `[GameManager] add_to_inventory('weapon_wooden_sword', 1, type='equipment') -> count=1` が出る
8. 別の武器へ持ち替えたとき、`previous=`に前の武器IDが入り、その武器の`add_to_inventory`が出ている

### 5-2. ファイル（`user://saves/save_slot_0.json`をテキストエディタで開く）

1. 装備してセーブすると、`character_growth.char_swordsman.equipment.weapon` に `"weapon_wooden_sword"` が入っている
2. 同じとき、`inventory` から `weapon_wooden_sword` のエントリが消えている（1個しか持っていなかった場合）
3. 外してセーブすると、`equipment.weapon` が `null` に戻り、`inventory` に `weapon_wooden_sword` が `count: 1` で戻っている
4. `character_growth.char_swordsman.stats` に装備分が**混ざっていない**（レベル由来の素の値のまま。`atk`が`18`のままで`21`になっていない）
5. `equipment.weapon` に性能値がコピーされていない（`item_id`の文字列だけが入っている）
6. 数値に `.0` が付いていない

### 5-3. 画面（実機で触る）

1. ショップで`weapon_debug_blade`を買うと、倉庫の持ち物タブに「【検証用】試し斬りの剣」として出る
2. 育成画面 → 剣士の詳細 → 「装備」を押すと装備画面へ遷移する（`placeholder`ではない）
3. 装備画面の上部に、剣士の名前とレベルが出ている
4. 装備画面に「武器：なし」と出ており、「外す」ボタンが押せない
5. 「持っている装備」に、所持している武器が並んでいる（数と「攻撃 +3」等が出ている）
6. 装備品でないもの（スタミナポーション）が一覧に出ていない
7. 「装備する」を押すと、上部の`atk`の値が増え、末尾に `(+3)` のような内訳が出る
8. 同時に、その装備が一覧から消え、「武器：木の剣」に変わり、「外す」が押せるようになる
9. **行が二重に並んでいない**（着脱を5回繰り返して確認する）
10. 「外す」を押すと一覧に戻り、`atk`が元の値に戻り、内訳の `(+3)` が消える
11. 別の武器を装備すると、前の武器が一覧に戻り、新しい武器が一覧から消える
12. 装備した状態で倉庫を開くと、その装備が持ち物タブに出ていない
13. 戻るボタンが1つだけで、押すと育成画面に戻る
14. 育成画面の剣士の詳細で、`atk`が装備分を含んだ値になっている
15. **その状態でステージ1に入り、剣士の通常攻撃のダメージ数値が装備前より大きい**（`weapon_debug_blade`の`atk +50`で試すと一目で分かる）
16. F3のデバッグパネルで、剣士の`atk`が装備込みの値になっている
17. 作業場に「建築素材 ×20 → 木の剣 ×1」の行が出ており、開始して受け取ると倉庫に入る
18. アプリを再起動しても、装備した状態と`atk`の値が保たれている

**15が今回の本体。** ここが通らなければ`battle_controller.gd`の差し替えが当たっていない。

### 5-4. 将来コードを変えたときに見る項目（人間の確認項目ではない）

UIから到達できないため、実機では試せない。コードを変えたときの保険として書き残す。

- 存在しない`character_id`を渡すと`false`を返し、状態が変わらない
- `item_type`が`equipment`でないIDを渡すと`false`を返す
- `equip_slot`が`armor`の装備を`weapon`スロットに渡すと`false`を返す
- 所持数0のIDを渡すと`false`を返す
- `items.json`から消えたIDを装備したままロードすると、`push_warning`が出て加算が0になる（装備は外れない）

---

## 6. 止まる条件

- 1つの症状に対して**2手まで**。3手目に進まず報告する
- **1ファイルへの書き込みが2回失敗したら中止する**（方法を変えても回数に数える）
- 切り分けのために本番コードを書き換えない
- 原因を「環境の問題」と結論づけない。観測した事実だけ報告する

---

## 7. 実施結果
## 7. 実施結果

ログ8項目・ファイル6項目・画面18項目、すべて通った。

### 通らなかった項目

なし。ただし画面15（戦闘のダメージが増える）が最初は通らず、
原因は battle_controller.gd の差し替えが当たっていなかったこと。
当て直して通った。**5回連続で事故ゼロ。**

### やり残し

- 検証用の4スロット（shop.json・0G）と weapon_debug_blade を消していない
- 防具・装飾スロットは器のまま。hp / def / spd を上げる装備は無い
- 宝箱の中身に装備を入れていない

### このタスクで直したドキュメント

- NEXT_STEPS.md：「戦闘側で get_effective_stats() を呼んでいる箇所」が誤り。
  実際には呼んでおらず、生の stats を直接読んでいた（PLANのズレ5回目）
（実装後に記入する）

### 通らなかった項目

### やり残し

### このタスクで直したドキュメント

---

## 8. このタスクのあとに増える宿題

- **`weapon_debug_blade`を`items.json`と`shop.json`から消す。** リリース前に必ず。`debug_instant`と同じ扱い
- 装備の第2弾：防具・装飾スロット、`hp` / `def` / `spd`を上げる装備、宝箱への投入
- ショップの装備ラインナップ（現在は検証用の1スロットのみ）
- `MasterDataLoader.get_all_characters()`（`training_screen.gd`の`CHARACTER_IDS`決め打ちが消せる。末尾追記だけ）
- 装備の確認モーダル（`Modal.confirm`の待ち方を確認してから）
- **バランス調整。** 研究の+3が戦闘に効き始めた分と、装備の加算幅を合わせて実測する
