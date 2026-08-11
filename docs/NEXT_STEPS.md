# 次にやること：ギルドのショップ

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は`PROJECT_STATUS.md`、手順の型は`WORKFLOW.md`。

---

## なぜショップが次なのか

**ゴールドに出口が1つも無い。**

戦闘の報酬でゴールドは増える。`apply_battle_rewards()`が扱うのは`gold`と`materials`だけで、そのゴールドを使う場所がどこにもない。**貯まる一方の数字になっている。**

素材のほうは、育成と研究で出口が2つ開いた。

```
戦闘で training_material / construction_material / gold を得る
  → 育成で training_material を使う      ✅ 済
  → 研究で construction_material を使う  ✅ 済
  → ショップで gold を使う               ← ここ
```

---

## 研究と決定的に違うところ

**研究は読み取り側が既に本実装だった。** `get_effective_level_cap()`と`get_stat_boost_all()`が動いていて、書き込み側（`unlock_research_node`）だけを足せばよかった。

**ショップは全部空実装。** 3つとも中身が無い。

| 関数 | 現在 |
|---|---|
| `get_shop_lineup(shop_type)` | `_state`から読むが、ラインナップが空なので常に`[]` |
| `purchase_shop_item(shop_type, slot_id)` | `print`して`false`を返すだけ |
| `refresh_shop_if_needed(shop_type)` | `print`のみ。何もしない |

**接続先も無い。** 研究は育成画面が既に`get_effective_level_cap()`を呼んでいたが、ショップで買ったものを受け取る側（インベントリ）は`add_to_inventory()`があるだけで、購入と結びついていない。

**研究より1段階重い。見積もりを研究と同じにしないこと。**

---

## 最初にやること

新しい会話を開いて、設計役（Claude）に以下を渡す。

1. `PROJECT_STATUS.md`
2. このファイル
3. `AGENTS.md`
4. `PLAN_GUILD_SHOP.md`（第2層。既にある）
5. `DATA_SCHEMA.md` の 4-2「ショップ」
6. **`EXEC_GUILD_RESEARCH.md`**（直前のタスク。書き方を揃えるため）

そのうえで、**実コードを見せる。**

- `autoload/game_manager.gd`（`get_shop_lineup` / `purchase_shop_item` / `refresh_shop_if_needed` / `add_to_inventory`まわり）
- `autoload/master_data_loader.gd`（**研究で末尾追記した版**）
- `resources/balance/shop_config.gd`（**中身が未確認。研究の`ResearchConfig`と同じく空かもしれない**）
- `scenes/guild/guild_screen.gd` と `.tscn`
- **`scenes/guild/research_screen.gd` と `.tscn`**（同じ作りに揃えるため）
- `scripts/utils/state_keys.gd`
- `scripts/utils/game_date.gd`（**リフレッシュ判定で要る**）
- `scenes/guild/warehouse_screen.gd`（買ったものの受け取り先）

**`PLAN_GUILD_SHOP.md`は実コードを見ずに書かれている可能性が高い。**

育成のPLANは装備アイテムが1つも存在しないのに装備前提で書かれていた。研究のPLANは`unlock_research_node()`を「対応済み」と書いていたが空実装だった。**2回続けてズレている。突き合わせて、ズレがあればPLANを先に直す。**

**特に「対応済み」「実装済み」という記述は信じないこと。** `grep`で関数の中身を見てから判断する。

---

## このタスクでいま分かっていること

### 使えるもの

| もの | 状態 |
|---|---|
| 状態の構造 | `state_keys.gd`に一式ある（`DAILY_SHOP` / `WEEKLY_SHOP` / `MONTHLY_SHOP` / `SHOP_REFRESH_AT` / `SHOP_LINE_UP` / `SHOP_SLOT_ID` / `SHOP_ITEM_ID` / `SHOP_COST` / `SHOP_STOCK_LIMIT` / `SHOP_PURCHASED_COUNT` / `COST_CURRENCY_TYPE` / `COST_AMOUNT`）。**中身は空** |
| `_shop_key(shop_type)` | 実装済み。`"daily"`→`DAILY_SHOP`の変換 |
| `add_to_inventory(item_id, count, item_type)` | **本実装済み。** 図鑑の`discovered`も自動で立つ |
| ゴールドの増減 | `add_gold()` / `resource_changed`シグナル。**`add_gold()`は残高を確認しない** |
| `GameDate` | 4時基準の日付判定。**リフレッシュ時刻の判定はここに集約する。自分で書かない** |
| マスターと状態の同期の型 | **研究で作った`_sync_research_tree_from_master()`。** ショップも同じ考え方で書ける |
| `MasterDataLoader` | 研究で`get_research_node()` / `get_all_research_nodes()`を末尾追記済み。**同じ形で`items.json`を足せる** |
| 研究画面 | 1画面・スクロール・行をコードで生成。**ショップも同じ作りにできる** |

### 決めることになるはず

- **第1弾はどのショップか。** `daily` / `weekly` / `monthly`の3つがあるが、**まず`daily`だけでいい**
- **リフレッシュをどう判定するか。** `refresh_at`と`GameDate`の突き合わせ。**ここがこのタスクで一番難しい**
- **ラインナップを抽選するか、固定にするか。** 第1弾は**固定でいい**（抽選テーブルは未確定のまま）
- 売るものは何か。**現時点で装備アイテムが1つも存在しない**
- `stock_limit`（購入回数の上限）を第1弾に入れるか
- 通貨は`gold`だけにするか、`gems`も使えるようにするか

### スコープの目安

**第1弾は「固定ラインナップのdailyショップだけ」でいい。**

理由は、それだけで「ゴールドを使う → 何かが手に入る」が成立するから。**抽選もリフレッシュも無くていい。**

ただし**リフレッシュが無いと在庫が復活しない。** `stock_limit`を入れるなら、リフレッシュもセットで要る。**この2つは切り離せない。設計役と相談して決める。**

### 売るものの問題

**装備アイテムが1つも存在しない。** 育成のPLANが装備前提で書かれていて、実物が無くてスコープごと書き直しになった件と同じ状況。

**素材か消耗品を売るのが素直。** 具体的には：

- `training_material` / `construction_material` をゴールドで買えるようにする
- `stamina_potion` をゴールドで買えるようにする（**既に実装済みのアイテム**）

**装備を作るのはこのタスクに含めない。** 装備は`get_effective_stats()`への加算・スロット・戦闘反映がまとめて要る。別タスク。

### 見た目の注意

**研究画面と同じ作りにする。** 1画面・スクロール・行をコードで生成・詳細画面なし。

**戻るボタンは1つだけ。** 育成で2つ並んだ件を繰り返さない。

---

## 渡し方（研究のときと同じ）

### 完了条件は「どこを見るか」で3つに分ける

**担当者（A章／B章）で分けない。** 実装役を使わないタスクが2回続いており、その分け方は機能しない。

| 種類 | 例 |
|---|---|
| **ログ** | 起動時の同期件数、`purchase_shop_item()`の失敗理由 |
| **ファイル** | `save_slot_0.json`の`daily_shop` |
| **画面** | ラインナップの表示・購入・残高の更新・遷移 |

**同じことを2箇所に書かない。** 研究では16項目中10項目が重複していた。画面を操作すれば分かることは、画面の章にだけ書く。

**UIから到達できない項目（在庫切れの再購入・存在しない`slot_id`）は人間の確認項目にしない。** 別枠にするか書かない。

### 誰が書くか

**研究では実装役に投げず、設計役が`.gd`・`.tscn`・`.json`を全部書いた。** 事故ゼロ。育成に続いて2回目。

ショップも同じ判断でよい。ただし`game_manager.gd`（**現在1051行**）に手を入れるので、**必ず設計役が全文を書く。** 原本をコピーして該当箇所だけ差し替える方式なら、既存関数が変質しない。

### 止まる条件（実装役を使う場合）

- 1つのファイルへの書き込みが2回失敗したら中止して報告
- 1つの症状に対して試す方法は2つまで
- 実装できなかったものは「未実装」と正直に書いてよい

---

## 研究で分かった罠（ショップでも踏む）

### `_copy_dict()`は浅いコピー

`_copy_dict(DAILY_SHOP)`で取り出しても、**中の`line_up`配列は`_state`と同じ実体を指す。** もう一段`duplicate(true)`してから書き換える。

### `MasterDataLoader`が返す数値は`float`

`cost.amount`・`stock_limit`は**必ず`int()`で包む。** 包み忘れるとセーブに`100.0`と書かれる。

### 状態を変える前に全部の判定を終える

研究の`unlock_research_node()`は「存在 → 解放済み → 前提 → 素材」の順に判定し、**通ってから初めて状態を触る。** ショップも「存在 → 在庫 → 残高」を先に全部確認する。

`add_gold()`は残高を確認しない。**負数を渡せばマイナスまで減る。**

### マスターの変更を既存セーブに反映する

研究では起動時とロード時にマスターから流し込み、**進捗（`unlocked`）だけ残した。** ショップも同じ形にすると、価格を変えたときに既存セーブへ反映される。

**進捗にあたるのは`purchased_count`。** ここだけ残す。

### 検証手順は、その出力が実在することを確かめてから書く

育成で「ログで確認する」と書いたが、その`print`に該当項目が無かった。**書く前にコードを見る。**

---

## ショップのあとの順番

1. **作業場** — 素材の出口。時間投資型
2. **装備** — `get_effective_stats()`への加算まで含めて1タスク
3. **パーティ選択** — 第2層から書く
4. **バランス調整** — ここで初めて実際に何日か使う

**装備が入るまで、本格的な試用はしない。** 数値の調整もそれまで待つ。全部JSONか`.tres`なので後から変えられる。

---

## 溜まっている宿題（気が向いたら）

`PROJECT_STATUS.md`の「溜まっている宿題」を参照。特に以下は小さいのに効く。

- **`MasterDataLoader`に`get_all_characters()`を足す。** 研究で`get_all_research_nodes()`を書いたので同じ形。**末尾追記だけで`training_screen.gd`の`CHARACTER_IDS`決め打ちが消せる**
- 研究の解放に確認モーダルを足す（`Modal.confirm`の待ち方を確認してから）
- 受け取り報告で「宝箱を0個」と出るのを直す
- 拠点下部のレイアウト調整
- プロジェクト直下のゴミファイル（`bash`など）を削除
